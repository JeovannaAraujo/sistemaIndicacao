import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Login/login.dart';
import 'agendaPrestador.dart';
// TODO: importe suas telas reais para as rotas abaixo
// import 'servicos_finalizados.dart';
// import 'solicitacoes.dart';
// import 'agenda_prestador.dart';
// import 'perfilPrestador.dart';

class HomePrestadorScreen extends StatefulWidget {
  const HomePrestadorScreen({super.key});

  @override
  State<HomePrestadorScreen> createState() => _HomePrestadorScreenState();
}

class _HomePrestadorScreenState extends State<HomePrestadorScreen> {
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    // mantenho a navegação já existente, ajuste se necessário
    if (index == 3 && user != null) {
      // TODO: aponte para sua tela de perfil, se desejar manter no bottom bar
      // Navigator.push(context,
      //   MaterialPageRoute(builder: (_) => PerfilPrestador(userId: user!.uid)),
      // );
    }
  }

  // === NOVO: somente a seção Atalhos com 3 itens ============================
  Widget _buildAtalhos() {
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
              Icons.check_circle,
              'Serviços Finalizados',
              Colors.green,
              () {
                // TODO: navegue para sua tela de serviços finalizados
                // Navigator.push(context, MaterialPageRoute(builder: (_) => ServicosFinalizadosScreen()));
              },
            ),
            _buildAtalho(Icons.assignment, 'Solicitações', Colors.orange, () {
              // TODO: navegue para sua tela de solicitações/órçamentos recebidos
              // Navigator.push(context, MaterialPageRoute(builder: (_) => SolicitacoesScreen()));
            }),
            _buildAtalho(Icons.calendar_month, 'Agenda', Colors.blue, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AgendaPrestadorScreen(),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildAtalho(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
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
  }

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
          _buildAtalhos(), // os 3 atalhos
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Scaffold(
      // Drawer mantido (se quiser remover também, me avise)
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
}
