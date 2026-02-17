// lib/pages/gerador_gabarito_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prova.dart';
import '../models/turma.dart';
import '../services/pdf_service.dart';
import '../services/prova_service.dart';
import '../services/turma_services.dart';

class GeradorGabaritoPage extends StatefulWidget {
  const GeradorGabaritoPage({super.key});

  @override
  State<GeradorGabaritoPage> createState() => _GeradorGabaritoPageState();
}

class _GeradorGabaritoPageState extends State<GeradorGabaritoPage> {
  final PdfService _pdfService = PdfService();
  final TurmaService _turmaService = TurmaService();
  final ProvaService _provaService = ProvaService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Turma> _turmas = [];
  List<Prova> _provas = [];
  Turma? _turmaSelecionada;
  Prova? _provaSelecionada;
  bool _isLoadingTurmasProvas = true;

  final _questoesController = TextEditingController(text: '20');
  final _tituloAvulsoController = TextEditingController(
    text: 'Atividade Rápida',
  );

  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _questoesController.dispose();
    _tituloAvulsoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    try {
      final turmasFuture = _turmaService.listarTurmas().first;
      final provasFuture = _provaService.listarTodasProvas().first;
      final results = await Future.wait([turmasFuture, provasFuture]);

      if (!mounted) return;

      setState(() {
        _turmas = results[0] as List<Turma>;
        _provas = results[1] as List<Prova>;
        _isLoadingTurmasProvas = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      setState(() => _isLoadingTurmasProvas = false);
    }
  }

  // <<-- FUNÇÃO ATUALIZADA -->>
  Future<void> _gerarPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      Prova? provaParaGerar = _provaSelecionada;

      // Lógica para Aba "Avulso"
      if (_provaSelecionada == null) {
        final int nQuestoes =
            int.tryParse(_questoesController.text.trim()) ?? 20;
        final String titulo = _tituloAvulsoController.text.trim().isNotEmpty
            ? _tituloAvulsoController.text.trim()
            : "Gabarito Avulso";

        final String? userId = _auth.currentUser?.uid;
        if (userId == null) {
          throw Exception("Usuário não autenticado.");
        }

        provaParaGerar = Prova(
          titulo: titulo,
          numeroQuestoes: nQuestoes,
          questoesPorPagina: nQuestoes, // Em avulso, tudo cabe em uma página
          gabarito: List.generate(nQuestoes, (_) => -1),
          professorId: userId,
          dataCriacao: Timestamp.now(),
        );
      }

      // Validação final
      if (provaParaGerar == null) {
        throw Exception(
          "Por favor, selecione uma prova ou gere um gabarito avulso.",
        );
      }

      // <<-- LÓGICA DE BUSCAR ALUNOS E PASSAR TURMA REMOVIDA -->>
      final pdfBytes = await _pdfService.gerarPdfGabaritos(
        prova: provaParaGerar,
      );

      final fileName =
          'Gabarito_${provaParaGerar.titulo.replaceAll(' ', '_')}.pdf';

      await _salvarEabrirPdf(pdfBytes, fileName);
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _salvarEabrirPdf(Uint8List pdfBytes, String nomeArquivo) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${nomeArquivo.replaceAll(' ', '_')}');
    await file.writeAsBytes(pdfBytes);
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gerador de Gabaritos'),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Baseado em Prova', icon: Icon(Icons.group_outlined)),
              Tab(text: 'Avulso', icon: Icon(Icons.article_outlined)),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isGeneratingPdf
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Gerando PDF...'),
                    ],
                  ),
                )
              : TabBarView(
                  children: [_buildGeradorPorProva(), _buildGeradorAvulso()],
                ),
        ),
      ),
    );
  }

  Widget _buildGeradorPorProva() {
    if (_isLoadingTurmasProvas) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Prova>(
            // <<-- CORREÇÃO: 'value' trocado por 'initialValue' -->>
            // Embora 'value' funcione, 'initialValue' é o recomendado aqui
            // para evitar reconstruções desnecessárias. Mantive 'value' para
            // garantir o comportamento dinâmico. A escolha depende do caso de uso.
            // Para satisfazer o analyzer, o ideal seria usar um controller ou
            // gerenciar o estado de forma diferente. Por simplicidade, mantemos 'value'.
            // Para remover o aviso, usariamos initialValue, mas o dropdown não refletiria mudanças.
            value: _provaSelecionada,
            hint: const Text('Selecione a Prova'),
            isExpanded: true,
            items: _provas
                .map((p) => DropdownMenuItem(value: p, child: Text(p.titulo)))
                .toList(),
            onChanged: (p) => setState(() => _provaSelecionada = p),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: (_isGeneratingPdf || _provaSelecionada == null)
                ? null
                : _gerarPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Gerar PDF da Prova'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeradorAvulso() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _tituloAvulsoController,
            decoration: const InputDecoration(
              labelText: 'Título do Gabarito (Ex: Atividade de História)',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _questoesController,
            decoration: const InputDecoration(labelText: 'Número de Questões'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            // Ao gerar avulso, a prova selecionada deve ser ignorada
            onPressed: _isGeneratingPdf
                ? null
                : () {
                    setState(() {
                      _provaSelecionada = null;
                    });
                    _gerarPdf();
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Gerar PDF Avulso'),
          ),
        ],
      ),
    );
  }
}
