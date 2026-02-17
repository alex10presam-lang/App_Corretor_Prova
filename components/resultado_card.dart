// lib/components/resultado_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/resultado.dart';
import 'package:corretor_provas/utils/validator.dart';

class ResultadoCard extends StatelessWidget {
  final Resultado resultado;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // <<-- PARÂMETRO ADICIONADO

  const ResultadoCard({
    super.key,
    required this.resultado,
    required this.onDelete,
    required this.onEdit, // <<-- PARÂMETRO ADICIONADO
  });

  @override
  Widget build(BuildContext context) {
    final int acertos = resultado.acertos;
    final int totalQuestoes = resultado.respostasAluno.length;
    final double percentualAcertos = totalQuestoes > 0
        ? (acertos / totalQuestoes) * 100
        : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    resultado.alunoNome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // <<-- BOTÃO DE MENU ATUALIZADO -->>
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit(); // Chama a nova função
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Excluir',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatarData(resultado.dataCorrecao.toDate()),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatistic(
                  'Nota',
                  resultado.nota.toStringAsFixed(1),
                  Icons.grade,
                  Colors.blue,
                ),
                _buildStatistic(
                  'Acertos',
                  '$acertos/$totalQuestoes',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatistic(
                  '%',
                  '${percentualAcertos.toStringAsFixed(1)}%',
                  Icons.percent,
                  _getColorPorPercentual(percentualAcertos),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: LinearProgressIndicator(
                value: percentualAcertos / 100,
                backgroundColor: Colors.grey[300],
                color: _getColorPorPercentual(percentualAcertos),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _showDetalhesResultado(
                    context,
                    acertos,
                    totalQuestoes,
                    percentualAcertos,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ver detalhes'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // O resto do código (widgets de build, formatação de data, etc.) continua o mesmo.
  // ... (código dos métodos auxiliares)
  Widget _buildStatistic(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Color _getColorPorPercentual(double percentual) {
    if (percentual >= 70) return Colors.green;
    if (percentual >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatarData(DateTime data) {
    return 'Corrigido em: ${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(data)}';
  }

  void _showDetalhesResultado(
    BuildContext context,
    int acertos,
    int totalQuestoes,
    double percentualAcertos,
  ) {
    final erros = totalQuestoes - acertos;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes do Resultado'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resultado.alunoNome,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Nota:', resultado.nota.toStringAsFixed(1)),
              _buildDetailRow('Total de questões:', totalQuestoes.toString()),
              _buildDetailRow(
                'Acertos:',
                '$acertos (${percentualAcertos.toStringAsFixed(1)}%)',
              ),
              _buildDetailRow('Erros:', erros.toString()),
              _buildDetailRow(
                'Data:',
                _formatarData(resultado.dataCorrecao.toDate()),
              ),
              const SizedBox(height: 16),
              const Text(
                'Respostas do aluno:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: resultado.respostasAluno.asMap().entries.map((entry) {
                  final index = entry.key;
                  final resposta = GabaritoValidator.letraAlternativa(
                    entry.value,
                  );
                  final correcao = index < resultado.correcoes.length
                      ? resultado.correcoes[index]
                      : '-';

                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getColorPorCorrecao(correcao),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Q${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          resposta,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Color _getColorPorCorrecao(String correcao) {
    switch (correcao) {
      case 'C':
        return Colors.green.shade100;
      case 'E':
        return Colors.red.shade100;
      case 'A':
        return Colors.orange.shade100;
      case 'N':
        return Colors.grey.shade200;
      default:
        return Colors.grey.shade100;
    }
  }
}
