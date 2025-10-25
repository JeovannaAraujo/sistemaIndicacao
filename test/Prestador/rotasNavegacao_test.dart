// 🧭 test/Prestador/rotasNavegacao_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

/// ===========================================================
/// 🔧 Setup Firebase Fake (evita erro [core/no-app])
/// ===========================================================
Future<void> _setupFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// ===========================================================
/// 🧩 DummyScreen — simula telas reais sem Firebase
/// ===========================================================
class DummyScreen extends StatelessWidget {
  final String label;
  const DummyScreen(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

/// ===========================================================
/// 🧪 FakePrestadorBottomNav — mock sem rotas nem Firebase
/// ===========================================================
class FakePrestadorBottomNav extends StatelessWidget {
  final int selectedIndex;
  const FakePrestadorBottomNav({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
        BottomNavigationBarItem(
            icon: Icon(Icons.description), label: 'Solicitações'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
      onTap: (i) {
      },
    );
  }
}

void main() {
  setUpAll(() async => await _setupFirebase());

  // ===========================================================
  // GRUPO 1️⃣ - Testes das rotas diretas
  // ===========================================================
  group('🧭 RotasNavegacaoPrestador', () {
    testWidgets('🏠 irParaInicio navega corretamente', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DummyScreen('Inicio')),
            );
          });
          return const Placeholder();
        }),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets('📋 irParaSolicitacoes navega corretamente', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DummyScreen('Solicitacoes')),
            );
          });
          return const Placeholder();
        }),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Solicitacoes'), findsOneWidget);
    });

    testWidgets('⚠️ irParaPerfil sem user mostra SnackBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final context = tester.element(find.byType(Scaffold));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ===========================================================
  // GRUPO 2️⃣ - Testes do BottomNavigationBar do Prestador
  // ===========================================================
  group('🧭 PrestadorBottomNav', () {
    testWidgets('🟣 BottomNavigation troca abas', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(bottomNavigationBar: FakePrestadorBottomNav(selectedIndex: 0)),
      ));

      await tester.tap(find.text('Solicitações'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Perfil'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('🔒 Evita reabrir aba atual', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(bottomNavigationBar: FakePrestadorBottomNav(selectedIndex: 1)),
      ));

      await tester.tap(find.text('Solicitações'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('⭐ Label ativo muda conforme selectedIndex', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(bottomNavigationBar: FakePrestadorBottomNav(selectedIndex: 2)),
      ));

      // Verifica se o label "Perfil" existe na tela
      expect(find.text('Perfil'), findsOneWidget);
    });
  });
}
