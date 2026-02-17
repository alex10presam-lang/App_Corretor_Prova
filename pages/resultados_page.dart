// lib/pages/resultados_page.dart

import 'package:corretor_provas/pages/editar_resultado_page.dart';
import 'package:corretor_provas/services/export_service.dart';
import 'package:flutter/material.dart';
import '../models/prova.dart';
import '../models/resultado.dart';
import '../services/prova_service.dart';
import '../services/resultado_service.dart';
import '../components/resultado_card.dart';

class ResultadosPage extends StatefulWidget {
  final String provaId;

  const ResultadosPage({super.key, required this.provaId});

  @override
  State<ResultadosPage> createState() => _ResultadosPageState();
}

class _ResultadosPageState extends State<ResultadosPage> {
  final ResultadoService _resultadoService = ResultadoService();
  final ProvaService _provaService = ProvaService();
  final ExportService _exportService = ExportService();

  bool _isExporting = false;

  void _navegarParaEdicao(Resultado resultado, Prova prova) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditarResultadoPage(resultadoId: resultado.id!, provaId: prova.id!),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Future<void> _excluirResultado(String resultadoId) async {
    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
          'Tem certeza que deseja excluir esta correção? A imagem associada também será apagada permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Excluir',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmacao == true) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        await _resultadoService.excluirResultado(resultadoId);
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Resultado excluído com sucesso!')),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao excluir resultado: $e')),
        );
      }
    }
  }

  Future<void> _exportarResultados(
    List<Resultado> resultados,
    String nomeProva,
  ) async {
    setState(() => _isExporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _exportService.exportarResultadosProva(
        resultados: resultados,
        nomeProva: nomeProva,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erro ao exportar: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados da Correção'),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Prova?>(
        future: _provaService.getProvaById(widget.provaId),
        builder: (context, provaSnapshot) {
          if (provaSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provaSnapshot.hasError ||
              !provaSnapshot.hasData ||
              provaSnapshot.data == null) {
            return const Center(
              child: Text('Erro: Não foi possível carregar os dados da prova.'),
            );
          }
          final prova = provaSnapshot.data!;

          return StreamBuilder<List<Resultado>>(
            stream: _resultadoService.listarResultados(widget.provaId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Erro ao carregar resultados: ${snapshot.error}'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final resultados = snapshot.data ?? [];

              if (resultados.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Nenhuma correção foi salva para esta prova ainda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  _buildEstatisticasPanel(resultados),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () =>
                                  _exportarResultados(resultados, prova.titulo),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share_outlined),
                        label: Text(
                          _isExporting
                              ? 'Exportando...'
                              : 'Exportar Resultados (CSV)',
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: resultados.length,
                      itemBuilder: (context, index) {
                        final resultado = resultados[index];
                        return ResultadoCard(
                          resultado: resultado,
                          onEdit: () => _navegarParaEdicao(resultado, prova),
                          onDelete: () => _excluirResultado(resultado.id!),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEstatisticasPanel(List<Resultado> resultados) {
    if (resultados.isEmpty) return const SizedBox.shrink();

    final double mediaNotas =
        resultados.map((r) => r.nota).reduce((a, b) => a + b) /
        resultados.length;
    final int maiorAcertos = resultados
        .map((r) => r.acertos)
        .reduce((a, b) => a > b ? a : b);
    final int menorAcertos = resultados
        .map((r) => r.acertos)
        .reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Média da Turma',
            mediaNotas.toStringAsFixed(1),
            Icons.bar_chart,
            Colors.orange,
          ),
          _buildStatItem(
            'Melhor Desempenho',
            '$maiorAcertos acertos',
            Icons.star,
            Colors.green,
          ),
          _buildStatItem(
            'Pior Desempenho',
            '$menorAcertos acertos',
            Icons.warning,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
