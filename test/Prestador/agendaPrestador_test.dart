import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myapp/Prestador/agendaPrestador.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null); // ✅ Corrige erro do intl

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late AgendaPrestadorScreenState state;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prestador123', email: 'teste@prest.com'),
    );

    state = AgendaPrestadorScreen(firestore: fakeDb, auth: mockAuth)
        .createState() as AgendaPrestadorScreenState;

    // ✅ Injeção manual dos mocks, sem acessar widget nem initState
    state.db = fakeDb;
    state.auth = mockAuth;
  });

  // ==========================================================
  // 🧩 CREATE
  // ==========================================================
  group('🧩 CREATE – markBusyFromDoc', () {
    test('Marca 3 dias úteis ocupados com dataFinalPrevista', () {
      final data = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 13)), // seg
        'dataFinalPrevista': Timestamp.fromDate(DateTime(2025, 10, 15)), // qua
      };
      state.markBusyFromDoc(data);
      expect(state.isBusy(DateTime(2025, 10, 13)), true);
      expect(state.isBusy(DateTime(2025, 10, 14)), true);
      expect(state.isBusy(DateTime(2025, 10, 15)), true);
    });

    test('Marca apenas 1 dia se tempoEstimado for zero', () {
      final data = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 13)),
        'tempoEstimadoUnidade': 'dia',
        'tempoEstimadoValor': 0
      };
      state.markBusyFromDoc(data);
      expect(state.isBusy(DateTime(2025, 10, 13)), true);
    });

    test('Marca 1 dia se unidade for hora', () {
      final data = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 14)),
        'tempoEstimadoUnidade': 'hora',
        'tempoEstimadoValor': 5,
      };
      state.markBusyFromDoc(data);
      expect(state.isBusy(DateTime(2025, 10, 14)), true);
    });
  });

  // ==========================================================
  // 🔍 READ
  // ==========================================================
  group('🔍 READ – docHitsDay', () {
    test('Retorna true dentro do intervalo previsto', () {
      final doc = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 13)),
        'dataFinalPrevista': Timestamp.fromDate(DateTime(2025, 10, 15)),
      };
      expect(state.docHitsDay(doc, DateTime(2025, 10, 14)), true);
    });

    test('Retorna false fora do intervalo', () {
      final doc = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 13)),
        'dataFinalPrevista': Timestamp.fromDate(DateTime(2025, 10, 15)),
      };
      expect(state.docHitsDay(doc, DateTime(2025, 10, 20)), false);
    });

    test('Reconhece finalização real (dataFinalizacaoReal)', () {
      final doc = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 10)),
        'dataFinalizacaoReal': Timestamp.fromDate(DateTime(2025, 10, 12)),
      };
      expect(state.docHitsDay(doc, DateTime(2025, 10, 11)), true);
      expect(state.docHitsDay(doc, DateTime(2025, 10, 13)), false);
    });
  });

  // ==========================================================
  // 🛠️ UPDATE
  // ==========================================================
  group('🛠️ UPDATE – countWorkdays', () {
    test('Conta 5 dias úteis de seg a dom', () {
      final total =
          state.countWorkdays(DateTime(2025, 10, 13), DateTime(2025, 10, 19));
      expect(total, 5);
    });
  });

  // ==========================================================
  // 🧨 DELETE / controle
  // ==========================================================
  group('🧨 DELETE – limpeza e controle', () {
    test('Limpa busyDays corretamente', () {
      state.busyDays.add(DateTime(2025, 10, 10));
      expect(state.busyDays.isNotEmpty, true);
      state.busyDays.clear();
      expect(state.busyDays.isEmpty, true);
    });

    test('isBusy retorna false quando vazio', () {
      expect(state.isBusy(DateTime(2025, 10, 13)), false);
    });
  });

  // ==========================================================
  // 📞 UTILITÁRIOS
  // ==========================================================
  group('📞 UTILITÁRIOS', () {
    test('fmtEndereco formata endereço completo', () {
      final e = {
        'rua': 'Av. Goiás',
        'numero': '123',
        'bairro': 'Centro',
        'cidade': 'Rio Verde',
        'estado': 'GO',
        'cep': '75900-000'
      };
      final res = state.fmtEndereco(e);
      expect(res, contains('Av. Goiás'));
      expect(res, contains('CEP 75900-000'));
    });

    test('fmtEndereco retorna — se vazio', () {
      final e = <String, dynamic>{};
      expect(state.fmtEndereco(e), '—');
    });

    test('pickWhatsApp retorna número válido', () {
      final d = {'clienteWhatsapp': '64 99999-0000'};
      expect(state.pickWhatsApp(d), '64 99999-0000');
    });

    test('pickWhatsApp retorna — se nenhum número', () {
      final d = <String, dynamic>{};
      expect(state.pickWhatsApp(d), '—');
    });

    test('onlyDigits remove tudo exceto números', () {
      expect(state.onlyDigits('(64) 99999-0000'), '64999990000');
    });
  });

  // ==========================================================
  // 🧠 getFinalizacaoReal
  // ==========================================================
  group('🧠 getFinalizacaoReal', () {
    test('Retorna data real de finalização', () {
      final doc = {
        'dataFinalizacaoReal':
            Timestamp.fromDate(DateTime(2025, 10, 15, 12, 0))
      };
      final res = state.getFinalizacaoReal(doc);
      expect(res, DateTime(2025, 10, 15));
    });

    test('Retorna null se nenhuma chave válida', () {
      final doc = {'outraChave': 123};
      expect(state.getFinalizacaoReal(doc), null);
    });
  });

  // ==========================================================
  // 🧭 nextBusinessDays
  // ==========================================================
  group('🧭 nextBusinessDays', () {
    test('Gera apenas dias úteis a partir de sábado', () {
      final dias =
          state.nextBusinessDays(DateTime(2025, 10, 11), 3).toList(); // sábado
      expect(dias.first.weekday, DateTime.monday);
      expect(dias.length, 3);
    });

    test('Ignora domingos e retorna 5 úteis consecutivos', () {
      final dias = state.nextBusinessDays(DateTime(2025, 10, 10), 5).toList();
      expect(dias.every((d) => d.weekday != DateTime.sunday), true);
      expect(dias.length, 5);
    });
  });

  // ==========================================================
  // 🧱 isFinalStatus
  // ==========================================================
  group('🧱 isFinalStatus', () {
    test('Reconhece status finalizado', () {
      expect(state.isFinalStatus('finalizada'), true);
    });

    test('Retorna false para status não finalizado', () {
      expect(state.isFinalStatus('aceita'), false);
    });
  });

  // ==========================================================
  // 📚 fmtData
  // ==========================================================
  group('📚 fmtData', () {
    test('Formata data em português', () {
      final res = state.fmtData(DateTime(2025, 10, 10));
      expect(res, contains('de outubro'));
    });
  });

  // ==========================================================
  // 🔥 loadWorkdays
  // ==========================================================
  group('🔥 loadWorkdays (mock Firestore)', () {
    test('Define jornada personalizada no banco', () async {
      await fakeDb.collection('usuarios').doc('prestador123').set({
        'jornada': ['Segunda-feira', 'Terça-feira', 'Quarta-feira']
      });

      await state.loadWorkdays();
      expect(state.isWorkday(DateTime(2025, 10, 13)), true); // segunda
      expect(state.isWorkday(DateTime(2025, 10, 14)), true); // terça
      expect(state.isWorkday(DateTime(2025, 10, 19)), false); // domingo
    });
  });
}
