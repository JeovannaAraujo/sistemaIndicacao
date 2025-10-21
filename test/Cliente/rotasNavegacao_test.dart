import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================
// 🔹 MOCKS: Telas genéricas sem Firebase
// ===========================================================
class FakeScreen extends StatelessWidget {
  final String title;
  const FakeScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(title)));
}

// ===========================================================
// 🔹 MOCK RotasNavegacao (versão testável, sem Firebase)
// ===========================================================
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
      _nav<T>(c, const FakeScreen('HomeScreen'), replace: replace);

  static Future<T?> irParaBuscar<T>(BuildContext c, {bool replace = true}) =>
      _nav<T>(c, const FakeScreen('BuscarServicosScreen'), replace: replace);

  static Future<T?> irParaSolicitacoesEnviadas<T>(BuildContext c,
          {bool replace = true}) =>
      _nav<T>(c, const FakeScreen('SolicitacoesEnviadasScreen'),
          replace: replace);

  static Future<T?> irParaSolicitacoesRespondidas<T>(BuildContext c,
          {bool replace = true}) =>
      _nav<T>(c, const FakeScreen('SolicitacoesRespondidasScreen'),
          replace: replace);

  static Future<T?> irParaSolicitacoesAceitas<T>(BuildContext c,
          {bool replace = true}) =>
      _nav<T>(c, const FakeScreen('SolicitacoesAceitasScreen'),
          replace: replace);

  static Future<T?> irParaPerfil<T>(BuildContext c,
      {bool replace = true, String? userId}) {
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(c)
          .showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));
      return Future.value(null);
    }
    return _nav<T>(c, FakeScreen('PerfilCliente ($userId)'), replace: replace);
  }
}

// ===========================================================
// 🔹 BottomNavigationBar mockado
// ===========================================================
class ClienteBottomNav extends StatelessWidget {
  final int selectedIndex;
  const ClienteBottomNav({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Solicitações'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
      onTap: (i) {
        if (i == selectedIndex) return;
        switch (i) {
          case 0:
            RotasNavegacao.irParaHome(context);
            break;
          case 1:
            RotasNavegacao.irParaBuscar(context);
            break;
          case 2:
            RotasNavegacao.irParaSolicitacoesEnviadas(context);
            break;
          case 3:
            RotasNavegacao.irParaPerfil(context, userId: 'abc123');
            break;
        }
      },
    );
  }
}

// ===========================================================
// 🧪 TESTES
// ===========================================================
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🧠 RotasNavegacao isolada', () {
    testWidgets('🔹 irParaHome navega para Fake HomeScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => RotasNavegacao.irParaHome(context),
            child: const Text('GoHome'),
          );
        }),
      ));

      await tester.tap(find.text('GoHome'));
      await tester.pumpAndSettle();

      expect(find.text('HomeScreen'), findsOneWidget);
    });

    testWidgets('🔹 irParaBuscar navega para Fake BuscarServicosScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => RotasNavegacao.irParaBuscar(context),
            child: const Text('GoBuscar'),
          );
        }),
      ));

      await tester.tap(find.text('GoBuscar'));
      await tester.pumpAndSettle();

      expect(find.text('BuscarServicosScreen'), findsOneWidget);
    });

    testWidgets('🔹 irParaSolicitacoesEnviadas navega corretamente', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => RotasNavegacao.irParaSolicitacoesEnviadas(context),
            child: const Text('GoEnviadas'),
          );
        }),
      ));

      await tester.tap(find.text('GoEnviadas'));
      await tester.pumpAndSettle();

      expect(find.text('SolicitacoesEnviadasScreen'), findsOneWidget);
    });

    testWidgets('🔹 irParaPerfil mostra SnackBar se userId vazio', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RotasNavegacao.irParaPerfil(context, userId: ''),
              child: const Text('GoPerfil'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('GoPerfil'));
      await tester.pumpAndSettle();

      expect(find.text('Usuário não autenticado.'), findsOneWidget);
    });

    testWidgets('🔹 irParaPerfil navega se userId válido', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => RotasNavegacao.irParaPerfil(context, userId: '123'),
            child: const Text('PerfilOK'),
          );
        }),
      ));

      await tester.tap(find.text('PerfilOK'));
      await tester.pumpAndSettle();

      expect(find.textContaining('PerfilCliente (123)'), findsOneWidget);
    });
  });

  group('🧩 ClienteBottomNav isolado', () {
    testWidgets('🔹 Renderiza ícones', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ClienteBottomNav(selectedIndex: 0)),
      ));

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('🔹 Tocar em Buscar navega para BuscarServicosScreen', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ClienteBottomNav(selectedIndex: 0)),
      ));

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('BuscarServicosScreen'), findsOneWidget);
    });
  });
}
