import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/Prestador/solicitacoesRecebidas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late SolicitacoesRecebidasScreenState state;

setUp(() {
  fakeDb = FakeFirebaseFirestore();
  mockAuth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: 'prestador123', email: 'teste@teste.com'),
  );

  final widget = SolicitacoesRecebidasScreen(
    firestore: fakeDb,
    auth: mockAuth,
  );

  state = widget.createState() as SolicitacoesRecebidasScreenState;
  state.db = fakeDb;
  state.auth = mockAuth;
  state.prestadorId = 'prestador123'; // ✅ adicionado
});


  group('🧩 SolicitacoesRecebidasScreen – Testes Unitários CRUD', () {
    // =======================================================
    // CREATE
    // =======================================================
    test('CREATE – adiciona solicitação ao Firestore', () async {
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'status': 'pendente',
        'clienteNome': 'Maria',
        'servicoTitulo': 'Pintura de parede',
      });

      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first['clienteNome'], 'Maria');
    });

    test('CREATE (negativo) – aceita inserção com campos faltando', () async {
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'status': 'pendente',
      });

      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data().containsKey('clienteNome'), false);
    });

    // =======================================================
    // READ
    // =======================================================
    test('READ – stream retorna apenas pendentes do prestador logado', () async {
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'status': 'pendente',
        'clienteNome': 'Ana',
      });
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'outro',
        'status': 'pendente',
        'clienteNome': 'Outro',
      });

      final stream = state.streamSolicitacoes();
      final snap = await stream.first;

      expect(snap.docs.length, 1);
      expect(snap.docs.first['clienteNome'], 'Ana');
    });

    test('READ (negativo) – stream vazio quando não há pendentes', () async {
      final stream = state.streamSolicitacoes();
      final snap = await stream.first;
      expect(snap.docs.isEmpty, true);
    });

    // =======================================================
    // UPDATE (indireto)
    // =======================================================
    testWidgets('UPDATE – troca de aba aciona navegação', (tester) async {
      final screen = SolicitacoesRecebidasScreen(
        firestore: fakeDb,
        auth: mockAuth,
      );

      await tester.pumpWidget(MaterialApp(home: screen));
      final s = tester.state<SolicitacoesRecebidasScreenState>(
        find.byType(SolicitacoesRecebidasScreen),
      );

      expect(s.tabController.length, 2);
      s.tabController.index = 1;
      expect(s.tabController.index, 1);
    });

    // =======================================================
    // DELETE
    // =======================================================
    test('DELETE – remove documento existente', () async {
      final doc = await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'status': 'pendente',
      });

      await fakeDb.collection('solicitacoesOrcamento').doc(doc.id).delete();
      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.isEmpty, true);
    });

    test('DELETE (negativo) – remover inexistente não gera erro', () async {
      await expectLater(
        fakeDb.collection('solicitacoesOrcamento').doc('inexistente').delete(),
        completes,
      );
    });

    // =======================================================
    // EXTRA: helpers
    // =======================================================
    test('EXTRA – enderecoLinha formata corretamente', () {
      final lista = ListaSolicitacoes(
        stream: const Stream.empty(),
        moeda: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$'),
        recebidas: true,
      );

      final r = lista.enderecoLinha({
        'rua': 'Av. Goiás',
        'numero': '123',
        'bairro': 'Centro',
        'cidade': 'Rio Verde',
      });

      expect(r, contains('Av. Goiás'));
      expect(r, contains('Centro'));
      expect(r, contains('Rio Verde'));
    });
  });
}
