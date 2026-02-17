// lib/pages/dashboard_page.dart
import 'package:corretor_provas/models/resultado.dart';
import 'package:corretor_provas/pages/camera_scanner_page.dart';
import 'package:corretor_provas/criar_prova_page.dart';
import 'package:corretor_provas/criar_turma_page.dart';
import 'package:corretor_provas/services/auth_service.dart';
import 'package:corretor_provas/services/prova_service.dart';
import 'package:corretor_provas/services/resultado_service.dart';
import 'package:corretor_provas/services/turma_services.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  // <<-- CORREÇÃO: Adicionando o parâmetro para receber a função -->>
  final Function(int) onNavigate;
  const DashboardPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final TurmaService turmaService = TurmaService();
    final ProvaService provaService = ProvaService();
    final ResultadoService resultadoService = ResultadoService();
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // A navegação será tratada pelo StreamBuilder no main.dart
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatsCard(turmaService, provaService, resultadoService),
          const SizedBox(height: 24),
          Text(
            'Ações Rápidas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildShortcutsCard(context),
          const SizedBox(height: 24),
          Text(
            'Últimas Correções',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRecentCorrectionsCard(resultadoService),
        ],
      ),
    );
  }

  Widget _buildShortcutsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // <<-- CORREÇÃO: Ações dos botões agora usam a função onNavigate -->>
            _buildShortcutItem(
              context,
              Icons.group,
              'Turmas',
              () => onNavigate(1),
            ),
            _buildShortcutItem(
              context,
              Icons.assignment,
              'Provas',
              () => onNavigate(2),
            ),
            _buildShortcutItem(context, Icons.qr_code_scanner, 'Escanear', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraScannerPage(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    TurmaService turmaService,
    ProvaService provaService,
    ResultadoService resultadoService,
  ) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: turmaService.getTotalTurmas(),
            builder: (context, snapshot) {
              return _buildStatItem(
                'Turmas',
                snapshot.data ?? 0,
                Icons.group,
                Colors.blue,
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StreamBuilder<int>(
            stream: provaService.getTotalProvas(),
            builder: (context, snapshot) {
              return _buildStatItem(
                'Provas',
                snapshot.data ?? 0,
                Icons.assignment,
                Colors.orange,
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StreamBuilder<int>(
            stream: resultadoService.getTotalCorrecoes(),
            builder: (context, snapshot) {
              return _buildStatItem(
                'Correções',
                snapshot.data ?? 0,
                Icons.check_circle,
                Colors.green,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildRecentCorrectionsCard(ResultadoService resultadoService) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<Resultado>>(
          stream: resultadoService.getResultadosRecentes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text('Nenhuma correção recente.'),
                ),
              );
            }
            final resultados = snapshot.data!;
            return Column(
              children: resultados.map((resultado) {
                return ListTile(
                  title: Text(
                    resultado.alunoNome,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    '${resultado.nota.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: resultado.nota >= 6 ? Colors.green : Colors.red,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
