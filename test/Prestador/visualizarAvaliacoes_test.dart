import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/Prestador/visualizarAvaliacoes.dart';

/// 🔧 Cria um QueryDocumentSnapshot real usando o FakeFirebaseFirestore.
/// Isso evita erros com classes 'sealed' no Firestore moderno.
Future<QueryDocumentSnapshot<Map<String, dynamic>>> fakeDoc(
  Map<String, dynamic> data,
) async {
  final fake = FakeFirebaseFirestore();
  await fake.collection('avaliacoes').add(data);
  final snap = await fake.collection('avaliacoes').get();
  return snap.docs.first;
}

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
  });

  group('🧠 Funções isoladas de lógica', () {
    late VisualizarAvaliacoesScreenState state;

    setUp(() {
      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Pintura',
        firestore: fakeDb,
      );
      state = widget.createState() as VisualizarAvaliacoesScreenState;
      state.db = fakeDb;
    });

    test('nota() interpreta números e strings corretamente', () {
      expect(state.nota({'nota': 4.5}), 4.5);
      expect(state.nota({'rating': '3'}), 3);
      expect(state.nota({'avaliacao': {'notaGeral': '4.0'}}), 4.0);
      expect(state.nota({'outra': 2}), isNull);
    });

    test('temMidia() detecta imagens corretamente', () {
      expect(state.temMidia({'imagens': ['foto1']}), true);
      expect(state.temMidia({'imagens': []}), false);
      expect(state.temMidia({'imagens': 'url.jpg'}), true);
      expect(state.temMidia({'outra': 'x'}), false);
    });

    test('aplicarFiltros() filtra por mídia e estrelas corretamente', () async {
      final docs = [
        await fakeDoc({'imagens': ['img'], 'nota': 5}),
        await fakeDoc({'imagens': [], 'nota': 4}),
        await fakeDoc({'imagens': [], 'nota': 5}),
      ];

      final f1 = state.aplicarFiltros(
        docs: docs,
        somenteMidia: true,
        estrelasExatas: 0,
      );
      expect(f1.length, 1);

      final f2 = state.aplicarFiltros(
        docs: docs,
        somenteMidia: false,
        estrelasExatas: 5,
      );
      expect(f2.length, 2);

      final f3 = state.aplicarFiltros(
        docs: docs,
        somenteMidia: true,
        estrelasExatas: 5,
      );
      expect(f3.length, 1);
    });

    test('getClienteInfo() busca e cacheia corretamente', () async {
      await fakeDb.collection('usuarios').doc('cli1').set({
        'nome': 'Maria',
        'fotoUrl': 'foto.jpg',
      });

      final info1 = await state.getClienteInfo('cli1');
      expect(info1.nome, 'Maria');
      expect(info1.fotoUrl, 'foto.jpg');

      // cache test
      await fakeDb.collection('usuarios').doc('cli1').delete();
      final info2 = await state.getClienteInfo('cli1');
      expect(info2.nome, 'Maria');
    });

    test('getClienteInfo() retorna padrão se doc não existe', () async {
      final info = await state.getClienteInfo('inexistente');
      expect(info.nome, 'Cliente');
    });
  });

  group('📊 Consultas Firestore com ciclo real de widget', () {
    testWidgets('mediaQtdServico() calcula média corretamente', (tester) async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'servicoTitulo': 'Pintura',
        'nota': 4.0,
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'servicoTitulo': 'Pintura',
        'nota': 2.0,
      });

      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Pintura',
        firestore: fakeDb,
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      final state = tester.state<VisualizarAvaliacoesScreenState>(
        find.byType(VisualizarAvaliacoesScreen),
      );

      final r = await state.mediaQtdServico();
      expect(r['qtd'], 2);
      expect(r['media'], 3);
    });

    testWidgets('mediaQtdServico() retorna 0 quando vazio', (tester) async {
      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Pintura',
        firestore: fakeDb,
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      final state = tester.state<VisualizarAvaliacoesScreenState>(
        find.byType(VisualizarAvaliacoesScreen),
      );

      final r = await state.mediaQtdServico();
      expect(r['qtd'], 0);
      expect(r['media'], 0);
    });

    testWidgets('mediaQtdPrestador() calcula média geral', (tester) async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 5.0,
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 3.0,
      });

      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Pintura',
        firestore: fakeDb,
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      final state = tester.state<VisualizarAvaliacoesScreenState>(
        find.byType(VisualizarAvaliacoesScreen),
      );

      final r = await state.mediaQtdPrestador();
      expect(r['media'], 4);
      expect(r['qtd'], 2);
    });

    testWidgets('streamAvaliacoesDoServico() retorna stream ativa', (tester) async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'servicoTitulo': 'Pintura',
        'nota': 5.0,
      });

      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Pintura',
        firestore: fakeDb,
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      final state = tester.state<VisualizarAvaliacoesScreenState>(
        find.byType(VisualizarAvaliacoesScreen),
      );

      final stream = state.streamAvaliacoesDoServico();
      final snap = await stream.first;
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['nota'], 5.0);
    });

    testWidgets('streamAvaliacoesDoPrestador() retorna stream com docs', (tester) async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 5.0,
      });
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'prest123',
        'nota': 4.0,
      });

      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Pintura',
        firestore: fakeDb,
      );

      await tester.pumpWidget(MaterialApp(home: widget));
      final state = tester.state<VisualizarAvaliacoesScreenState>(
        find.byType(VisualizarAvaliacoesScreen),
      );

      final stream = state.streamAvaliacoesDoPrestador();
      final snap = await stream.first;
      expect(snap.docs.length, 2);
    });
  });

  group('🧩 Casos de borda e comportamento esperado', () {
    late VisualizarAvaliacoesScreenState state;

    setUp(() {
      final widget = VisualizarAvaliacoesScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        servicoTitulo: 'Teste',
        firestore: fakeDb,
      );
      state = widget.createState() as VisualizarAvaliacoesScreenState;
      state.db = fakeDb;
    });

    test('nota() retorna null para campos não reconhecidos', () {
      expect(state.nota({'foo': 123}), isNull);
    });

    test('temMidia() retorna falso se não houver imagens', () {
      expect(state.temMidia({}), false);
    });

    test('aplicarFiltros() com lista vazia não falha', () {
      final result = state.aplicarFiltros(
        docs: [],
        somenteMidia: true,
        estrelasExatas: 5,
      );
      expect(result, isEmpty);
    });
  });
}
