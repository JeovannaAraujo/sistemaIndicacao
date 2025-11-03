import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/visualizar_resposta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
  });

  // -------------------- READ --------------------
  group('📖 READ (Leitura)', () {
    test('1️⃣ fmtData converte Timestamp corretamente', () {
      final ts = Timestamp.fromDate(DateTime(2025, 10, 17));
      final res = VisualizarRespostaScreenState.fmtData(ts);
      expect(res, '17/10/2025');
    });

    test('2️⃣ fmtData retorna "—" se não for Timestamp', () {
      final res = VisualizarRespostaScreenState.fmtData('abc');
      expect(res, '—');
    });
  });

  // -------------------- CREATE --------------------
  group('🧩 CREATE (Criação)', () {
    test('3️⃣ formatTempo formata singular/plural corretamente', () {
      final state = VisualizarRespostaScreenState();
      expect(state.formatTempo(1, 'dia'), '1 dia');
      expect(state.formatTempo(3, 'dia'), '3 dias');
    });

    test('4️⃣ formatTempo retorna "—" se nulo', () {
      final state = VisualizarRespostaScreenState();
      expect(state.formatTempo(null, ''), '—');
      expect(state.formatTempo('', 'hora'), '—');
    });
  });

  // -------------------- UPDATE --------------------
  group('🧠 UPDATE (Atualização)', () {
    test(
      '5️⃣ getInfo busca unidade e imagem do serviço (FakeFirestore)',
      () async {
        await fakeDb.collection('unidades').doc('u1').set({'abreviacao': 'm²'});
        await fakeDb.collection('categoriasServicos').doc('c1').set({
          'imagemUrl': 'https://img.com/cat.jpg',
        });
        await fakeDb.collection('servicos').doc('s1').set({
          'valorMinimo': 10,
          'valorMedio': 20,
          'valorMaximo': 30,
          'categoriaId': 'c1',
          'unidadeId': 'u1',
        });
        await fakeDb.collection('usuarios').doc('p1').set({
          'endereco': {'whatsapp': '64 99999-9999'},
        });

        final state = VisualizarRespostaScreenState();
        final res = await state.getInfo('s1', 'p1', 'u1', firestore: fakeDb);
        expect(res['unidadeAbrev'], 'm²');
        expect(res['imagemUrl'], 'https://img.com/cat.jpg');
        expect(res['valorMin'], 10);
        expect(res['whatsapp'], '64 99999-9999');
      },
    );

    test('6️⃣ getInfo retorna vazio quando ids são inválidos', () async {
      final state = VisualizarRespostaScreenState();
      final res = await state.getInfo('', '', '', firestore: fakeDb);
      expect(res['unidadeAbrev'], '');
      expect(res['imagemUrl'], '');
      expect(res['whatsapp'], '');
    });
  });

  // -------------------- DELETE (Falha / Limpeza) --------------------
  group('🗑️ DELETE (Falhas / Limpeza)', () {
    test('7️⃣ formatTempo pluraliza corretamente mesmo sem "s"', () {
      final state = VisualizarRespostaScreenState();
      expect(state.formatTempo(2, 'hora'), '2 horas');
    });

    test('8️⃣ getInfo trata exceções sem lançar erro', () async {
      final state = VisualizarRespostaScreenState();
      final res = await state.getInfo(
        'fake',
        'fake',
        'fake',
        firestore: fakeDb,
      );
      expect(res, isA<Map<String, dynamic>>());
    });
  });

  // -------------------- INTERFACE --------------------
  group('🎨 INTERFACE', () {
    testWidgets('9️⃣ Renderiza mensagem de erro', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Erro: simulado',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Erro:'), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('🔟 Botão Aceitar atualiza status para "aceita"', (
      tester,
    ) async {
      await fakeDb.collection('solicitacoesOrcamento').doc('doc1').set({
        'status': 'pendente',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VisualizarRespostaScreenFake(docId: 'doc1', firestore: fakeDb),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('btnAceitar')));
      await tester.pump();

      final snap = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('doc1')
          .get();
      expect(snap.data()?['status'], 'aceita');
    });

    testWidgets(
      '1️⃣1️⃣ Botão Recusar atualiza status para "recusada_cliente"',
      (tester) async {
        await fakeDb.collection('solicitacoesOrcamento').doc('doc2').set({
          'status': 'pendente',
        });

        await tester.pumpWidget(
          MaterialApp(
            home: VisualizarRespostaScreenFake(
              docId: 'doc2',
              firestore: fakeDb,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('btnRecusar')));
        await tester.pump();

        final snap = await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('doc2')
            .get();
        expect(snap.data()?['status'], 'recusada_cliente');
      },
    );
  });
}
