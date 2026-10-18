import 'dart:convert';

/// The QR identifies the sheet; it does not contain an answer key.
class ScanSheet {
  final String provaId;
  final String? alunoId;
  final String? turmaId;
  final int totalPages;

  const ScanSheet(this.provaId, this.alunoId, this.turmaId, this.totalPages);

  factory ScanSheet.parse(String raw) {
    final dynamic value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Este QR Code não identifica uma prova.');
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
    final dynamic pages = value['totalPages'];
    if (prova == null || pages is! int || pages < 1) {
      throw const FormatException(
        'QR Code sem identificação ou paginação válida.',
      );
    }
    if ((aluno == null) != (turma == null)) {
      throw const FormatException('Identificação de aluno e turma incompleta.');
    }
    return ScanSheet(prova, aluno, turma, pages);
  }

  int questionsOnSheet(int questionCount) {
    if (questionCount < 1) {
      throw const FormatException('A prova não possui questões.');
    }
    // The PDF generator in this repository emits exactly one sheet per student.
    // Multi-page sheets need a page identifier before they can be graded safely.
    if (totalPages != 1) {
      throw const FormatException(
        'Use uma folha de página única gerada por este aplicativo. '
        'A leitura de várias páginas ainda não está disponível.',
      );
    }
    return questionCount;
  }
}

List<int> decodeOmrAnswers(String body, int expectedQuestions) {
  final dynamic data = jsonDecode(body);
  if (expectedQuestions < 1 || data is! Map<String, dynamic>) {
    throw const FormatException('Resposta inválida do serviço de leitura.');
  }
  final dynamic answers = data['answers'];
  if (answers is! List || answers.length != expectedQuestions) {
    throw FormatException(
      'A leitura precisa retornar exatamente $expectedQuestions respostas. '
      'Enquadre a folha inteira e tente novamente.',
    );
  }
  // -1 = blank; -2 = multiple marks; 0..4 = A..E, as used by the validator.
  if (answers.any((dynamic item) => item is! int || item < -2 || item > 4)) {
    throw const FormatException('O serviço retornou alternativas inválidas.');
  }
  return List<int>.from(answers);
}
