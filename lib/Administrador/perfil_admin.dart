import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/Administrador/categoria_profissionais.dart';
import 'unidades_medidas.dart';
import 'categoria_servicos.dart';
import 'visualizar_usuarios.dart';
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
          const SizedBox(height: 50),
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
          const SizedBox(height: 10),

          // 🔹 Botão Sair (com logout real)
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao sair: $e')),
                    );
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: const Text(
                  'Sair do Painel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  elevation: 3,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
            color: Colors.deepPurple.withValues(alpha: 0.1),
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
