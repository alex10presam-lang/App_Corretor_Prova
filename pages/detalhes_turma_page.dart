// lib/pages/detalhes_turma_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/aluno.dart';
import '../models/prova.dart';
import '../models/resultado.dart';
import '../models/turma.dart';
import '../services/aluno_service.dart';
import '../services/export_service.dart';
import '../services/pdf_service.dart'; // <-- Import do PdfService
import '../services/prova_service.dart';
import '../services/resultado_service.dart';
import 'adicionar_aluno_page.dart';
import 'editar_aluno_page.dart';

class DetalhesTurmaPage extends StatefulWidget {
  final Turma turma;
  const DetalhesTurmaPage({super.key, required this.turma});

  @override
  State<DetalhesTurmaPage> createState() => _DetalhesTurmaPageState();
}

class _DetalhesTurmaPageState extends State<DetalhesTurmaPage> {
  final AlunoService _alunoService = AlunoService();
  final ProvaService _provaService = ProvaService();
  final ResultadoService _resultadoService = ResultadoService();
  final ExportService _exportService = ExportService();
  final PdfService _pdfService = PdfService(); // <-- Instância do PdfService

  bool _isExporting = false;
  bool _isGeneratingPdf = false; // <-- Novo estado de loading

  // <<-- NOVA FUNÇÃO PARA GERAR AS FOLHAS DE RESPOSTA -->>
  Future<void> _gerarFolhasDeResposta(List<Aluno> alunos) async {
    if (alunos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione alunos à turma antes de gerar as folhas de resposta.',
          ),
        ),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      // 1. Busca as provas associadas a esta turma
      final List<Prova> provasDaTurma = await _provaService
          .listarProvasPorTurma(widget.turma.id!)
          .first;
      if (provasDaTurma.isEmpty) {
        throw Exception(
          'Nenhuma prova encontrada para esta turma. Crie uma prova primeiro.',
        );
      }

      // 2. Mostra um diálogo para o professor escolher a prova
      final Prova? provaSelecionada = await showDialog<Prova>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Selecionar Prova'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provasDaTurma.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(provasDaTurma[index].titulo),
                    onTap: () =>
                        Navigator.of(context).pop(provasDaTurma[index]),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (provaSelecionada == null) return; // O usuário cancelou

      // 3. Gera o PDF para a turma e prova selecionadas
      final pdfBytes = await _pdfService.gerarFolhasDeRespostasParaTurma(
        prova: provaSelecionada,
        turma: widget.turma,
        alunos: alunos,
      );

      // 4. Salva e abre o ficheiro
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Folhas_de_Resposta_${widget.turma.nome}.pdf'.replaceAll(
        ' ',
        '_',
      );
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _exportarBoletim() async {
    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final turmaId = widget.turma.id!;
      final results = await Future.wait([
        _alunoService.listarAlunos(turmaId).first,
        _provaService.listarProvasPorTurma(turmaId).first,
        _resultadoService.listarResultadosPorTurma(turmaId).first,
      ]);

      final List<Aluno> alunos = results[0] as List<Aluno>;
      final List<Prova> provas = results[1] as List<Prova>;
      final List<Resultado> resultados = results[2] as List<Resultado>;

      await _exportService.exportarBoletimTurma(
        turma: widget.turma,
        alunos: alunos,
        provas: provas,
        resultados: resultados,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erro ao exportar boletim: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _adicionarAluno() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdicionarAlunoPage(turmaId: widget.turma.id!),
      ),
    );
  }

  void _editarAluno(Aluno aluno) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditarAlunoPage(turmaId: widget.turma.id!, aluno: aluno),
      ),
    );
  }

  Future<void> _excluirAluno(Aluno aluno) async {
    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o aluno "${aluno.nome}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Excluir',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmacao == true) {
      try {
        await _alunoService.excluirAluno(widget.turma.id!, aluno.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aluno excluído com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao excluir aluno: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.turma.nome),
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting || _isGeneratingPdf)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'exportar_boletim') {
                  _exportarBoletim();
                } else if (value == 'gerar_folhas') {
                  final alunos = await _alunoService
                      .listarAlunos(widget.turma.id!)
                      .first;
                  _gerarFolhasDeResposta(alunos);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'gerar_folhas',
                  child: ListTile(
                    leading: Icon(Icons.print_outlined),
                    title: Text('Gerar Folhas de Resposta'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'exportar_boletim',
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Exportar Boletim'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<Aluno>>(
        stream: _alunoService.listarAlunos(widget.turma.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar alunos: ${snapshot.error}'),
            );
          }
          final alunos = snapshot.data ?? [];

          if (alunos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 80,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum aluno cadastrado',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clique no botão + para adicionar o primeiro aluno.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: alunos.length,
            itemBuilder: (context, index) {
              final aluno = alunos[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    aluno.nome.isNotEmpty
                        ? aluno.nome.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(aluno.nome),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editarAluno(aluno);
                    } else if (value == 'delete') {
                      _excluirAluno(aluno);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Excluir',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarAluno,
        child: const Icon(Icons.add),
      ),
    );
  }
}
