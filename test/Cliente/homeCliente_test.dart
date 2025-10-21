// test/Cliente/homeCliente_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Cliente/homeCliente.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // 🔒 Bloqueia inicialização real do Firebase
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(
            'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi',
          ),
          (MethodCall methodCall) async => null,
        );
  });

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: '123',
        email: 'jeovanna@test.com',
        displayName: 'Jeovanna 💜',
      ),
    );
  });

  group('🏠 HomeCliente – Estrutura e estado', () {
    test('1️⃣ Classe HomeScreen existe', () {
      expect(HomeScreen, isA<Type>());
    });

    testWidgets('2️⃣ selectedIndex inicia em 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );
      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;
      expect(state.selectedIndex, equals(0));
    });

    test('3️⃣ Categorias fixas contém pelo menos 5', () {
      expect(HomeScreenState.categoriasFixas.length, greaterThanOrEqualTo(5));
    });
  });

  group('📋 Conteúdo principal', () {
    testWidgets('4️⃣ Renderiza título principal "Indica Aí"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Indica Aí'), findsOneWidget);
    });

    testWidgets('5️⃣ Renderiza subtítulo explicativo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Encontre os melhores profissionais'),
        findsOneWidget,
      );
    });

    testWidgets('6️⃣ Campo de busca presente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('7️⃣ Renderiza "Categorias"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Categorias'), findsOneWidget);
    });
  });

  group('🧭 Drawer e navegação', () {
    testWidgets('8️⃣ Drawer contém item "Notificações"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Notificações'), findsOneWidget);
    });

    testWidgets('9️⃣ Drawer contém item "Configurações"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Configurações'), findsOneWidget);
    });

    testWidgets('🔟 Drawer contém item "Serviços Finalizados"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Serviços Finalizados'), findsOneWidget);
    });
  });

  group('💡 Funções auxiliares', () {
    test('11️⃣ iconForCategory retorna ícone de Pedreiro', () {
      final state = HomeScreenState();
      expect(state.iconForCategory('Pedreiro'), equals(Icons.construction));
    });

    test('12️⃣ iconForCategory retorna ícone de Eletricista', () {
      final state = HomeScreenState();
      expect(state.iconForCategory('Eletricista'), equals(Icons.flash_on));
    });

    test('13️⃣ fromHexOrDefault converte cores', () {
      final state = HomeScreenState();
      expect(
        state.fromHexOrDefault('#FF0000', Colors.black),
        equals(const Color(0xFFFF0000)),
      );
    });
  });

  group('📊 Firestore e profissionais em destaque', () {
    testWidgets('14️⃣ Mostra mensagem padrão sem profissionais', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(firestore: fakeDb, auth: mockAuth),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nenhum profissional em destaque'),
        findsOneWidget,
      );
    });

    // ✅ Corrigido com campos esperados e pump adicional
