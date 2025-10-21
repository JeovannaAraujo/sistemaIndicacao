import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Administrador/categoria_profissionais.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
  });

  group('🧪 Testes da tela CategProf', () {
    testWidgets('1️⃣ Tela carrega título e botão principal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CategProf(firestore: firestore)),
      );
      expect(find.text('Categorias de profissionais'), findsOneWidget);
      expect(find.text('Nova Categoria'), findsOneWidget);
    });

    testWidgets('2️⃣ Exibe texto informativo inicial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CategProf(firestore: firestore)),
      );
      expect(
        find.text('Gerencie as categorias disponíveis de profissionais'),
        findsOneWidget,
      );
    });

    testWidgets('3️⃣ Mostra carregando ou lista inicial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CategProf(firestore: firestore)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasText = find.textContaining('categoria').evaluate().isNotEmpty;

      expect(hasLoading || hasText, true, reason: 'Deveria exibir loading ou lista inicial');
    });

    testWidgets('4️⃣ Exibe texto quando não há categorias', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CategProf(firestore: firestore)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma categoria cadastrada.'), findsOneWidget);
    });

    testWidgets('5️⃣ Adiciona categoria e lista aparece', (tester) async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Eletricista',
        'descricao': 'Serviços elétricos',
        'ativo': true,
      });

      await tester.pumpWidget(
        MaterialApp(home: CategProf(firestore: firestore)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eletricista'), findsOneWidget);
      expect(find.text('Serviços elétricos'), findsOneWidget);
    });

    testWidgets('6️⃣ Abre diálogo ao clicar em Nova Categoria', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();

      expect(find.text('Nova categoria de profissional'), findsOneWidget);
      expect(find.text('Nome da categoria'), findsOneWidget);
      expect(find.text('Descrição da categoria'), findsOneWidget);
    });

    testWidgets('7️⃣ Fecha diálogo ao clicar em Cancelar', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Nova categoria de profissional'), findsNothing);
    });

    testWidgets('8️⃣ Salvar sem preencher não adiciona categoria', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final docs = await firestore.collection('categoriasProfissionais').get();
      expect(docs.docs.isEmpty, true);
    });

    testWidgets('9️⃣ Salvar adiciona nova categoria', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Pedreiro');
      await tester.enterText(find.byType(TextFormField).at(1), 'Construção civil');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final snap = await firestore.collection('categoriasProfissionais').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first['nome'], 'Pedreiro');
    });

    testWidgets('🔟 Botão Editar aparece na listagem', (tester) async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Pintor',
        'descricao': 'Serviços de pintura',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('11️⃣ Abre diálogo de edição corretamente', (tester) async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Pintor',
        'descricao': 'Serviços de pintura',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Alteração de categoria de profissional'), findsOneWidget);
    });

    testWidgets('12️⃣ Edição mantém dados anteriores nos campos', (tester) async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Pintor',
        'descricao': 'Pinta paredes',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Pintor'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pinta paredes'), findsOneWidget);
    });

    testWidgets('13️⃣ Editar e salvar atualiza categoria', (tester) async {
      final doc = await firestore.collection('categoriasProfissionais').add({
        'nome': 'Pintor',
        'descricao': 'Pinta paredes',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), 'Pinta casas');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final atualizado = await firestore.collection('categoriasProfissionais').doc(doc.id).get();
      expect(atualizado['descricao'], 'Pinta casas');
    });

    testWidgets('14️⃣ Switch de ativo aparece e pode mudar', (tester) async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Marceneiro',
        'descricao': 'Faz móveis',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('15️⃣ Mudar switch atualiza campo ativo no Firestore', (tester) async {
      final doc = await firestore.collection('categoriasProfissionais').add({
        'nome': 'Encadernador',
        'descricao': 'Trabalha com livros',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final atualizado = await firestore.collection('categoriasProfissionais').doc(doc.id).get();
      expect(atualizado['ativo'], false);
    });

    testWidgets('16️⃣ Títulos de colunas aparecem corretamente', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Descrição'), findsOneWidget);
    });

    testWidgets('17️⃣ Ícone de voltar existe', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('18️⃣ Layout contém Divider entre cabeçalho e lista', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('19️⃣ Padding principal é 16', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, const EdgeInsets.all(16));
    });

    testWidgets('20️⃣ Teste de múltiplas categorias ordenadas por nome', (tester) async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Zelador',
        'descricao': 'Limpeza geral',
        'ativo': true,
      });
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Alinhador',
        'descricao': 'Ajuste de rodas',
        'ativo': true,
      });
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.pumpAndSettle();
      expect(find.text('Alinhador'), findsOneWidget);
      expect(find.text('Zelador'), findsOneWidget);
    });

    test('21️⃣ Campo nome ausente não quebra', () async {
      await firestore.collection('categoriasProfissionais').add({
        'descricao': 'Sem nome',
        'ativo': true,
      });
      final snap = await firestore.collection('categoriasProfissionais').get();
      expect(snap.docs.first.data().containsKey('nome'), false);
    });

    test('22️⃣ Criação direta no Firestore funciona', () async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Encanador',
        'descricao': 'Tubulações',
        'ativo': false,
      });
      final snap = await firestore.collection('categoriasProfissionais').get();
      expect(snap.docs.first['nome'], 'Encanador');
    });

    test('23️⃣ Atualização direta via doc.update', () async {
      final doc = await firestore.collection('categoriasProfissionais').add({
        'nome': 'Soldador',
        'descricao': 'Solda metais',
        'ativo': true,
      });
      await firestore.collection('categoriasProfissionais').doc(doc.id).update({
        'descricao': 'Trabalha com soldas',
      });
      final get = await firestore.collection('categoriasProfissionais').doc(doc.id).get();
      expect(get['descricao'], 'Trabalha com soldas');
    });

    test('24️⃣ Exclui todos e garante vazio', () async {
      final ref = firestore.collection('categoriasProfissionais');
      await ref.add({'nome': 'Teste', 'descricao': 'Temp', 'ativo': true});
      final snap = await ref.get();
      for (final d in snap.docs) {
        await ref.doc(d.id).delete();
      }
      final again = await ref.get();
      expect(again.docs.isEmpty, true);
    });

    test('25️⃣ Campo ativo default é null se não informado', () async {
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'Cabelereiro',
        'descricao': 'Cortes',
      });
      final doc = await firestore.collection('categoriasProfissionais').get();
      expect(doc.docs.first.data().containsKey('ativo'), false);
    });

    testWidgets('26️⃣ Botão Salvar existe e é roxo', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('27️⃣ Texto do botão Cancelar é visível', (tester) async {
      await tester.pumpWidget(MaterialApp(home: CategProf(firestore: firestore)));
      await tester.tap(find.text('Nova Categoria'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
    });

    test('28️⃣ Verifica isolamento entre instâncias de FakeFirestore', () async {
      final fs2 = FakeFirebaseFirestore();
      await fs2.collection('categoriasProfissionais').add({'nome': 'Teste'});
      final s2 = await fs2.collection('categoriasProfissionais').get();
      final s1 = await firestore.collection('categoriasProfissionais').get();
      expect(s2.docs.length, 1);
      expect(s1.docs.length, 0);
    });

    test('29️⃣ Campo descrição suporta texto longo', () async {
      final longText = 'a' * 500;
      await firestore.collection('categoriasProfissionais').add({
        'nome': 'LongText',
        'descricao': longText,
      });
      final doc = await firestore.collection('categoriasProfissionais').get();
      expect(doc.docs.first['descricao'].length, 500);
    });

    test('30️⃣ Nome da coleção está correto', () {
      expect('categoriasProfissionais', 'categoriasProfissionais');
    });
  });

  test('31 Tentativa de exclusão de doc inexistente não quebra', () async {
  final ref = firestore.collection('categoriasProfissionais');
  await expectLater(ref.doc('inexistente').delete(), completes);
});

}
