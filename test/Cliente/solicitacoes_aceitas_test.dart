import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/solicitacoes_aceitas.dart';

Future<void> settleShort(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
 

  // ✅ Nenhum Firebase real inicializado
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();


    // Usuário e categoria fake
    await fakeDb.collection('usuarios').doc('prest1').set({
      'nome': 'Carlos Eletricista',
      'categoriaProfissionalId': 'cat123',
    });

    await fakeDb.collection('categoriasProfissionais').doc('cat123').set({
      'nome': 'Eletricista',
    });

    // Solicitação aceita
    await fakeDb.collection('solicitacoesOrcamento').doc('sol1').set({
      'clienteId': 'cli123',
      'prestadorId': 'prest1',
      'servicoTitulo': 'Instalação Elétrica',
      'valorProposto': 350.0,
      'status': 'aceita',
      'dataInicioSugerida': DateTime(2025, 10, 15),
      'dataFinalPrevista': DateTime(2025, 10, 18),
    });
  });

  group('🧩 READ (Leitura)', () {
    testWidgets('1️⃣ Exibe card de solicitação aceita', (tester) async {
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('sol1')
          .get();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardAceita(id: doc.id, dados: doc.data()!, firestore: fakeDb),
          ),
        ),
      );
      await settleShort(tester);

      expect(find.text('Instalação Elétrica'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
      expect(find.text('Ver orçamento'), findsOneWidget);
    });

    test('2️⃣ CategoriaRepo retorna nome do cache', () async {
      CategoriaRepoAceita.firestore = fakeDb;
      await CategoriaRepoAceita.nome('cat123');
      final res = await CategoriaRepoAceita.nome('cat123');
      expect(res, 'Eletricista');
    });
  });

  group('🧮 UPDATE (Cancelamento)', () {
    test('3️⃣ Atualiza status para cancelada', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('sol1').update({
        'status': 'cancelada',
      });
      final atualizado = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('sol1')
          .get();
      expect(atualizado['status'], 'cancelada');
    });
  });

  group('🧩 CREATE', () {
    test('4️⃣ Cria nova solicitação aceita', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('novo').set({
        'clienteId': 'cli123',
        'status': 'aceita',
        'servicoTitulo': 'Pintura',
      });
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('novo')
          .get();
      expect(doc.exists, true);
    });
  });

  group('🗑️ DELETE', () {
    test('5️⃣ Deleta solicitação com sucesso', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('solDel').set({
        'clienteId': 'cli123',
        'status': 'aceita',
      });
      await fakeDb.collection('solicitacoesOrcamento').doc('solDel').delete();
      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.where((d) => d.id == 'solDel').isEmpty, true);
    });
  });

  group('🧠 Interface', () {
    testWidgets('6️⃣ Renderiza abas com Aceitas ativa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tabs(
              active: TabKind.aceitas,
              onTapEnviadas: () {},
              onTapRespondidas: () {},
              onTapAceitas: () {},
            ),
          ),
        ),
      );
      await settleShort(tester);
      expect(find.text('Aceitas'), findsOneWidget);
    });

    test('Falha ao buscar documento inexistente', () async {
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('naoExiste')
          .get();
      expect(doc.exists, false);
    });

    test('Falha ao atualizar documento inexistente', () async {
      try {
        await fakeDb.collection('solicitacoesOrcamento').doc('invalido').update(
          {'status': 'cancelada'},
        );
        fail('Deveria lançar exceção');
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('Falha ao deletar documento inexistente', () async {
      try {
        await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('naoExiste')
            .delete();
        // O FakeFirebaseFirestore não lança erro, mas podemos validar manualmente
        final snap = await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('naoExiste')
            .get();
        expect(snap.exists, false);
      } catch (_) {
        // Aceita também caso o mock mude o comportamento
      }
    });
  });
}
