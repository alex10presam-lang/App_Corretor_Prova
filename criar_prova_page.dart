// lib/pages/criar_prova_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prova.dart';
import '../services/prova_service.dart';
import '../models/turma.dart';
import '../services/turma_services.dart';
import 'dart:async';

class CriarProvaPage extends StatefulWidget {
  const CriarProvaPage({super.key});

  @override
  State<CriarProvaPage> createState() => _CriarProvaPageState();
}

class _CriarProvaPageState extends State<CriarProvaPage> {
  final _formKey = GlobalKey<FormState>();
  final _provaService = ProvaService();
  final _turmaService = TurmaService();
  final _tituloController = TextEditingController();

  List<int> _gabaritoRespostas = [];
  int _numeroQuestoes = 10;
  String? _turmaSelecionadaId;
  List<Turma> _turmas = [];
  bool _isLoading = false;
  bool _carregandoTurmas = true;

  final List<String> _alternativas = ['A', 'B', 'C', 'D', 'E'];
  StreamSubscription? _turmasSubscription;

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
    _inicializarGabarito();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _turmasSubscription?.cancel();
    super.dispose();
  }

  Future<void> _carregarTurmas() async {
    setState(() => _carregandoTurmas = true);
    _turmasSubscription = _turmaService.listarTurmas().listen((turmas) {
      if (mounted) {
        setState(() {
          _turmas = turmas;
          _carregandoTurmas = false;
        });
      }
    });
  }

  void _inicializarGabarito() {
    _gabaritoRespostas = List.generate(_numeroQuestoes, (_) => 0);
  }

  void _atualizarNumeroQuestoes(int novoNumero) {
    setState(() {
      _numeroQuestoes = novoNumero;
      _inicializarGabarito();
    });
  }

  Future<void> _criarProva() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuário não autenticado');

      final novaProva = Prova(
        titulo: _tituloController.text.trim(),
        turmaId: _turmaSelecionadaId ?? '',
        numeroQuestoes: _numeroQuestoes,
        gabarito: _gabaritoRespostas,
        professorId: userId,
        dataCriacao: Timestamp.now(),
        questoesPorPagina: 20,
      );

      await _provaService.criarProva(novaProva);

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Prova criada com sucesso!')),
      );
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Erro ao criar prova: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSeletorDeAlternativa(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0,
              runSpacing: 12.0,
              children: List.generate(5, (buttonIndex) {
                final isSelected = _gabaritoRespostas[index] == buttonIndex;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _gabaritoRespostas[index] = buttonIndex;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                  ),
                  child: Text(
                    _alternativas[buttonIndex],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Prova'),
        foregroundColor: Colors.white,
      ),
      // <<-- CORREÇÃO: Usando Column e Expanded para o ListView -->>
      body: _carregandoTurmas
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título da Prova',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Digite o título da prova';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _turmaSelecionadaId,
                      decoration: const InputDecoration(
                        labelText: 'Turma (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      items: _turmas.map((turma) {
                        return DropdownMenuItem<String>(
                          value: turma.id,
                          child: Text(turma.nome),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _turmaSelecionadaId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _numeroQuestoes,
                      decoration: const InputDecoration(
                        labelText: 'Número de Questões',
                        border: OutlineInputBorder(),
                      ),
                      items: [10, 15, 20, 25, 30, 40, 50].map((numero) {
                        return DropdownMenuItem<int>(
                          value: numero,
                          child: Text('$numero questões'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _atualizarNumeroQuestoes(value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Gabarito (Respostas Corretas)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 16),
                    // <<-- CORREÇÃO: ListView.builder para a lista de questões -->>
                    Expanded(
                      child: ListView.separated(
                        itemCount: _numeroQuestoes,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              'Q${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            title: const Text('Resposta:'),
                            trailing: ActionChip(
                              label: Text(
                                _alternativas[_gabaritoRespostas[index]],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              onPressed: () =>
                                  _mostrarSeletorDeAlternativa(index),
                            ),
                            onTap: () => _mostrarSeletorDeAlternativa(index),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _criarProva,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text('Criar Prova'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
