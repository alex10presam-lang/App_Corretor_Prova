import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/aluno.dart';
import '../models/prova.dart';
import '../models/turma.dart';
import '../scanner/sheet_layout.dart';

class PdfService {
  Future<Uint8List> generateAnswerSheet({
    required String nomeProva,
    int numQuestoes = 10,
    Turma? turma,
    Aluno? aluno,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      _page(title: nomeProva, count: numQuestoes, turma: turma, aluno: aluno),
    );
    return doc.save();
  }

  Future<Uint8List> gerarPdfGabaritos({required Prova prova}) async {
    final doc = pw.Document();
    doc.addPage(
      _page(title: prova.titulo, count: prova.numeroQuestoes, prova: prova),
    );
    return doc.save();
  }

  Future<Uint8List> gerarFolhasDeRespostasParaTurma({
    required Prova prova,
    required Turma turma,
    required List<Aluno> alunos,
  }) async {
    if (alunos.isEmpty) {
      throw const FormatException('Selecione pelo menos um aluno.');
    }
    final doc = pw.Document();
    for (final aluno in alunos) {
      doc.addPage(
        _page(
          title: prova.titulo,
          count: prova.numeroQuestoes,
          prova: prova,
          turma: turma,
          aluno: aluno,
        ),
      );
    }
    return doc.save();
  }

  pw.Page _page({
    required String title,
    required int count,
    Prova? prova,
    Turma? turma,
    Aluno? aluno,
  }) {
    SheetLayout.validateCount(count);
    final automatic = prova?.id != null && prova!.id!.isNotEmpty;
    final personalized = aluno?.id != null && turma?.id != null;
    final qr = automatic
        ? jsonEncode({
            'layout': SheetLayout.version,
            'provaId': prova.id,
            'questions': count,
            'totalPages': 1,
            if (personalized) 'alunoId': aluno!.id,
            if (personalized) 'turmaId': turma!.id,
          })
        : null;
    pw.Widget textAt(
      double x,
      double y,
      String text, {
      double size = 10,
      double width = 340,
    }) => pw.Positioned(
      left: x,
      top: y,
      child: pw.SizedBox(
        width: width,
        child: pw.Text(text, maxLines: 2, style: pw.TextStyle(fontSize: size)),
      ),
    );
    return pw.Page(
      pageFormat: const PdfPageFormat(SheetLayout.width, SheetLayout.height),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        children: [
          for (final p in SheetLayout.anchors)
            pw.Positioned(
              left: p.x - SheetLayout.anchorSize / 2,
              top: p.y - SheetLayout.anchorSize / 2,
              child: pw.Container(
                width: SheetLayout.anchorSize,
                height: SheetLayout.anchorSize,
                color: PdfColors.black,
              ),
            ),
          for (var i = 0; i < SheetLayout.orientationBits.length; i++)
            if (SheetLayout.orientationBits[i])
              pw.Positioned(
                left: SheetLayout.orientationCell(i).x - 4,
                top: SheetLayout.orientationCell(i).y - 4,
                child: pw.Container(
                  width: 8,
                  height: 8,
                  color: PdfColors.black,
                ),
              ),
          textAt(58, 66, 'FOLHA DE RESPOSTAS', size: 17),
          textAt(58, 96, title, size: 12, width: 350),
          textAt(
            58,
            134,
            'Aluno: ${aluno?.nome ?? '________________________________'}',
          ),
          textAt(
            58,
            157,
            'Turma: ${turma?.nome ?? '________________'}     Questões: $count',
          ),
          if (qr != null)
            pw.Positioned(
              left: 448,
              top: 65,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qr,
                width: 88,
                height: 88,
              ),
            ),
          for (var col = 0; col < (count > 25 ? 2 : 1); col++)
            for (var option = 0; option < 5; option++)
              textAt(
                SheetLayout.firstBubble +
                    col * SheetLayout.columnSpacing +
                    option * SheetLayout.optionSpacing -
                    3,
                191,
                'ABCDE'[option],
                width: 12,
                size: 9,
              ),
          for (var question = 0; question < count; question++) ...[
            textAt(
              SheetLayout.bubble(question, 0).x - 42,
              SheetLayout.bubble(question, 0).y - 5,
              '${question + 1}'.padLeft(2, '0'),
              width: 24,
              size: 10,
            ),
            for (var option = 0; option < 5; option++)
              pw.Positioned(
                left:
                    SheetLayout.bubble(question, option).x -
                    SheetLayout.bubbleRadius,
                top:
                    SheetLayout.bubble(question, option).y -
                    SheetLayout.bubbleRadius,
                child: pw.Container(
                  width: SheetLayout.bubbleRadius * 2,
                  height: SheetLayout.bubbleRadius * 2,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(width: .9),
                  ),
                ),
              ),
          ],
          textAt(
            58,
            745,
            'Preencha todo o círculo com caneta azul ou preta. Evite rasuras.\nFotografe a folha inteira sobre fundo liso, sem sombras ou dobras.',
            size: 9,
            width: 478,
          ),
          textAt(
            58,
            782,
            automatic
                ? 'LEITURA LOCAL  /  ${SheetLayout.version}  /  Página 1 de 1'
                : 'MODELO AVULSO: sem correção automática. Cadastre a prova para gerar o QR.',
            size: 8,
            width: 480,
          ),
        ],
      ),
    );
  }
}
