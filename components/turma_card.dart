// lib/components/turma_card.dart

import 'package:flutter/material.dart';
import '../models/aluno.dart';
import '../models/turma.dart';
import '../services/aluno_service.dart'; // Precisamos do serviço para contar os alunos

class TurmaCard extends StatelessWidget {
  final Turma turma;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const TurmaCard({
    super.key,
    required this.turma,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.group_outlined,
                      color: theme.colorScheme.primary, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          turma.nome,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${turma.disciplina} - ${turma.periodo}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
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
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir',
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                    icon: Icon(Icons.more_vert,
                        color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // <<-- A MÁGICA ACONTECE AQUI -->>
              // Este widget agora busca e exibe a contagem de alunos em tempo real
              _AlunoCountChip(turmaId: turma.id!),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para buscar e exibir a contagem de alunos de forma reativa
class _AlunoCountChip extends StatelessWidget {
  final String turmaId;
  final AlunoService _alunoService = AlunoService();

  _AlunoCountChip({required this.turmaId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Aluno>>(
      stream: _alunoService.listarAlunos(turmaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Mostra um pequeno indicador de carregamento na primeira vez
          return const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        final count = snapshot.data?.length ?? 0;

        return Chip(
          avatar: Icon(Icons.person_outline,
              size: 16, color: theme.colorScheme.primary),
          label: Text('$count ${count == 1 ? "aluno" : "alunos"}'),
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          side: BorderSide.none,
        );
      },
    );
  }
}
