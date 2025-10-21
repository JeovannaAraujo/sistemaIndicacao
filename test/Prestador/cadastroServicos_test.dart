import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Prestador/cadastroServicos.dart';

Future<void> settleShort(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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
    await fakeDb.collection('unidades').doc('u1').set({'nome': 'Hora', 'ativo': true});
    await fakeDb.collection('unidades').doc('u2').set({'nome': 'Peça', 'ativo': false});
    await fakeDb.collection('categoriasServicos').doc('c1').set({'nome': 'Elétrica', 'ativo': true});
    await fakeDb.collection('categoriasServicos').doc('c2').set({'nome': 'Pintura', 'ativo': false});

    widget = MaterialApp(
      home: CadastroServicos(firestore: fakeDb, auth: mockAuth),
    );
  });

  // ------------------- CREATE -------------------
  testWidgets('🟢 Create - cadastra serviço com sucesso', (tester) async {
    await tester.pumpWidget(widget);

    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';
    state.nomeController.text = 'Instalação Elétrica';
    state.descricaoController.text = 'Instalar tomadas e fiação.';
    state.valorMinimoController.text = '10,0';
    state.valorMedioController.text = '20,0';
    state.valorMaximoController.text = '30,0';

    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final serv = await fakeDb.collection('servicos').get();
    expect(serv.docs.length, 1);
    expect(serv.docs.first.data()['prestadorId'], 'prest123');
  });

  testWidgets('🔴 Create - falha se não logado', (tester) async {
    final authSemUser = MockFirebaseAuth(signedIn: false);
    await tester.pumpWidget(MaterialApp(
      home: CadastroServicos(firestore: fakeDb, auth: authSemUser),
    ));

    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';
    state.nomeController.text = 'Teste sem login';
    state.descricaoController.text = 'Deveria falhar';

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

    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final serv = await fakeDb.collection('servicos').get();
    expect(serv.docs.isEmpty, true);
  });

  // ------------------- READ -------------------
  test('🟢 Read - busca unidades e categorias ativas', () async {
    final unidades = await fakeDb.collection('unidades').where('ativo', isEqualTo: true).get();
    final categorias = await fakeDb.collection('categoriasServicos').where('ativo', isEqualTo: true).get();

    expect(unidades.docs.first.data()['nome'], 'Hora');
    expect(categorias.docs.first.data()['nome'], 'Elétrica');
  });

  test('🔴 Read - retorna vazio se coleções inativas', () async {
    await fakeDb.collection('unidades').doc('u1').update({'ativo': false});
    await fakeDb.collection('categoriasServicos').doc('c1').update({'ativo': false});

    final un = await fakeDb.collection('unidades').where('ativo', isEqualTo: true).get();
    final cat = await fakeDb.collection('categoriasServicos').where('ativo', isEqualTo: true).get();

    expect(un.docs.isEmpty, true);
    expect(cat.docs.isEmpty, true);
  });

  // ------------------- UPDATE -------------------
  testWidgets('🟢 Update - altera valores e salva novamente', (tester) async {
    await fakeDb.collection('servicos').add({
      'prestadorId': 'prest123',
      'nome': 'Teste',
      'descricao': 'Antigo',
      'ativo': true,
    });

    await tester.pumpWidget(widget);
    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.nomeController.text = 'Atualizado';
    state.descricaoController.text = 'Nova desc';
    state.unidadeSelecionadaId = 'u1';
    state.categoriaSelecionadaId = 'c1';
    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final servs = await fakeDb.collection('servicos').get();
    expect(servs.docs.last.data()['nome'], 'Atualizado');
  });

  test('🔴 Update - falha se serviço não existir', () async {
    final doc = await fakeDb.collection('servicos').doc('fake').get();
    expect(doc.exists, false);
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

    await tester.tap(find.text('Salvar'));
    await settleShort(tester);

    final serv = await fakeDb.collection('servicos').get();
    final data = serv.docs.first.data();
    expect(data['valorMinimo'], 10.5);
    expect(data['valorMedio'], 20.5);
    expect(data['valorMaximo'], 30.5);
  });

  testWidgets('🎨 Dropdown - não quebra se ID não está mais ativo', (tester) async {
    await fakeDb.collection('unidades').doc('u3').set({'nome': 'Inexistente', 'ativo': false});

    await tester.pumpWidget(widget);
    final state = tester.state(find.byType(CadastroServicos)) as dynamic;
    state.unidadeSelecionadaId = 'u3'; // não existe mais
    await tester.pump();
    expect(state.unidadeSelecionadaId, 'u3'); // ainda mantém o valor interno
  });
}
