// services/prova_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prova.dart';

class ProvaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Prova> _provasRef() {
    // Usando .withConverter para automatizar a conversão de dados
    return _firestore
        .collection('provas')
        .withConverter<Prova>(
          fromFirestore: Prova.fromFirestore,
          toFirestore: (Prova prova, _) => prova.toFirestore(),
        );
  }

  // Adicione esta função dentro da classe ProvaService

  Stream<int> getTotalProvas() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _provasRef()
        .where('professorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<String> criarProva(Prova prova) async {
    try {
      // O .withConverter já usa o toFirestore automaticamente
      final docRef = await _provasRef().add(prova);
      return docRef.id;
    } catch (e) {
      throw Exception('Erro ao criar prova: $e');
    }
  }

  Future<Prova?> getProvaById(String provaId) async {
    try {
      final docSnapshot = await _provasRef().doc(provaId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data(); // .data() já retorna o objeto Prova
      }
      return null;
    } catch (e) {
      print('Erro ao buscar prova por ID: $e');
      rethrow;
    }
  }

  Stream<List<Prova>> listarProvasPorTurma(String turmaId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _provasRef()
        .where('turmaId', isEqualTo: turmaId)
        .where('professorId', isEqualTo: userId)
        .orderBy('dataCriacao', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Prova>> listarTodasProvas() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _provasRef()
        .where('professorId', isEqualTo: userId)
        .orderBy('dataCriacao', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> atualizarProva(String id, Prova prova) async {
    try {
      // O .withConverter já usa o toFirestore automaticamente
      await _provasRef().doc(id).set(prova, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Erro ao atualizar prova: $e');
    }
  }

  Future<void> excluirProva(String id) async {
    try {
      await _provasRef().doc(id).delete();
    } catch (e) {
      throw Exception('Erro ao excluir prova: $e');
    }
  }
}
