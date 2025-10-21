import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/solicitacoesEnviadas.dart';

Future<void> settleShort(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    // 🔹 Injeta o fake Firestore no repositório
    CategoriaRepo.firestore = fakeDb;
    CategoriaRepo.limparCache();

    // 🔹 Dados fake
    await fakeDb.collection('usuarios').doc('prest001').set({
      'nome': 'João Pintor',
      'categoriaProfissionalId': 'cat001',
      'endereco': {'cidade': 'Rio Verde', 'uf': 'GO'}
    });

    await fakeDb.collection('categoriasProfissionais').doc('cat001').set({
      'nome': 'Pintor',
    });

    await fakeDb.collection('unidades').doc('u001').set({
      'abreviacao': 'm²',
    });

    await fakeDb.collection('solicitacoesOrcamento').doc('sol001').set({
      'clienteId': 'cli001',
      'prestadorId': 'prest001',
      'servicoTitulo': 'Pintura de parede',
      'descricaoDetalhada': 'Pintar sala e cozinha',
      'quantidade': 30,
      'unidadeSelecionadaId': 'u001',
      'status': 'pendente',
      'criadoEm': DateTime(2025, 10, 15),
    });
  });

  group('🧩 READ (Leitura)', () {
    testWidgets('1️⃣ Exibe card de solicitação enviada', (tester) async {
      final doc =
          await fakeDb.collection('solicitacoesOrcamento').doc('sol001').get();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardEnviada(
              dados: doc.data()!,
              docId: doc.id,
              firestore: fakeDb, // 🔹 usa o fake Firestore
            ),
          ),
        ),
      );

      await settleShort(tester);

      // Verifica se os textos aparecem corretamente
      expect(find.textContaining('Pintura de parede'), findsOneWidget);

      // 🔹 Usa predicado RichText, mais seguro
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('Descrição'),
        ),
        findsOneWidget,
      );

      expect(find.text('Ver solicitação'), findsOneWidget);
    });

    test('2️⃣ CategoriaRepo retorna nome do cache', () async {
      final res1 = await CategoriaRepo.nome('cat001');
      final res2 = await CategoriaRepo.nome('cat001');
      expect(res1, 'Pintor');
      expect(res2, 'Pintor'); // 🔹 vem do cache
    });

    test('3️⃣ Falha ao buscar documento inexistente', () async {
      final doc =
          await fakeDb.collection('solicitacoesOrcamento').doc('naoExiste').get();
      expect(doc.exists, false);
    });
  });

  group('🧮 CREATE', () {
    test('4️⃣ Cria nova solicitação', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('nova').set({
        'clienteId': 'cli001',
        'servicoTitulo': 'Reparo hidráulico',
        'status': 'pendente',
        'criadoEm': DateTime(2025, 10, 16),
      });
      final novo =
          await fakeDb.collection('solicitacoesOrcamento').doc('nova').get();
      expect(novo.exists, true);
    });
  });

  group('🧠 UPDATE', () {
    test('5️⃣ Atualiza status para respondida', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('sol001').update({
        'status': 'respondida',
      });
      final doc =
          await fakeDb.collection('solicitacoesOrcamento').doc('sol001').get();
      expect(doc['status'], 'respondida');
    });

    test('6️⃣ Falha ao atualizar documento inexistente', () async {
      try {
        await fakeDb.collection('solicitacoesOrcamento').doc('inv').update({
          'status': 'respondida',
        });
        fail('Deveria lançar exceção');
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });
  });

  group('🗑️ DELETE', () {
    test('7️⃣ Deleta solicitação com sucesso', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('solDel').set({
        'clienteId': 'cli001',
        'status': 'pendente',
      });
      await fakeDb.collection('solicitacoesOrcamento').doc('solDel').delete();
      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.where((d) => d.id == 'solDel').isEmpty, true);
    });

    test('8️⃣ Falha ao deletar documento inexistente', () async {
      try {
        await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('naoExiste')
            .delete();
        final doc = await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('naoExiste')
            .get();
        expect(doc.exists, false);
      } catch (_) {}
    });
  });

  group('🎨 INTERFACE', () {
    testWidgets('9️⃣ Renderiza abas com Enviadas ativa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tabs(
              active: TabKind.enviadas,
              onTapEnviadas: () {},
              onTapRespondidas: () {},
              onTapAceitas: () {},
            ),
          ),
        ),
      );
      await settleShort(tester);
      expect(find.text('Enviadas'), findsOneWidget);
      expect(find.text('Respondidas'), findsOneWidget);
      expect(find.text('Aceitas'), findsOneWidget);
    });
  });
}
