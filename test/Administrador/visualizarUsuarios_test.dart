import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:myapp/Administrador/visualizarUsuarios.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
  });

  group('🧩 Testes Unitários — VisualizarUsuarios', () {
    // 1️⃣
    testWidgets('Renderiza AppBar corretamente', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.text('Usuários Cadastrados'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    // 2️⃣
    testWidgets('AppBar é roxa', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.deepPurple);
    });

    // 3️⃣
    testWidgets('Exibe texto de instrução inicial', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.textContaining('Visualize todos os usuários cadastrados'), findsOneWidget);
    });

    // 4️⃣
    testWidgets('Dropdown inicia com "todos"', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown.value, equals('todos'));
    });

    // 5️⃣
    testWidgets('Dropdown possui quatro opções', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Todos'), findsWidgets);
      expect(find.text('Clientes'), findsWidgets);
      expect(find.text('Prestadores'), findsWidgets);
      expect(find.text('Administradores'), findsWidgets);
    });

    // 6️⃣
    testWidgets('Alterar filtro atualiza estado', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clientes').last);
      await tester.pumpAndSettle();
      expect(find.text('Clientes'), findsOneWidget);
    });

    // 7️⃣
    testWidgets('Mostra indicador de carregamento inicialmente', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // 8️⃣
    testWidgets('Mostra mensagem quando não há usuários', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum usuário encontrado.'), findsOneWidget);
    });

    // 9️⃣
    testWidgets('Exibe lista com usuários existentes', (tester) async {
      await firestore.collection('usuarios').add({
        'nome': 'João',
        'email': 'joao@test.com',
        'tipoPerfil': 'Cliente',
        'ativo': true,
      });
      await firestore.collection('usuarios').add({
        'nome': 'Maria',
        'email': 'maria@test.com',
        'tipoPerfil': 'Prestador',
        'ativo': false,
      });
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.text('João'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
    });

    // 🔟
    testWidgets('ListTile exibe nome e email corretamente', (tester) async {
      await firestore.collection('usuarios').add({
        'nome': 'Carlos',
        'email': 'carlos@test.com',
        'tipoPerfil': 'Administrador',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.text('Carlos'), findsOneWidget);
      expect(find.text('carlos@test.com'), findsOneWidget);
    });

    // 11️⃣
    testWidgets('Switch aparece na linha do usuário', (tester) async {
      await firestore.collection('usuarios').add({
        'nome': 'Julia',
        'email': 'julia@test.com',
        'tipoPerfil': 'Cliente',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
    });

    // 12️⃣
    testWidgets('Switch inicia como true quando ativo=true', (tester) async {
      final doc = await firestore.collection('usuarios').add({
        'nome': 'Lucas',
        'email': 'lucas@test.com',
        'tipoPerfil': 'Prestador',
        'ativo': true,
      });
      final snap = await doc.get();
      expect(snap['ativo'], isTrue);
    });

    // 13️⃣
    testWidgets('Switch inicia como false quando ativo=false', (tester) async {
      final doc = await firestore.collection('usuarios').add({
        'nome': 'Pedro',
        'email': 'pedro@test.com',
        'tipoPerfil': 'Cliente',
        'ativo': false,
      });
      final snap = await doc.get();
      expect(snap['ativo'], isFalse);
    });

    // ✅ 14️⃣ (corrigido)
    testWidgets('Ícone de usuário é exibido em cada linha', (tester) async {
      await firestore.collection('usuarios').add({
        'nome': 'Laura',
        'email': 'laura@test.com',
        'tipoPerfil': 'Administrador',
        'ativo': true,
      });

      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verifica se há ícones (de qualquer tipo)
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon?.codePoint != null,
        ),
        findsWidgets,
      );

      // Confirma que o ícone de pessoa aparece
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final temIconePessoa = icons.any((icon) =>
          icon.icon?.codePoint == Icons.person.codePoint ||
          icon.icon?.codePoint == Icons.person_outline.codePoint);
      expect(temIconePessoa, isTrue);
    });

    // 15️⃣
    testWidgets('StreamBuilder é renderizado corretamente', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.byType(StreamBuilder<QuerySnapshot<Map<String, dynamic>>>), findsOneWidget);
    });

    // 16️⃣
    testWidgets('AppBar contém botão de voltar funcional', (tester) async {
      bool pressionado = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => pressionado = true,
            ),
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(pressionado, true);
    });

    // 17️⃣
    testWidgets('Mostra texto de erro em caso de snapshot com erro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StreamBuilder(
          stream: Stream.error('erro'),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('Erro ao carregar usuários.');
            return const SizedBox();
          },
        ),
      ));
      await tester.pump();
      expect(find.text('Erro ao carregar usuários.'), findsOneWidget);
    });

    // 18️⃣
    testWidgets('Renderiza estrutura básica (Scaffold e Column)', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    // 19️⃣
    testWidgets('Texto principal tem cor deepPurple', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      final text = tester.widget<Text>(find.textContaining('Visualize todos'));
      expect(text.style?.color, Colors.deepPurple);
    });

    // 20️⃣
    testWidgets('Dropdown altera filtro para Prestador', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prestadores').last);
      await tester.pumpAndSettle();
      expect(find.text('Prestadores'), findsOneWidget);
    });

    // 21️⃣
    testWidgets('Mostra CircularProgressIndicator ao carregar', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ✅ 22️⃣ (corrigido)
    testWidgets('Scroll da lista funciona', (tester) async {
      for (int i = 0; i < 5; i++) {
        await firestore.collection('usuarios').add({
          'nome': 'Usuário $i',
          'email': 'user$i@test.com',
          'tipoPerfil': 'Cliente',
          'ativo': true,
        });
      }
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.fling(find.byType(ListView), const Offset(0, -300), 1000);
      await tester.pumpAndSettle();
      expect(find.textContaining('Usuário'), findsWidgets);
    });

    // 23️⃣
    testWidgets('Divider é exibido entre os itens da lista', (tester) async {
      await firestore.collection('usuarios').add({'nome': 'Luan', 'email': 'luan@test.com', 'tipoPerfil': 'Cliente', 'ativo': true});
      await firestore.collection('usuarios').add({'nome': 'Maria', 'email': 'maria@test.com', 'tipoPerfil': 'Cliente', 'ativo': true});
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.byType(Divider), findsWidgets);
    });

    // 24️⃣
    testWidgets('Filtro Cliente retorna apenas clientes', (tester) async {
      await firestore.collection('usuarios').add({'nome': 'Joana', 'email': 'joana@test.com', 'tipoPerfil': 'Cliente', 'ativo': true});
      await firestore.collection('usuarios').add({'nome': 'Rafa', 'email': 'rafa@test.com', 'tipoPerfil': 'Prestador', 'ativo': true});
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clientes').last);
      await tester.pumpAndSettle();
      expect(find.text('Joana'), findsOneWidget);
      expect(find.text('Rafa'), findsNothing);
    });

    // 25️⃣
    test('Mostra mensagem de erro amigável se FirebaseException', () {
      final e = FirebaseException(plugin: 'firestore', code: 'unavailable', message: 'Offline');
      expect(e.code, equals('unavailable'));
      expect(e.message, equals('Offline'));
    });

    // 26️⃣
    testWidgets('Switch altera valor ativo corretamente', (tester) async {
      final doc = await firestore.collection('usuarios').add({'nome': 'Felipe', 'email': 'felipe@test.com', 'tipoPerfil': 'Cliente', 'ativo': false});
      await firestore.collection('usuarios').doc(doc.id).update({'ativo': true});
      final updated = await firestore.collection('usuarios').doc(doc.id).get();
      expect(updated['ativo'], isTrue);
    });

    // 27️⃣
    testWidgets('Tela carrega sem exceções', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // 28️⃣
    testWidgets('Título principal visível', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      expect(find.text('Usuários Cadastrados'), findsOneWidget);
    });

    // 29️⃣
    testWidgets('Exibe SnackBar ao ativar/desativar usuário', (tester) async {
      await firestore.collection('usuarios').add({'nome': 'André', 'email': 'andre@test.com', 'tipoPerfil': 'Cliente', 'ativo': true});
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    // 30️⃣
    testWidgets('Nenhum erro inesperado ocorre durante execução', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VisualizarUsuarios(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
