// lib/home_screen.dart
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

// Imports de páginas
import '/criar_turma_page.dart';
import '/criar_prova_page.dart';
import 'pages/perfil_page.dart';
import 'pages/detalhes_turma_page.dart';
import 'pages/gerador_gabarito_page.dart';
import 'pages/camera_scanner_page.dart';
import '/detalhes_prova_page.dart';
import 'pages/dashboard_page.dart';
import '/editar_turma_page.dart';

// Imports de modelos e serviços
import 'models/turma.dart';
import 'services/turma_services.dart';
import 'models/prova.dart';
import 'services/prova_service.dart';

// Imports de componentes
import 'components/prova_card.dart';
import 'components/turma_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      DashboardPage(onNavigate: _onItemTapped),
      const TurmasPage(),
      const ProvasPage(),
      const PerfilPage(),
      const GeradorGabaritoPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Turmas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Provas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.print_outlined),
            activeIcon: Icon(Icons.print),
            label: 'Gerador',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// =================== PÁGINA DE TURMAS (COM PESQUISA) ===================
class TurmasPage extends StatefulWidget {
  const TurmasPage({super.key});

  @override
  State<TurmasPage> createState() => _TurmasPageState();
}

class _TurmasPageState extends State<TurmasPage> {
  final TurmaService _turmaService = TurmaService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Turmas'),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar pelo nome da turma...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Turma>>(
              stream: _turmaService.listarTurmas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }

                final todasAsTurmas = snapshot.data ?? [];
                final turmasFiltradas = todasAsTurmas.where((turma) {
                  final nomeTurma = turma.nome.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return nomeTurma.contains(query);
                }).toList();

                if (turmasFiltradas.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Nenhuma turma criada.'
                          : 'Nenhuma turma encontrada.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: turmasFiltradas.length,
                  itemBuilder: (context, index) {
                    final turma = turmasFiltradas[index];
                    return TurmaCard(
                      turma: turma,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetalhesTurmaPage(turma: turma),
                        ),
                      ),
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditarTurmaPage(turma: turma),
                        ),
                      ),
                      onDelete: () async {
                        final confirm =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmar Exclusão'),
                                content: const Text(
                                  'Tem certeza que deseja excluir esta turma?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Excluir',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (confirm) {
                          await _turmaService.excluirTurma(turma.id!);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CriarTurmaPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// =================== PÁGINA DE PROVAS (COM PESQUISA) ===================
class ProvasPage extends StatefulWidget {
  const ProvasPage({super.key});

  @override
  State<ProvasPage> createState() => _ProvasPageState();
}

class _ProvasPageState extends State<ProvasPage> {
  final ProvaService _provaService = ProvaService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Provas'),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar pelo título da prova...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Prova>>(
              stream: _provaService.listarTodasProvas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }

                final todasAsProvas = snapshot.data ?? [];
                final provasFiltradas = todasAsProvas.where((prova) {
                  final tituloProva = prova.titulo.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return tituloProva.contains(query);
                }).toList();

                if (provasFiltradas.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Nenhuma prova criada.'
                          : 'Nenhuma prova encontrada.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: provasFiltradas.length,
                  itemBuilder: (context, index) {
                    final prova = provasFiltradas[index];
                    return ProvaCard(
                      prova: prova,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetalhesProvaPage(prova: prova),
                        ),
                      ),
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetalhesProvaPage(prova: prova),
                        ),
                      ),
                      onDelete: () async {
                        final confirm =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmar Exclusão'),
                                content: const Text(
                                  'Tem certeza que deseja excluir esta prova?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Excluir',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (confirm) {
                          await _provaService.excluirProva(prova.id!);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CriarProvaPage()),
        ),
        label: const Text('Nova Prova'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
