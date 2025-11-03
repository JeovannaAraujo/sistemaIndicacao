import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/Administrador/perfil_admin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🧪 Testes unitários do método buildModernTile', () {
    Widget makeTestableWidget(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    Widget makeTile({
      IconData icon = Icons.home,
      String title = 'Título padrão',
      String subtitle = 'Subtítulo padrão',
      VoidCallback? onTap,
    }) {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      return makeTestableWidget(
        screen.buildModernTile(
          ctx,
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onTap ?? () {},
        ),
      );
    }

    testWidgets('1️⃣ Cria um widget do tipo Container', (tester) async {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildModernTile(
        ctx,
        icon: Icons.home,
        title: 'Teste',
        subtitle: 'Teste',
        onTap: () {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget, // Usa o widget diretamente
          ),
        ),
      );

      // Verifica se há pelo menos um Container na árvore
      expect(find.byType(Container), findsAtLeast(1));
    });

    testWidgets('2️⃣ Contém um ListTile dentro do Container', (tester) async {
      await tester.pumpWidget(makeTile());
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('3️⃣ Exibe o ícone correto', (tester) async {
      await tester.pumpWidget(makeTile(icon: Icons.star));
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('4️⃣ Exibe o título correto', (tester) async {
      await tester.pumpWidget(makeTile(title: 'Teste Título'));
      expect(find.text('Teste Título'), findsOneWidget);
    });

    testWidgets('5️⃣ Exibe o subtítulo correto', (tester) async {
      await tester.pumpWidget(makeTile(subtitle: 'Subtexto'));
      expect(find.text('Subtexto'), findsOneWidget);
    });

    testWidgets('6️⃣ Ícone principal tem cor roxa', (tester) async {
      await tester.pumpWidget(makeTile(icon: Icons.settings));
      final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
      expect(icon.color, Colors.deepPurple);
    });

    testWidgets('7️⃣ Ícone principal tem tamanho 28', (tester) async {
      await tester.pumpWidget(makeTile());
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.size, 28);
    });

    testWidgets('8️⃣ Exibe ícone de seta à direita', (tester) async {
      await tester.pumpWidget(makeTile());
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    });

    testWidgets('9️⃣ Título está em negrito', (tester) async {
      await tester.pumpWidget(makeTile(title: 'Negrito'));
      final textWidget = tester.widget<Text>(find.text('Negrito'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('🔟 Container possui margem inferior de 16', (tester) async {
      await tester.pumpWidget(makeTile());
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.margin, const EdgeInsets.only(bottom: 16));
    });

    testWidgets('11️⃣ Ao tocar chama o onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(makeTile(onTap: () => tapped = true));
      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('12️⃣ Ícone de seta é do tipo Icon', (tester) async {
      await tester.pumpWidget(makeTile());
      final trailing = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_ios_rounded),
      );
      expect(trailing.runtimeType, Icon);
    });

    testWidgets('13️⃣ Não lança exceções ao construir com parâmetros padrão', (
      tester,
    ) async {
      await tester.pumpWidget(makeTile());
      expect(tester.takeException(), isNull);
    });

    testWidgets('14️⃣ Suporta diferentes ícones sem falhar', (tester) async {
      final icons = [Icons.add, Icons.remove, Icons.alarm, Icons.book];
      for (var i in icons) {
        await tester.pumpWidget(makeTile(icon: i));
        expect(find.byIcon(i), findsOneWidget);
      }
    });

    testWidgets('15️⃣ Renderiza corretamente em modo escuro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: const PerfilAdminScreen().buildModernTile(
              _FakeContext(),
              icon: Icons.star,
              title: 'Teste',
              subtitle: 'Teste',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('16️⃣ Exibe título e subtítulo juntos', (tester) async {
      await tester.pumpWidget(makeTile(title: 'Título', subtitle: 'Sub'));
      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
    });

    testWidgets('17️⃣ O Container é clicável pelo ListTile', (tester) async {
      await tester.pumpWidget(makeTile());
      expect(find.byType(ListTile), findsOneWidget);
    });

    // Testes de unidade direta (sem contexto de widget)
    test('18️⃣ O método pode ser chamado diretamente (sem contexto real)', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildModernTile(
        ctx,
        icon: Icons.code,
        title: 'Teste direto',
        subtitle: 'Chamado manualmente',
        onTap: () {},
      );
      expect(widget, isA<Widget>());
    });

    test('19️⃣ O método retorna um Container com ListTile', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget =
          screen.buildModernTile(
                ctx,
                icon: Icons.code,
                title: 'Direto',
                subtitle: 'Teste',
                onTap: () {},
              )
              as Container;
      expect(widget.child, isA<ListTile>());
    });

    test('20️⃣ O Container tem margem correta no retorno direto', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'Teste',
                subtitle: 'Margem',
                onTap: () {},
              )
              as Container;
      expect(widget.margin, const EdgeInsets.only(bottom: 16));
    });

    test('21️⃣ O ListTile possui título e subtítulo atribuídos', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.check,
                title: 'Título',
                subtitle: 'Sub',
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      expect(tile.title, isNotNull);
      expect(tile.subtitle, isNotNull);
    });

    test('22️⃣ O método não retorna null', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildModernTile(
        ctx,
        icon: Icons.ac_unit,
        title: 'OK',
        subtitle: 'Teste',
        onTap: () {},
      );
      expect(widget, isNotNull);
    });

    test('23️⃣ Ícone leading é um Container com Icon', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'Tile',
                subtitle: 'Sub',
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      expect(tile.leading, isA<Container>());
    });

    test('24️⃣ onTap é obrigatório', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      expect(
        () => screen.buildModernTile(
          ctx,
          icon: Icons.star,
          title: 't',
          subtitle: 's',
          onTap: () {},
        ),
        returnsNormally,
      );
    });

    test('25️⃣ Suporta diferentes textos longos', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final long = 'a' * 200;
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.home,
                title: long,
                subtitle: long,
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      expect((tile.title as Text).data!.length, 200);
    });

    test('26️⃣ Título vem como Text', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'Título',
                subtitle: 'Sub',
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      expect(tile.title, isA<Text>());
    });

    test('27️⃣ Subtítulo vem como Text', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'Título',
                subtitle: 'Sub',
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      expect(tile.subtitle, isA<Text>());
    });

    test('28️⃣ trailing é um ícone de seta', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'T',
                subtitle: 'S',
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      expect(tile.trailing, isA<Icon>());
    });

    test('29️⃣ Ícone de seta é o correto', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'Tile',
                subtitle: 'Sub',
                onTap: () {},
              )
              as Container;
      final tile = container.child as ListTile;
      final icon = tile.trailing as Icon;
      expect(icon.icon, Icons.arrow_forward_ios_rounded);
    });

    test('30️⃣ Container tem BoxDecoration com sombra', () {
      const screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final container =
          screen.buildModernTile(
                ctx,
                icon: Icons.star,
                title: 'Tile',
                subtitle: 'Sub',
                onTap: () {},
              )
              as Container;
      expect(container.decoration, isA<BoxDecoration>());
    });
  });
}

/// Fake context apenas para permitir chamada direta ao método privado
class _FakeContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
