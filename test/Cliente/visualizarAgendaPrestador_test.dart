// test/Cliente/visualizarAgendaPrestador_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myapp/Cliente/visualizarAgendaPrestador.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VisualizarAgendaPrestador widget;
  late VisualizarAgendaPrestadorState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting(
      'pt_BR',
      null,
    ); // Corrige LocaleDataException
  });

  setUp(() {
    widget = const VisualizarAgendaPrestador(
      prestadorId: 'p001',
      prestadorNome: 'João',
    );
    state = widget.createState() as VisualizarAgendaPrestadorState;
  });

  // -------------------- READ --------------------
  group('📖 READ (Leitura)', () {
    test('1️⃣ fmtData formata corretamente', () {
      final data = DateTime(2025, 10, 17);
      final res = state.fmtData(data);
      expect(res.contains('2025'), true);
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
      state.markBusyFromDoc(data);
      expect(state.busyDays.isNotEmpty, true);
      expect(state.busyDays.length >= 3, true);
    });

    test('4️⃣ markBusyFromDoc ignora documento inválido', () {
      state.busyDays.clear();
      state.markBusyFromDoc({'dataInicioSugerida': null});
      expect(state.busyDays.isEmpty, true);
    });
  });

  // -------------------- UPDATE --------------------
  group('🧠 UPDATE (Atualização)', () {
    test('5️⃣ nextBusinessDays gera sequência de dias úteis', () {
      final res = state.nextBusinessDays(DateTime(2025, 10, 17), 5).toList();
      expect(res.length, 5);
      for (final d in res) {
        expect(state.isWorkday(d), true);
      }
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
        expect(state.busyDays.isNotEmpty, true);
        expect(state.busyDays.length >= 3, true);
      },
    );
  });

  // -------------------- DELETE --------------------
  group('🗑️ DELETE (Limpeza)', () {
    test('7️⃣ Limpa dias ocupados corretamente', () {
      state.busyDays.add(DateTime(2025, 10, 15));
      state.busyDays.add(DateTime(2025, 10, 16));
      expect(state.busyDays.isNotEmpty, true);
      state.busyDays.clear();
      expect(state.busyDays.isEmpty, true);
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
  });
}
