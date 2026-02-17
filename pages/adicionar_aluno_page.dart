// lib/pages/adicionar_aluno_page.dart

import 'package:flutter/material.dart';
import '../models/aluno.dart';
import '../services/aluno_service.dart';

class AdicionarAlunoPage extends StatefulWidget {
  final String turmaId;

  const AdicionarAlunoPage({super.key, required this.turmaId});

  @override
  State<AdicionarAlunoPage> createState() => _AdicionarAlunoPageState();
}

class _AdicionarAlunoPageState extends State<AdicionarAlunoPage> {
  final _formKey = GlobalKey<FormState>();
  final _alunoService = AlunoService();
  final _nomeController = TextEditingController();
  // O campo de matrícula pode continuar na UI, mas não está no modelo Aluno no momento.
  final _matriculaController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    super.dispose();
  }

  Future<void> _salvarAluno() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      // <<-- CORREÇÃO APLICADA AQUI -->>
      // Agora passamos o turmaId e removemos a matrícula, que não existe mais no modelo.
      final novoAluno = Aluno(
        nome: _nomeController.text.trim(),
        turmaId: widget.turmaId,
      );

      try {
        await _alunoService.adicionarAluno(widget.turmaId, novoAluno);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aluno adicionado com sucesso!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao adicionar aluno: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Novo Aluno'),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo do Aluno',
                  hintText: 'Ex: João da Silva',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do aluno é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _matriculaController,
                decoration: const InputDecoration(
                  labelText: 'Matrícula / RA (Opcional)',
                  hintText: 'Ex: 202512345',
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _salvarAluno,
                      child: const Text('Salvar Aluno'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
