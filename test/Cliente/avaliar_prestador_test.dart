import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:myapp/Cliente/avaliar_prestador.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockFirebaseStorage storage;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'cliente123'),
    );
    storage = MockFirebaseStorage();
  });

  group('🧪 Testes da tela AvaliarPrestadorScreen', () {
    testWidgets('1️⃣ Renderiza título e botões principais', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoTitulo': 'Limpeza de Piscina',
        'prestadorNome': 'João Silva',
        'clienteEndereco': {'rua': 'Rua das Flores'},
        'valorProposto': 150.0,
        'prestadorId': 'prestador123',
        'servicoId': 'servico123',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Avaliar Serviço'), findsOneWidget);
      expect(find.text('Enviar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('5️⃣ Envia avaliação e atualiza Firestore', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'prestadorId': 'prestador123',
        'servicoId': 'serv001',
        'servicoTitulo': 'Instalação elétrica',
        'prestadorNome': 'João Silva',
        'clienteEndereco': {'rua': 'Rua Teste'},
        'valorProposto': 100.0,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.star_border).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Excelente serviço!');
      await tester.pumpAndSettle();

      // ✅ Força rolagem até o botão
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar'), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final avaliacoes = await firestore.collection('avaliacoes').get();
      expect(avaliacoes.docs, hasLength(1));
    });

    testWidgets('8️⃣ Cancelar retorna à tela anterior', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoTitulo': 'Teste',
        'prestadorId': 'prestador123',
        'servicoId': 'servico123',
      });

      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            // ignore: deprecated_member_use
            onPopPage: (route, result) {
              popped = true;
              return route.didPop(result);
            },
            pages: [
              MaterialPage(
                child: AvaliarPrestadorScreen(
                  solicitacaoId: 'sol1',
                  firestore: firestore,
                  auth: auth,
                  storage: storage,
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(popped, true);
    });

    testWidgets('9️⃣ Envia avaliação chamando método diretamente', (
      tester,
    ) async {
      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'prestadorId': 'prestador123',
        'servicoId': 'serv001',
        'servicoTitulo': 'Teste Direto',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state =
          tester.state(find.byType(AvaliarPrestadorScreen)) as dynamic;
      state.nota = 4.0;
      state.comentarioCtrl.text = 'Comentário teste';

      await state.enviarAvaliacao();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final avaliacoes = await firestore.collection('avaliacoes').get();
      expect(avaliacoes.docs, hasLength(1));
    });

    testWidgets('2️⃣ Serviço inexistente exibe mensagem', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'inexistente',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Serviço não encontrado.'), findsOneWidget);
    });

    testWidgets('3️⃣ Clicar em estrela altera a nota', (tester) async {
      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoTitulo': 'Teste',
        'prestadorId': 'prestador123',
        'servicoId': 'servico123',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final estrelaVazia = find.byIcon(Icons.star_border).first;
      await tester.tap(estrelaVazia);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('4️⃣ Mostra Snackbar se tentar enviar sem nota', (
      tester,
    ) async {
      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoTitulo': 'Teste',
        'prestadorId': 'prestador123',
        'servicoId': 'servico123',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final enviarButton = find.text('Enviar');
      await tester.ensureVisible(enviarButton);
      await tester.tap(enviarButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Selecione uma nota antes de enviar.'), findsOneWidget);
    });

    testWidgets('6️⃣ Gerencia lista de imagens localmente', (tester) async {
      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoTitulo': 'Teste',
        'prestadorId': 'prestador123',
        'servicoId': 'servico123',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state =
          tester.state(find.byType(AvaliarPrestadorScreen)) as dynamic;
      state.imagens = [File('test/image1.jpg'), File('test/image2.jpg')];
      await tester.pump();
      expect(state.imagens, hasLength(2));

      state.removerImagem(0);
      await tester.pump();
      expect(state.imagens, hasLength(1));
    });

    testWidgets('7️⃣ Upload de imagens funciona com storage mock', (
      tester,
    ) async {
      await firestore.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoTitulo': 'Teste',
        'prestadorId': 'prestador123',
        'servicoId': 'servico123',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AvaliarPrestadorScreen(
            solicitacaoId: 'sol1',
            firestore: firestore,
            auth: auth,
            storage: storage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state =
          tester.state(find.byType(AvaliarPrestadorScreen)) as dynamic;

      final urlsVazias = await state.uploadImagens('cliente123');
      expect(urlsVazias, isEmpty);

      state.imagens = [File('test/image1.jpg')];
      final urls = await state.uploadImagens('cliente123');
      expect(urls, isA<List<String>>());
      expect(urls, hasLength(1));
    });
  });
}
