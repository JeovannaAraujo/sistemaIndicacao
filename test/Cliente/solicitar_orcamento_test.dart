import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/Cliente/solicitar_orcamento.dart';

Future<void> settleShort(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseStorage mockStorage;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'cliente123', email: 'cli@teste.com'),
    );
    mockStorage = MockFirebaseStorage();

    // 🔹 Usuário (cliente)
    await fakeDb.collection('usuarios').doc('cliente123').set({
      'nome': 'Maria Cliente',
      'endereco': {
        'rua': 'Rua A',
        'numero': '10',
        'cidade': 'Rio Verde',
        'whatsapp': '62999999999',
      },
    });

    // 🔹 Prestador
    await fakeDb.collection('usuarios').doc('prest123').set({
      'nome': 'João Prestador',
      'endereco': {'cidade': 'Rio Verde', 'uf': 'GO'},
    });

    // 🔹 Unidade
    await fakeDb.collection('unidades').doc('u1').set({'abreviacao': 'm²'});

    // 🔹 Serviço
    await fakeDb.collection('servicos').doc('serv123').set({
      'titulo': 'Pintura de parede',
      'descricao': 'Pintar 3 cômodos',
      'valorMedio': 50.0,
      'unidadeId': 'u1',
      'unidadeAbreviacao': 'm²',
      'categoriaServicoId': 'cat1',
    });

    // 🔹 Categoria do serviço
    await fakeDb.collection('categoriasServicos').doc('cat1').set({
      'imagemUrl': 'https://fake.com/img.png',
    });
  });

  group('🧮 Funções auxiliares', () {
    testWidgets('1️⃣ parseValor converte strings corretamente', (tester) async {
      final state =
          SolicitarOrcamentoScreen(
                prestadorId: 'prest123',
                servicoId: 'serv123',
                firestore: fakeDb,
                auth: mockAuth,
                storage: MockFirebaseStorage(), // ✅ mock isolado
              ).createState()
              as SolicitarOrcamentoScreenState;

      expect(state.parseValor('R\$ 120,50'), 120.5);
      expect(state.parseValor('250'), 250);
      expect(state.parseValor(80.5), 80.5);
      expect(state.parseValor(null), null);
    });

    testWidgets('2️⃣ formatEndereco concatena corretamente', (tester) async {
      final state =
          SolicitarOrcamentoScreen(
                prestadorId: 'prest123',
                servicoId: 'serv123',
                firestore: fakeDb,
                auth: mockAuth,
                storage: mockStorage,
              ).createState()
              as SolicitarOrcamentoScreenState;

      final txt = state.formatEndereco({
        'rua': 'Rua A',
        'numero': '10',
        'bairro': 'Centro',
        'cep': '75900-000',
        'cidade': 'Rio Verde',
      });
      expect(txt.contains('Rua A, Nº 10'), true);
      expect(txt.contains('Centro'), true);
      expect(txt.contains('CEP 75900-000'), true);
      expect(txt.contains('Rio Verde'), true);
    });
  });

  group('📈 Estimativa de Valor', () {
    testWidgets('3️⃣ Retorna valor correto conforme quantidade e média', (
      tester,
    ) async {
      final state =
          SolicitarOrcamentoScreen(
                prestadorId: 'prest123',
                servicoId: 'serv123',
                firestore: fakeDb,
                auth: mockAuth,
                storage: mockStorage,
              ).createState()
              as SolicitarOrcamentoScreenState;

      state.valorMedio = 50.0;
      state.quantCtl.text = '2';
      state.docServico = await fakeDb
          .collection('servicos')
          .doc('serv123')
          .get();
      state.selectedUnidadeId = 'u1';

      expect(state.estimativaValor, 100.0);
    });

    testWidgets('4️⃣ Retorna null se unidade diferente', (tester) async {
      final state =
          SolicitarOrcamentoScreen(
                prestadorId: 'prest123',
                servicoId: 'serv123',
                firestore: fakeDb,
                auth: mockAuth,
                storage: mockStorage,
              ).createState()
              as SolicitarOrcamentoScreenState;

      state.valorMedio = 50.0;
      state.quantCtl.text = '3';
      state.docServico = await fakeDb
          .collection('servicos')
          .doc('serv123')
          .get();
      state.selectedUnidadeId = 'outra';

      expect(state.estimativaValor, null);
    });
  });

  group('📤 Envio da solicitação', () {
    testWidgets('5️⃣ Cria solicitação no Firestore com sucesso', (
      tester,
    ) async {
      final screen = SolicitarOrcamentoScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        firestore: fakeDb,
        auth: mockAuth,
        storage: mockStorage,
      );

      await tester.pumpWidget(MaterialApp(home: screen));
      await settleShort(tester);

      final state =
          tester.state(find.byType(SolicitarOrcamentoScreen))
              as SolicitarOrcamentoScreenState;

      state.docServico = await fakeDb
          .collection('servicos')
          .doc('serv123')
          .get();
      state.docPrestador = await fakeDb
          .collection('usuarios')
          .doc('prest123')
          .get();
      state.docCliente = await fakeDb
          .collection('usuarios')
          .doc('cliente123')
          .get();

      state.quantCtl.text = '5';
      state.descricaoCtl.text = 'Pintura interna da casa';
      state.selectedUnidadeId = 'u1';
      state.valorMedio = 50.0;

      await state.enviar();

      final docs = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(docs.docs.isNotEmpty, true);
      expect(
        docs.docs.first.data()['descricaoDetalhada'],
        'Pintura interna da casa',
      );
      expect(docs.docs.first.data()['status'], 'pendente');
    });

    testWidgets('6️⃣ Não envia se formulário inválido', (tester) async {
      final screen = SolicitarOrcamentoScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        firestore: fakeDb,
        auth: mockAuth,
        storage: mockStorage,
      );

      await tester.pumpWidget(MaterialApp(home: screen));
      await settleShort(tester);

      final state =
          tester.state(find.byType(SolicitarOrcamentoScreen))
              as SolicitarOrcamentoScreenState;

      state.docServico = await fakeDb
          .collection('servicos')
          .doc('serv123')
          .get();
      state.docPrestador = await fakeDb
          .collection('usuarios')
          .doc('prest123')
          .get();
      state.docCliente = await fakeDb
          .collection('usuarios')
          .doc('cliente123')
          .get();

      state.descricaoCtl.text = '';
      state.quantCtl.text = '';

      await state.enviar();
      final snap = await fakeDb.collection('solicitacoesOrcamento').get();
      expect(snap.docs.isEmpty, true);
    });
  });

  group('🖼️ Upload e imagens', () {
    testWidgets('7️⃣ Remove imagem corretamente', (tester) async {
      final screen = SolicitarOrcamentoScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        firestore: fakeDb,
        auth: mockAuth,
        storage: mockStorage,
      );

      await tester.pumpWidget(MaterialApp(home: screen));
      await settleShort(tester);

      final state =
          tester.state(find.byType(SolicitarOrcamentoScreen))
              as SolicitarOrcamentoScreenState;

      final fakeImg = XFile('fake1.jpg');
      state.imagens.add(fakeImg);
      state.removeImage(fakeImg);
      expect(state.imagens.contains(fakeImg), false);
    });

    testWidgets('8️⃣ Simula upload e retorna URLs fake', (tester) async {
      final screen = SolicitarOrcamentoScreen(
        prestadorId: 'prest123',
        servicoId: 'serv123',
        firestore: fakeDb,
        auth: mockAuth,
        storage: mockStorage,
      );

      await tester.pumpWidget(MaterialApp(home: screen));
      await settleShort(tester);

      final state =
          tester.state(find.byType(SolicitarOrcamentoScreen))
              as SolicitarOrcamentoScreenState;

      // 🔧 Correção: Adicione um XFile com caminho fake (sem criar arquivo real)
      // O método uploadImagens detecta MockFirebaseStorage e não usa o arquivo
      state.imagens.add(XFile('/fake/path/temp.jpg'));

      final urls = await state.uploadImagens('solTest');
      expect(urls, isA<List<String>>());
      expect(urls.first.contains('fake.storage'), true);
    });
  });

  group('🎨 Interface', () {
    testWidgets('9️⃣ Renderiza estrutura básica da tela', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SolicitarOrcamentoScreen(
            prestadorId: 'prest123',
            servicoId: 'serv123',
            firestore: fakeDb,
            auth: mockAuth,
            storage: mockStorage,
          ),
        ),
      );
      await settleShort(tester);
      expect(find.textContaining('Solicitação de Orçamento'), findsOneWidget);
    });
  });
}
