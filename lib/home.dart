import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'buscarServicos.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Indica Aí', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const Text('Encontre os melhores profissionais de sua região', style: TextStyle(color: Colors.deepPurple)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BuscarServicosScreen()));
            },
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar serviços ou profissionais...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Categorias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildCategoria(Icons.construction, 'Pedreiro', Colors.green),
              _buildCategoria(Icons.flash_on, 'Eletricista', Colors.yellow),
              _buildCategoria(Icons.water_drop, 'Encanador', Colors.blue),
              _buildCategoria(Icons.build, 'Mecânico', Colors.grey),
              _buildCategoria(Icons.format_paint, 'Pintor', Colors.purple),
              _buildCategoria(Icons.cleaning_services, 'Faxineira', Colors.blueGrey),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Profissionais em destaque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 12),
          _buildProfissional('Lucas Fernandes', 'Mecânico', 5.0, 150),
          _buildProfissional('Luna Mendes', 'Faxineira', 5.0, 100),
          _buildProfissional('Eduardo Silva', 'Encanador', 5.0, 95),
          _buildProfissional('Wesley Santos', 'Pedreiro', 5.0, 75),
        ],
      ),
    );
  }

  Widget _buildCategoria(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          radius: 28,
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.black87)),
      ],
    );
  }

  Widget _buildProfissional(String nome, String categoria, double nota, int avaliacoes) {
    return ListTile(
      leading: const CircleAvatar(radius: 24, child: Icon(Icons.person)),
      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(categoria, style: const TextStyle(fontSize: 12)),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              Text('$nota  ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('($avaliacoes avaliações)', style: const TextStyle(fontSize: 12))
            ],
          )
        ],
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
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person, size: 36)),
              decoration: const BoxDecoration(color: Colors.deepPurple),
              otherAccountsPictures: const [
                Text('Rua Margarida...', style: TextStyle(color: Colors.white70, fontSize: 12))
              ],
            ),
            ListTile(leading: const Icon(Icons.notifications), title: const Text('Notificações')),
            ListTile(leading: const Icon(Icons.settings), title: const Text('Configurações')),
            ListTile(leading: const Icon(Icons.description), title: const Text('Solicitações')),
            ListTile(leading: const Icon(Icons.check_circle), title: const Text('Serviços Finalizados')),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
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
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Solicitações'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
