import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/Prestador/servicos_finalizados.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late ServicosFinalizadosPrestadorScreenState screenState;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prestador123', email: 'prestador@teste.com'),
    );

    // Cria uma instância do state manualmente
    final widget = ServicosFinalizadosPrestadorScreen(
      firestore: fakeDb,
      auth: mockAuth,
    );
    screenState = ServicosFinalizadosPrestadorScreenState();
    screenState =
        widget.createState() as ServicosFinalizadosPrestadorScreenState;
    screenState.db = fakeDb;
    screenState.auth = mockAuth;
  });

  group('🧩 ServicosFinalizadosPrestadorScreen - Testes Unitários CRUD', () {
    // =======================================================
    // CREATE - Inserção de dados fake
    // =======================================================
    test('CREATE (positivo) - cria documento fake corretamente', () async {
      await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'clienteNome': 'João',
        'servicoTitulo': 'Instalação elétrica',
        'status': 'finalizada',
        'respondidaEm': Timestamp.now(),
      });

      final docs = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(docs.docs.length, 1);
      expect(docs.docs.first.data()['clienteNome'], 'João');
    });

    test(
      'CREATE (negativo) - cria com campo nulo mas não lança erro (esperado no fake)',
      () async {
        await fakeDb.collection('solicitacoesOrcamento').add({
          'prestadorId': null,
          'status': 'finalizada',
        });

        final docs = await fakeDb.collection('solicitacoesOrcamento').get();
        expect(docs.docs.length, 1);
        expect(docs.docs.first.data()['prestadorId'], isNull);
      },
    );

    // =======================================================
    // READ - Leitura dos dados
    // =======================================================
    test('READ (positivo) - fmtData converte Timestamp corretamente', () {
      final ts = Timestamp.fromDate(DateTime(2025, 1, 1));
      final r = screenState.fmtData(ts);
      expect(r, '01/01/2025');
    });

    test('READ (negativo) - fmtData retorna "—" para nulos', () {
      final r = screenState.fmtData(null);
      expect(r, '—');
    });

    // =======================================================
    // UPDATE - Cálculo de duração com jornada
    // =======================================================
    test(
      'UPDATE (positivo) - calcDuracaoComJornada considera jornada definida',
      () async {
        // Define jornada do prestador (Segunda a Sexta)
        await fakeDb.collection('usuarios').doc('prestador123').set({
          'jornada': ['Segunda-feira', 'Terça-feira', 'Quarta-feira'],
        });

        final inicio = Timestamp.fromDate(DateTime(2025, 10, 6)); // Segunda
        final fim = Timestamp.fromDate(DateTime(2025, 10, 10)); // Sexta

        final r = await screenState.calcDuracaoComJornada(
          'prestador123',
          inicio,
          fim,
        );

        expect(r, contains('3 dia'));
      },
    );

    test(
      'UPDATE (negativo) - calcDuracaoComJornada com jornada vazia assume seg-sex',
      () async {
        await fakeDb.collection('usuarios').doc('prestador123').set({});

        final inicio = Timestamp.fromDate(DateTime(2025, 10, 4)); // Sábado
        final fim = Timestamp.fromDate(DateTime(2025, 10, 10)); // Sexta

        final r = await screenState.calcDuracaoComJornada(
          'prestador123',
          inicio,
          fim,
        );

        expect(r, contains('5 dia'));
      },
    );

    // =======================================================
    // DELETE - Exclusão lógica simulada
    // =======================================================
    test('DELETE (positivo) - deleta documento existente', () async {
      final ref = await fakeDb.collection('solicitacoesOrcamento').add({
        'prestadorId': 'prestador123',
        'status': 'finalizada',
      });

      await fakeDb.collection('solicitacoesOrcamento').doc(ref.id).delete();

      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.length, 0);
    });

    test(
      'DELETE (negativo) - deleta documento inexistente sem lançar erro',
      () async {
        try {
          await fakeDb
              .collection('solicitacoesOrcamento')
              .doc('naoexiste')
              .delete();
        } catch (e) {
          fail('Não deve lançar erro ao deletar doc inexistente');
        }
      },
    );

    // =======================================================
    // EXTRA - Cenário completo
    // =======================================================
    test('EXTRA - calcDuracaoComJornada com realFim usa data real', () async {
      await fakeDb.collection('usuarios').doc('prestador123').set({
        'jornada': [
          'Segunda-feira',
          'Terça-feira',
          'Quarta-feira',
          'Quinta-feira',
        ],
      });

      final inicio = Timestamp.fromDate(DateTime(2025, 10, 6)); // Segunda
      final fimPrevisto = Timestamp.fromDate(DateTime(2025, 10, 10)); // Sexta
      final fimReal = Timestamp.fromDate(DateTime(2025, 10, 8)); // Quarta

      final r = await screenState.calcDuracaoComJornada(
        'prestador123',
        inicio,
        fimPrevisto,
        realFim: fimReal,
      );

      expect(r, '3 dias');
    });
  });
}
