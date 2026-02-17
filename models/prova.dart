// lib/models/prova.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Prova {
  final String? id;
  final String titulo;
  final int numeroQuestoes;
  final int questoesPorPagina; // <<-- CAMPO ADICIONADO
  final List<int> gabarito;
  final String turmaId;
  final String professorId;
  final Timestamp dataCriacao;

  Prova({
    this.id,
    required this.titulo,
    required this.numeroQuestoes,
    required this.questoesPorPagina, // <<-- ADICIONADO AO CONSTRUTOR
    required this.gabarito,
    this.turmaId = '',
    required this.professorId,
    required this.dataCriacao,
  });

  factory Prova.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return Prova(
      id: snapshot.id,
      titulo: data['titulo'] ?? '',
      numeroQuestoes: data['numeroQuestoes'] ?? 0,
      questoesPorPagina:
          data['questoesPorPagina'] ?? 40, // <<-- ADICIONADO (com valor padrão)
      gabarito: List<int>.from(data['gabarito'] ?? []),
      turmaId: data['turmaId'] ?? '',
      professorId: data['professorId'] ?? '',
      dataCriacao: data['dataCriacao'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'numeroQuestoes': numeroQuestoes,
      'questoesPorPagina': questoesPorPagina, // <<-- ADICIONADO
      'gabarito': gabarito,
      'turmaId': turmaId,
      'professorId': professorId,
      'dataCriacao': dataCriacao,
    };
  }
}
