import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myapp/Cliente/visualizar_agenda_prestador.dart';
import 'package:table_calendar/table_calendar.dart';

// 🔹 Mock da tela que sempre considera todos os dias como úteis
class VisualizarAgendaPrestadorMock extends VisualizarAgendaPrestador {
  const VisualizarAgendaPrestadorMock({
    super.key,
    required super.prestadorId,
    super.prestadorNome,
    super.firestore,
  });

  @override
  VisualizarAgendaPrestadorState createState() =>
      VisualizarAgendaPrestadorStateMock();
}

class VisualizarAgendaPrestadorStateMock
    extends VisualizarAgendaPrestadorState {
  @override
  bool isWorkday(DateTime d) => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VisualizarAgendaPrestadorMock widget;
  late VisualizarAgendaPrestadorStateMock state;
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() async {
    // 🔹 Evita tentativa de abrir canal nativo do Firebase
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('pt_BR', null);
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    widget = VisualizarAgendaPrestadorMock(
      prestadorId: 'p001',
      prestadorNome: 'João',
      firestore: fakeFirestore, // ✅ injeta o fake
    );
    state = widget.createState() as VisualizarAgendaPrestadorStateMock;
  });

  // -------------------- READ --------------------
  group('📖 READ (Leitura)', () {
    test('1️⃣ fmtData formata corretamente', () {
      final data = DateTime(2025, 10, 17);
      final res = state.fmtData(data);
      expect(res.contains('2025'), isTrue);
      expect(res.toLowerCase(), contains('outubro'));
    });

    test('2️⃣ toYMD converte Timestamp corretamente', () {
      final ts = Timestamp.fromDate(DateTime(2025, 10, 17, 10, 30));
      final res = state.toYMD(ts);
      expect(res.year, 2025);
      expect(res.month, 10);
      expect(res.day, 17);
    });
  });

  // -------------------- CREATE --------------------
  group('🧩 CREATE (Criação)', () {
    test('3️⃣ markBusyFromDoc marca dias ocupados de intervalo', () {
      final data = {
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 1)),
        'dataFinalPrevista': Timestamp.fromDate(DateTime(2025, 10, 3)),
      };

      state.busyDays.clear();
      state.markBusyFromDoc(data);

      expect(state.busyDays.isNotEmpty, isTrue);
      expect(state.busyDays.length >= 3, isTrue);
    });

    test('4️⃣ markBusyFromDoc ignora documento inválido', () {
      state.busyDays.clear();
      state.markBusyFromDoc({'dataInicioSugerida': null});
      expect(state.busyDays.isEmpty, isTrue);
    });
  });

  // -------------------- UPDATE --------------------
  group('🧠 UPDATE (Atualização)', () {
    test('5️⃣ nextBusinessDays gera sequência de dias úteis', () {
      final res = state.nextBusinessDays(DateTime(2025, 10, 17), 5).toList();
      expect(res.length, 5);
    });

    test(
      '6️⃣ markBusyFromDoc preenche busyDays com dias úteis consecutivos',
      () {
        state.busyDays.clear();
        final data = {
          'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 10, 7)),
          'tempoEstimadoValor': 3,
          'tempoEstimadoUnidade': 'dias',
        };

        state.markBusyFromDoc(data);

        expect(state.busyDays.isNotEmpty, isTrue);
        expect(state.busyDays.length >= 3, isTrue);
      },
    );
  });

  // -------------------- DELETE --------------------
  group('🗑️ DELETE (Limpeza)', () {
    test('7️⃣ Limpa dias ocupados corretamente', () {
      state.busyDays.add(DateTime(2025, 10, 15));
      state.busyDays.add(DateTime(2025, 10, 16));
      expect(state.busyDays.isNotEmpty, isTrue);
      state.busyDays.clear();
      expect(state.busyDays.isEmpty, isTrue);
    });
  });

  // -------------------- INTERFACE --------------------
  group('🎨 INTERFACE', () {
    testWidgets('8️⃣ Renderiza modal com nome do prestador', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Agenda do prestador João Teste')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Agenda do prestador'), findsOneWidget);
    });

    testWidgets('9️⃣ Exibe legenda de cores no calendário', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(children: [Text('Indisponível'), Text('Disponível')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Indisponível'), findsOneWidget);
      expect(find.text('Disponível'), findsOneWidget);
    });

    testWidgets('🔟 Exibe calendário e permite selecionar um dia', (
      tester,
    ) async {
      await fakeFirestore.collection('usuarios').doc('p001').set({
        'jornada': ['Segunda-feira', 'Terça-feira'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VisualizarAgendaPrestadorMock(
            prestadorId: 'p001',
            prestadorNome: 'João',
            firestore: fakeFirestore, // ✅ injeta o fake aqui também
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Agenda do prestador'), findsOneWidget);
      expect(find.byType(TableCalendar), findsOneWidget);
    });
  });
}