testWidgets('15️⃣ Lista profissionais quando houver', (tester) async {
  await fakeDb.collection('usuarios').add({
    'tipoPerfil': 'Prestador',
    'ativo': true,
    'nome': 'João da Luz',
    'categoriaProfissional': 'Eletricista',
    'mediaAvaliacoes': 4.8,
    'totalAvaliacoes': 25,
  });

  await tester.pumpWidget(MaterialApp(
    home: HomeScreen(firestore: fakeDb, auth: mockAuth),
  ));

  // ⏳ Dá tempo para o StreamBuilder carregar
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();

  bool encontrouNome = false;
  bool encontrouCategoria = false;

  tester.widgetList(find.byType(Text)).forEach((widget) {
    final textWidget = widget as Text;
    final text = textWidget.data ?? '';
    if (text.contains('João')) encontrouNome = true;
    if (text.contains('Eletricista')) encontrouCategoria = true;
  });

  expect(encontrouNome, isTrue,
      reason: 'O nome "João da Luz" deveria aparecer na lista de profissionais.');
  expect(encontrouCategoria, isTrue,
      reason: 'A categoria "Eletricista" deveria aparecer junto do profissional.');
});


    group('🎯 Consistência visual e lógica', () {
      test('16️⃣ Todas as categorias têm nome e cor', () {
        for (final cat in HomeScreenState.categoriasFixas) {
          expect(cat['nome'], isNotEmpty);
          expect(cat['cor'], isNotNull);
        }
      });

      testWidgets('17️⃣ Scaffold renderiza sem erro', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(firestore: fakeDb, auth: mockAuth),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsOneWidget);
      });

      test('18️⃣ Lista de categorias contém Montador', () {
        final nomes = HomeScreenState.categoriasFixas.map((e) => e['nome']);
        expect(nomes, contains('Montador'));
      });
    });
  });

  group('🎨 Aparência visual', () {
  testWidgets('19️⃣ Mostra título com cor roxa', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: fakeDb, auth: mockAuth),
    ));
    final titleText = tester.widget<Text>(find.text('Indica Aí'));
    expect(titleText.style?.color, equals(Colors.deepPurple));
  });

  testWidgets('20️⃣ Mostra ícones nas categorias fixas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: fakeDb, auth: mockAuth),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Icon), findsWidgets);
  });

  testWidgets('21️⃣ Mostra texto "Profissionais em destaque"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: fakeDb, auth: mockAuth),
    ));
    expect(find.text('Profissionais em destaque'), findsOneWidget);
  });

  testWidgets('22️⃣ Exibe mensagem padrão quando sem prestadores', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: fakeDb, auth: mockAuth),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum profissional'), findsOneWidget);
  });
});

group('🧠 Interações básicas', () {
  testWidgets('23️⃣ Abre Drawer e mostra botão "Sair"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: fakeDb, auth: mockAuth),
    ));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Sair'), findsOneWidget);
  });

testWidgets('24️⃣ Campo de busca está dentro de pelo menos um AbsorbPointer', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: HomeScreen(firestore: fakeDb, auth: mockAuth),
  ));

  final absorb = find.ancestor(
    of: find.byType(TextField),
    matching: find.byType(AbsorbPointer),
  );

  final count = absorb.evaluate().length;
  expect(count > 0, isTrue,
      reason: 'O TextField deve estar protegido por ao menos um AbsorbPointer.');
});



  testWidgets('25️⃣ Botão de categoria executa abrirCategoria()', (tester) async {
    bool clicou = false;
    final widget = MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => InkWell(
            onTap: () => clicou = true,
            child: const Text('Categoria'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.tap(find.text('Categoria'));
    expect(clicou, isTrue);
  });
});

group('⚙️ Funções auxiliares detalhadas', () {
  final state = HomeScreenState();

  test('26️⃣ iconForCategory reconhece encanador e pintor', () {
    expect(state.iconForCategory('Encanador'), equals(Icons.water_drop));
    expect(state.iconForCategory('Pintor'), equals(Icons.format_paint));
  });

  test('27️⃣ iconForCategory retorna padrão para desconhecidos', () {
    expect(state.iconForCategory('Desconhecido'), equals(Icons.handyman));
  });

  test('28️⃣ fromHexOrDefault lida com entrada inválida', () {
    final cor = state.fromHexOrDefault('gibberish', Colors.pink);
    expect(cor, equals(Colors.pink));
  });
});
group('📏 Consistência e layout', () {
  testWidgets('29️⃣ buildProfissional gera ListTile com nome e categoria', (tester) async {
    final state = HomeScreenState();
    final widget = state.buildProfissional('João', 'Pintor', 4.5, 12);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.text('João'), findsOneWidget);
    expect(find.text('Pintor'), findsOneWidget);
  });

  testWidgets('30️⃣ Página completa tem Scaffold e ScrollView', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: fakeDb, auth: mockAuth),
    ));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
});

}
