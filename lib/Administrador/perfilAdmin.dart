import 'package:flutter/material.dart';
import 'package:myapp/Administrador/categProf.dart';
import 'unidadeMed.dart';
import 'categServ.dart';
import 'visualizarUsuarios.dart';

class PerfilAdminScreen extends StatelessWidget {
  const PerfilAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Painel do Administrador'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Bem-vindo, Administrador',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 24),
          _buildTile(
            context,
            icon: Icons.category,
            title: 'Unidades de Medida',
            subtitle:
                'Gerencie as unidades de medida disponíveis para serviços',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnidadeMedScreen()),
              );
            },
          ),
          _buildTile(
            context,
            icon: Icons.category,
            title: 'Categorias de Serviço',
            subtitle: 'Gerencie as categorias disponíveis de serviço',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategServ()),
              );
            },
          ),
          _buildTile(
            context,
            icon: Icons.category,
            title: 'Categorias de Profissionais',
            subtitle: 'Gerencie as categorias disponíveis de profissionais',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategProf()),
              );
            },
          ),
          _buildTile(
            context,
            icon: Icons.group,
            title: 'Visualizar Usuários',
            subtitle: 'Listar e monitorar usuários cadastrados',
            onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VisualizarUsuarios()),
              );
            },
          ),
          _buildTile(
            context,
            icon: Icons.settings,
            title: 'Configurações Gerais',
            subtitle: 'Ajustes do sistema e permissões',
            onTap: () {
              // Navegar para configurações
            },
          ),
          const SizedBox(height: 5),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Sair do Painel',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.deepPurple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
