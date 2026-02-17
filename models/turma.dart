class Turma {
  String? id;
  final String nome;
  final String disciplina;
  final int ano;
  final String periodo;
  final List<String> alunos;
  final DateTime dataCriacao;
  final String professorId;

  Turma({
    this.id,
    required this.nome,
    required this.disciplina,
    required this.ano,
    required this.periodo,
    List<String>? alunos,
    required this.professorId,
  })  : alunos = alunos ?? [],
        dataCriacao = DateTime.now();

  // Converter para Map (para Firestore)
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'disciplina': disciplina,
      'ano': ano,
      'periodo': periodo,
      'alunos': alunos,
      'professorId': professorId,
      'dataCriacao': dataCriacao,
    };
  }

  // Criar a partir de Map (do Firestore)
  factory Turma.fromMap(String id, Map<String, dynamic> map) {
    return Turma(
      id: id,
      nome: map['nome'] ?? '',
      disciplina: map['disciplina'] ?? '',
      ano: map['ano'] ?? DateTime.now().year,
      periodo: map['periodo'] ?? '',
      alunos: List<String>.from(map['alunos'] ?? []),
      professorId: map['professorId'] ?? '',
    );
  }
}
