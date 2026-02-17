// lib/services/turma_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/turma.dart';

class TurmaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _turmasRef => _firestore.collection('turmas');
  String? get _userId => _auth.currentUser?.uid;

  Stream<int> getTotalTurmas() {
    if (_userId == null) return Stream.value(0);
    return _turmasRef
        .where('professorId', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // <<-- NOVA FUNÇÃO -->>
  // Adiciona uma lista de alunos à turma de uma só vez.
  Future<void> adicionarAlunosEmMassa(
    String turmaId,
    List<String> nomesDosAlunos,
  ) async {
    if (nomesDosAlunos.isEmpty) return;
    try {
      await _turmasRef.doc(turmaId).update({
        'alunos': FieldValue.arrayUnion(nomesDosAlunos),
      });
    } catch (e) {
      throw Exception('Erro ao adicionar alunos em massa: $e');
    }
  }

  Future<String> criarTurma(Turma turma) async {
    try {
      final docRef = await _turmasRef.add(turma.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Erro ao criar turma: $e');
    }
  }

  Stream<List<Turma>> listarTurmas() {
    if (_userId == null) return Stream.value([]);
    return _turmasRef
        .where('professorId', isEqualTo: _userId)
        .orderBy('dataCriacao', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Turma.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  Future<void> atualizarTurma(String id, Turma turma) async {
    try {
      await _turmasRef.doc(id).update(turma.toMap());
    } catch (e) {
      throw Exception('Erro ao atualizar turma: $e');
    }
  }

  Future<void> excluirTurma(String id) async {
    try {
      await _turmasRef.doc(id).delete();
    } catch (e) {
      throw Exception('Erro ao excluir turma: $e');
    }
  }

  Future<void> adicionarAluno(String turmaId, String alunoNome) async {
    try {
      await _turmasRef.doc(turmaId).update({
        'alunos': FieldValue.arrayUnion([alunoNome]),
      });
    } catch (e) {
      throw Exception('Erro ao adicionar aluno: $e');
    }
  }

  Future<void> removerAluno(String turmaId, String alunoNome) async {
    try {
      await _turmasRef.doc(turmaId).update({
        'alunos': FieldValue.arrayRemove([alunoNome]),
      });
    } catch (e) {
      throw Exception('Erro ao remover aluno: $e');
    }
  }
}
