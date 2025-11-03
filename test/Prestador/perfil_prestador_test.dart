import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/Prestador/perfil_prestador.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late PerfilPrestadorState state;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prest1', email: 'prest@teste.com'),
    );

    state = PerfilPrestadorState()
      ..db = fakeDb
      ..auth = mockAuth
      ..user = mockAuth.currentUser;
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  // =======================================================
  // 🧠 TESTES DE EXTRAIR NOTA
  // =======================================================
  test('💬 extrairNotaGenerica lê nota direta', () {
    final nota = state.extrairNotaGenerica({'nota': 4});
    expect(nota, equals(4));
  });

  test('💬 extrairNotaGenerica lê nested em "avaliacao"', () {
    final nota = state.extrairNotaGenerica({
      'avaliacao': {'estrelas': '4.5'}
    });
    expect(nota, equals(4.5));
  });

  test('💡 extrairNotaGenerica ignora valores inválidos', () {
    final nota = state.extrairNotaGenerica({'nota': 'abc'});
    expect(nota, isNull);
  });

  test('🧠 extrairNotaGenerica lê campo alternativo notaGeral', () {
    final nota = state.extrairNotaGenerica({
      'avaliacao': {'notaGeral': 3.2}
    });
    expect(nota, equals(3.2));
  });

  test('🧩 extrairNotaGenerica retorna null quando não há dados válidos', () {
    final result = state.extrairNotaGenerica({'semNota': 123});
    expect(result, isNull);
  });

  // =======================================================
  // 🧾 TESTES DE CATEGORIA PROFISSIONAL
  // =======================================================
  testWidgets('📘 getNomeCategoriaProfById retorna nome e usa cache', (tester) async {
    await fakeDb.collection('categoriasProfissionais').doc('cat1').set({'nome': 'Eletricista'});
    final nome1 = await state.getNomeCategoriaProfById('cat1');
    expect(nome1, equals('Eletricista'));

    // Segunda vez vem do cache
    final nome2 = await state.getNomeCategoriaProfById('cat1');
    expect(nome2, equals('Eletricista'));
    expect(state.categoriaProfCache.containsKey('cat1'), isTrue);
  });

  test('🧩 getNomeCategoriaProfById adiciona várias categorias no cache', () async {
    await fakeDb.collection('categoriasProfissionais').doc('cat1').set({'nome': 'Pintor'});
    await fakeDb.collection('categoriasProfissionais').doc('cat2').set({'nome': 'Pedreiro'});

    final n1 = await state.getNomeCategoriaProfById('cat1');
    final n2 = await state.getNomeCategoriaProfById('cat2');

    expect(n1, equals('Pintor'));
    expect(n2, equals('Pedreiro'));
    expect(state.categoriaProfCache.length, equals(2));
  });

  test('📭 getNomeCategoriaProfById retorna null quando ID é vazio', () async {
    final nome = await state.getNomeCategoriaProfById('');
    expect(nome, isNull);
  });

  // =======================================================
  // 📊 TESTES DE STREAM DE AVALIAÇÕES
  // =======================================================
  test('📊 streamMediaETotalDoPrestador calcula média corretamente', () async {
    await fakeDb.collection('avaliacoes').add({'prestadorId': 'prest1', 'nota': 5});
    await fakeDb.collection('avaliacoes').add({'prestadorId': 'prest1', 'nota': 3});

    final stream = state.streamMediaETotalDoPrestador('prest1');
    final result = await stream.first;

    expect(result['media'], closeTo(4.0, 0.01));
    expect(result['qtd'], equals(2));
  });

  test('📉 streamMediaETotalDoPrestador retorna 0 quando não há avaliações', () async {
    final stream = state.streamMediaETotalDoPrestador('semNotas');
    final result = await stream.first;
    expect(result['media'], equals(0));
    expect(result['qtd'], equals(0));
  });

  test('🧪 streamMediaETotalDoPrestador aceita notas em string', () async {
    await fakeDb.collection('avaliacoes').add({'prestadorId': 'prest1', 'nota': '5'});
    await fakeDb.collection('avaliacoes').add({'prestadorId': 'prest1', 'nota': '4'});

    final result = await state.streamMediaETotalDoPrestador('prest1').first;
    expect(result['media'], closeTo(4.5, 0.01));
    expect(result['qtd'], equals(2));
  });
}
