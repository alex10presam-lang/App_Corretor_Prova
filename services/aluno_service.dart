// lib/services/aluno_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/aluno.dart';

class AlunoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // A referência da coleção de turmas foi movida para ser mais específica para cada usuário no futuro.
  // Por enquanto, aponta para a raiz 'turmas'.
  CollectionReference<Map<String, dynamic>> _turmasCollection() {
    return _firestore.collection('turmas');
  }

  Future<Aluno?> getAlunoById(String turmaId, String alunoId) async {
    try {
      // Busca direta, muito mais eficiente e segura
      final docSnapshot = await _turmasCollection()
          .doc(turmaId)
          .collection('alunos')
          .doc(alunoId)
          .get();

      if (docSnapshot.exists) {
        return Aluno.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      print('Erro ao buscar aluno por ID: $e');
      rethrow;
    }
  }

  Stream<List<Aluno>> listarAlunos(String turmaId) {
    return _turmasCollection()
        .doc(turmaId)
        .collection('alunos')
        .orderBy('nome')
        .snapshots()
        .map((snapshot) {
          // Esta chamada já estava correta.
          return snapshot.docs.map((doc) => Aluno.fromFirestore(doc)).toList();
        });
  }

  Future<void> adicionarAluno(String turmaId, Aluno aluno) {
    return _turmasCollection()
        .doc(turmaId)
        .collection('alunos')
        // <<-- CORREÇÃO: Usa toFirestore() como definido no modelo -->>
        .add(aluno.toFirestore());
  }

  Future<void> editarAluno(String turmaId, Aluno aluno) {
    return _turmasCollection()
        .doc(turmaId)
        .collection('alunos')
        .doc(aluno.id)
        // <<-- CORREÇÃO: Usa toFirestore() como definido no modelo -->>
        .update(aluno.toFirestore());
  }

  Future<void> excluirAluno(String turmaId, String alunoId) {
    return _turmasCollection()
        .doc(turmaId)
        .collection('alunos')
        .doc(alunoId)
        .delete();
  }
}
