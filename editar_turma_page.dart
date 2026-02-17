// lib/pages/editar_turma_page.dart
import 'package:flutter/material.dart';
import '../models/turma.dart';
import '/services/turma_services.dart';

class EditarTurmaPage extends StatefulWidget {
  final Turma turma;

  const EditarTurmaPage({super.key, required this.turma});

  @override
  State<EditarTurmaPage> createState() => _EditarTurmaPageState();
}

class _EditarTurmaPageState extends State<EditarTurmaPage> {
  final _formKey = GlobalKey<FormState>();
  final _turmaService = TurmaService();
  late final TextEditingController _nomeController;
  late final TextEditingController _disciplinaController;
  late final TextEditingController _periodoController;
  late int _anoSelecionado;
  bool _isLoading = false;

  final List<int> _anos = List.generate(
    5,
    (index) => DateTime.now().year - 2 + index,
  );
  final List<String> _periodos = ['Manhã', 'Tarde', 'Noite'];

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.turma.nome);
    _disciplinaController = TextEditingController(
      text: widget.turma.disciplina,
    );
    _periodoController = TextEditingController(text: widget.turma.periodo);
    _anoSelecionado = widget.turma.ano;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _disciplinaController.dispose();
    _periodoController.dispose();
    super.dispose();
  }

  Future<void> _atualizarTurma() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final turmaAtualizada = Turma(
        id: widget.turma.id,
        nome: _nomeController.text.trim(),
        disciplina: _disciplinaController.text.trim(),
        ano: _anoSelecionado,
        periodo: _periodoController.text,
        alunos: widget.turma.alunos,
        professorId: widget.turma.professorId,
      );

      await _turmaService.atualizarTurma(widget.turma.id!, turmaAtualizada);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Turma atualizada com sucesso!')),
      );

      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erro ao atualizar turma: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Turma'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _atualizarTurma,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Turma',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o nome da turma';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _disciplinaController,
                  decoration: const InputDecoration(
                    labelText: 'Disciplina',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite a disciplina';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _anoSelecionado, // <<-- CORRIGIDO
                  decoration: const InputDecoration(
                    labelText: 'Ano',
                    border: OutlineInputBorder(),
                  ),
                  items: _anos.map((ano) {
                    return DropdownMenuItem<int>(
                      value: ano,
                      child: Text(ano.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _anoSelecionado = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _periodoController.text,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    border: OutlineInputBorder(),
                  ),
                  items: _periodos.map((periodo) {
                    return DropdownMenuItem<String>(
                      value: periodo,
                      child: Text(periodo),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _periodoController.text = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _atualizarTurma,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                          child: const Text('Salvar Alterações'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
