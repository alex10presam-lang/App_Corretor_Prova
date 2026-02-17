// lib/services/export_service.dart

import 'dart:io';
import 'package:collection/collection.dart'; // Import necessário para 'firstWhereOrNull'
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/aluno.dart';
import '../models/prova.dart';
import '../models/resultado.dart';
import '../models/turma.dart';

class ExportService {
  // Função que já tínhamos, para exportar os resultados de UMA prova.
  Future<void> exportarResultadosProva({
    required List<Resultado> resultados,
    required String nomeProva,
  }) async {
    // ... (código desta função permanece o mesmo)
  }

  // <<-- NOVA FUNÇÃO PARA GERAR O BOLETIM COMPLETO DA TURMA -->>
  Future<void> exportarBoletimTurma({
    required Turma turma,
    required List<Aluno> alunos,
    required List<Prova> provas,
    required List<Resultado> resultados,
  }) async {
    if (alunos.isEmpty || provas.isEmpty) {
      throw Exception(
        "Não há dados suficientes para gerar o boletim (sem alunos ou provas).",
      );
    }

    final List<List<dynamic>> rows = [];

    // 1. Organiza as provas por data para que as colunas fiquem em ordem
    provas.sort((a, b) => a.dataCriacao.compareTo(b.dataCriacao));

    // 2. Cria o cabeçalho dinâmico
    final List<dynamic> headerRow = ['Nome do Aluno'];
    for (final prova in provas) {
      headerRow.add(prova.titulo); // Adiciona uma coluna para cada prova
    }
    headerRow.add('Média Final');
    rows.add(headerRow);

    // 3. Cria uma linha para cada aluno
    for (final aluno in alunos) {
      final List<dynamic> alunoRow = [aluno.nome];
      final List<double> notasDoAluno = [];

      // Para cada prova no cabeçalho...
      for (final prova in provas) {
        // ...encontra o resultado correspondente daquele aluno naquela prova
        final resultado = resultados.firstWhereOrNull(
          (r) => r.alunoId == aluno.id && r.provaId == prova.id,
        );

        if (resultado != null) {
          alunoRow.add(resultado.nota.toStringAsFixed(1));
          notasDoAluno.add(resultado.nota);
        } else {
          alunoRow.add('-'); // Adiciona um traço se o aluno não fez a prova
        }
      }

      // Calcula a média final do aluno e adiciona na última coluna
      if (notasDoAluno.isNotEmpty) {
        final mediaFinal =
            notasDoAluno.reduce((a, b) => a + b) / notasDoAluno.length;
        alunoRow.add(mediaFinal.toStringAsFixed(1));
      } else {
        alunoRow.add('N/A');
      }

      rows.add(alunoRow);
    }

    // O resto do processo é igual: converter, salvar e compartilhar
    final String csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final fileName =
        'Boletim_${turma.nome.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final path = '${directory.path}/$fileName';

    final File file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([
      XFile(path),
    ], text: 'Boletim da turma "${turma.nome}"');
  }
}
