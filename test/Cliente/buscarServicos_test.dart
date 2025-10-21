import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:myapp/Cliente/buscarServicos.dart';

/// 🔧 Mock seguro do Firebase compatível com o SDK atual.
/// Nenhum método `@override` que não existe mais será declarado.
class _FakeFirebase extends FirebasePlatform {
  FirebaseAppPlatform createFirebaseApp({
    required String name,
    required FirebaseOptions options,
  }) {
    return _FakeFirebaseApp(name, options);
  }

  @override
  FirebaseAppPlatform app([String? name]) {
    return _FakeFirebaseApp(
      name ?? 'fake',
      const FirebaseOptions(
        apiKey: 'fake',
        appId: 'fake',
        messagingSenderId: 'fake',
        projectId: 'fake',
      ),
    );
  }

  @override
  List<FirebaseAppPlatform> get apps => [
        _FakeFirebaseApp(
          'fake',
          const FirebaseOptions(
            apiKey: 'fake',
            appId: 'fake',
            messagingSenderId: 'fake',
            projectId: 'fake',
          ),
        ),
      ];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _FakeFirebaseApp(
      name ?? 'fake',
      options ??
          const FirebaseOptions(
            apiKey: 'fake',
            appId: 'fake',
            messagingSenderId: 'fake',
            projectId: 'fake',
          ),
    );
  }
}

/// 🔹 Representa um app Firebase simulado
class _FakeFirebaseApp extends FirebaseAppPlatform {
  _FakeFirebaseApp(String name, FirebaseOptions options) : super(name, options);
}

