// lib/Prestador/rotasNavegacao.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_prestador.dart';
import 'solicitacoes_recebidas.dart';
import 'perfil_prestador.dart';

class RotasNavegacaoPrestador {
  static Future<T?> _nav<T>(
    BuildContext c,
    Widget page, {
    bool replace = true,
  }) {
    final r = MaterialPageRoute<T>(builder: (_) => page);
    // ✅ Retorna diretamente o Future do Navigator (funciona em testes e no app)
    return replace
        ? Navigator.of(c).pushReplacement(r)
        : Navigator.of(c).push(r);
  }

  /// ===== INÍCIO =====
  static Future<T?> irParaInicio<T>(BuildContext c, {bool replace = true}) =>
      _nav<T>(c, const HomePrestadorScreen(), replace: replace);

  /// ===== SOLICITAÇÕES =====
  static Future<T?> irParaSolicitacoes<T>(BuildContext c, {bool replace = true}) =>
      _nav<T>(c, const SolicitacoesRecebidasScreen(), replace: replace);

  /// ===== PERFIL DO PRESTADOR =====
  /// Usa o userId passado ou o do usuário autenticado.
  static Future<T?> irParaPerfil<T>(
    BuildContext c, {
    bool replace = true,
    String? userId,
  }) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return Future.value(null);
    }
    return _nav<T>(c, PerfilPrestador(userId: uid), replace: replace);
  }
}

/// Atalhos de contexto
extension RotasPrestadorExt on BuildContext {
  Future<T?> goInicio<T>({bool replace = true}) =>
      RotasNavegacaoPrestador.irParaInicio<T>(this, replace: replace);

  Future<T?> goSolicitacoes<T>({bool replace = true}) =>
      RotasNavegacaoPrestador.irParaSolicitacoes<T>(this, replace: replace);

  Future<T?> goPerfil<T>({bool replace = true, String? userId}) =>
      RotasNavegacaoPrestador.irParaPerfil<T>(this, replace: replace, userId: userId);
}

/* ================== BottomNavigationBar (prestador) ================== */

class PrestadorBottomNav extends StatelessWidget {
  /// 0: Início, 1: Solicitações, 2: Perfil
  final int selectedIndex;
  const PrestadorBottomNav({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Solicitações'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
      onTap: (i) {
        if (i == selectedIndex) return;
        switch (i) {
          case 0:
            context.goInicio();
            break;
          case 1:
            context.goSolicitacoes();
            break;
          case 2:
            context.goPerfil();
            break;
        }
      },
    );
  }
}
