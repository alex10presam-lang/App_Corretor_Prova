// lib/pages/editar_resultado_page.dart

import 'package:flutter/material.dart';
import '../models/prova.dart';
import '../models/resultado.dart';
import '../services/prova_service.dart';
import '../services/resultado_service.dart';
import '../utils/validator.dart';

class EditarResultadoPage extends StatefulWidget {
  final String resultadoId;
  final String provaId;

  const EditarResultadoPage({
    super.key,
    required this.resultadoId,
    required this.provaId,
  });

  @override
  State<EditarResultadoPage> createState() => _EditarResultadoPageState();
}

class _EditarResultadoPageState extends State<EditarResultadoPage> {
  final ProvaService _provaService = ProvaService();
  final ResultadoService _resultadoService = ResultadoService();

  late Future<Map<String, dynamic>> _dataFuture;
  List<int>? _respostasEditadas;
  int _acertosAtuais = 0;
  double _notaAtual = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _carregarDados();
  }

  Future<Map<String, dynamic>> _carregarDados() async {
    final prova = await _provaService.getProvaById(widget.provaId);
    final resultado = await _resultadoService.getResultadoById(
      widget.resultadoId,
    );
    if (prova == null || resultado == null) {
      throw Exception(
        'Não foi possível carregar os dados da prova ou resultado.',
      );
    }
    _respostasEditadas = List<int>.from(resultado.respostasAluno);
    _recalcularResultado(prova.gabarito);
    return {'prova': prova, 'resultado': resultado};
  }

  void _recalcularResultado(List<int> gabaritoOficial) {
    if (_respostasEditadas == null) return;

    final validationResult = GabaritoValidator.validarRespostas(
      respostasDetectadas: _respostasEditadas!,
      gabaritoOficial: gabaritoOficial,
      numQuestoes: gabaritoOficial.length,
    );
    setState(() {
      _acertosAtuais = validationResult.acertos;
      _notaAtual = validationResult.nota;
    });
  }

  Future<void> _salvarAlteracoes(Prova prova) async {
    if (_respostasEditadas == null) return;
    setState(() => _isLoading = true);

    try {
      await _resultadoService.atualizarResultado(
        resultadoId: widget.resultadoId,
        novasRespostas: _respostasEditadas!,
        prova: prova,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correção atualizada com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Erro: ${snapshot.error}')),
          );
        }

        final Prova prova = snapshot.data!['prova'];
        final Resultado resultado = snapshot.data!['resultado'];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Editar Correção'),
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              _buildHeader(resultado.alunoNome),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: prova.numeroQuestoes,
                  itemBuilder: (context, index) {
                    return _buildQuestaoRow(index, prova.gabarito);
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isLoading ? null : () => _salvarAlteracoes(prova),
            label: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Salvar Alterações'),
            icon: const Icon(Icons.save),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String alunoNome) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alunoNome, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Nota', _notaAtual.toStringAsFixed(1), Colors.blue),
                _buildStat('Acertos', _acertosAtuais.toString(), Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestaoRow(int index, List<int> gabaritoOficial) {
    final respostaOficial = gabaritoOficial[index];
    final respostaAluno = _respostasEditadas![index];
    final bool isCorrect = respostaOficial == respostaAluno;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCorrect
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Text(
            'Q${index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
        title: Text(
          'Gabarito: ${GabaritoValidator.letraAlternativa(respostaOficial)}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('Resposta:', style: TextStyle(fontSize: 14)),
            ActionChip(
              label: Text(
                GabaritoValidator.letraAlternativa(respostaAluno),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () =>
                  _mostrarSeletorDeAlternativa(index, gabaritoOficial),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSeletorDeAlternativa(int index, List<int> gabaritoOficial) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: List.generate(6, (buttonIndex) {
                // 5 para 'E', -1 para 'N' (Não respondida)
                final valorResposta = buttonIndex < 5 ? buttonIndex : -1;
                final letra = GabaritoValidator.letraAlternativa(valorResposta);

                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _respostasEditadas![index] = valorResposta;
                    });
                    _recalcularResultado(gabaritoOficial);
                    Navigator.pop(context);
                  },
                  child: Text(letra),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
