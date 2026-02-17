// lib/components/selecionar_aluno_dialog.dart

import 'package:flutter/material.dart';
import '../models/aluno.dart';
import '../models/turma.dart';
import '../services/aluno_service.dart';
import '../services/turma_services.dart';

class SelecionarAlunoDialog extends StatefulWidget {
  const SelecionarAlunoDialog({super.key});

  @override
  State<SelecionarAlunoDialog> createState() => _SelecionarAlunoDialogState();
}

class _SelecionarAlunoDialogState extends State<SelecionarAlunoDialog> {
  final TurmaService _turmaService = TurmaService();
  final AlunoService _alunoService = AlunoService();

  List<Turma> _turmas = [];
  List<Aluno> _alunos = [];
  Turma? _turmaSelecionada;
  Aluno? _alunoSelecionado;
  bool _isLoadingTurmas = true;
  bool _isLoadingAlunos = false;

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    try {
      final turmas = await _turmaService.listarTurmas().first;
      if (mounted) {
        setState(() {
          _turmas = turmas;
          _isLoadingTurmas = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar turmas: $e");
      if (mounted) {
        setState(() {
          _isLoadingTurmas = false;
        });
      }
    }
  }

  Future<void> _carregarAlunos(String turmaId) async {
    setState(() {
      _isLoadingAlunos = true;
      _alunos = [];
      _alunoSelecionado = null;
    });
    try {
      final alunos = await _alunoService.listarAlunos(turmaId).first;
      if (mounted) {
        setState(() {
          _alunos = alunos;
          _isLoadingAlunos = false;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar alunos: $e");
      if (mounted) {
        setState(() {
          _isLoadingAlunos = false;
        });
      }
    }
  }

  void _onTurmaChanged(Turma? turma) {
    if (turma != null) {
      setState(() {
        _turmaSelecionada = turma;
      });
      _carregarAlunos(turma.id!);
    }
  }

  void _onAlunoChanged(Aluno? aluno) {
    setState(() {
      _alunoSelecionado = aluno;
    });
  }

  void _confirmarSelecao() {
    if (_alunoSelecionado != null) {
      Navigator.of(context).pop(_alunoSelecionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atribuir Resultado'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingTurmas)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Turma>(
                  value: _turmaSelecionada,
                  onChanged: _onTurmaChanged,
                  hint: const Text('Selecione uma turma'),
                  isExpanded: true,
                  items: _turmas.map((turma) {
                    return DropdownMenuItem(
                      value: turma,
                      child: Text(turma.nome),
                    );
                  }).toList(),
                  decoration: const InputDecoration(
                    labelText: 'Turma',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 24),
              if (_isLoadingAlunos)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                )
              else if (_turmaSelecionada != null)
                DropdownButtonFormField<Aluno>(
                  value: _alunoSelecionado,
                  onChanged: _onAlunoChanged,
                  hint: const Text('Selecione um aluno'),
                  isExpanded: true,
                  items: _alunos.map((aluno) {
                    return DropdownMenuItem(
                      value: aluno,
                      child: Text(aluno.nome),
                    );
                  }).toList(),
                  decoration: const InputDecoration(
                    labelText: 'Aluno',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _alunoSelecionado != null ? _confirmarSelecao : null,
          child: const Text('Atribuir e Salvar'),
        ),
      ],
    );
  }
}
