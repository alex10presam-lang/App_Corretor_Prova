import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prova.dart';

class ProvaCard extends StatelessWidget {
  final Prova prova;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProvaCard({
    super.key,
    required this.prova,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prova.titulo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.list_alt,
                            size: 16,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          '${prova.numeroQuestoes} questões',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // <<-- VERIFICAÇÃO DE NULO SIMPLIFICADA
                    if (prova.turmaId.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('turmas')
                            .doc(prova.turmaId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('Carregando turma...',
                                style: TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic));
                          }
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final turmaData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            final turmaNome =
                                turmaData?['nome'] ?? 'Turma desconhecida';
                            return Chip(
                              label: Text(turmaNome),
                              avatar: const Icon(Icons.group, size: 16),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Ver Detalhes')),
                  const PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Excluir', style: TextStyle(color: Colors.red))),
                ],
                icon: Icon(Icons.more_vert,
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
