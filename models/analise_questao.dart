// lib/models/analise_questao.dart

class AnaliseQuestao {
  final int numeroQuestao;
  final int respostaCorreta;
  final double percentualAcerto;
  final int? alternativaMaisMarcadaIncorreta;
  final int totalRespostas;
  final int totalAcertos;
  // Mapa para contar quantas vezes cada alternativa (0=A, 1=B, etc.) foi marcada
  final Map<int, int> contagemRespostas;

  AnaliseQuestao({
    required this.numeroQuestao,
    required this.respostaCorreta,
    required this.percentualAcerto,
    required this.totalRespostas,
    required this.totalAcertos,
    required this.contagemRespostas,
    this.alternativaMaisMarcadaIncorreta,
  });
}
