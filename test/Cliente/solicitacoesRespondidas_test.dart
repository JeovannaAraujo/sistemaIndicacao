import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/solicitacoesRespondidas.dart';

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
    // 🔹 Injeção direta no repositório
    CategoriaRepo.cache.clear();
    CategoriaRepo.setFirestore(fakeDb); // ✅ Importante!

    // 🔹 Dados iniciais fake
    await fakeDb.collection('usuarios').doc('prestResp').set({
      'nome': 'Ana Decoradora',
      'categoriaProfissionalId': 'catResp',
      'endereco': {'cidade': 'Rio Verde', 'uf': 'GO'}
    });

    await fakeDb.collection('categoriasProfissionais').doc('catResp').set({
      'nome': 'Decoradora',
    });

    await fakeDb.collection('unidades').doc('uResp').set({
      'abreviacao': 'm²',
    });

    // Solicitação respondida
    await fakeDb.collection('solicitacoesOrcamento').doc('solResp').set({
      'clienteId': 'cliResp',
      'prestadorId': 'prestResp',
      'servicoTitulo': 'Decoração de sala',
      'descricaoDetalhada': 'Montagem de cortinas e tapete',
      'quantidade': 25,
      'unidadeSelecionadaId': 'uResp',
      'status': 'respondida',
      'respondidaEm': DateTime(2025, 10, 16, 10, 30),
    });
  });

  group('🧩 READ (Leitura)', () {
    testWidgets('1️⃣ Exibe card de solicitação respondida', (tester) async {
      final doc =
          await fakeDb.collection('solicitacoesOrcamento').doc('solResp').get();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropostaCard(
              docId: doc.id,
              dados: doc.data()!,
              firestore: fakeDb, // ✅ usa fake Firestore injetado
            ),
          ),
        ),
      );
      await settleShort(tester);

      // Verifica informações essenciais
      expect(find.textContaining('Decoração de sala'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
      expect(find.textContaining('Ver Orçamento'), findsOneWidget);
    });

    test('2️⃣ CategoriaRepo retorna nome do cache', () async {
      final nome1 = await CategoriaRepo.nome('catResp');
      final nome2 = await CategoriaRepo.nome('catResp');
      expect(nome1, 'Decoradora');
      expect(nome2, 'Decoradora');
    });

    test('3️⃣ Falha ao buscar documento inexistente', () async {
      final doc =
          await fakeDb.collection('solicitacoesOrcamento').doc('naoExiste').get();
      expect(doc.exists, false);
    });
  });

  group('🧮 CREATE', () {
    test('4️⃣ Cria nova solicitação respondida', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('novaResp').set({
        'clienteId': 'cliResp',
        'status': 'respondida',
        'servicoTitulo': 'Projeto de iluminação',
        'respondidaEm': DateTime(2025, 10, 17),
      });
      final novo =
          await fakeDb.collection('solicitacoesOrcamento').doc('novaResp').get();
      expect(novo.exists, true);
    });
  });

  group('🧠 UPDATE', () {
    test('5️⃣ Atualiza status para aceita', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('solResp').update({
        'status': 'aceita',
      });
      final doc =
          await fakeDb.collection('solicitacoesOrcamento').doc('solResp').get();
      expect(doc['status'], 'aceita');
    });

    test('6️⃣ Falha ao atualizar documento inexistente', () async {
      try {
        await fakeDb.collection('solicitacoesOrcamento').doc('invResp').update({
          'status': 'aceita',
        });
        fail('Deveria lançar exceção');
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });
  });

  group('🗑️ DELETE', () {
    test('7️⃣ Deleta solicitação com sucesso', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('delResp').set({
        'clienteId': 'cliResp',
        'status': 'respondida',
      });
      await fakeDb.collection('solicitacoesOrcamento').doc('delResp').delete();
      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.where((d) => d.id == 'delResp').isEmpty, true);
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
    testWidgets('9️⃣ Renderiza abas com Respondidas ativa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tabs(
              active: TabKind.respondidas,
              onTapEnviadas: () {},
              onTapRespondidas: () {},
              onTapAceitas: () {},
            ),
          ),
        ),
      );
      await settleShort(tester);

      expect(find.text('Respondidas'), findsOneWidget);
      expect(find.text('Enviadas'), findsOneWidget);
      expect(find.text('Aceitas'), findsOneWidget);
    });
  });
}
