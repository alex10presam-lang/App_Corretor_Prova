// lib/models/aluno.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Aluno {
  final String? id;
  final String nome;
  final String turmaId;

  Aluno({this.id, required this.nome, required this.turmaId});

  // <<-- CORREÇÃO: A função agora aceita apenas um argumento -->>
  factory Aluno.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return Aluno(
      id: snapshot.id,
      nome: data?['nome'] ?? '',
      turmaId: data?['turmaId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'nome': nome, 'turmaId': turmaId};
  }
}
