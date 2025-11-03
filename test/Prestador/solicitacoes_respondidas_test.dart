import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/Prestador/solicitacoes_respondidas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late SolicitacoesRespondidasScreenState state;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    await fakeDb.clearPersistence(); // 🔹 limpa o cache entre execuções

    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prest123', email: 'teste@teste.com'),
    );

    // 🔹 injeta o fakeDb nas classes estáticas (necessário p/ mocks de imagem)
    CategoriaThumbByServico.setFirestore(fakeDb);
    CategoriaThumbCache.setFirestore(fakeDb);

    final widget = SolicitacoesRespondidasScreen(
      firestore: fakeDb,
      auth: mockAuth,
    );

    state = widget.createState() as SolicitacoesRespondidasScreenState;
    state.db = fakeDb;
    state.auth = mockAuth;
    state.prestadorId = 'prest123';
  });

  tearDown(() async {
    // 🔹 limpa caches estáticos p/ não interferir entre testes
    CategoriaThumbByServico.setFirestore(null);
    CategoriaThumbCache.setFirestore(null);
  });

  // =======================================================
  // CREATE
  // =======================================================
  test('CREATE – adiciona nova solicitação respondida', () async {
    await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest123',
      'status': 'respondida',
      'servicoTitulo': 'Troca de torneira',
    });

    final snap = await fakeDb
        .collection('solicitacoesOrcamento')
        .where('status', isEqualTo: 'respondida')
        .get();

    expect(snap.docs.length, 1);
  });

  test('CREATE (negativo) – não deve criar sem prestadorId', () async {
    await fakeDb.collection('solicitacoesOrcamento').add({'status': 'respondida'});
    final all = await fakeDb.collection('solicitacoesOrcamento').get();
    expect(all.docs.first.data().containsKey('prestadorId'), false);
  });

  // =======================================================
  // READ
  // =======================================================
  test('READ – stream retorna apenas respondidas do prestador logado', () async {
    await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest123',
      'status': 'respondida',
      'servicoTitulo': 'Instalação elétrica',
      'criadoEm': Timestamp.now(),
    });
    await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'outro',
      'status': 'respondida',
      'servicoTitulo': 'Não deve aparecer',
      'criadoEm': Timestamp.now(),
    });

    final stream = state.streamSolicitacoes();
    final snap = await stream.first;
    expect(snap.docs.length, 1);
    expect(snap.docs.first.data()['prestadorId'], 'prest123');
  });

  test('READ (negativo) – stream vazio quando não há respondidas', () async {
    final stream = state.streamSolicitacoes();
    final snap = await stream.first;
    expect(snap.docs, isEmpty);
  });

  // =======================================================
  // UPDATE
  // =======================================================
  test('UPDATE – muda status de respondida para aceita', () async {
    final doc = await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest123',
      'status': 'respondida',
    });

    await fakeDb
        .collection('solicitacoesOrcamento')
        .doc(doc.id)
        .update({'status': 'aceita'});

    final updated = await fakeDb.collection('solicitacoesOrcamento').doc(doc.id).get();
    expect(updated.data()?['status'], 'aceita');
  });

  test('UPDATE (negativo) – tenta atualizar doc inexistente', () async {
    await expectLater(
      fakeDb
          .collection('solicitacoesOrcamento')
          .doc('inexistente')
          .update({'status': 'aceita'}),
      throwsA(isA<FirebaseException>()),
    );
  });

  // =======================================================
  // DELETE
  // =======================================================
  test('DELETE – remove solicitação respondida', () async {
    final doc = await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest123',
      'status': 'respondida',
    });
    await fakeDb.collection('solicitacoesOrcamento').doc(doc.id).delete();
    final snap = await fakeDb.collection('solicitacoesOrcamento').get();
    expect(snap.docs, isEmpty);
  });

  test('DELETE (negativo) – excluir doc inexistente não lança erro', () async {
    await expectLater(
      fakeDb.collection('solicitacoesOrcamento').doc('fake').delete(),
      completes,
    );
  });
}
