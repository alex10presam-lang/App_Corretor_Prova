// lib/utils/validator.dart

// Esta classe é responsável por comparar as respostas lidas com o gabarito
// e calcular o resultado final (nota, acertos) E OS DETALHES.

class GabaritoValidator {
  /// Compara as respostas detectadas com o gabarito oficial.
  static ValidationResult validarRespostas({
    required List<int> respostasDetectadas,
    required List<int> gabaritoOficial,
    required int numQuestoes,
  }) {
    int acertos = 0;

    // Lista para guardar o detalhe de cada questão
    List<Map<String, dynamic>> detalhes = [];

    // Garante que ambas as listas tenham o tamanho exato de numQuestoes
    final List<int> gabaritoFinal = _ajustarLista(gabaritoOficial, numQuestoes);
    final List<int> respostasFinal = _ajustarLista(
      respostasDetectadas,
      numQuestoes,
    );

    // Compara as respostas
    for (int i = 0; i < numQuestoes; i++) {
      bool acertou = false;

      // Considera acerto apenas se:
      // 1. O aluno marcou uma resposta (não é -1 ou -2)
      // 2. A resposta do aluno é a mesma do gabarito oficial
      if (respostasFinal[i] >= 0 && respostasFinal[i] == gabaritoFinal[i]) {
        acertos++;
        acertou = true;
      }

      // Adiciona o detalhe da questão
      detalhes.add({
        'questao': i + 1, // 1-based index
        'respostaAluno': respostasFinal[i],
        'respostaCorreta': gabaritoFinal[i],
        'acertou': acertou,
      });
    }

    // Calcula a nota (baseado em 10 pontos)
    final double nota = (numQuestoes > 0)
        ? (acertos / numQuestoes) * 10.0
        : 0.0;

    return ValidationResult(
      acertos: acertos,
      nota: nota,
      detalhesQuestoes: detalhes, // Retorna os detalhes
    );
  }

  /// Função auxiliar para garantir que a lista tenha o tamanho [numQuestoes]
  static List<int> _ajustarLista(List<int> lista, int numQuestoes) {
    List<int> listaAjustada = List.from(lista);

    // Se a lista for menor, preenche com -1 (não respondida)
    while (listaAjustada.length < numQuestoes) {
      listaAjustada.add(-1);
    }

    // Se a lista for maior, corta no tamanho correto
    if (listaAjustada.length > numQuestoes) {
      listaAjustada = listaAjustada.sublist(0, numQuestoes);
    }

    return listaAjustada;
  }

  // --- FUNÇÃO ADICIONADA ---
  /// Função helper para converter o índice da resposta (int) para a Letra (String).
  static String letraAlternativa(int valor) {
    switch (valor) {
      case 0:
        return 'A';
      case 1:
        return 'B';
      case 2:
        return 'C';
      case 3:
        return 'D';
      case 4:
        return 'E';
      case -1:
        return 'N/R'; // "Não Respondeu" ou Vazio
      case -2:
        return 'NULA'; // Múltiplas respostas marcadas
      default:
        return '?'; // Caso inesperado
    }
  }
}

/// DTO para armazenar o resultado da validação.
class ValidationResult {
  final int acertos;
  final double nota;
  final List<Map<String, dynamic>> detalhesQuestoes; // O campo que faltava

  ValidationResult({
    required this.acertos,
    required this.nota,
    required this.detalhesQuestoes, // Adicionado ao construtor
  });
}
