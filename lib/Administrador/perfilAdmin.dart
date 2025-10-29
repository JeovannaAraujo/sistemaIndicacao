import 'package:flutter/material.dart';
import 'package:myapp/Administrador/categoriaProfissionais.dart';
import 'unidadesMedidas.dart';
import 'categoriaServicos.dart';
import 'visualizarUsuarios.dart';
import '../Login/login.dart';

class PerfilAdminScreen extends StatelessWidget {
  const PerfilAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          const SizedBox(height: 40),

          const Text(
            'Bem-vindo, Administrador',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gerencie facilmente as configurações e recursos do sistema.',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 25),

          // 🔹 Seções
          buildModernTile(
            context,
            icon: Icons.straighten_rounded,
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
          buildModernTile(
            context,
            icon: Icons.home_repair_service_rounded,
            title: 'Categorias de Serviço',
            subtitle: 'Gerencie as categorias disponíveis de serviço',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategServ()),
              );
            },
          ),
          buildModernTile(
            context,
            icon: Icons.engineering_rounded,
            title: 'Categorias de Profissionais',
            subtitle: 'Gerencie as categorias disponíveis de profissionais',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategProf()),
              );
            },
          ),
          buildModernTile(
            context,
            icon: Icons.people_alt_rounded,
            title: 'Visualizar Usuários',
            subtitle: 'Listar e monitorar usuários cadastrados',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VisualizarUsuarios()),
              );
            },
          ),
          // 🔹 Botão Sair
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              label: const Text(
                'Sair do Painel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Card Moderno
  Widget buildModernTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 28, color: Colors.deepPurple),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.deepPurple,
          size: 18,
        ),
        onTap: onTap,
      ),
    );
  }
}
