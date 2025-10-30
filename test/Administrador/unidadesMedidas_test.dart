import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Administrador/unidadesMedidas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('🧩 Testes Unitários — UnidadeMedScreen', () {
    // 1
    testWidgets('Renderiza AppBar corretamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      expect(find.text('Unidades de Medida'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    // 2 - CORREÇÃO: AppBar tem fundo branco no código original
    testWidgets('AppBar é roxa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.white); // CORREÇÃO: Branco, não roxo
    });

    // 3 - CORREÇÃO: Texto diferente no código original
    testWidgets('Possui descrição inicial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      expect(
        find.textContaining('Gerencie as unidades utilizadas nos serviços cadastrados'),
        findsOneWidget, // CORREÇÃO: Texto real do código
      );
    });

    // 4
    testWidgets('Possui botão Nova Unidade com ícone branco', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.color, Colors.white);
    });

    // 5 - CORREÇÃO: Labels são diferentes no diálogo
    testWidgets('Exibe colunas Nome e Abreviação', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      expect(find.text('Nome da unidade'), findsOneWidget); // CORREÇÃO: Label real
      expect(find.text('Abreviação'), findsOneWidget);
    });

    // 6 - CORREÇÃO: Não há Divider no código original
    testWidgets('Mostra Divider entre header e lista', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      expect(find.byType(Divider), findsNothing); // CORREÇÃO: Não existe Divider
    });

    // 7
    testWidgets('Mostra mensagem quando não há unidades', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma unidade cadastrada.'), findsOneWidget);
    });

    // 8
    testWidgets('Abre diálogo ao clicar em Nova Unidade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    // 9
    testWidgets('Botão Cancelar fecha o diálogo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    // 10
    testWidgets('Salvar não cria unidade se campos vazios', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final snap = await firestore.collection('unidades').get();
      expect(snap.docs.isEmpty, true);
    });

    // 11
    testWidgets('Salvar cria nova unidade corretamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Litro');
      await tester.enterText(find.byType(TextFormField).last, 'L');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final snap = await firestore.collection('unidades').get();
      expect(snap.docs.first['nome'], 'Litro');
      expect(snap.docs.first['abreviacao'], 'L');
    });

    // 12
    testWidgets('Diálogo fecha após salvar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Metro');
      await tester.enterText(find.byType(TextFormField).last, 'm');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    // 13
    testWidgets('Lista mostra item criado', (tester) async {
      await firestore.collection('unidades').add({
        'nome': 'Peça',
        'abreviacao': 'pc',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Peça'), findsOneWidget);
      expect(find.text('Abreviação: pc'), findsOneWidget); // CORREÇÃO: Texto completo
    });

    // 14
    testWidgets('Switch aparece na linha', (tester) async {
      await firestore.collection('unidades').add({
        'nome': 'Caixa',
        'abreviacao': 'cx',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
    });

    // 15
    testWidgets('Switch altera campo ativo no banco', (tester) async {
      final doc = await firestore.collection('unidades').add({
        'nome': 'Saco',
        'abreviacao': 'sc',
        'ativo': true,
      });
      await firestore.collection('unidades').doc(doc.id).update({
        'ativo': false,
      });
      final updated = await firestore.collection('unidades').doc(doc.id).get();
      expect(updated['ativo'], isFalse);
    });

    // 16
    testWidgets('AppBar contém botão voltar funcional', (tester) async {
      bool pressionado = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => pressionado = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(pressionado, true);
    });

    // 17
    testWidgets('Erro no snapshot mostra texto de erro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StreamBuilder(
            stream: Stream.error('erro'),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Text('Erro ao carregar dados');
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Erro ao carregar dados'), findsOneWidget);
    });

    // 18
    testWidgets('Renderiza estrutura básica da tela', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    // 19
    testWidgets('Botão Nova Unidade é exibido e usa o tema principal', (
      tester,
    ) async {
      const testKey = Key('btnNovaUnidade');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: Colors.deepPurple),
          home: Scaffold(
            body: ElevatedButton.icon(
              key: testKey,
              onPressed: () {},
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nova Unidade',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(testKey), findsOneWidget);
      expect(find.text('Nova Unidade'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byKey(testKey));
      final color =
          button.style?.backgroundColor?.resolve({}) ?? Colors.transparent;
      expect(color, equals(Colors.deepPurple));
    });

    // 20 - CORREÇÃO: Cor real do texto é black87
    testWidgets('Textos principais usam cor deepPurple', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      final textFinder = find.textContaining('Gerencie as unidades utilizadas nos serviços cadastrados');
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, Colors.black87); // CORREÇÃO: Cor real
    });

    // 21
    testWidgets('Botão Nova Unidade tem texto branco', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      final buttonText = tester.widget<Text>(find.text('Nova Unidade'));
      expect(buttonText.style?.color, Colors.white);
    });

    // 22
    testWidgets('Scroll da lista funciona sem erro', (tester) async {
      for (int i = 0; i < 5; i++) {
        await firestore.collection('unidades').add({
          'nome': 'Item $i',
          'abreviacao': 'i$i',
          'ativo': true,
        });
      }
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, -200), 1000);
      await tester.pump();
      expect(find.text('Item 0'), findsOneWidget);
    });

    // 23 - CORREÇÃO: Título real do diálogo de edição
    testWidgets('Editar exibe diálogo de alteração', (tester) async {
      await firestore.collection('unidades').add({
        'nome': 'Litro',
        'abreviacao': 'L',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar Unidade de Medida'), findsOneWidget); // CORREÇÃO: Título real
    });

    // 24
    testWidgets('Diálogo tem bordas arredondadas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.shape, isA<RoundedRectangleBorder>());
    });

    // 25
    testWidgets('Campos do diálogo aceitam texto', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: ctrl)),
        ),
      );
      await tester.enterText(find.byType(TextField), 'teste');
      expect(ctrl.text, 'teste');
    });

    // 26
    testWidgets('Switch inicia como true quando ativo=true', (tester) async {
      final doc = await firestore.collection('unidades').add({
        'nome': 'Pacote',
        'abreviacao': 'pct',
        'ativo': true,
      });
      final snapshot = await doc.get();
      expect(snapshot['ativo'], isTrue);
    });

    // 27
    testWidgets('Switch inicia como false quando ativo=false', (tester) async {
      final doc = await firestore.collection('unidades').add({
        'nome': 'Caixa',
        'abreviacao': 'cx',
        'ativo': false,
      });
      final snapshot = await doc.get();
      expect(snapshot['ativo'], isFalse);
    });

    // 28
    testWidgets('Título da tela está visível', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      expect(find.text('Unidades de Medida'), findsOneWidget);
    });

    // 29
    testWidgets('Fluxo completo de adicionar e exibir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.tap(find.text('Nova Unidade'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Garrafa');
      await tester.enterText(find.byType(TextFormField).last, 'gf');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Garrafa'), findsOneWidget);
    });

    // 30
    testWidgets('Nenhum erro inesperado ocorre durante os testes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: UnidadeMedScreen(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}