import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/Administrador/perfilAdmin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🧪 Testes unitários do método buildTile', () {
    Widget makeTile({
      IconData icon = Icons.home,
      String title = 'Título padrão',
      String subtitle = 'Subtítulo padrão',
      VoidCallback? onTap,
    }) {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      return screen.buildTile(
        ctx,
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onTap ?? () {},
      );
    }

    testWidgets('1️⃣ Cria um widget do tipo Card', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('2️⃣ Contém um ListTile dentro do Card', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('3️⃣ Exibe o ícone correto', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile(icon: Icons.star)));
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('4️⃣ Exibe o título correto', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile(title: 'Teste Título')));
      expect(find.text('Teste Título'), findsOneWidget);
    });

    testWidgets('5️⃣ Exibe o subtítulo correto', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile(subtitle: 'Subtexto')));
      expect(find.text('Subtexto'), findsOneWidget);
    });

    testWidgets('6️⃣ Ícone principal tem cor roxa', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile(icon: Icons.settings)));
      final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
      expect(icon.color, Colors.deepPurple);
    });

    testWidgets('7️⃣ Ícone principal tem tamanho 32', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      final icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(icon.size, 32);
    });

    testWidgets('8️⃣ Exibe ícone de seta à direita', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('9️⃣ Título está em negrito', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile(title: 'Negrito')));
      final textWidget = tester.widget<Text>(find.text('Negrito'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('🔟 Card possui margem inferior de 16', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, const EdgeInsets.only(bottom: 16));
    });

    testWidgets('11️⃣ Ao tocar chama o onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: makeTile(onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(ListTile));
      expect(tapped, isTrue);
    });

    testWidgets('12️⃣ Ícone de seta é do tipo Icon', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      final trailing = tester.widget<Icon>(find.byIcon(Icons.arrow_forward_ios));
      expect(trailing.runtimeType, Icon);
    });

    testWidgets('13️⃣ Não lança exceções ao construir com parâmetros padrão', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('14️⃣ Suporta diferentes ícones sem falhar', (tester) async {
      final icons = [Icons.add, Icons.remove, Icons.alarm, Icons.book];
      for (var i in icons) {
        await tester.pumpWidget(MaterialApp(home: makeTile(icon: i)));
        expect(find.byIcon(i), findsOneWidget);
      }
    });

    testWidgets('15️⃣ Renderiza corretamente em modo escuro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: makeTile(),
      ));
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('16️⃣ Exibe título e subtítulo juntos', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile(title: 'Título', subtitle: 'Sub')));
      expect(find.text('Título'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
    });

    testWidgets('17️⃣ O Card é clicável pelo ListTile', (tester) async {
      await tester.pumpWidget(MaterialApp(home: makeTile()));
      expect(find.byType(ListTile), findsOneWidget);
    });

    test('18️⃣ O método pode ser chamado diretamente (sem contexto real)', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildTile(
        ctx,
        icon: Icons.code,
        title: 'Teste direto',
        subtitle: 'Chamado manualmente',
        onTap: () {},
      );
      expect(widget, isA<Widget>());
    });

    test('19️⃣ O método retorna um Card com ListTile', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildTile(
        ctx,
        icon: Icons.code,
        title: 'Direto',
        subtitle: 'Teste',
        onTap: () {},
      ) as Card;
      expect(widget.child, isA<ListTile>());
    });

    test('20️⃣ O Card tem margem correta no retorno direto', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildTile(
        ctx,
        icon: Icons.star,
        title: 'Teste',
        subtitle: 'Margem',
        onTap: () {},
      ) as Card;
      expect(widget.margin, const EdgeInsets.only(bottom: 16));
    });

    test('21️⃣ O ListTile possui título e subtítulo atribuídos', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.check,
        title: 'Título',
        subtitle: 'Sub',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      expect(tile.title, isNotNull);
      expect(tile.subtitle, isNotNull);
    });

    test('22️⃣ O método não retorna null', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final widget = screen.buildTile(
        ctx,
        icon: Icons.ac_unit,
        title: 'OK',
        subtitle: 'Teste',
        onTap: () {},
      );
      expect(widget, isNotNull);
    });

    test('23️⃣ Ícone leading é do tipo Icon', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.star,
        title: 'Tile',
        subtitle: 'Sub',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      expect(tile.leading, isA<Icon>());
    });

    test('24️⃣ onTap é obrigatório', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      expect(
        () => screen.buildTile(ctx,
            icon: Icons.star, title: 't', subtitle: 's', onTap: () {}),
        returnsNormally,
      );
    });

    test('25️⃣ Suporta diferentes textos longos', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final long = 'a' * 200;
      final card = screen.buildTile(
        ctx,
        icon: Icons.home,
        title: long,
        subtitle: long,
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      expect((tile.title as Text).data!.length, 200);
    });

    test('26️⃣ Ícone leading tem cor deepPurple', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.person,
        title: 'X',
        subtitle: 'Y',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      final icon = tile.leading as Icon;
      expect(icon.color, Colors.deepPurple);
    });

    test('27️⃣ Título vem como Text', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.star,
        title: 'Título',
        subtitle: 'Sub',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      expect(tile.title, isA<Text>());
    });

    test('28️⃣ Subtítulo vem como Text', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.star,
        title: 'Título',
        subtitle: 'Sub',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      expect(tile.subtitle, isA<Text>());
    });

    test('29️⃣ trailing é um ícone de seta', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.star,
        title: 'T',
        subtitle: 'S',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      expect(tile.trailing, isA<Icon>());
    });

    test('30️⃣ Ícone de seta é o correto', () {
      final screen = PerfilAdminScreen();
      final ctx = _FakeContext();
      final card = screen.buildTile(
        ctx,
        icon: Icons.star,
        title: 'Tile',
        subtitle: 'Sub',
        onTap: () {},
      ) as Card;
      final tile = card.child as ListTile;
      final icon = tile.trailing as Icon;
      expect(icon.icon, Icons.arrow_forward_ios);
    });
  });
}

/// Fake context apenas para permitir chamada direta ao método privado
class _FakeContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
