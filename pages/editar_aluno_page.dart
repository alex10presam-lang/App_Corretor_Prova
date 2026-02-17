// lib/pages/editar_aluno_page.dart

import 'package:flutter/material.dart';
import '../models/aluno.dart';
import '../services/aluno_service.dart';

class EditarAlunoPage extends StatefulWidget {
  final String turmaId;
  final Aluno aluno;

  const EditarAlunoPage({
    super.key,
    required this.turmaId,
    required this.aluno,
  });

  @override
  State<EditarAlunoPage> createState() => _EditarAlunoPageState();
}

class _EditarAlunoPageState extends State<EditarAlunoPage> {
  final _formKey = GlobalKey<FormState>();
  final _alunoService = AlunoService();
  late TextEditingController _nomeController;
  late TextEditingController _matriculaController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.aluno.nome);
    // <<-- CORREÇÃO: O modelo Aluno não tem mais matrícula, então inicializamos vazio -->>
    _matriculaController = TextEditingController();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _matriculaController.dispose();
    super.dispose();
  }

  Future<void> _salvarAlteracoes() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      // <<-- CORREÇÃO APLICADA AQUI -->>
      // Adicionado `turmaId` e removido `matricula` para corresponder ao novo modelo Aluno
      final alunoAtualizado = Aluno(
        id: widget.aluno.id, // Mantém o mesmo ID
        nome: _nomeController.text.trim(),
        turmaId: widget.turmaId,
      );

      try {
        await _alunoService.editarAluno(widget.turmaId, alunoAtualizado);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aluno atualizado com sucesso!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar aluno: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Aluno'),
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
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _matriculaController,
                decoration: const InputDecoration(
                  labelText: 'Matrícula / RA (Opcional)',
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _salvarAlteracoes,
                      child: const Text('Salvar Alterações'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
