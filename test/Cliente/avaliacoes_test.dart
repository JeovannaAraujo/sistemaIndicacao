import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/avaliacoes.dart'; // ajuste o caminho real

void main() {
  final tab = MinhasAvaliacoesTab();

  group('🧩 fmtData()', () {
    test('1️⃣ formata data corretamente', () {
      final ts = Timestamp.fromDate(DateTime(2025, 10, 14));
      expect(tab.fmtData(ts), '14/10/2025');
    });

    test('2️⃣ retorna — para null', () {
      expect(tab.fmtData(null), '—');
    });

    test('3️⃣ retorna — para tipos inválidos', () {
      expect(tab.fmtData(123), '—');
      expect(tab.fmtData('2025-10-14'), '—');
    });

    test('4️⃣ respeita o formato dd/MM/yyyy', () {
      final ts = Timestamp.fromDate(DateTime(2030, 1, 5));
      expect(tab.fmtData(ts), '05/01/2030');
    });
  });

  group('⏳ duracaoFromSolic()', () {
    test('5️⃣ retorna valor + unidade singular', () {
      final s = {'tempoEstimadoValor': 1, 'tempoEstimadoUnidade': 'dia'};
      expect(tab.duracaoFromSolic(s), '1 dia');
    });

    test('6️⃣ retorna valor + unidade plural', () {
      final s = {'tempoEstimadoValor': 3, 'tempoEstimadoUnidade': 'hora'};
      expect(tab.duracaoFromSolic(s), '3 horas');
    });

    test('7️⃣ ignora valores 0 ou negativos', () {
      final s = {'tempoEstimadoValor': 0, 'tempoEstimadoUnidade': 'dia'};
      expect(tab.duracaoFromSolic(s), '—');
      final s2 = {'tempoEstimadoValor': -2, 'tempoEstimadoUnidade': 'hora'};
      expect(tab.duracaoFromSolic(s2), '—');
    });

    test('8️⃣ ignora quando unidade está vazia', () {
      final s = {'tempoEstimadoValor': 3, 'tempoEstimadoUnidade': ''};
      expect(tab.duracaoFromSolic(s), '—');
    });

    test('9️⃣ ignora quando valor é nulo', () {
      final s = {'tempoEstimadoUnidade': 'dias'};
      expect(tab.duracaoFromSolic(s), '—');
    });

    test('🔟 retorna duração baseada em timestamps (3 dias)', () {
      final ini = Timestamp.fromDate(DateTime(2025, 1, 1));
      final fim = Timestamp.fromDate(DateTime(2025, 1, 3));
      final s = {'dataInicioSugerida': ini, 'dataFinalPrevista': fim};
      expect(tab.duracaoFromSolic(s), '3 dias');
    });

    test('11️⃣ diferença 0 dia → 1 dia', () {
      final ini = Timestamp.fromDate(DateTime(2025, 1, 1));
      final fim = Timestamp.fromDate(DateTime(2025, 1, 1));
      final s = {'dataInicioSugerida': ini, 'dataFinalPrevista': fim};
      expect(tab.duracaoFromSolic(s), '1 dia');
    });

    test('12️⃣ diferença negativa também vira positiva', () {
      final ini = Timestamp.fromDate(DateTime(2025, 1, 10));
      final fim = Timestamp.fromDate(DateTime(2025, 1, 5));
      final s = {'dataInicioSugerida': ini, 'dataFinalPrevista': fim};
      expect(tab.duracaoFromSolic(s), '6 dias');
    });

    test('13️⃣ retorna — quando mapa é nulo', () {
      expect(tab.duracaoFromSolic(null), '—');
    });

    test('14️⃣ retorna — quando sem datas', () {
      expect(tab.duracaoFromSolic({}), '—');
    });

    test('15️⃣ ignora quando campos são inválidos', () {
      final s = {'dataInicioSugerida': 'texto', 'dataFinalPrevista': 123};
      expect(tab.duracaoFromSolic(s), '—');
    });

    test('16️⃣ formata corretamente quando usa dataFinalizacaoReal', () {
      final ini = Timestamp.fromDate(DateTime(2025, 1, 1));
      final fim = Timestamp.fromDate(DateTime(2025, 1, 2));
      final s = {'dataInicioSugerida': ini, 'dataFinalizacaoReal': fim};
      expect(tab.duracaoFromSolic(s), '2 dias');
    });

    test('17️⃣ arredonda corretamente duração longa', () {
      final ini = Timestamp.fromDate(DateTime(2025, 1, 1));
      final fim = Timestamp.fromDate(DateTime(2025, 1, 31));
      final s = {'dataInicioSugerida': ini, 'dataFinalPrevista': fim};
      expect(tab.duracaoFromSolic(s), '31 dias');
    });
  });

  group('📦 marcarAvaliadaSeNecessario()', () {
    late FakeFirebaseFirestore fake;

    setUp(() async {
      fake = FakeFirebaseFirestore();
    });

    test('18️⃣ não faz nada com solicitacaoId vazio', () async {
      await tab.marcarAvaliadaSeNecessario(
        solicitacaoId: '',
        clienteUid: 'cli123',
        nota: 5,
        comentario: 'ótimo',
        firestore: fake,
      );
      expect(true, isTrue);
    });

    test('19️⃣ não altera se documento não existe', () async {
      await tab.marcarAvaliadaSeNecessario(
        solicitacaoId: 'inexistente',
        clienteUid: 'cli123',
        nota: 5,
        comentario: 'bom',
        firestore: fake,
      );
      final snap = await fake.collection('solicitacoesOrcamento').get();
      expect(snap.docs, isEmpty);
    });

    test('20️⃣ atualiza status se for finalizada', () async {
      final doc = await fake.collection('solicitacoesOrcamento').add({
        'status': 'finalizada',
      });
      await tab.marcarAvaliadaSeNecessario(
        solicitacaoId: doc.id,
        clienteUid: 'cli123',
        nota: 4.5,
        comentario: 'show',
        firestore: fake,
      );
      final updated = await fake.collection('solicitacoesOrcamento').doc(doc.id).get();
      expect(updated['status'], 'avaliada');
    });

    test('21️⃣ cria histórico dentro da subcoleção', () async {
      final doc = await fake.collection('solicitacoesOrcamento').add({
        'status': 'finalizada',
      });
      await tab.marcarAvaliadaSeNecessario(
        solicitacaoId: doc.id,
        clienteUid: 'cliXYZ',
        nota: 4,
        comentario: 'bom serviço',
        firestore: fake,
      );
      final historico = await fake
          .collection('solicitacoesOrcamento')
          .doc(doc.id)
          .collection('historico')
          .get();
      expect(historico.docs.length, 1);
      expect(historico.docs.first['tipo'], 'avaliada_cliente');
    });

    test('22️⃣ ignora se status não é finalizada', () async {
      final doc = await fake.collection('solicitacoesOrcamento').add({
        'status': 'andamento',
      });
      await tab.marcarAvaliadaSeNecessario(
        solicitacaoId: doc.id,
        clienteUid: 'cli123',
        nota: 3,
        comentario: 'meh',
        firestore: fake,
      );
      final snap = await fake.collection('solicitacoesOrcamento').doc(doc.id).get();
      expect(snap['status'], 'andamento');
    });

    test('23️⃣ adiciona campos corretos no histórico', () async {
      final doc = await fake.collection('solicitacoesOrcamento').add({'status': 'finalizada'});
      await tab.marcarAvaliadaSeNecessario(
        solicitacaoId: doc.id,
        clienteUid: 'u123',
        nota: 5,
        comentario: 'perfeito',
        firestore: fake,
      );
      final hist = await fake
          .collection('solicitacoesOrcamento')
          .doc(doc.id)
          .collection('historico')
          .get();
      final data = hist.docs.first.data();
      expect(data['porUid'], 'u123');
      expect(data['porRole'], 'Cliente');
      expect(data['mensagem'], contains('avaliou'));
    });
  });

  group('⭐ StarsReadOnly', () {
    testWidgets('24️⃣ mostra 5 ícones sempre', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 3)));
      expect(find.byType(Icon), findsNWidgets(5));
    });

    testWidgets('25️⃣ rating 0 mostra todas vazias', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 0)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.where((i) => i.icon == Icons.star_border).length, 5);
    });

    testWidgets('26️⃣ rating 5 mostra todas cheias', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 5)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.where((i) => i.icon == Icons.star).length, 5);
    });

    testWidgets('27️⃣ rating 3 mostra 3 cheias e 2 vazias', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 3)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      final full = icons.where((i) => i.icon == Icons.star).length;
      final empty = icons.where((i) => i.icon == Icons.star_border).length;
      expect(full, 3);
      expect(empty, 2);
    });

    testWidgets('28️⃣ rating fracionado 2.5 arredonda corretamente', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 2.5)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      final full = icons.where((i) => i.icon == Icons.star).length;
      expect(full, 2);
    });

    testWidgets('29️⃣ rating negativo trata como 0', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: -3)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.where((i) => i.icon == Icons.star).isEmpty, true);
    });

    testWidgets('30️⃣ rating >5 mantém máximo 5 cheias', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 10)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.where((i) => i.icon == Icons.star).length, 5);
    });

    testWidgets('31️⃣ widget renderiza sem erros com rating nulo', (tester) async {
      await tester.pumpWidget(MaterialApp(home: StarsReadOnly(rating: 0)));
      expect(find.byType(StarsReadOnly), findsOneWidget);
    });

    testWidgets('32️⃣ possui cor amarela padrão', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 4)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.first.color, const Color(0xFFFFC107));
    });

    testWidgets('33️⃣ tamanho dos ícones é 18', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StarsReadOnly(rating: 4)));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.first.size, 18);
    });
  });
}
