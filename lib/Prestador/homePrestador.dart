// lib/Prestador/homePrestador.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Login/login.dart';
import 'agendaPrestador.dart';
import 'solicitacoesRecebidas.dart'; // << tela das solicitações recebidas

class HomePrestadorScreen extends StatefulWidget {
  const HomePrestadorScreen({super.key});

  @override
  State<HomePrestadorScreen> createState() => _HomePrestadorScreenState();
}

class _HomePrestadorScreenState extends State<HomePrestadorScreen> {
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  // ======== STREAM: contagem de pendentes para badge ========
  static const String _colSolicitacoes = 'solicitacoesOrcamento';
  Stream<int> _pendentesCountStream(String prestadorId) {
    return FirebaseFirestore.instance
        .collection(_colSolicitacoes)
        .where('prestadorId', isEqualTo: prestadorId)
        .where('status', isEqualTo: 'pendente')
        .snapshots()
        .map((s) => s.size);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    // Se quiser navegação imediata por aba:
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SolicitacoesRecebidasScreen()),
      );
    }
    // if (index == 3) -> perfil, etc
  }

  // ===================== ATALHOS ============================
  Widget _buildAtalhos() {
    final uid = user?.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Atalhos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAtalho(
              icon: Icons.check_circle,
              label: 'Serviços Finalizados',
              color: Colors.green,
              onTap: () {
                // TODO: navegue para sua tela de serviços finalizados
              },
            ),
            // Atalho de Solicitações com BADGE em tempo real
            _buildAtalho(
              icon: Icons.assignment,
              label: 'Solicitações',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SolicitacoesRecebidasScreen(),
                  ),
                );
              },
              badgeStream: (uid == null) ? null : _pendentesCountStream(uid),
            ),
            _buildAtalho(
              icon: Icons.calendar_month,
              label: 'Agenda',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AgendaPrestadorScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // Card de atalho com suporte a badge opcional
  Widget _buildAtalho({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Stream<int>? badgeStream,
  }) {
    Widget card = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 24,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    // Se houver stream de badge, envelopa num Stack
    if (badgeStream == null) return card;

    return StreamBuilder<int>(
      stream: badgeStream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return card;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(right: 6, top: 6, child: _Badge(count: count)),
          ],
        );
      },
    );
  }

  // ===================== CONTEÚDO ===========================
  Widget _buildBody() {
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
            'Gerencie seus serviços e oportunidades',
            style: TextStyle(color: Colors.deepPurple),
          ),
          const SizedBox(height: 20),
          _buildAtalhos(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final uid = u?.uid;

    return Scaffold(
      drawer: Drawer(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (u == null)
              ? const Stream.empty()
              : FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(u.uid)
                    .snapshots(),
          builder: (context, snap) {
            final dados = snap.data?.data();
            final nome = (dados?['nome'] ?? 'Prestador') as String;
            final endereco =
                (dados?['endereco'] as Map<String, dynamic>?) ?? {};
            final whatsapp = (endereco['whatsapp'] ?? '') as String;
            final rua = (endereco['rua'] ?? '') as String;
            final numero = (endereco['numero'] ?? '') as String;
            final bairro = (endereco['bairro'] ?? '') as String;
            final cidade = (endereco['cidade'] ?? '') as String;
            final fotoUrl = (dados?['fotoUrl'] ?? '') as String?;

            final enderecoTxt = [
              if (rua.isNotEmpty) '$rua, $numero',
              if (bairro.isNotEmpty) bairro,
              if (cidade.isNotEmpty) cidade,
            ].where((e) => e.trim().isNotEmpty).join(' • ');

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(nome),
                  accountEmail: Text(
                    whatsapp.isNotEmpty ? whatsapp : (u?.email ?? ''),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                        ? NetworkImage(fotoUrl)
                        : null,
                    child: (fotoUrl == null || fotoUrl.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.deepPurple,
                          )
                        : null,
                  ),
                  decoration: const BoxDecoration(color: Colors.deepPurple),
                  otherAccountsPictures: [
                    if (enderecoTxt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          enderecoTxt,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notificações'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configurações'),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment),
                  title: const Text('Solicitações'),
                  trailing: (uid == null)
                      ? null
                      : StreamBuilder<int>(
                          stream: _pendentesCountStream(uid),
                          builder: (context, snap) {
                            final c = snap.data ?? 0;
                            if (c <= 0) return const SizedBox.shrink();
                            return _Badge(count: c, small: true);
                          },
                        ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SolicitacoesRecebidasScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Serviços Finalizados'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),

      appBar: AppBar(
        title: const Text('Indica Aí'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        elevation: 0,
      ),

      body: _buildBody(),

      // ============== Bottom Bar com BADGE dinâmico ==============
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          BottomNavigationBarItem(
            // Ícone com badge em tempo real
            icon: (uid == null)
                ? const Icon(Icons.description)
                : StreamBuilder<int>(
                    stream: _pendentesCountStream(uid),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      if (count <= 0) {
                        return const Icon(Icons.description);
                      }
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.description),
                          Positioned(
                            right: -6,
                            top: -2,
                            child: _Badge(count: count),
                          ),
                        ],
                      );
                    },
                  ),
            label: 'Solicitações',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// =================== Widget de Badge reutilizável ===================
class _Badge extends StatelessWidget {
  final int count;
  final bool small;
  const _Badge({required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    final txt = (count > 99) ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 7,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: small ? 1 : 1.5),
      ),
      constraints: BoxConstraints(
        minWidth: small ? 18 : 20,
        minHeight: small ? 18 : 20,
      ),
      child: Text(
        txt,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}
