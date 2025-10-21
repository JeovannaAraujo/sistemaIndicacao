import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/Prestador/homePrestador.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late HomePrestadorScreenState state;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prest1', email: 'prest@teste.com'),
    );

    // Cria manualmente o estado e injeta dependências mockadas
    state = HomePrestadorScreenState();
    state.db = fakeDb;
    state.auth = mockAuth;

    // Dados simulados
    await fakeDb.collection('avaliacoes').add({
      'servicoId': 'serv1',
      'nota': 4,
    });
    await fakeDb.collection('avaliacoes').add({
      'servicoId': 'serv1',
      'nota': 2,
    });
  });

  test('🧮 extrairNotaGenerica retorna nota de campo direto', () {
    final nota = state.extrairNotaGenerica({'nota': 4});
    expect(nota, equals(4));
  });

  test('💬 extrairNotaGenerica aceita string e nested', () {
    final n1 = state.extrairNotaGenerica({'nota': '3.5'});
    final n2 = state.extrairNotaGenerica({
      'avaliacao': {'estrelas': '5'}
    });
    expect(n1, equals(3.5));
    expect(n2, equals(5));
  });

  test('📊 mediaQtdDoServicoPorAvaliacoes calcula média correta', () async {
    final result = await state.mediaQtdDoServicoPorAvaliacoes('serv1');
    expect(result['media'], closeTo(3.0, 0.01)); // (4 + 2) / 2
    expect(result['qtd'], equals(2));
  });

  test('📉 mediaQtdDoServicoPorAvaliacoes retorna 0 se não há avaliações', () async {
    final result = await state.mediaQtdDoServicoPorAvaliacoes('inexistente');
    expect(result['media'], equals(0));
    expect(result['qtd'], equals(0));
  });

  testWidgets('🟣 pendentesCountStream retorna quantidade correta', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest1',
      'status': 'pendente',
    });
    await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest1',
      'status': 'respondida',
    });

    final stream = state.pendentesCountStream('prest1');
    final count = await stream.first;
    expect(count, equals(1));
  });

  testWidgets('📘 getNomeCategoriaServById retorna nome', (tester) async {
    await fakeDb.collection('categoriasServicos').doc('cat1').set({'nome': 'Elétrica'});
    final nome = await state.getNomeCategoriaServById('cat1');
    expect(nome, equals('Elétrica'));
  });

  testWidgets('📏 getNomeUnidadeById retorna abreviação', (tester) async {
    await fakeDb.collection('unidades').doc('m2').set({'abreviacao': 'm²'});
    final abrev = await state.getNomeUnidadeById('m2');
    expect(abrev, equals('m²'));
  });

    test('🔁 mediaQtdDoServicoPorAvaliacoes fallback por prestadorId + servicoTitulo', () async {
    // Cenário: Nenhuma avaliação por servicoId, mas existem por prestadorId + servicoTitulo
    await fakeDb.collection('avaliacoes').add({
      'prestadorId': 'prest1',
      'servicoTitulo': 'Pintura',
      'nota': 5,
    });
    await fakeDb.collection('avaliacoes').add({
      'prestadorId': 'prest1',
      'servicoTitulo': 'Pintura',
      'nota': 3,
    });

    final state = HomePrestadorScreenState();
    state.db = fakeDb;

    final result = await state.mediaQtdDoServicoPorAvaliacoes(
      'inexistente',
      prestadorId: 'prest1',
      servicoTitulo: 'Pintura',
    );

    expect(result['media'], closeTo(4.0, 0.01)); // (5 + 3) / 2
    expect(result['qtd'], equals(2));
  });

  test('⚠️ mediaQtdDoServicoPorAvaliacoes lida com erro (retorna 0)', () async {
    // Simula erro no Firestore usando uma instância inválida
    final state = HomePrestadorScreenState();
    state.db = FakeFirebaseFirestore(); // db vazio

    // Força erro de acesso usando um id inválido
    final result = await state.mediaQtdDoServicoPorAvaliacoes('');
    expect(result['media'], equals(0));
    expect(result['qtd'], equals(0));
  });

  testWidgets('📉 pendentesCountStream retorna 0 quando não há pendentes', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').add({
      'prestadorId': 'prest1',
      'status': 'respondida',
    });

    final state = HomePrestadorScreenState();
    state.db = fakeDb;

    final stream = state.pendentesCountStream('prest1');
    final count = await stream.first;
    expect(count, equals(0));
  });

}
