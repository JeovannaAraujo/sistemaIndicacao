import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myapp/Prestador/visualizar_resposta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late VisualizarRespostaPrestadorScreenState state;

  // ✅ Inicializa locale pt_BR para garantir formatação correta nos testes
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
    Intl.defaultLocale = 'pt_BR';
  });

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();

    final widget = VisualizarRespostaPrestadorScreen(
      docId: 'orc123',
      firestore: fakeDb,
    );

    // ✅ cast explícito para acessar o estado e injetar o fakeDb
    final s = widget.createState() as VisualizarRespostaPrestadorScreenState;
    s.db = fakeDb;
    state = s;
  });

  // ======================================================
  // 🧠 TESTES DE LÓGICA ISOLADA
  // ======================================================
  group('🧠 Funções auxiliares isoladas', () {
    test('🔹 fmtData() formata Timestamp corretamente', () {
      final ts = Timestamp.fromDate(DateTime(2024, 10, 5));
      expect(VisualizarRespostaPrestadorScreenState.fmtData(ts), '05/10/2024');
    });

    test('🔹 fmtData() retorna "—" se não for Timestamp', () {
      expect(VisualizarRespostaPrestadorScreenState.fmtData('texto'), '—');
    });

    test('🔹 formatTempo() trata plural e singular corretamente', () {
      expect(state.formatTempo(1, 'dia'), '1 dia');
      expect(state.formatTempo(2, 'dia'), '2 dias');
      expect(state.formatTempo(3, 'hora'), '3 horas');
    });

    test('🔹 formatTempo() retorna "—" se nulo ou vazio', () {
      expect(state.formatTempo('', 'minuto'), '—');
      expect(state.formatTempo(null, 'hora'), '—');
    });
  });

  // ======================================================
  // 📊 FIRESTORE - TESTES UNITÁRIOS DE getInfo()
  // ======================================================
  group('📊 Firestore – getInfo()', () {
    test(
      '🔹 Retorna dados completos de serviço, categoria e unidade',
      () async {
        await fakeDb.collection('categoriasServicos').doc('cat1').set({
          'nome': 'Elétrica',
          'imagemUrl': 'img.png',
        });

        await fakeDb.collection('servicos').doc('serv1').set({
          'descricao': 'Instalação elétrica',
          'valorMinimo': 50,
          'valorMedio': 100,
          'valorMaximo': 200,
          'categoriaId': 'cat1',
        });

        await fakeDb.collection('unidades').doc('u1').set({'abreviacao': 'm²'});

        final result = await state.getInfo('serv1', 'u1');
        expect(result['descricaoServ'], 'Instalação elétrica');
        expect(result['valorMin'], 50);
        expect(result['valorMax'], 200);
        expect(result['unidadeAbrev'], 'm²');
        expect(result['categoriaNome'], 'Elétrica');
        expect(result['imagemUrl'], 'img.png');
      },
    );

    test('🔹 Retorna valores padrão se documentos não existem', () async {
      final result = await state.getInfo('naoExiste', 'u9');
      expect(result['descricaoServ'], '');
      expect(result['valorMin'], isNull);
      expect(result['unidadeAbrev'], '');
      expect(result['categoriaNome'], '');
    });
  });

  // ======================================================
  // 📋 FIRESTORE - STREAMS DE DOCUMENTOS
  // ======================================================
  group('📋 Stream de solicitacoes', () {
    test('🔹 Stream sem dados retorna inexistente', () async {
      final snap = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('orc123')
          .snapshots()
          .first;
      expect(snap.exists, false);
    });

    test('🔹 Stream retorna documento com dados corretos', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('orc123').set({
        'servicoTitulo': 'Pintura',
        'quantidade': 10,
        'valorProposto': 250.0,
        'clienteNome': 'Maria',
        'clienteWhatsapp': '64 99999-1111',
        'clienteEndereco': {
          'rua': 'Rua A',
          'numero': '321',
          'bairro': 'Centro',
          'cidade': 'Rio Verde',
        },
      });

      final snap = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('orc123')
          .snapshots()
          .first;

      expect(snap.exists, true);
      expect(snap.data()?['servicoTitulo'], 'Pintura');
      expect(snap.data()?['valorProposto'], 250.0);
    });
  });

  // ======================================================
  // 🧩 TESTES DE INTERFACE COM WIDGETS (build)
  // ======================================================
  group('🧩 Interface visual (pumpWidget)', () {
    testWidgets('🔹 Renderiza AppBar e indicador de carregamento', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VisualizarRespostaPrestadorScreen(
            docId: 'orc123',
            firestore: fakeDb,
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Resposta Enviada'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('🔹 Mostra mensagem "Solicitação não encontrada"', (
      WidgetTester tester,
    ) async {
      await fakeDb.collection('solicitacoesOrcamento').doc('orc123').set({});
      await fakeDb.collection('solicitacoesOrcamento').doc('orc123').delete();

      await tester.pumpWidget(
        MaterialApp(
          home: VisualizarRespostaPrestadorScreen(
            docId: 'orc123',
            firestore: fakeDb,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Solicitação não encontrada.'), findsOneWidget);
    });

    testWidgets('🔹 Mostra informações do cliente corretamente', (
      WidgetTester tester,
    ) async {
      await fakeDb.collection('solicitacoesOrcamento').doc('orc123').set({
        'servicoTitulo': 'Limpeza de Caixa D’água',
        'quantidade': 3,
        'valorProposto': 180.0,
        'clienteNome': 'Lucas Silva',
        'clienteWhatsapp': '64 99999-0000',
        'clienteEndereco': {
          'rua': 'Rua das Flores',
          'numero': '123',
          'bairro': 'Centro',
          'cidade': 'Rio Verde',
          'complemento': 'Próximo ao mercado',
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VisualizarRespostaPrestadorScreen(
            docId: 'orc123',
            firestore: fakeDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Lucas Silva'), findsOneWidget);
      expect(find.textContaining('Rua das Flores'), findsOneWidget);
      expect(find.textContaining('64 99999-0000'), findsOneWidget);
    });

    testWidgets('🔹 Mostra valores e datas formatadas corretamente', (
      WidgetTester tester,
    ) async {
      await fakeDb.collection('solicitacoesOrcamento').doc('orc999').set({
        'servicoTitulo': 'Pintura',
        'quantidade': 10,
        'valorProposto': 350.0,
        'dataInicioSugerida': Timestamp.fromDate(DateTime(2025, 1, 15)),
        'dataFinalPrevista': Timestamp.fromDate(DateTime(2025, 1, 20)),
        'clienteNome': 'Rafaela',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VisualizarRespostaPrestadorScreen(
            docId: 'orc999',
            firestore: fakeDb,
          ),
        ),
      );

      // 🔹 Espera as streams e o FutureBuilder terminarem
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Pintura'), findsOneWidget);

      // ✅ Aceita qualquer formato de moeda (ponto, vírgula, espaço, etc.)
      // ✅ Procura especificamente o valor proposto (R$ 350)
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              w.data!.contains('R\$') &&
              w.data!.contains('350'),
        ),
        findsAtLeastNWidgets(1),
      );

      expect(find.textContaining('15/01/2025'), findsOneWidget);
      expect(find.textContaining('20/01/2025'), findsOneWidget);
    });
  });
}
