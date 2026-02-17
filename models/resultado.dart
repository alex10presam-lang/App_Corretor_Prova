// lib/models/resultado.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Resultado {
  final String? id;
  final String provaId;
  final String turmaId;
  final String professorId;
  final String alunoNome;
  final String alunoId;
  final List<int> respostasAluno; // <<-- CORRIGIDO para List<int>
  final List<String> correcoes;
  final double nota;
  final int acertos; // <<-- CAMPO ADICIONADO para acesso rápido
  final Timestamp dataCorrecao;
  final String? imageUrl;

  Resultado({
    this.id,
    required this.provaId,
    required this.turmaId,
    required this.professorId,
    required this.alunoNome,
    required this.alunoId,
    required this.respostasAluno,
    required this.correcoes,
    required this.nota,
    required this.acertos,
    required this.dataCorrecao,
    this.imageUrl,
  });

  // <<-- CONVERSOR ATUALIZADO (PADRÃO MODERNO) -->>
  factory Resultado.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return Resultado(
      id: snapshot.id,
      provaId: data['provaId'] ?? '',
      turmaId: data['turmaId'] ?? '',
      professorId: data['professorId'] ?? '',
      alunoNome: data['alunoNome'] ?? '',
      alunoId: data['alunoId'] ?? '',
      respostasAluno: List<int>.from(data['respostasAluno'] ?? []),
      correcoes: List<String>.from(data['correcoes'] ?? []),
      nota: (data['nota'] as num? ?? 0.0).toDouble(),
      acertos: data['acertos'] ?? 0,
      dataCorrecao: data['dataCorrecao'] ?? Timestamp.now(),
      imageUrl: data['imageUrl'],
    );
  }

  // <<-- CONVERSOR ATUALIZADO (PADRÃO MODERNO) -->>
  Map<String, dynamic> toFirestore() {
    return {
      'provaId': provaId,
      'turmaId': turmaId,
      'professorId': professorId,
      'alunoNome': alunoNome,
      'alunoId': alunoId,
      'respostasAluno': respostasAluno,
      'correcoes': correcoes,
      'nota': nota,
      'acertos': acertos,
      'dataCorrecao': dataCorrecao,
      'imageUrl': imageUrl,
    };
  }
}
