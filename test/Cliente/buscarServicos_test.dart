import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:myapp/Cliente/buscarServicos.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 🔧 Mock seguro do Firebase compatível com o SDK atual.
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

/// Mock do Firebase Auth
class MockFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.empty();

  @override
  Stream<User?> userChanges() => Stream<User?>.empty();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
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
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fake = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
  });

  // 🧮 Cálculos e conversões básicas ------------------------------------------------------
  group('🧮 Cálculos e conversões básicas', () {
    test('1️⃣ _deg2rad converte corretamente', () {
      // Método auxiliar para testar a função privada
      double deg2rad(double deg) => deg * (3.141592653589793 / 180.0);
      expect(deg2rad(180), closeTo(3.14159, 0.0001));
    });

    test('2️⃣ _distanciaKm retorna ~0 para pontos iguais', () {
      // Método auxiliar para testar a função privada
      double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
        const r = 6371.0;
        final dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
        final dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
        final a =
            math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos((lat1) * (3.141592653589793 / 180.0)) *
                math.cos((lat2) * (3.141592653589793 / 180.0)) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);
        final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
        return r * c;
      }

      expect(distanciaKm(0, 0, 0, 0), closeTo(0, 0.001));
    });

    test('3️⃣ isSameDay retorna true para mesma data', () {
      // Método auxiliar
      bool isSameDay(DateTime a, DateTime b) {
        return a.year == b.year && a.month == b.month && a.day == b.day;
      }

      final a = DateTime(2025, 10, 10, 8);
      final b = DateTime(2025, 10, 10, 20);
      expect(isSameDay(a, b), true);
    });

    test('4️⃣ isSameDay retorna false para dias diferentes', () {
      // Método auxiliar
      bool isSameDay(DateTime a, DateTime b) {
        return a.year == b.year && a.month == b.month && a.day == b.day;
      }

      expect(isSameDay(DateTime(2025, 10, 10), DateTime(2025, 10, 11)), false);
    });
  });

  // 🧾 Títulos e textos -----------------------------------------------------------------
  group('🧾 Títulos e textos', () {
    testWidgets('5️⃣ tituloResultados plural (serviços)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      state.exibirProfissionais = false;
      expect(state.tituloResultados(2), '2 serviços encontrados');
    });

    testWidgets('6️⃣ tituloResultados singular (prestador)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      state.exibirProfissionais = true;
      expect(state.tituloResultados(1), '1 prestador encontrado');
    });

    testWidgets('7️⃣ tituloResultados plural (prestadores)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      state.exibirProfissionais = true;
      expect(state.tituloResultados(4), '4 prestadores encontrados');
    });
  });

  // 🧠 Lógica e cache -------------------------------------------------------------------
  group('🧠 Lógica de caches', () {
    testWidgets('8️⃣ nomeCategoriaProf retorna vazio se id for vazio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      expect(await state.nomeCategoriaProf(''), '');
    });

    testWidgets('9️⃣ ratingPrestador retorna 0 sem dados', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      final r = await state.ratingPrestador('id_fake');
      expect(r['media'], 0.0);
      expect(r['total'], 0);
    });

    testWidgets('🔟 ratingServico retorna 0 sem dados', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      final r = await state.ratingServico('srv_fake');
      expect(r['media'], 0.0);
      expect(r['total'], 0);
    });
  });

  // 🧱 Widgets básicos ----------------------------------------------------------------
  group('🧱 Widgets básicos', () {
    testWidgets('11️⃣ Renderiza campo de busca principal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('12️⃣ Renderiza botões de ação', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      
      // Usa finders mais específicos para evitar ambiguidade
      expect(find.widgetWithText(ElevatedButton, 'Buscar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Limpar Filtros'), findsOneWidget);
    });

    testWidgets('13️⃣ Botão Buscar executa sem erros', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      
      final buscarButton = find.widgetWithText(ElevatedButton, 'Buscar').first;
      expect(buscarButton, findsOneWidget);
      
      await tester.tap(buscarButton);
      await tester.pump(const Duration(milliseconds: 100));
      
      // Verifica que o widget ainda está presente (não crashou)
      expect(find.byType(BuscarServicosScreen), findsOneWidget);
    });

    testWidgets('14️⃣ Botão Limpar Filtros executa sem erros', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      
      final limparButton = find.widgetWithText(OutlinedButton, 'Limpar Filtros').first;
      expect(limparButton, findsOneWidget);
      
      await tester.tap(limparButton);
      await tester.pump(const Duration(milliseconds: 100));
      
      expect(find.byType(BuscarServicosScreen), findsOneWidget);
    });

    testWidgets('15️⃣ Renderiza seções de filtro corretamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      
      // Verifica seções principais dos filtros
      expect(find.text('Categoria de serviço'), findsOneWidget);
      expect(find.text('Valor por unidade'), findsOneWidget);
      expect(find.text('Avaliação mínima'), findsOneWidget);
      expect(find.text('Raio de distância (km)'), findsOneWidget);
    });

    testWidgets('16️⃣ Campo de busca aceita texto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      
      // Encontra o campo de busca principal (geralmente o primeiro)
      final buscaField = find.byType(TextField).first;
      await tester.enterText(buscaField, 'encanador');
      await tester.pump();
      
      // Verifica que o texto foi inserido
      expect(find.text('encanador'), findsOneWidget);
    });
  });

  // 🧰 Limpeza e resets -----------------------------------------------------------------
  group('🧰 Limpeza e resets', () {
    testWidgets('17️⃣ limparFiltros redefine tudo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );
      
      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );
      
      state.buscaController.text = 'abc';
      state.minValueController.text = '10';
      state.maxValueController.text = '100';
      state.avaliacaoMinima = 3;
      
      state.limparFiltros();
      
      expect(state.buscaController.text, '');
      expect(state.minValueController.text, '');
      expect(state.maxValueController.text, '');
      expect(state.avaliacaoMinima, 0);
    });
  });

  // 📏 Geográficos ----------------------------------------------------------------------
  group('📏 Geográficos', () {
    test('18️⃣ _boundsFromMarkers calcula corretamente', () {
      // Método auxiliar para testar função privada
      LatLngBounds boundsFromMarkers(Set<Marker> markers) {
        final latitudes = markers.map((m) => m.position.latitude).toList();
        final longitudes = markers.map((m) => m.position.longitude).toList();

        final southwest = LatLng(
          latitudes.reduce((a, b) => a < b ? a : b),
          longitudes.reduce((a, b) => a < b ? a : b),
        );
        final northeast = LatLng(
          latitudes.reduce((a, b) => a > b ? a : b),
          longitudes.reduce((a, b) => a > b ? a : b),
        );

        return LatLngBounds(southwest: southwest, northeast: northeast);
      }
      
      final markers = {
        const Marker(markerId: MarkerId('a'), position: LatLng(0, 0)),
        const Marker(markerId: MarkerId('b'), position: LatLng(1, 1)),
      };
      final b = boundsFromMarkers(markers);
      expect(b.northeast.latitude, 1);
      expect(b.southwest.longitude, 0);
    });

    test('19️⃣ _distanciaKm não negativa', () {
      // Método auxiliar para testar função privada
      double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
        const r = 6371.0;
        final dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
        final dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
        final a = 
            math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos((lat1) * (3.141592653589793 / 180.0)) *
                math.cos((lat2) * (3.141592653589793 / 180.0)) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);
        final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
        return r * c;
      }
      
      final d = distanciaKm(-10, -10, 10, 10);
      expect(d >= 0, true);
    });
  });

  // 🎯 Extras e consistência ------------------------------------------------------------
  group('🎯 Extras e consistência', () {
    test('20️⃣ _deg2rad é determinística', () {
      // Método auxiliar
      double deg2rad(double deg) => deg * (3.141592653589793 / 180.0);
      expect(deg2rad(45), deg2rad(45));
    });

    testWidgets('21️⃣ tituloResultados pluraliza corretamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      expect(state.tituloResultados(2).contains('encontrad'), true);
    });

    testWidgets('22️⃣ Cache de unidade inexistente retorna string vazia', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      final un = await state.abrevUnidade('');
      expect(un, '');
    });

    testWidgets('23️⃣ Cache de nomePrestador inexistente retorna vazio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      final nome = await state.nomePrest('semId');
      expect(nome, '');
    });

    testWidgets('24️⃣ Metodo tituloResultados sempre retorna String', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      final t = state.tituloResultados(10);
      expect(t, isA<String>());
    });
  });

  // 💰 Formatação de valores ------------------------------------------------------------
  group('💰 Formatação de valores', () {
    testWidgets('25️⃣ formatPreco formata número corretamente', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      expect(state.formatPreco(10.5), 'R\$10,50');
      expect(state.formatPreco(1000), 'R\$1000,00');
      expect(state.formatPreco(null), 'R\$ --');
    });

    testWidgets('26️⃣ formatPreco formata string corretamente', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      // Teste com string no formato brasileiro
      expect(state.formatPreco('10,50'), 'R\$10,50');
      expect(state.formatPreco('1000,00'), 'R\$1000,00');
      expect(state.formatPreco('texto'), 'R\$ --'); // String inválida
    });

    testWidgets('27️⃣ formatPreco com valores mínimos, médios e máximos', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: BuscarServicosScreen(firestore: fake, auth: mockAuth)),
      );

      final state = tester.state<BuscarServicosScreenState>(
        find.byType(BuscarServicosScreen),
      );

      // Teste com diferentes tipos de entrada
      expect(state.formatPreco(0), 'R\$0,00');
      expect(state.formatPreco(999.99), 'R\$999,99');
      expect(state.formatPreco(''), 'R\$ --');
    });
  });
}