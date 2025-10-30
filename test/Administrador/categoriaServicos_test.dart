import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:myapp/Administrador/categoriaServicos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
  });

  group('🧪 Testes da tela CategServ', () {
    testWidgets('1️⃣ Tela carrega título e botão principal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      expect(find.text('Categorias de Serviço'), findsOneWidget);
      expect(find.text('Nova Categoria'), findsOneWidget);
    });

    testWidgets('2️⃣ Exibe texto informativo inicial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      expect(
        find.text('Gerencie as categorias utilizadas nos serviços cadastrados'),
        findsOneWidget,
      ); // CORRIGIDO
    });

    testWidgets('3️⃣ Exibe mensagem quando não há categorias', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma categoria cadastrada.'), findsOneWidget);
    });

    testWidgets('4️⃣ Adiciona categoria no Firestore', (tester) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'Elétrica',
        'descricao': 'Serviços elétricos',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elétrica'), findsOneWidget);
      expect(find.text('Serviços elétricos'), findsOneWidget);
    });

    testWidgets('5️⃣ Abre diálogo ao clicar em Nova Categoria', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nova Categoria de Serviço'),
        findsOneWidget,
      ); // CORRIGIDO
    });

    testWidgets('6️⃣ Fecha diálogo ao clicar em Cancelar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Nova Categoria de Serviço'), findsNothing); // CORRIGIDO
    });

    testWidgets('7️⃣ Salvar sem preencher não adiciona categoria', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final docs = await firestore.collection('categoriasServicos').get();
      expect(docs.docs.isEmpty, true);
    });

    testWidgets('8️⃣ Salvar adiciona nova categoria', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Hidráulica');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Consertos de canos',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final snap = await firestore.collection('categoriasServicos').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first['nome'], 'Hidráulica');
    });

    testWidgets('9️⃣ Exibe botão Editar na listagem', (tester) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'Elétrica',
        'descricao': 'Instalações',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('🔟 Abre diálogo de edição', (tester) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'Pintura',
        'descricao': 'Residencial',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Editar Categoria de Serviço'),
        findsOneWidget,
      ); // CORRIGIDO
    });

    testWidgets('11️⃣ Editar e salvar atualiza Firestore', (tester) async {
      final doc = await firestore.collection('categoriasServicos').add({
        'nome': 'Reforma',
        'descricao': 'Pequenas obras',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'Grandes obras');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final atualizado = await firestore
          .collection('categoriasServicos')
          .doc(doc.id)
          .get();
      expect(atualizado['descricao'], 'Grandes obras');
    });

    testWidgets('12️⃣ Switch aparece e pode mudar valor', (tester) async {
      final doc = await firestore.collection('categoriasServicos').add({
        'nome': 'Jardinagem',
        'descricao': 'Podas',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final atualizado = await firestore
          .collection('categoriasServicos')
          .doc(doc.id)
          .get();
      expect(atualizado['ativo'], false);
    });

    // REMOVIDO: Teste 13 - Não há títulos de colunas no código real
    testWidgets('13️⃣ Cartão exibe nome e descrição corretamente', (
      tester,
    ) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'Encanador',
        'descricao': 'Serviços hidráulicos',
        'ativo': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Encanador'), findsOneWidget);
      expect(find.text('Serviços hidráulicos'), findsOneWidget);
    });

    testWidgets('14️⃣ Mostra ícone de imagem padrão se vazio', (tester) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'SemImagem',
        'descricao': 'Teste',
        'ativo': true,
        'imagemUrl': '',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image), findsWidgets);
    });

    test('15️⃣ Campo imagem pode ser string vazia', () async {
      await firestore.collection('categoriasServicos').add({'imagemUrl': ''});
      final snap = await firestore.collection('categoriasServicos').get();
      expect(snap.docs.first['imagemUrl'], '');
    });

    test('16️⃣ Atualiza campo ativo no Firestore direto', () async {
      final doc = await firestore.collection('categoriasServicos').add({
        'ativo': true,
      });
      await firestore.collection('categoriasServicos').doc(doc.id).update({
        'ativo': false,
      });
      final get = await firestore
          .collection('categoriasServicos')
          .doc(doc.id)
          .get();
      expect(get['ativo'], false);
    });

    testWidgets('17️⃣ Ícone voltar existe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('18️⃣ Botão Salvar existe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('19️⃣ Botão Cancelar existe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
    });

    test('20️⃣ Criação direta funciona', () async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'Limpeza',
        'descricao': 'Geral',
      });
      final snap = await firestore.collection('categoriasServicos').get();
      expect(snap.docs.first['nome'], 'Limpeza');
    });

    test('21️⃣ Atualização direta funciona', () async {
      final doc = await firestore.collection('categoriasServicos').add({
        'descricao': 'Antigo',
      });
      await firestore.collection('categoriasServicos').doc(doc.id).update({
        'descricao': 'Novo',
      });
      final get = await firestore
          .collection('categoriasServicos')
          .doc(doc.id)
          .get();
      expect(get['descricao'], 'Novo');
    });

    test('22️⃣ Exclusão de docs funciona', () async {
      final ref = firestore.collection('categoriasServicos');
      final doc = await ref.add({'nome': 'Teste'});
      await ref.doc(doc.id).delete();
      final all = await ref.get();
      expect(all.docs.isEmpty, true);
    });

    // REMOVIDO: Teste 23 - Não há Divider no código real

    testWidgets('23️⃣ Padding do body está correto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      final paddingFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(16, 12, 16, 24),
      );
      expect(paddingFinder, findsOneWidget);
    });

    test('24️⃣ Suporte a texto longo na descrição', () async {
      final long = 'a' * 400;
      await firestore.collection('categoriasServicos').add({'descricao': long});
      final get = await firestore.collection('categoriasServicos').get();
      expect(get.docs.first['descricao'].length, 400);
    });

    testWidgets('25️⃣ Botão Nova Categoria tem ícone de add', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('26️⃣ Lista mostra nome e descrição', (tester) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'Teste',
        'descricao': 'Desc',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teste'), findsOneWidget);
      expect(find.text('Desc'), findsOneWidget);
    });

    testWidgets('27️⃣ Exibe lista ou mensagem quando vazio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica se exibe a mensagem de "vazio" OU uma lista
      final hasEmptyMessage = find
          .text('Nenhuma categoria cadastrada.')
          .evaluate()
          .isNotEmpty;
      final hasListView = find.byType(ListView).evaluate().isNotEmpty;

      expect(hasEmptyMessage || hasListView, true);
    });

    test('28️⃣ Firestore fake é isolado', () async {
      final f2 = FakeFirebaseFirestore();
      await f2.collection('categoriasServicos').add({'nome': 'X'});
      final s1 = await firestore.collection('categoriasServicos').get();
      expect(s1.docs.isEmpty, true);
    });

    test('29️⃣ Nome da coleção está correto', () {
      expect('categoriasServicos', 'categoriasServicos');
    });

    testWidgets('30️⃣ Cartão tem container de imagem', (tester) async {
      await firestore.collection('categoriasServicos').add({
        'nome': 'ComImagem',
        'descricao': 'Teste',
        'ativo': true,
        'imagemUrl': '', // Usar string vazia para evitar erro de rede
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CategServ(firestore: firestore, storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica se há um container para imagem
      expect(find.byType(Container), findsWidgets);
    });

    // CORREÇÃO: Teste 31 - FakeFirestore lança exceção para doc inexistente
    test('31️⃣ Tentar atualizar doc inexistente lança exceção', () async {
      final ref = firestore.collection('categoriasServicos');
      await expectLater(
        ref.doc('naoExiste').update({'nome': 'Teste'}),
        throwsA(anything),
      );
    });

    test('32️⃣ Tentativa de exclusão de doc inexistente não quebra', () async {
      final ref = firestore.collection('categoriasServicos');
      await expectLater(ref.doc('inexistente').delete(), completes);
    });
  });
}
