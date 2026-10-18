import 'dart:convert';
import 'sheet_layout.dart';

class ScanSheet {
  final String provaId;
  final String? alunoId;
  final String? turmaId;
  final int questionCount;
  const ScanSheet(this.provaId, this.alunoId, this.turmaId, this.questionCount);

  factory ScanSheet.parse(String raw) {
    final dynamic value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Este QR Code não identifica uma prova.');
    }
    if (value['layout'] != SheetLayout.version || value['totalPages'] != 1) {
      throw const FormatException(
        'Folha incompatível. Gere e imprima o novo modelo de leitura local.',
      );
    }
    String? identifier(String key) {
      final dynamic id = value[key];
      if (id == null) return null;
      if (id is! String || id.trim().isEmpty || id.contains('/')) {
        throw const FormatException('Identificação inválida no QR Code.');
      }
      return id;
    }

    final prova = identifier('provaId');
    final aluno = identifier('alunoId');
    final turma = identifier('turmaId');
    final dynamic count = value['questions'];
    if (prova == null || count is! int || (aluno == null) != (turma == null)) {
      throw const FormatException('Identificação da folha incompleta.');
    }
    SheetLayout.validateCount(count);
    return ScanSheet(prova, aluno, turma, count);
  }

  int questionsOnSheet(int count) {
    SheetLayout.validateCount(count);
    if (count != questionCount) {
      throw const FormatException(
        'A prova mudou. Gere uma nova folha antes de corrigir.',
      );
    }
    return count;
  }

  bool sameSheet(ScanSheet other) =>
      provaId == other.provaId &&
      alunoId == other.alunoId &&
      turmaId == other.turmaId &&
      questionCount == other.questionCount;
}
