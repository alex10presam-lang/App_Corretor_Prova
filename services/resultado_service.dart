// lib/services/resultado_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/aluno.dart';
import '../models/prova.dart';
import '../models/resultado.dart';
import 'package:corretor_provas/utils/validator.dart'; // LINHA CORRIGIDA

class ResultadoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Resultado> _resultadosCollection() {
    return _firestore
        .collection('resultados')
        .withConverter<Resultado>(
          fromFirestore: Resultado.fromFirestore,
          toFirestore: (Resultado resultado, _) => resultado.toFirestore(),
        );
  }

  // <<-- MELHORIA: Helper para aplicar a segurança em todas as queries -->>
  Query<Resultado> _secureQuery() {
    if (_userId == null) {
      // Retorna uma query que nunca terá resultados se o usuário não estiver logado.
      return _resultadosCollection().where(
        'professorId',
        isEqualTo: 'invalid_user',
      );
    }
    return _resultadosCollection().where('professorId', isEqualTo: _userId);
  }

  Stream<List<Resultado>> getResultadosRecentes() {
    return _secureQuery()
        .orderBy('dataCorrecao', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<int> getTotalCorrecoes() {
    return _secureQuery().snapshots().map((snapshot) => snapshot.docs.length);
  }

  Future<Resultado?> getResultadoById(String resultadoId) async {
    // Para buscas diretas por ID, a regra de segurança do documento já protege.
    final snapshot = await _resultadosCollection().doc(resultadoId).get();
    return snapshot.data();
  }

  // <<-- CORREÇÃO E REFACTOR: Usando o _secureQuery -->>
  Stream<List<Resultado>> listarResultados(String provaId) {
    return _secureQuery()
        .where('provaId', isEqualTo: provaId)
        .orderBy('alunoNome')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // <<-- CORREÇÃO E REFACTOR: Usando o _secureQuery -->>
  Stream<List<Resultado>> listarResultadosPorTurma(String turmaId) {
    return _secureQuery()
        .where('turmaId', isEqualTo: turmaId)
        .orderBy('dataCorrecao', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> excluirResultado(String resultadoId) async {
    final docRef = _resultadosCollection().doc(resultadoId);
    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final resultado = docSnapshot.data();
        if (resultado != null &&
            resultado.imageUrl != null &&
            resultado.imageUrl!.isNotEmpty) {
          try {
            await _storage.refFromURL(resultado.imageUrl!).delete();
          } catch (e) {
            print("Erro ao excluir imagem do Storage: $e");
          }
        }
      }
      await docRef.delete();
    } catch (e) {
      throw Exception('Erro ao excluir resultado: $e');
    }
  }

  Future<void> atualizarResultado({
    required String resultadoId,
    required List<int> novasRespostas,
    required Prova prova,
  }) async {
    final validationResult = GabaritoValidator.validarRespostas(
      respostasDetectadas: novasRespostas,
      gabaritoOficial: prova.gabarito,
      numQuestoes: prova.numeroQuestoes,
    );

    final dadosAtualizados = {
      'respostasAluno': novasRespostas,
      'nota': validationResult.nota,
      'acertos': validationResult.acertos,
      'correcoes': validationResult.detalhesQuestoes
          // --- LINHA CORRIGIDA ---
          .map((d) => (d['acertou'] == true) ? 'C' : 'E')
          .toList(),
    };

    await _resultadosCollection().doc(resultadoId).update(dadosAtualizados);
  }

  Future<void> salvarResultado({
    required String provaId,
    required String turmaId,
    required Aluno aluno,
    required List<int> gabaritoOficial,
    required List<int> respostasAluno,
    String? imagePath,
  }) async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado.');
    }

    final validationResult = GabaritoValidator.validarRespostas(
      respostasDetectadas: respostasAluno,
      gabaritoOficial: gabaritoOficial,
      numQuestoes: gabaritoOficial.length,
    );

    String? imageUrl;
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      final ref = _storage.ref().child(
        'correcoes/$_userId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(file);
      imageUrl = await ref.getDownloadURL();
    }

    final novoResultado = Resultado(
      provaId: provaId,
      turmaId: turmaId,
      professorId: _userId!,
      alunoId: aluno.id!,
      alunoNome: aluno.nome,
      respostasAluno: respostasAluno,
      correcoes: validationResult.detalhesQuestoes
          // --- LINHA CORRIGIDA ---
          .map((d) => (d['acertou'] == true) ? 'C' : 'E')
          .toList(),
      nota: validationResult.nota,
      acertos: validationResult.acertos,
      dataCorrecao: Timestamp.now(),
      imageUrl: imageUrl,
    );

    await _resultadosCollection().add(novoResultado);
  }
}
