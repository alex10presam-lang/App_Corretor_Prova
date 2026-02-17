// lib/services/analise_service.dart

import '../models/analise_questao.dart';
import '../models/prova.dart';
import '../models/resultado.dart';

class AnaliseService {
  // Recebe uma prova e todos os seus resultados para gerar as estatísticas
  List<AnaliseQuestao> gerarAnalisePorQuestao({
    required Prova prova,
    required List<Resultado> resultados,
  }) {
    if (resultados.isEmpty) {
      return [];
    }

    final List<AnaliseQuestao> analises = [];
    final int numeroDeQuestoes = prova.numeroQuestoes;
    final int numeroDeAlunos = resultados.length;

    // Itera por cada questão da prova (de 1 a N)
    for (int i = 0; i < numeroDeQuestoes; i++) {
      final int numeroQuestao = i + 1;
      final int respostaCorreta = prova.gabarito[i];
      int totalAcertos = 0;
      final Map<int, int> contagemRespostas = {
        0: 0,
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        -1: 0,
      };

      // Itera por cada resultado de aluno
      for (final resultado in resultados) {
        if (resultado.respostasAluno.length > i) {
          final respostaAluno = resultado.respostasAluno[i];

          if (respostaAluno == respostaCorreta) {
            totalAcertos++;
          }

          // Incrementa a contagem para a alternativa marcada pelo aluno
          contagemRespostas.update(
            respostaAluno,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }

      // Calcula o percentual de acerto
      final double percentualAcerto = (totalAcertos / numeroDeAlunos) * 100;

      // Encontra a alternativa incorreta mais marcada (o "distrator principal")
      int? alternativaMaisMarcadaIncorreta;
      int maxContagemIncorreta = 0;
      contagemRespostas.forEach((alternativa, contagem) {
        if (alternativa != respostaCorreta && contagem > maxContagemIncorreta) {
          maxContagemIncorreta = contagem;
          alternativaMaisMarcadaIncorreta = alternativa;
        }
      });

      analises.add(
        AnaliseQuestao(
          numeroQuestao: numeroQuestao,
          respostaCorreta: respostaCorreta,
          percentualAcerto: percentualAcerto,
          totalRespostas: numeroDeAlunos,
          totalAcertos: totalAcertos,
          contagemRespostas: contagemRespostas,
          alternativaMaisMarcadaIncorreta: alternativaMaisMarcadaIncorreta,
        ),
      );
    }

    return analises;
  }
}
