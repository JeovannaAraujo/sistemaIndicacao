import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ADICIONADO
import 'solicitacoesEnviadas.dart';
import 'solicitacoesRespondidas.dart';
import 'solicitacoesAceitas.dart';
import 'buscarServicos.dart';
import 'homeCliente.dart';
import 'perfilCliente.dart'; // ADICIONADO

class RotasNavegacao {
  static Future<T?> _nav<T>(
    BuildContext c,
    Widget page, {
    bool replace = true,
  }) {
    final r = MaterialPageRoute<T>(builder: (_) => page);
    return replace
        ? Navigator.of(c).pushReplacement(r)
        : Navigator.of(c).push(r);
  }

  static Future<T?> irParaHome<T>(BuildContext c, {bool replace = true}) =>
      _nav<T>(c, const HomeScreen(), replace: replace);

  static Future<T?> irParaBuscar<T>(BuildContext c, {bool replace = true}) =>
      _nav<T>(c, const BuscarServicosScreen(), replace: replace);

  static Future<T?> irParaSolicitacoesEnviadas<T>(
    BuildContext c, {
    bool replace = true,
  }) => _nav<T>(c, const SolicitacoesEnviadasScreen(), replace: replace);

  static Future<T?> irParaSolicitacoesRespondidas<T>(
    BuildContext c, {
    bool replace = true,
  }) => _nav<T>(c, const SolicitacoesRespondidasScreen(), replace: replace);

  static Future<T?> irParaSolicitacoesAceitas<T>(
    BuildContext c, {
    bool replace = true,
  }) => _nav<T>(c, const SolicitacoesAceitasScreen(), replace: replace);

  /// ===== PERFIL DO CLIENTE =====
  /// Se [userId] não for informado, tenta usar o usuário autenticado.
  static Future<T?> irParaPerfil<T>(
    BuildContext c, {
    bool replace = true,
    String? userId,
  }) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(
        c,
      ).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));
      return Future.value(null);
    }
    return _nav<T>(c, PerfilCliente(userId: uid), replace: replace);
  }
}

/// Atalhos: context.goEnviadas(), context.goAceitas(), etc.
extension RotasExt on BuildContext {
  Future<T?> goHome<T>({bool replace = true}) =>
      RotasNavegacao.irParaHome<T>(this, replace: replace);
  Future<T?> goBuscar<T>({bool replace = true}) =>
      RotasNavegacao.irParaBuscar<T>(this, replace: replace);
  Future<T?> goEnviadas<T>({bool replace = true}) =>
      RotasNavegacao.irParaSolicitacoesEnviadas<T>(this, replace: replace);
  Future<T?> goRespondidas<T>({bool replace = true}) =>
      RotasNavegacao.irParaSolicitacoesRespondidas<T>(this, replace: replace);
  Future<T?> goAceitas<T>({bool replace = true}) =>
      RotasNavegacao.irParaSolicitacoesAceitas<T>(this, replace: replace);

  /// Novo atalho para o perfil do cliente
  Future<T?> goPerfil<T>({bool replace = true, String? userId}) =>
      RotasNavegacao.irParaPerfil<T>(this, replace: replace, userId: userId);
}

/* ====================== BottomNavigationBar (cliente) ====================== */

class ClienteBottomNav extends StatelessWidget {
  /// 0: Início, 1: Buscar, 2: Solicitações, 3: Perfil
  final int selectedIndex;
  const ClienteBottomNav({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
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
      onTap: (i) {
        if (i == selectedIndex) return;
        switch (i) {
          case 0:
            context.goHome();
            break;
          case 1:
            context.goBuscar();
            break;
          case 2:
            context.goEnviadas(); // raiz das Solicitações
            break;
          case 3:
            context.goPerfil(); // agora navega pro PerfilCliente
            break;
        }
      },
    );
  }
}
