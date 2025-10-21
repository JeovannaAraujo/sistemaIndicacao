// test/Prestador/visualizarAvaliacoesPrestador_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/Prestador/avaliacoesPrestador.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late VisualizarAvaliacoesPrestadorState state;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();

    // ✅ Cria o state manualmente e injeta tudo o que ele precisa
    state = VisualizarAvaliacoesPrestadorState();
    state.firestore = fakeDb;
    state.prestadorId = 'prest123'; // 💥 obrigatório para evitar length 0
  });

  group('🧮 nota()', () {
    test('Extrai valor numérico direto', () {
      expect(state.nota({'nota': 4}), 4);
    });

    test('Extrai de string numérica', () {
      expect(state.nota({'rating': '3.5'}), 3.5);
    });

    test('Extrai de map interno avaliacao', () {
      expect(state.nota({'avaliacao': {'estrelas': '4.0'}}), 4);
    });

    test('Retorna null se nenhum campo válido', () {
      expect(state.nota({'outra': 123}), null);
    });
  });

  group('🖼️ temMidia()', () {
    test('Detecta lista de imagens não vazia', () {
      expect(state.temMidia({'imagens': ['url1']}), true);
    });
    test('Detecta string de imagem não vazia', () {
      expect(state.temMidia({'imagens': 'http://x.com/img.png'}), true);
    });
    test('Retorna false se lista vazia', () {
      expect(state.temMidia({'imagens': []}), false);
    });
    test('Retorna false se string vazia', () {
      expect(state.temMidia({'imagens': ''}), false);
    });
  });

  group('🎯 aplicarFiltros()', () {
    test('Retorna todas se nenhum filtro ativo', () async {
      await fakeDb.collection('avaliacoes').add({'nota': 5});
      await fakeDb.collection('avaliacoes').add({'nota': 4});

      final snap = await fakeDb.collection('avaliacoes').get();
      final res = state.aplicarFiltros(
        docs: snap.docs,
        somenteMidia: false,
        estrelasExatas: 0,
      );
      expect(res.length, 2);
    });

    test('Filtra somenteMidia true', () async {
      await fakeDb.collection('avaliacoes').add({'imagens': ['img']});
      await fakeDb.collection('avaliacoes').add({'imagens': []});

      final snap = await fakeDb.collection('avaliacoes').get();
      final res = state.aplicarFiltros(
        docs: snap.docs,
        somenteMidia: true,
        estrelasExatas: 0,
      );
      expect(res.length, 1);
    });

    test('Filtra estrelas exatas', () async {
      await fakeDb.collection('avaliacoes').add({'nota': 5});
      await fakeDb.collection('avaliacoes').add({'nota': 4});

      final snap = await fakeDb.collection('avaliacoes').get();
      final res = state.aplicarFiltros(
        docs: snap.docs,
        somenteMidia: false,
        estrelasExatas: 5,
      );
      expect(res.length, 1);
    });
  });

  group('👤 getClienteInfo()', () {
    test('Retorna cliente padrão se ID vazio', () async {
      final info = await state.getClienteInfo('');
      expect(info.nome, 'Cliente');
    });

    test('Busca cliente e salva em cache', () async {
      await fakeDb.collection('usuarios').doc('c1').set({
        'nome': 'João Teste',
        'fotoUrl': 'foto.jpg',
      });

      final info = await state.getClienteInfo('c1');
      expect(info.nome, 'João Teste');
      expect(info.fotoUrl, 'foto.jpg');

      // deve vir do cache agora
      final info2 = await state.getClienteInfo('c1');
      expect(identical(info, info2), true);
    });

    test('Retorna nome padrão se doc inexistente', () async {
      final info = await state.getClienteInfo('naoExiste');
      expect(info.nome, 'Cliente');
    });
  });

  group('🌊 streamAvaliacoesDoPrestador()', () {
    test('Retorna stream filtrada pelo prestadorId', () async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 5,
        'criadoEm': Timestamp.fromDate(DateTime(2025, 10, 1)), // ✅ Timestamp
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'outro',
        'nota': 2,
        'criadoEm': Timestamp.fromDate(DateTime(2025, 10, 1)),
      });

      final snap = await state.streamAvaliacoesDoPrestador().first;
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['nota'], 5);
    });
  });

  group('📊 mediaQtdPrestador()', () {
    test('Calcula média e quantidade corretamente', () async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 4,
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 2,
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'outro',
        'nota': 5,
      });

      final res = await state.mediaQtdPrestador();
      expect(res['media'], 3);
      expect(res['qtd'], 2);
    });

    test('Retorna média 0 se não houver avaliações', () async {
      final res = await state.mediaQtdPrestador();
      expect(res['media'], 0);
      expect(res['qtd'], 0);
    });
  });

  group('🧠 Integração leve', () {
    test('Aplicar filtros + média combina corretamente', () async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 5,
        'imagens': ['x'],
        'criadoEm': Timestamp.fromDate(DateTime(2025, 10, 1)),
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 3,
        'imagens': [],
        'criadoEm': Timestamp.fromDate(DateTime(2025, 10, 1)),
      });

      final snap = await state.streamAvaliacoesDoPrestador().first;
      final filtrados = state.aplicarFiltros(
        docs: snap.docs,
        somenteMidia: true,
        estrelasExatas: 0,
      );
      expect(filtrados.length, 1);

      final media = await state.mediaQtdPrestador();
      expect(media['qtd'], 2);
      expect(media['media'], greaterThan(3));
    });
  });

  group('🧩 Widgets visuais', () {
    testWidgets('Renderiza HeaderPrestador com média e qtd', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: HeaderPrestador(media: 4.2, qtd: 12),
        ),
      ));
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('(12 avaliações)'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });

    testWidgets('Renderiza FiltroPill e reage ao toque', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FiltroPill(
            label: 'Teste',
            count: 5,
            selected: false,
            width: 100,
            height: 40,
            onTap: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('Teste'), findsOneWidget);
      expect(find.text('(5)'), findsOneWidget);
      await tester.tap(find.text('Teste'));
      expect(tapped, true);
    });
  });
}
