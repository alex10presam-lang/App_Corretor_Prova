// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'professores';

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection(_collectionPath).doc(uid).snapshots();
  }

  Future<void> createUserDocument(String uid, String nome, String email) async {
    await _firestore.collection(_collectionPath).doc(uid).set({
      'nome': nome,
      'email': email,
      'escola': '', // Campo opcional para o futuro
      'dataCriacao': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserName(String uid, String newName) async {
    await _firestore.collection(_collectionPath).doc(uid).update({
      'nome': newName,
    });
  }
}
