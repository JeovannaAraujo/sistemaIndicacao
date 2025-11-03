import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/Prestador/servicos_finalizados.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late ServicosFinalizadosPrestadorScreenState state;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prestador123', email: 'prestador@teste.com'),
    );

    final widget = ServicosFinalizadosPrestadorScreen(
      firestore: fakeDb,
      auth: mockAuth,
    );
    state = widget.createState() as ServicosFinalizadosPrestadorScreenState;
    state.db = fakeDb;
    state.auth = mockAuth;
  });

  group('🧩 ServicosFinalizadosPrestadorScreen - Testes Unitários CRUD', () {
    // =======================================================
    // CREATE
    // =======================================================
    test('CREATE (positivo) - adiciona documento com sucesso', () async {
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'clienteNome': 'João',
        'servicoTitulo': 'Pintura residencial',
        'status': 'finalizada',
      });

      final docs =
          await fakeDb.collection('solicitacoesOrcamento').get();
      expect(docs.docs.length, 1);
      expect(docs.docs.first.data()['clienteNome'], 'João');
    });

    test('CREATE (negativo) - permite criação com campos nulos (fake não valida)', () async {
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': null,
        'status': 'finalizada',
      });

      final docs = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(docs.docs.length, 1);
      expect(docs.docs.first.data()['prestadorId'], isNull);
    });

    // =======================================================
    // READ
    // =======================================================
    test('READ (positivo) - fmtData converte Timestamp em data formatada', () {
      final ts = Timestamp.fromDate(DateTime(2025, 10, 20));
      final r = state.fmtData(ts);
      expect(r, '20/10/2025');
    });

    test('READ (negativo) - fmtData retorna "—" para valor inválido', () {
      final r = state.fmtData(null);
      expect(r, '—');
    });

    // =======================================================
    // UPDATE
    // =======================================================
    test('UPDATE (positivo) - calcDuracaoComJornada respeita dias de jornada', () async {
      await fakeDb.collection('usuarios').doc('prestador123').set({
        'jornada': ['Segunda-feira', 'Terça-feira', 'Quarta-feira'],
      });

      final inicio = Timestamp.fromDate(DateTime(2025, 10, 6)); // Segunda
      final fim = Timestamp.fromDate(DateTime(2025, 10, 8)); // Quarta

      final r = await state.calcDuracaoComJornada('prestador123', inicio, fim);
      expect(r, contains('3 dia'));
    });

    test('UPDATE (negativo) - calcDuracaoComJornada assume seg-sex quando jornada vazia', () async {
      await fakeDb.collection('usuarios').doc('prestador123').set({});

      final inicio = Timestamp.fromDate(DateTime(2025, 10, 5)); // Domingo
      final fim = Timestamp.fromDate(DateTime(2025, 10, 10)); // Sexta

      final r = await state.calcDuracaoComJornada('prestador123', inicio, fim);
      expect(r, contains('5 dia'));
    });

    // =======================================================
    // DELETE
    // =======================================================
    test('DELETE (positivo) - remove documento existente sem erro', () async {
      final ref = await fakeDb.collection('solicitacoesOrcamento').add({
        'status': 'finalizada',
      });

      await fakeDb.collection('solicitacoesOrcamento').doc(ref.id).delete();

      final docs =
          await fakeDb.collection('solicitacoesOrcamento').get();
      expect(docs.docs.length, 0);
    });

    test('DELETE (negativo) - deleta documento inexistente sem lançar exceção', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('inexistente').delete();
      final docs = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(docs.docs.isEmpty, true);
    });

    // =======================================================
    // EXTRA
    // =======================================================
    test('EXTRA - calcDuracaoComJornada usa data real de fim se existir', () async {
      await fakeDb.collection('usuarios').doc('prestador123').set({
        'jornada': ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira']
      });

      final inicio = Timestamp.fromDate(DateTime(2025, 10, 6)); // Segunda
      final fimPrevisto = Timestamp.fromDate(DateTime(2025, 10, 10)); // Sexta
      final fimReal = Timestamp.fromDate(DateTime(2025, 10, 8)); // Quarta

      final r = await state.calcDuracaoComJornada(
        'prestador123',
        inicio,
        fimPrevisto,
        realFim: fimReal,
      );

      expect(r, '3 dias');
    });
  });
}
