// criar_turma_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/turma.dart';
import 'services/turma_services.dart';

class CriarTurmaPage extends StatefulWidget {
  const CriarTurmaPage({super.key});

  @override
  State<CriarTurmaPage> createState() => _CriarTurmaPageState();
}

class _CriarTurmaPageState extends State<CriarTurmaPage> {
  final _formKey = GlobalKey<FormState>();
  final _turmaService = TurmaService();
  final _nomeController = TextEditingController();
  final _disciplinaController = TextEditingController();
  final _periodoController = TextEditingController();
  int _anoSelecionado = DateTime.now().year;
  bool _isLoading = false;

  final List<int> _anos = [2023, 2024, 2025];
  final List<String> _periodos = ['Manhã', 'Tarde', 'Noite'];

  Future<void> _criarTurma() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuário não autenticado');

      final novaTurma = Turma(
        nome: _nomeController.text.trim(),
        disciplina: _disciplinaController.text.trim(),
        ano: _anoSelecionado,
        periodo: _periodoController.text,
        professorId: userId,
      );

      await _turmaService.criarTurma(novaTurma);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turma criada com sucesso!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar turma: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Turma'),
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
                    if (value == null || value.isEmpty) {
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
                    if (value == null || value.isEmpty) {
                      return 'Digite a disciplina';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _anoSelecionado,
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
                    setState(() {
                      _anoSelecionado = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _periodos.first,
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
                    _periodoController.text = value!;
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _criarTurma,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Criar Turma'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _disciplinaController.dispose();
    _periodoController.dispose();
    super.dispose();
  }
}
