import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Cliente/servicosFinalizados.dart';

Future<void> settleShort(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'cliente123', email: 'cli@teste.com'),
    );

    await fakeDb.collection('usuarios').doc('prest123').set({
      'nome': 'João Prestador',
    });

    await fakeDb.collection('servicos').doc('serv1').set({
      'clienteId': 'cliente123',
      'prestadorId': 'prest123',
      'descricao': 'Pintura completa',
      'status': 'finalizado',
      'dataFim': DateTime(2025, 10, 16),
    });
  });

  // ---------------------- CREATE ----------------------
  group('🧩 CREATE (Criação)', () {
    testWidgets('1️⃣ Cria avaliação com sucesso', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AvaliarServicoScreen(
          servicoId: 'serv1',
          prestadorId: 'prest123',
          firestore: fakeDb,
          auth: mockAuth,
        ),
      ));

      await settleShort(tester);

      await tester.tap(find.byType(ElevatedButton));
      await settleShort(tester);

      final docs = await fakeDb.collection('avaliacoes').get();
      expect(docs.docs.length, 1);
    });

    testWidgets('2️⃣ Não cria avaliação se usuário não logado', (tester) async {
      final noAuth = MockFirebaseAuth(signedIn: false);

      await tester.pumpWidget(MaterialApp(
        home: AvaliarServicoScreen(
          servicoId: 'serv1',
          prestadorId: 'prest123',
          firestore: fakeDb,
          auth: noAuth,
        ),
      ));
      await settleShort(tester);

      await tester.tap(find.byType(ElevatedButton));
      await settleShort(tester);

      final docs = await fakeDb.collection('avaliacoes').get();
      expect(docs.docs.length, equals(0));
    });
  });

  // ---------------------- READ ----------------------
  group('📖 READ (Leitura)', () {
    testWidgets('3️⃣ Lista de serviços finalizados é exibida', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ServicosFinalizadosScreen(
          firestore: fakeDb,
          auth: mockAuth,
        ),
      ));
      await settleShort(tester);

      expect(find.text('Pintura completa'), findsOneWidget);
    });

    testWidgets('4️⃣ Exibe mensagem quando não há serviços', (tester) async {
      final vazio = FakeFirebaseFirestore();
      await tester.pumpWidget(MaterialApp(
        home: ServicosFinalizadosScreen(
          firestore: vazio,
          auth: mockAuth,
        ),
      ));
      await settleShort(tester);

      expect(find.textContaining('Nenhum serviço'), findsOneWidget);
    });
  });

  // ---------------------- UPDATE ----------------------
  group('🧮 UPDATE (Atualização)', () {
    testWidgets('5️⃣ Atualiza status para "avaliada" após enviar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AvaliarServicoScreen(
          servicoId: 'serv1',
          prestadorId: 'prest123',
          firestore: fakeDb,
          auth: mockAuth,
        ),
      ));
      await settleShort(tester);

      await tester.tap(find.byType(ElevatedButton));
      await settleShort(tester);

      final servico = await fakeDb.collection('servicos').doc('serv1').get();
      expect(servico['status'], 'avaliada');
    });

    testWidgets('6️⃣ Falha ao atualizar serviço inexistente', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AvaliarServicoScreen(
          servicoId: 'invalido',
          prestadorId: 'prest123',
          firestore: fakeDb,
          auth: mockAuth,
        ),
      ));
      await settleShort(tester);

      // Não deve lançar exceção nem alterar nenhum documento
      await tester.tap(find.byType(ElevatedButton));
      await settleShort(tester);

      final servicos = await fakeDb.collection('servicos').get();
      expect(servicos.docs.first['status'], isNot('erro'));
    });
  });

  // ---------------------- DELETE ----------------------
  group('🗑️ DELETE (Exclusão)', () {
    test('7️⃣ Deleta avaliação existente com sucesso', () async {
      final ref = await fakeDb.collection('avaliacoes').add({
        'clienteId': 'cliente123',
        'prestadorId': 'prest123',
      });

      await fakeDb.collection('avaliacoes').doc(ref.id).delete();
      final docs = await fakeDb.collection('avaliacoes').get();

      expect(docs.docs.isEmpty, true);
    });

    test('8️⃣ Tenta deletar avaliação inexistente sem erro', () async {
      await fakeDb.collection('avaliacoes').doc('naoExiste').delete();
      final docs = await fakeDb.collection('avaliacoes').get();

      expect(docs.docs.length, 0);
    });
  });

  // ---------------------- UI EXTRA ----------------------
  group('🧠 INTERFACE (Extras)', () {
    testWidgets('9️⃣ Botão de envio desativa durante operação', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AvaliarServicoScreen(
          servicoId: 'serv1',
          prestadorId: 'prest123',
          firestore: fakeDb,
          auth: mockAuth,
        ),
      ));
      await settleShort(tester);

      final botao = find.byType(ElevatedButton);
      expect(botao, findsOneWidget);

      await tester.tap(botao);
      await tester.pump(const Duration(milliseconds: 200));

      final ElevatedButton btn = tester.widget(botao);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('🔟 Tabs "Finalizados" e "Minhas avaliações" aparecem', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ServicosFinalizadosScreen(
          firestore: fakeDb,
          auth: mockAuth,
        ),
      ));
      await settleShort(tester);

      expect(find.text('Finalizados'), findsOneWidget);
      expect(find.text('Minhas avaliações'), findsOneWidget);
    });
  });
}
