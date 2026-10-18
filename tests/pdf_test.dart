import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:corretor_provas/models/prova.dart';
import 'package:corretor_provas/services/pdf_service.dart';

void main() {
  test('gera a folha real de 50 questões para verificação do layout', () async {
    final prova = Prova(
      id: 'demo-local',
      titulo: 'Ciências - avaliação demonstrativa',
      numeroQuestoes: 50,
      questoesPorPagina: 50,
      gabarito: List.generate(50, (i) => i % 5),
      professorId: 'demo',
      dataCriacao: Timestamp.fromDate(DateTime(2026, 1, 1)),
    );
    final bytes = await PdfService().gerarPdfGabaritos(prova: prova);
    expect(bytes.take(4), [37, 80, 68, 70]);
    final dir = Directory('build/scanner-fixtures');
    await dir.create(recursive: true);
    await File('${dir.path}/modelo-local.pdf').writeAsBytes(bytes);
  });
  test('modelo avulso sem id gera PDF sem falhar', () async {
    final prova = Prova(
      titulo: 'Folha avulsa',
      numeroQuestoes: 10,
      questoesPorPagina: 10,
      gabarito: List.filled(10, -1),
      professorId: 'demo',
      dataCriacao: Timestamp.fromDate(DateTime(2026, 1, 1)),
    );
    expect(await PdfService().gerarPdfGabaritos(prova: prova), isNotEmpty);
  });
  test('não imprime quantidade que o leitor não suporta', () async {
    await expectLater(
      PdfService().generateAnswerSheet(nomeProva: 'Excesso', numQuestoes: 51),
      throwsFormatException,
    );
  });
}
