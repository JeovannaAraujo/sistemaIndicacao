import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Prestador/editarServico.dart';

// 🔁 Função auxiliar para evitar travamento com streams infinitas
Future<void> settleShort(WidgetTester tester, [int maxMs = 2000]) async {
  final end = DateTime.now().add(Duration(milliseconds: maxMs));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.any(find.byType(CircularProgressIndicator))) break;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  const servicoId = 'serv001';

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();

    // Cria dados iniciais simulados
    await fakeDb.collection('unidades').doc('uni1').set({
      'nome': 'Hora',
      'ativo': true,
    });

    await fakeDb.collection('categoriasServicos').doc('cat1').set({
      'nome': 'Elétrica',
      'ativo': true,
    });

    await fakeDb.collection('servicos').doc(servicoId).set({
      'nome': 'Instalação de tomadas',
      'descricao': 'Serviço de instalação elétrica residencial',
      'valorMinimo': 50,
      'valorMedio': 75,
      'valorMaximo': 100,
      'ativo': true,
      'categoriaId': 'cat1',
      'unidadeId': 'uni1',
    });
  });

  // ============================================================
  testWidgets('🟢 Carrega dados e exibe informações do serviço', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditarServico(
          serviceId: servicoId,
          firestore: fakeDb,
        ),
      ),
    );

    await settleShort(tester);

    expect(find.text('Instalação de tomadas'), findsWidgets);
    expect(find.text('Serviço de instalação elétrica residencial'), findsWidgets);
  });

  // ============================================================
  testWidgets('⚠️ Mostra erro se categoria estiver inativa', (tester) async {
    // Desativa categoria
    await fakeDb.collection('categoriasServicos').doc('cat1').update({'ativo': false});

    await tester.pumpWidget(
      MaterialApp(
        home: EditarServico(
          serviceId: servicoId,
          firestore: fakeDb,
        ),
      ),
    );

    await settleShort(tester);

    // Tenta salvar
    final salvar = find.text('Salvar alterações');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('não está mais ativa'), findsOneWidget);
  });

  // ============================================================
  testWidgets('⚠️ Mostra erro se unidade estiver inativa', (tester) async {
    // Reativa categoria
    await fakeDb.collection('categoriasServicos').doc('cat1').update({'ativo': true});
    // Desativa unidade
    await fakeDb.collection('unidades').doc('uni1').update({'ativo': false});

    await tester.pumpWidget(
      MaterialApp(
        home: EditarServico(
          serviceId: servicoId,
          firestore: fakeDb,
        ),
      ),
    );

    await settleShort(tester);

    final salvar = find.text('Salvar alterações');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('unidade selecionada não está mais ativa'), findsOneWidget);
  });

  // ============================================================
  testWidgets('🟣 Atualiza nome e salva com sucesso', (tester) async {
    await fakeDb.collection('unidades').doc('uni1').update({'ativo': true});

    await tester.pumpWidget(
      MaterialApp(
        home: EditarServico(
          serviceId: servicoId,
          firestore: fakeDb,
        ),
      ),
    );

    await settleShort(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Troca de fiação');
    final salvar = find.text('Salvar alterações');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));

    final doc = await fakeDb.collection('servicos').doc(servicoId).get();
    expect(doc.data()?['nome'], 'Troca de fiação');
  });

  // ============================================================
  testWidgets('🗑️ Exclui serviço com sucesso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditarServico(
          serviceId: servicoId,
          firestore: fakeDb,
        ),
      ),
    );

    await settleShort(tester);

    final excluirIcone = find.byTooltip('Excluir serviço');
    await tester.tap(excluirIcone, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    // Confirma no diálogo
    final confirmar = find.text('Excluir');
    expect(confirmar, findsOneWidget);
    await tester.tap(confirmar, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));

    final doc = await fakeDb.collection('servicos').doc(servicoId).get();
    expect(doc.exists, isFalse);
  });

  // ============================================================
  testWidgets('↩️ Botão Cancelar retorna à tela anterior', (tester) async {
    bool saiuDaTela = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onPopPage: (route, result) {
            saiuDaTela = true;
            return route.didPop(result);
          },
          pages: [
            const MaterialPage(child: SizedBox()),
            MaterialPage(
              child: EditarServico(
                serviceId: servicoId,
                firestore: fakeDb,
              ),
            ),
          ],
        ),
      ),
    );

    await settleShort(tester);

    final cancelar = find.text('Cancelar');
    await tester.ensureVisible(cancelar);
    await tester.tap(cancelar, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));

    expect(saiuDaTela, isTrue);
  });
}
