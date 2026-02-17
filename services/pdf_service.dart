// lib/services/pdf_service.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/aluno.dart';
import '../models/prova.dart';
import '../models/turma.dart';

class PdfService {
  // --- DEFINIÇÕES DE LAYOUT ---
  static const PdfPageFormat pageFormat = PdfPageFormat.a4;
  static const double anchorMargin = 15.0;
  static const double anchorSize = 28.3; // 10mm (~28 pontos)
  static const double contentMargin = 42.5; // ~15mm

  // Alturas estimadas para cálculo de centralização
  static const double headerHeight = 100.0;
  static const double footerHeight = 30.0;

  // --- MÉTODO RESTAURADO ---
  Future<Uint8List> generateAnswerSheet({
    required String nomeProva,
    int numQuestoes = 10,
    Turma? turma,
    Aluno? aluno,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _markerBox(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Prova: $nomeProva',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Página: 1 de 1',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  _markerBox(),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(100),
                  1: pw.FlexColumnWidth(3),
                },
                children: [
                  _headerRow('ALUNO:', aluno?.nome ?? '____________________'),
                  _headerRow('PROVA:', nomeProva),
                  _headerRow('TURMA:', turma?.nome ?? '____________________'),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Expanded(
                child: pw.Center(
                  child: _buildGrelhaSimples(numeroQuestoes: numQuestoes),
                ),
              ),
              pw.Text(
                'Instruções: Preencha completamente o círculo da alternativa correta com caneta azul ou preta. Não rasure.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [_markerBox(), _markerBox()],
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // --- MÉTODO PRINCIPAL PARA FOLHAS DE RESPOSTA DA TURMA ---
  Future<Uint8List> gerarFolhasDeRespostasParaTurma({
    required Prova prova,
    required Turma turma,
    required List<Aluno> alunos,
  }) async {
    final pdf = pw.Document();
    for (final aluno in alunos) {
      pdf.addPage(
        _buildFolhaDeRespostaConteudoCentralizado(
          prova: prova,
          turma: turma,
          aluno: aluno,
        ),
      );
    }
    return pdf.save();
  }

  // --- FUNÇÃO PARA GERAR GABARITO MODELO ---
  Future<Uint8List> gerarPdfGabaritos({required Prova prova}) async {
    final pdf = pw.Document();

    pdf.addPage(
      _buildFolhaDeRespostaConteudoCentralizado(
        prova: prova,
        turma: null,
        aluno: null,
      ),
    );
    return pdf.save();
  }

  // --- CONSTRUÇÃO DA PÁGINA COM CENTRALIZAÇÃO PERFEITA ---
  pw.Page _buildFolhaDeRespostaConteudoCentralizado({
    required Prova prova,
    Turma? turma,
    Aluno? aluno,
  }) {
    return pw.Page(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        // Calcula a altura disponível para a grelha
        final availableHeight =
            context.page.pageFormat.availableHeight -
            (contentMargin * 2) -
            headerHeight -
            footerHeight;

        return pw.Stack(
          children: [
            // Conteúdo principal
            pw.Padding(
              padding: const pw.EdgeInsets.all(contentMargin),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho
                  pw.Container(
                    height: headerHeight,
                    child: _buildHeader(
                      prova: prova,
                      turma: turma,
                      aluno: aluno,
                    ),
                  ),

                  // Área da grelha com altura fixa e centralização
                  pw.Container(
                    height: availableHeight,
                    alignment: pw.Alignment.center,
                    child: _buildGrelhaDeRespostasOtimizada(
                      numeroQuestoes: prova.numeroQuestoes,
                    ),
                  ),

                  // Rodapé
                  pw.Container(height: footerHeight, child: _buildFooter()),
                ],
              ),
            ),

            // Marcadores de âncora
            _buildAnchorMarkers(),
          ],
        );
      },
    );
  }

  // --- MARCADORES DE ÂNCORA NOS CANTOS ---
  pw.Widget _buildAnchorMarkers() {
    return pw.Stack(
      children: [
        // Canto superior esquerdo
        pw.Positioned(
          left: anchorMargin,
          top: anchorMargin,
          child: _anchorBox(),
        ),
        // Canto superior direito
        pw.Positioned(
          right: anchorMargin,
          top: anchorMargin,
          child: _anchorBox(),
        ),
        // Canto inferior esquerdo
        pw.Positioned(
          left: anchorMargin,
          bottom: anchorMargin,
          child: _anchorBox(),
        ),
        // Canto inferior direito
        pw.Positioned(
          right: anchorMargin,
          bottom: anchorMargin,
          child: _anchorBox(),
        ),
      ],
    );
  }

  // Caixa de âncora (quadrado preto)
  pw.Widget _anchorBox() {
    return pw.Container(
      width: anchorSize,
      height: anchorSize,
      color: PdfColors.black,
    );
  }

  // --- MÉTODOS AJUDANTES PARA O LAYOUT ---

  pw.Widget _buildHeader({required Prova prova, Turma? turma, Aluno? aluno}) {
    final qrDataMap = {
      'provaId': prova.id!,
      if (aluno?.id != null && aluno!.id!.isNotEmpty) 'alunoId': aluno.id!,
      if (turma?.id != null && turma!.id!.isNotEmpty) 'turmaId': turma.id!,
      'totalPages': 1,
    };
    final qrDataString = jsonEncode(qrDataMap);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(100),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _headerRow('ALUNO:', aluno?.nome ?? '____________________'),
              _headerRow('PROVA:', prova.titulo),
              _headerRow('TURMA:', turma?.nome ?? '____________________'),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrDataString,
          width: 85,
          height: 85,
          color: PdfColors.black,
        ),
      ],
    );
  }

  // GRELHA DE RESPOSTAS OTIMIZADA - VERSÃO CORRIGIDA
  pw.Widget _buildGrelhaDeRespostasOtimizada({required int numeroQuestoes}) {
    const int QUESTOES_POR_COLUNA = 13;

    // Calcula número de colunas necessárias
    final int numColunas = (numeroQuestoes / QUESTOES_POR_COLUNA).ceil();

    // Ajusta espaçamento baseado no número de colunas
    final double espacamentoEntreColunas = numColunas == 1
        ? 0.0
        : numColunas == 2
        ? 60.0
        : 40.0;

    // Constrói cada coluna
    List<pw.Widget> widgets = [];

    for (int colIndex = 0; colIndex < numColunas; colIndex++) {
      // Calcula o range de questões para esta coluna (base 0)
      final int startIndex = colIndex * QUESTOES_POR_COLUNA;
      final int endIndex = min(
        startIndex + QUESTOES_POR_COLUNA,
        numeroQuestoes,
      );
      final int totalQuestoesNaColuna = endIndex - startIndex;

      // Adiciona a coluna de questões
      widgets.add(
        pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: List.generate(
            totalQuestoesNaColuna,
            (index) => _questionRowOptimized(
              startIndex + index + 1, // +1 porque questões começam em 1
              numColunas: numColunas,
            ),
          ),
        ),
      );

      // Adiciona âncoras verticais entre colunas (se houver próxima coluna)
      if (colIndex < numColunas - 1) {
        widgets.add(pw.SizedBox(width: espacamentoEntreColunas / 2));
        widgets.add(_buildAncorasVerticais());
        widgets.add(pw.SizedBox(width: espacamentoEntreColunas / 2));
      }
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: widgets,
    );
  }

  // ÂNCORAS VERTICAIS ENTRE COLUNAS (estilo EvalBee)
  pw.Widget _buildAncorasVerticais() {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _ancoraVertical(),
        pw.SizedBox(height: 60),
        _ancoraVertical(),
        pw.SizedBox(height: 60),
        _ancoraVertical(),
        pw.SizedBox(height: 60),
        _ancoraVertical(),
        pw.SizedBox(height: 60),
        _ancoraVertical(),
      ],
    );
  }

  // Marcador vertical individual
  pw.Widget _ancoraVertical() {
    return pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: PdfColors.black,
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Instruções: Preencha completamente o círculo da alternativa correta com caneta azul ou preta. Não rasure.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // --- HELPERS GENÉRICOS ---

  pw.TableRow _headerRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // LINHA DE QUESTÃO OTIMIZADA (ajusta tamanho baseado no número de colunas)
  pw.Widget _questionRowOptimized(int numero, {required int numColunas}) {
    const letras = ['A', 'B', 'C', 'D', 'E'];

    // Ajusta tamanhos baseado no número de colunas
    final double circleSize = numColunas == 1
        ? 24.0
        : numColunas == 2
        ? 22.0
        : 18.0;
    final double fontSize = numColunas == 1
        ? 13.0
        : numColunas == 2
        ? 12.0
        : 10.0;
    final double letterSize = numColunas == 1
        ? 11.0
        : numColunas == 2
        ? 10.0
        : 9.0;
    final double verticalPadding = numColunas == 1
        ? 7.0
        : numColunas == 2
        ? 6.0
        : 5.0;
    final double horizontalPadding = numColunas == 1
        ? 9.0
        : numColunas == 2
        ? 7.0
        : 5.0;
    final double numberWidth = numColunas == 1
        ? 32.0
        : numColunas == 2
        ? 28.0
        : 24.0;
    final double spacing = numColunas == 1
        ? 14.0
        : numColunas == 2
        ? 12.0
        : 10.0;
    final double anchoraLinhaSize = numColunas == 1
        ? 6.0
        : numColunas == 2
        ? 5.5
        : 5.0;

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: verticalPadding),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // ÂNCORA DE LINHA (quadrado preto à esquerda do número)
          pw.Container(
            width: anchoraLinhaSize,
            height: anchoraLinhaSize,
            color: PdfColors.black,
          ),
          pw.SizedBox(width: 8),

          // Número da questão
          pw.SizedBox(
            width: numberWidth,
            child: pw.Text(
              '$numero',
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: spacing),

          // Círculos de resposta
          ...letras.map((letra) {
            return pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: pw.Container(
                width: circleSize,
                height: circleSize,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(width: 1.5, color: PdfColors.black),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  letra,
                  style: pw.TextStyle(
                    fontSize: letterSize,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Grelha simples (usado no generateAnswerSheet)
  pw.Widget _buildGrelhaSimples({required int numeroQuestoes}) {
    const int questoesPorColuna = 13;
    final int numColunas = (numeroQuestoes / questoesPorColuna).ceil();

    pw.Widget buildColumn(int start, int end) {
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: List.generate(end - start, (index) {
          return _questionRow(start + index + 1);
        }),
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: List.generate(numColunas, (colIndex) {
        final int start = colIndex * questoesPorColuna;
        final int end = min(start + questoesPorColuna, numeroQuestoes);
        return pw.Padding(
          padding: pw.EdgeInsets.only(left: colIndex > 0 ? 20.0 : 0.0),
          child: buildColumn(start, end),
        );
      }),
    );
  }

  // Versão menor para generateAnswerSheet
  pw.Widget _questionRow(int numero) {
    const letras = ['A', 'B', 'C', 'D', 'E'];
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // ÂNCORA DE LINHA
          pw.Container(width: 5, height: 5, color: PdfColors.black),
          pw.SizedBox(width: 6),

          pw.SizedBox(
            width: 25,
            child: pw.Text(
              '$numero',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),

          pw.SizedBox(width: 10),
          ...letras.map((letra) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Container(
                width: 16,
                height: 16,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(width: 1, color: PdfColors.black),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  letra,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Marcador pequeno (para generateAnswerSheet)
  pw.Widget _markerBox() {
    return pw.Container(width: 20, height: 20, color: PdfColors.black);
  }
}