/// 🔹 Inicializa o mock antes dos testes
Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = _FakeFirebase();
  await Firebase.initializeApp(
    name: 'fake',
    options: const FirebaseOptions(
      apiKey: 'fake',
      appId: 'fake',
      messagingSenderId: 'fake',
      projectId: 'fake',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupFirebaseMocks();
  });

  late FakeFirebaseFirestore fake;
  late BuscarServicosScreenState state;

  setUp(() {
    fake = FakeFirebaseFirestore();
    state = BuscarServicosScreenState.forTest(fake);
  });

  // 🧮 Cálculos e conversões básicas ------------------------------------------------------
  group('🧮 Cálculos e conversões básicas', () {
    test('1️⃣ deg2rad converte corretamente', () {
      expect(state.deg2rad(180), closeTo(3.14159, 0.0001));
    });

    test('2️⃣ distanciaKm retorna ~0 para pontos iguais', () {
      expect(state.distanciaKm(0, 0, 0, 0), closeTo(0, 0.001));
    });

    test('3️⃣ distanciaKm entre 0° e 1° longitude ≈ 111km', () {
      expect(state.distanciaKm(0, 0, 0, 1), closeTo(111, 1));
    });

    test('4️⃣ isSameDay retorna true para mesma data', () {
      final a = DateTime(2025, 10, 10, 8);
      final b = DateTime(2025, 10, 10, 20);
      expect(state.isSameDay(a, b), true);
    });

    test('5️⃣ isSameDay retorna false para dias diferentes', () {
      expect(
        state.isSameDay(DateTime(2025, 10, 10), DateTime(2025, 10, 11)),
        false,
      );
    });
  });

  // 🕐 Validação de horário --------------------------------------------------------------
  group('🕐 validarHorarioDesejado', () {
    test('6️⃣ Retorna true quando data e hora não foram informadas', () {
      state.dataSelecionada = null;
      state.horarioController.text = '';
      expect(state.validarHorarioDesejado(emTeste: true), true);
    });

    test('7️⃣ Retorna false quando hora inválida', () {
      state.dataSelecionada = DateTime.now();
      state.horarioController.text = '99:99';
      expect(state.validarHorarioDesejado(emTeste: true), false);
    });

    test('8️⃣ Retorna false quando hora no passado (dia anterior)', () {
      final now = DateTime.now();
      state.dataSelecionada = now.subtract(const Duration(days: 1));
      state.horarioController.text = DateFormat('HH:mm').format(now);
      expect(state.validarHorarioDesejado(emTeste: true), false);
    });

    test('9️⃣ Retorna true quando hora futura', () {
      final now = DateTime.now();
      state.dataSelecionada = now;
      state.horarioController.text =
          DateFormat('HH:mm').format(now.add(const Duration(hours: 2)));
      expect(state.validarHorarioDesejado(emTeste: true), true);
    });

    test('🔟 Retorna true para data futura distante', () {
      state.dataSelecionada = DateTime.now().add(const Duration(days: 5));
      state.horarioController.text = '08:30';
      expect(state.validarHorarioDesejado(emTeste: true), true);
    });
  });
  // 🧾 Títulos e textos -----------------------------------------------------------------
  group('🧾 Títulos e textos', () {
    test('11️⃣ tituloResultados plural (serviços)', () {
      state.exibirProfissionais = false;
      expect(state.tituloResultados(2), '2 serviços encontrados');
    });

    test('12️⃣ tituloResultados singular (prestador)', () {
      state.exibirProfissionais = true;
      expect(state.tituloResultados(1), '1 prestador encontrado');
    });

    test('13️⃣ tituloResultados plural (prestadores)', () {
      state.exibirProfissionais = true;
      expect(state.tituloResultados(4), '4 prestadores encontrados');
    });
  });

  // 🧠 Lógica e cache -------------------------------------------------------------------
  group('🧠 Lógica de caches', () {
    test('14️⃣ nomeCategoriaProf retorna vazio se id for vazio', () async {
      expect(await state.nomeCategoriaProf(''), '');
    });

    test('15️⃣ ratingPrestador retorna 0 sem dados', () async {
      final r = await state.ratingPrestador('id_fake');
      expect(r['media'], 0.0);
      expect(r['total'], 0);
    });

    test('16️⃣ ratingServico retorna 0 sem dados', () async {
      final r = await state.ratingServico('srv_fake');
      expect(r['media'], 0.0);
      expect(r['total'], 0);
    });
  });

  // 📅 Disponibilidade -----------------------------------------------------------------
  group('📅 prestadoresDisponiveisNaDataHora', () {
    test('17️⃣ Retorna vazio sem dados', () async {
      final res = await state.prestadoresDisponiveisNaDataHora(
        DateTime.now(),
        '08:00',
      );
      expect(res, isEmpty);
    });

    test('18️⃣ Retorna ID se hora disponível', () async {
      await fake.collection('agendaPrestador').add({
        'prestadorId': 'p1',
        'data': '2025-10-15',
        'horasLivres': ['08:00'],
      });
      final res = await state.prestadoresDisponiveisNaDataHora(
        DateTime(2025, 10, 15),
        '08:00',
      );
      expect(res, contains('p1'));
    });
  });

  // 🧱 Widgets simulados ----------------------------------------------------------------
  group('🧱 Widgets básicos', () {
    testWidgets('19️⃣ Renderiza campo de busca principal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake)),
      );
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('20️⃣ Renderiza botão Buscar e Limpar Filtros', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake)),
      );
      expect(find.text('Buscar'), findsWidgets);
      expect(find.textContaining('Limpar'), findsWidgets);
    });

    testWidgets('21️⃣ Alterna sem erro entre filtros e resultados', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake)),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buscar'));
      await tester.pump();
      expect(find.textContaining('Buscar'), findsWidgets);
    });
  });

  // 🧰 Limpeza e resets -----------------------------------------------------------------
  group('🧰 Limpeza e resets', () {
    test('22️⃣ limparFiltros redefine tudo', () {
      state.buscaController.text = 'abc';
      state.minValueController.text = '10';
      state.maxValueController.text = '100';
      state.localizacaoController.text = 'Cidade';
      state.limparFiltros();
      expect(state.buscaController.text, '');
      expect(state.minValueController.text, '');
      expect(state.maxValueController.text, '');
      expect(state.localizacaoController.text, '');
    });
  });

  // 📏 Geográficos ----------------------------------------------------------------------
  group('📏 Geográficos', () {
    test('23️⃣ boundsFromMarkers calcula corretamente', () {
      final markers = {
        const Marker(markerId: MarkerId('a'), position: LatLng(0, 0)),
        const Marker(markerId: MarkerId('b'), position: LatLng(1, 1)),
      };
      final b = state.boundsFromMarkers(markers);
      expect(b.northeast.latitude, 1);
      expect(b.southwest.longitude, 0);
    });

    test('24️⃣ distanciaKm não negativa', () {
      final d = state.distanciaKm(-10, -10, 10, 10);
      expect(d >= 0, true);
    });
  });

  // 🎯 Extras e consistência ------------------------------------------------------------
  group('🎯 Extras e consistência', () {
    test('25️⃣ deg2rad é determinística', () {
      expect(state.deg2rad(45), state.deg2rad(45));
    });

    test('26️⃣ tituloResultados pluraliza corretamente', () {
      expect(state.tituloResultados(2).contains('encontrad'), true);
    });

    test(
      '27️⃣ validarHorarioDesejado ignora hora vazia quando data futura',
      () {
        state.dataSelecionada = DateTime.now().add(const Duration(days: 1));
        state.horarioController.text = '';
        expect(state.validarHorarioDesejado(emTeste: true), true);
      },
    );

    test('28️⃣ Cache de unidade inexistente retorna string vazia', () async {
      final un = await state.abrevUnidade('');
      expect(un, '');
    });

    test('29️⃣ Cache de nomePrestador inexistente retorna vazio', () async {
      final nome = await state.nomePrest('semId');
      expect(nome, '');
    });

    test('30️⃣ Metodo tituloResultados sempre retorna String', () {
      final t = state.tituloResultados(10);
      expect(t, isA<String>());
    });
  });
}
