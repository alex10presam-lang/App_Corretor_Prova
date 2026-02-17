// lib/pages/detalhes_prova_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../models/analise_questao.dart';
import '../models/prova.dart';
import '../models/resultado.dart';
import '../services/analise_service.dart';
import '../services/pdf_service.dart'; // <-- Certifique-se que o PdfService está correto
import '../services/resultado_service.dart';
import 'pages/camera_scanner_page.dart';

class DetalhesProvaPage extends StatefulWidget {
  final Prova prova;
  const DetalhesProvaPage({super.key, required this.prova});

  @override
  State<DetalhesProvaPage> createState() => _DetalhesProvaPageState();
}

class _DetalhesProvaPageState extends State<DetalhesProvaPage> {
  final ResultadoService _resultadoService = ResultadoService();
  final AnaliseService _analiseService = AnaliseService();
  final PdfService _pdfService = PdfService(); // Instância do PdfService
  bool _isGeneratingPdf = false; // Estado para loading do PDF

  // Helper para converter índice em letra (0=A, 1=B, ...)
  String _getLetra(int index) {
    if (index < 0 || index > 4)
      return '?'; // Retorna '?' para inválido ou não marcado (-1)
    return String.fromCharCode('A'.codeUnitAt(0) + index);
  }

  // Função para gerar o PDF do gabarito modelo
  Future<void> _gerarPdfModelo() async {
    setState(() => _isGeneratingPdf = true);

    try {
      // Chama a função correta do PdfService
      final Uint8List pdfBytes = await _pdfService.gerarPdfGabaritos(
        prova: widget.prova,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Gabarito_${widget.prova.titulo}.pdf'.replaceAll(
        ' ',
        '_',
      );
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Duas abas: Resultados e Análise
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.prova.titulo),
          foregroundColor: Colors.white,
          actions: [
            // Indicador de loading ou Menu de Ações
            if (_isGeneratingPdf)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              )
            else
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'gerar_pdf') {
                    _gerarPdfModelo();
                  }
                  // Adicione mais ações aqui se necessário
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'gerar_pdf',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Gerar Gabarito Modelo'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: Colors.white),
              ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Resultados'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Análise'),
            ],
          ),
        ),
        body: StreamBuilder<List<Resultado>>(
          // Busca os resultados da prova (já seguro pela consulta no service)
          stream: _resultadoService.listarResultados(widget.prova.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // Mostra o erro específico do Firestore
              return Center(
                child: Text('Erro ao carregar resultados: ${snapshot.error}'),
              );
            }
            final resultados = snapshot.data ?? [];

            // Calcula a análise a partir dos resultados obtidos
            final analise = _analiseService.gerarAnalisePorQuestao(
              prova: widget.prova,
              resultados: resultados,
            );

            // Constrói as duas abas com os dados
            return TabBarView(
              children: [
                _ResultadosAlunosTab(resultados: resultados),
                _AnaliseQuestoesTab(analise: analise, getLetra: _getLetra),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          // Navega para a página do Scanner
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScannerPage()),
          ),
          tooltip: 'Escanear Provas',
          child: const Icon(Icons.qr_code_scanner),
        ),
      ),
    );
  }
}

// --- WIDGET PARA A ABA DE RESULTADOS DOS ALUNOS ---
class _ResultadosAlunosTab extends StatelessWidget {
  final List<Resultado> resultados;
  const _ResultadosAlunosTab({required this.resultados});

  @override
  Widget build(BuildContext context) {
    if (resultados.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Nenhum resultado escaneado para esta prova ainda. Use o botão de scanner para começar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Ordena os resultados por nome do aluno
    resultados.sort((a, b) => a.alunoNome.compareTo(b.alunoNome));

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: resultados.length,
      itemBuilder: (context, index) {
        final resultado = resultados[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                resultado.acertos.toString(), // Mostra o número de acertos
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              resultado.alunoNome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Nota: ${resultado.nota.toStringAsFixed(1)}',
            ), // Nota formatada
            trailing: Icon(
              resultado.nota >= 6
                  ? Icons.check_circle_outline
                  : Icons.highlight_off, // Ícones diferentes
              color: resultado.nota >= 6
                  ? Colors.green.shade600
                  : Colors.red.shade600,
              size: 28,
            ),
            // Adicionar onTap se quiser ver detalhes do resultado individual no futuro
            // onTap: () { /* Navegar para detalhes do resultado */ },
          ),
        );
      },
    );
  }
}

// --- WIDGET PARA A ABA DE ANÁLISE POR QUESTÃO ---
class _AnaliseQuestoesTab extends StatelessWidget {
  final List<AnaliseQuestao> analise;
  final String Function(int) getLetra;
  const _AnaliseQuestoesTab({required this.analise, required this.getLetra});

  @override
  Widget build(BuildContext context) {
    if (analise.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Escaneie pelo menos um resultado para gerar a análise estatística da prova.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: analise.length,
      itemBuilder: (context, index) {
        final item = analise[index];
        final percentual =
            item.percentualAcerto / 100.0; // Normaliza para 0.0 a 1.0
        // Define a cor baseada no percentual de acerto
        final corProgresso = Color.lerp(
          Colors.red.shade600,
          Colors.green.shade600,
          percentual,
        )!;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título da Questão
                Text(
                  'Questão ${item.numeroQuestao} (Gabarito: ${getLetra(item.respostaCorreta)})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Barra de Progresso e Percentual
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        // Garante bordas arredondadas
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percentual,
                          minHeight: 12,
                          backgroundColor: corProgresso.withOpacity(
                            0.2,
                          ), // Fundo mais claro
                          color: corProgresso, // Cor principal
                          valueColor: AlwaysStoppedAnimation<Color>(
                            corProgresso,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${item.percentualAcerto.toStringAsFixed(1)}%', // Percentual formatado
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: corProgresso,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Texto informativo
                Text(
                  '${item.totalAcertos} de ${item.totalRespostas} alunos acertaram.',
                ),

                // Informação do Distrator Principal (se houver)
                if (item.alternativaMaisMarcadaIncorreta != null &&
                    item.alternativaMaisMarcadaIncorreta! >= 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Distrator principal: Alternativa ${getLetra(item.alternativaMaisMarcadaIncorreta!)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
