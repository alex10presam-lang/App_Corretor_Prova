import 'package:flutter/material.dart';
import '../models/resultado.dart';

class EstatisticasPanel extends StatelessWidget {
  final List<Resultado> resultados;

  const EstatisticasPanel({super.key, required this.resultados});

  @override
  Widget build(BuildContext context) {
    if (resultados.isEmpty) {
      return Container(); // Painel vazio se não há resultados
    }

    final stats = _calcularEstatisticas(resultados);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estatísticas Gerais',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total', resultados.length.toString(),
                  Icons.assignment, Colors.blue),
              _buildStatCard('Média', '${stats.mediaGeral.toStringAsFixed(1)}%',
                  Icons.timeline, Colors.blue),
              _buildStatCard(
                  'Melhor',
                  '${stats.melhorNota.toStringAsFixed(1)}%',
                  Icons.emoji_events,
                  Colors.green),
              _buildStatCard('Pior', '${stats.piorNota.toStringAsFixed(1)}%',
                  Icons.warning, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Estatisticas _calcularEstatisticas(List<Resultado> resultados) {
    if (resultados.isEmpty) return Estatisticas();

    // Calcular percentual de acertos para cada resultado
    final percentuais = resultados.map((resultado) {
      final totalQuestoes = resultado.respostasAluno.length;
      if (totalQuestoes == 0) return 0.0;

      final acertos =
          resultado.correcoes.where((correcao) => correcao == 'Correta').length;
      return (acertos / totalQuestoes) * 100;
    }).toList();

    final media = percentuais.reduce((a, b) => a + b) / percentuais.length;
    final melhor = percentuais.reduce((a, b) => a > b ? a : b);
    final pior = percentuais.reduce((a, b) => a < b ? a : b);

    return Estatisticas(
      mediaGeral: media,
      melhorNota: melhor,
      piorNota: pior,
    );
  }
}

class Estatisticas {
  final double mediaGeral;
  final double melhorNota;
  final double piorNota;

  Estatisticas({
    this.mediaGeral = 0,
    this.melhorNota = 0,
    this.piorNota = 0,
  });
}
