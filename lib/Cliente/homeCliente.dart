import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Login/login.dart';
import 'buscarServicos.dart';
import 'listarProfissionais.dart'; // ProfissionaisPorCategoriaScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  // nome da coleção das categorias de PROFISSIONAIS
  static const String _categoriasCollection = 'categoriasProfissionais';

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _abrirCategoria(String categoriaId, String categoriaNome) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfissionaisPorCategoriaScreen(
          categoriaId: categoriaId,
          categoriaNome: categoriaNome,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Amélia Araújo'),
              accountEmail: const Text('(64)99999-9999'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person, size: 36),
              ),
              decoration: const BoxDecoration(color: Colors.deepPurple),
              otherAccountsPictures: const [
                Text(
                  'Rua Margarida...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notificações'),
            ),
            const ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configurações'),
            ),
            const ListTile(
              leading: Icon(Icons.description),
              title: Text('Solicitações'),
            ),
            const ListTile(
              leading: Icon(Icons.check_circle),
              title: Text('Serviços Finalizados'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Solicitações',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final categoriasQuery = FirebaseFirestore.instance
        .collection(_categoriasCollection)
        .where('ativo', isEqualTo: true)
        .orderBy('nome'); // se pedir índice composto, crie pelo link do erro

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Indica Aí',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const Text(
            'Encontre os melhores profissionais de sua região',
            style: TextStyle(color: Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuscarServicosScreen()),
              );
            },
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar serviços ou profissionais...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- CATEGORIAS DO FIRESTORE ---
          const Text(
            'Categorias',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: categoriasQuery.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('Erro ao carregar categorias.');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Text('Nenhuma categoria disponível no momento.');
              }

              // grid “fluido” com Wrap
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: docs.map((doc) {
                  final data = (doc.data() as Map<String, dynamic>?) ?? {};
                  final nome = (data['nome'] ?? '').toString();
                  final img = (data['imagemUrl'] ?? '').toString();
                  final corHex = (data['corHex'] ?? '').toString();

                  return _CategoriaItem(
                    label: nome,
                    imagemUrl: img,
                    color: _fromHexOrDefault(corHex, Colors.deepPurple),
                    iconData: _iconForCategory(nome),
                    onTap: () => _abrirCategoria(doc.id, nome),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // placeholder de destaques (você liga depois)
          const Text(
            'Profissionais em destaque',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          _buildProfissional('Lucas Fernandes', 'Mecânico', 5.0, 150),
          _buildProfissional('Luna Mendes', 'Faxineira', 5.0, 100),
          _buildProfissional('Eduardo Silva', 'Encanador', 5.0, 95),
          _buildProfissional('Wesley Santos', 'Pedreiro', 5.0, 75),
        ],
      ),
    );
  }

  // item visual de categoria (com imagem ou ícone)
  Widget _CategoriaItem({
    required String label,
    required Color color,
    required IconData iconData,
    required VoidCallback onTap,
    String imagemUrl = '',
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(48),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            radius: 28,
            child: (imagemUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      imagemUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(iconData, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 90,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ícone padrão por nome (fallback se a categoria não tiver imagem)
  IconData _iconForCategory(String nome) {
    final n = nome.toLowerCase();
    if (n.contains('pedreiro')) return Icons.construction;
    if (n.contains('eletric')) return Icons.flash_on;
    if (n.contains('encan') || n.contains('hidráu')) return Icons.water_drop;
    if (n.contains('mec') || n.contains('mecânico')) return Icons.build;
    if (n.contains('pint')) return Icons.format_paint;
    if (n.contains('faxin') || n.contains('diar')) {
      return Icons.cleaning_services;
    }
    return Icons.handyman;
  }

  Color _fromHexOrDefault(String hex, Color fallback) {
    if (hex.isEmpty) return fallback;
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  // placeholder do profissional em destaque (mock)
  Widget _buildProfissional(
    String nome,
    String categoria,
    double nota,
    int avaliacoes,
  ) {
    return ListTile(
      leading: const CircleAvatar(radius: 24, child: Icon(Icons.person)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Row(
        children: [
          Text(categoria, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.star, size: 16, color: Colors.amber),
          Text(' $nota  ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '($avaliacoes avaliações)',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
