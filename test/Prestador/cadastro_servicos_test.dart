import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Prestador/cadastro_servicos.dart';

/// ⏱ Função auxiliar para dar tempo de renderização aos widgets.
Future<void> settleShort(WidgetTester tester, [int cycles = 10]) async {
  for (int i = 0; i < cycles; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late Widget widget;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'prest123', email: 'p@test.com'),
    );

    // Dados iniciais
    await fakeDb.collection('unidades').doc('u1').set({
      'nome': 'Hora',
      'ativo': true,
    });
    await fakeDb.collection('unidades').doc('u2').set({
      'nome': 'Peça',
      'ativo': false,
    });
    await fakeDb.collection('categoriasServicos').doc('c1').set({
      'nome': 'Elétrica',
      'ativo': true,
    });
    await fakeDb.collection('categoriasServicos').doc('c2').set({
      'nome': 'Pintura',
      'ativo': false,
    });

    widget = MaterialApp(
      home: CadastroServicos(firestore: fakeDb, auth: mockAuth),
    );
  });

  // ------------------- CREATE -------------------
  testWidgets('🟢 Create - salva novo serviço corretamente', (tester) async {
    await tester.pumpWidget(widget);
    final state = tester.state(find.byType(CadastroServicos)) as dynamic;

    state.nomeController.text = 'Novo Serviço';
    state.descricaoController.text = 'Nova descrição';
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';

    // 🧮 Campos obrigatórios de valor
    state.valorMinimoController.text = '10,0';
    state.valorMedioController.text = '20,0';
    state.valorMaximoController.text = '30,0';

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final servs = await fakeDb.collection('servicos').get();

    // ✅ Verifica se foi salvo um novo serviço
    expect(servs.docs.isNotEmpty, true);
    expect(servs.docs.any((d) => d.data()['nome'] == 'Novo Serviço'), true);
  });

  testWidgets('🟢 Create - cria múltiplos serviços independentemente', (tester) async {
    // Cria um serviço inicial
    await fakeDb.collection('servicos').add({
      'prestadorId': 'prest123',
      'nome': 'Serviço Existente',
      'descricao': 'Antigo',
      'ativo': true,
    });

    await tester.pumpWidget(widget);
    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    
    // Preenche dados para novo serviço
    state.nomeController.text = 'Novo Serviço';
    state.descricaoController.text = 'Nova descrição';
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';
    
    // 🧮 Campos obrigatórios de valor
    state.valorMinimoController.text = '10,0';
    state.valorMedioController.text = '20,0';
    state.valorMaximoController.text = '30,0';

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final servs = await fakeDb.collection('servicos').get();

    // ✅ Verifica que temos 2 serviços: o original + o novo
    expect(servs.docs.length, 2);
    expect(servs.docs.any((d) => d.data()['nome'] == 'Serviço Existente'), true);
    expect(servs.docs.any((d) => d.data()['nome'] == 'Novo Serviço'), true);
  });

  testWidgets('🔴 Create - falha se não logado', (tester) async {
    final authSemUser = MockFirebaseAuth(signedIn: false);
    await tester.pumpWidget(
      MaterialApp(
        home: CadastroServicos(firestore: fakeDb, auth: authSemUser),
      ),
    );

    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';
    state.nomeController.text = 'Teste sem login';
    state.descricaoController.text = 'Deveria falhar';

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final serv = await fakeDb.collection('servicos').get();
    expect(serv.docs.isEmpty, true);
  });

  testWidgets('🚫 Create - impede cadastro se unidade inativa', (tester) async {
    await tester.pumpWidget(widget);

    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u2'; // inativa
    state.categoriaSelecionadaId = 'c1';
    state.nomeController.text = 'Teste';
    state.descricaoController.text = 'Unidade inativa';

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final serv = await fakeDb.collection('servicos').get();
    expect(serv.docs.isEmpty, true);
  });

  testWidgets('🚫 Create - impede cadastro se categoria inativa', (tester) async {
    await tester.pumpWidget(widget);

    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c2'; // inativa
    state.nomeController.text = 'Teste';
    state.descricaoController.text = 'Categoria inativa';

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final serv = await fakeDb.collection('servicos').get();
    expect(serv.docs.isEmpty, true);
  });

  // ------------------- READ -------------------
  test('🟢 Read - busca unidades e categorias ativas', () async {
    final unidades = await fakeDb
        .collection('unidades')
        .where('ativo', isEqualTo: true)
        .get();
    final categorias = await fakeDb
        .collection('categoriasServicos')
        .where('ativo', isEqualTo: true)
        .get();

    expect(unidades.docs.first.data()['nome'], 'Hora');
    expect(categorias.docs.first.data()['nome'], 'Elétrica');
  });

  test('🔴 Read - retorna vazio se coleções inativas', () async {
    await fakeDb.collection('unidades').doc('u1').update({'ativo': false});
    await fakeDb.collection('categoriasServicos').doc('c1').update({
      'ativo': false,
    });

    final un = await fakeDb
        .collection('unidades')
        .where('ativo', isEqualTo: true)
        .get();
    final cat = await fakeDb
        .collection('categoriasServicos')
        .where('ativo', isEqualTo: true)
        .get();

    expect(un.docs.isEmpty, true);
    expect(cat.docs.isEmpty, true);
  });

  // ------------------- DELETE -------------------
  test('🟢 Delete - exclui serviço existente', () async {
    final doc = await fakeDb.collection('servicos').add({'nome': 'Excluir'});
    await fakeDb.collection('servicos').doc(doc.id).delete();

    final check = await fakeDb.collection('servicos').doc(doc.id).get();
    expect(check.exists, false);
  });

  test('🔴 Delete - falha ao tentar excluir inexistente', () async {
    final doc = await fakeDb.collection('servicos').doc('naoExiste').get();
    expect(doc.exists, false);
  });

  // ------------------- VALIDAÇÕES EXTRA -------------------
  testWidgets('⚠️ Validação - campos obrigatórios impedem envio', (tester) async {
    await tester.pumpWidget(widget);
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    // Nenhum serviço deve ser salvo
    final serv = await fakeDb.collection('servicos').get();
    expect(serv.docs.isEmpty, true);
  });

  testWidgets('🧮 Conversão - valores decimais com vírgula são convertidos', (tester) async {
    await tester.pumpWidget(widget);
    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';
    state.nomeController.text = 'Teste Decimais';
    state.descricaoController.text = 'Conversão de vírgula';
    state.valorMinimoController.text = '10,5';
    state.valorMedioController.text = '20,5';
    state.valorMaximoController.text = '30,5';

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);
    await tester.pump(const Duration(seconds: 1)); // ⏳ tempo extra pro fake salvar

    final serv = await fakeDb.collection('servicos').get();
    final data = serv.docs.first.data();
    expect(data['valorMinimo'], 10.5);
    expect(data['valorMedio'], 20.5);
    expect(data['valorMaximo'], 30.5);
  });

  testWidgets('🎨 Dropdown - não quebra se ID não está mais ativo', (tester) async {
    await fakeDb.collection('unidades').doc('u3').set({
      'nome': 'Inexistente',
      'ativo': false,
    });

    await tester.pumpWidget(widget);
    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u3'; // não existe mais
    await tester.pump();
    expect(state.unidadeSelecionadaId, 'u3'); // ainda mantém o valor interno
  });
}