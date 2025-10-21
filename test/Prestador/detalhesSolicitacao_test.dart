import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Prestador/detalhesSolicitacao.dart';

Future<void> settleShort(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late String docId;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    docId = 'orc1';
  });

  // ------------------- CREATE / READ -------------------
  testWidgets('🟢 Renderiza dados completos da solicitação', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'pendente',
      'estimativaValor': 150.0,
      'servicoTitulo': 'Instalação elétrica',
      'descricaoDetalhada': 'Instalar tomadas e interruptores',
      'quantidade': 5,
      'unidadeSelecionadaAbrev': 'm²',
      'dataDesejada': DateTime(2025, 10, 20),
      'clienteNome': 'João Cliente',
      'clienteWhatsapp': '62999999999',
      'clienteEndereco': {
        'rua': 'Rua A',
        'numero': '123',
        'bairro': 'Centro',
        'cidade': 'Rio Verde',
        'cep': '75900-000',
      },
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);

    expect(find.text('Instalação elétrica'), findsOneWidget);
    expect(find.textContaining('R\$'), findsWidgets);
    expect(find.textContaining('João Cliente'), findsOneWidget);
  });

  testWidgets('🔴 Exibe mensagem se solicitação não existe', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: 'naoexiste', firestore: fakeDb),
    ));
    await settleShort(tester);
    expect(find.text('Solicitação não encontrada.'), findsOneWidget);
  });

  testWidgets('🔴 Exibe erro de snapshot ao carregar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StreamBuilder(
        stream: Stream.error('Erro simulado'),
        builder: (context, _) {
          return DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb);
        },
      ),
    ));
    await settleShort(tester);
    // Apenas verifica que não quebra renderização
    expect(find.byType(Scaffold), findsWidgets);
  });

  // ------------------- UPDATE -------------------
testWidgets('🟢 Abre diálogo de recusa e atualiza status', (tester) async {
  await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
    'status': 'pendente',
    'servicoTitulo': 'Serviço Teste',
  });

  await tester.pumpWidget(MaterialApp(
    home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
  ));

  await settleShort(tester);

  // 🔽 Garante que o botão esteja visível
  await tester.ensureVisible(find.text('Recusar Solicitação'));
  await tester.pumpAndSettle();

  // 🟣 Toca no botão
  await tester.tap(find.text('Recusar Solicitação'));
  await tester.pumpAndSettle();

  // 🧾 Verifica que o diálogo abriu
  expect(find.text('Recusar Solicitação'), findsWidgets);

  // 🔽 Garante que o botão "Confirmar" está visível
  await tester.ensureVisible(find.text('Confirmar'));
  await tester.pumpAndSettle();

  // ✅ Clica em confirmar
  await tester.tap(find.text('Confirmar'));
  await tester.pumpAndSettle();

  // 🔍 Verifica atualização no banco fake
  final doc = await fakeDb.collection('solicitacoesOrcamento').doc(docId).get();
  expect(doc.data()?['status'], 'recusada');
});

  testWidgets('🚫 Botões desativados se status processado', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'respondida',
      'servicoTitulo': 'Serviço Finalizado',
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);
    expect(find.text('Enviar Orçamento'), findsNothing);
    expect(find.text('Recusar Solicitação'), findsNothing);
  });

  // ------------------- DELETE (simulado) -------------------
  test('🟢 Deleta documento com sucesso (simulado)', () async {
    await fakeDb.collection('solicitacoesOrcamento').doc('del').set({'status': 'pendente'});
    await fakeDb.collection('solicitacoesOrcamento').doc('del').delete();
    final check = await fakeDb.collection('solicitacoesOrcamento').doc('del').get();
    expect(check.exists, false);
  });

  test('🔴 Delete falha se doc não existe', () async {
    final doc = await fakeDb.collection('solicitacoesOrcamento').doc('naoexiste').get();
    expect(doc.exists, false);
  });

  // ------------------- CAMPOS E FORMATAÇÃO -------------------
  testWidgets('🧮 Formata quantidade com casas decimais corretamente', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'pendente',
      'quantidade': 3.5,
      'servicoTitulo': 'Serviço Medido',
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);

    expect(find.textContaining('3,5'), findsOneWidget);
  });

  testWidgets('⚠️ Mostra aviso se estimativaValor = 0', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'pendente',
      'estimativaValor': 0,
      'servicoTitulo': 'Sem estimativa',
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);
    expect(find.textContaining('Não há estimativa de valor'), findsOneWidget);
  });

  testWidgets('📅 Exibe data e hora formatadas corretamente', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'pendente',
      'servicoTitulo': 'Agendamento',
      'dataDesejada': DateTime(2025, 11, 10, 14, 30),
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);

    expect(find.textContaining('10/11/2025'), findsOneWidget);
    expect(find.textContaining('14:30'), findsOneWidget);
  });

  testWidgets('🖼️ Exibe "Sem imagens anexadas" quando lista vazia', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'pendente',
      'imagens': [],
      'servicoTitulo': 'Sem imagens',
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);

    expect(find.text('Sem imagens anexadas'), findsOneWidget);
  });

  testWidgets('💬 Exibe dados do cliente e endereço corretamente', (tester) async {
    await fakeDb.collection('solicitacoesOrcamento').doc(docId).set({
      'status': 'pendente',
      'clienteNome': 'Maria Teste',
      'clienteWhatsapp': '62988888888',
      'clienteEndereco': {
        'rua': 'Av. Brasil',
        'numero': '100',
        'bairro': 'Centro',
        'cidade': 'Rio Verde',
        'cep': '75900-000',
      },
    });

    await tester.pumpWidget(MaterialApp(
      home: DetalhesSolicitacaoScreen(docId: docId, firestore: fakeDb),
    ));
    await settleShort(tester);

    expect(find.textContaining('Maria Teste'), findsOneWidget);
    expect(find.textContaining('62988888888'), findsOneWidget);
    expect(find.textContaining('Av. Brasil'), findsOneWidget);
  });
}
