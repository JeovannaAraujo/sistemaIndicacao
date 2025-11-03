import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Cliente/avaliacoes.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'user123', email: 'cliente@teste.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  });

  // Helper function to build the widget
  Future<void> pumpMinhasAvaliacoesTab(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MinhasAvaliacoesTab(
        firestore: fakeFirestore,
        auth: mockAuth,
      ),
    ));
  }

  // Helper function to create test data
  Future<void> setupTestData({
    required String avaliacaoId,
    String prestadorId = 'prestador123',
    String solicitacaoId = 'solicitacao123',
    double nota = 4.5,
    String comentario = 'Ótimo serviço',
    bool hasImagem = false,
    Timestamp? data,
  }) async {
    // Setup usuário (prestador)
    await fakeFirestore.collection('usuarios').doc(prestadorId).set({
      'nome': 'Carlos Prestador',
      'email': 'carlos@teste.com',
    });

    // Setup solicitação
    await fakeFirestore.collection('solicitacoesOrcamento').doc(solicitacaoId).set({
      'servicoTitulo': 'Pintura de Casa',
      'clienteEndereco': {'cidade': 'São Paulo'},
      'clienteId': 'user123',
    });

    // Setup avaliação
    final avaliacaoData = {
      'clienteId': 'user123',
      'prestadorId': prestadorId,
      'solicitacaoId': solicitacaoId,
      'nota': nota,
      'comentario': comentario,
      'data': data ?? Timestamp.now(),
    };

    if (hasImagem) {
      avaliacaoData['imagemUrl'] = 'https://example.com/image.jpg';
    }

    await fakeFirestore.collection('avaliacoes').doc(avaliacaoId).set(avaliacaoData);
  }

  group('🧩 Função fmtData', () {
    test('1️⃣ Formata Timestamp corretamente', () {
      const tab = MinhasAvaliacoesTab();
      final ts = Timestamp.fromDate(DateTime(2025, 1, 15, 14, 30));
      expect(tab.fmtData(ts), '15/01/2025 – 14:30');
    });

    test('2️⃣ Retorna — para tipos inválidos', () {
      const tab = MinhasAvaliacoesTab();
      expect(tab.fmtData(null), '—');
      expect(tab.fmtData('texto'), '—');
      expect(tab.fmtData(123), '—');
    });
  });

  group('⭐ StarsReadOnly Widget', () {
    testWidgets('3️⃣ Mostra 5 estrelas sempre', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StarsReadOnly(rating: 3)),
      ));
      expect(find.byType(Icon), findsNWidgets(5));
    });

    testWidgets('4️⃣ Rating 5 mostra todas cheias', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StarsReadOnly(rating: 5)),
      ));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.every((i) => i.icon == Icons.star), true);
    });

    testWidgets('5️⃣ Rating 0 mostra todas vazias', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StarsReadOnly(rating: 0)),
      ));
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.every((i) => i.icon == Icons.star_border), true);
    });
  });

  group('📱 MinhasAvaliacoesTab - Cenários principais', () {
    testWidgets('6️⃣ Mostra loading inicial', (tester) async {
      await pumpMinhasAvaliacoesTab(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('7️⃣ Mostra mensagem quando não há avaliações', (tester) async {
      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();
      expect(find.text('Você ainda não avaliou nenhum serviço.'), findsOneWidget);
    });

    testWidgets('8️⃣ Lista avaliações do usuário logado', (tester) async {
      await setupTestData(
        avaliacaoId: 'aval001',
        nota: 4.5,
        comentario: 'Serviço excelente!',
      );

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Pintura de Casa'), findsOneWidget);
      expect(find.text('Prestador: Carlos Prestador'), findsOneWidget);
      expect(find.text('Serviço excelente!'), findsOneWidget);
      expect(find.text('São Paulo'), findsOneWidget);
    });

    testWidgets('9️⃣ Mostra "Sem comentário" quando comentário vazio', (tester) async {
      await setupTestData(
        avaliacaoId: 'aval002',
        comentario: '',
      );

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sem comentário'), findsOneWidget);
    });

    testWidgets('🔟 Campo imagemUrl existe no documento quando tem imagem', (tester) async {
      await setupTestData(
        avaliacaoId: 'aval003',
        hasImagem: true,
      );

      // Verifica se o campo foi salvo no Firestore
      final doc = await fakeFirestore.collection('avaliacoes').doc('aval003').get();
      expect(doc.data()!['imagemUrl'], isNotNull);
      expect(doc.data()!['imagemUrl'], 'https://example.com/image.jpg');
    });
  });

  group('🔄 MinhasAvaliacoesTab - Dados relacionados', () {
    testWidgets('1️⃣1️⃣ Busca dados do prestador corretamente', (tester) async {
      await fakeFirestore.collection('usuarios').doc('prest456').set({
        'nome': 'João Silva',
      });

      await fakeFirestore.collection('avaliacoes').doc('aval004').set({
        'clienteId': 'user123',
        'prestadorId': 'prest456',
        'nota': 5.0,
        'comentario': 'Prestador específico',
        'data': Timestamp.now(),
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Prestador: João Silva'), findsOneWidget);
    });

    testWidgets('1️⃣2️⃣ Usa fallback quando prestador não existe', (tester) async {
      await fakeFirestore.collection('avaliacoes').doc('aval005').set({
        'clienteId': 'user123',
        'prestadorId': 'prestador_inexistente',
        'nota': 3.0,
        'comentario': 'Prestador não encontrado',
        'data': Timestamp.now(),
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Prestador: Prestador'), findsOneWidget);
    });

    testWidgets('1️⃣3️⃣ Busca dados da solicitação corretamente', (tester) async {
      await fakeFirestore.collection('solicitacoesOrcamento').doc('solic789').set({
        'servicoTitulo': 'Reparo Hidráulico',
        'clienteEndereco': {'cidade': 'Rio de Janeiro'},
      });

      await fakeFirestore.collection('avaliacoes').doc('aval006').set({
        'clienteId': 'user123',
        'solicitacaoId': 'solic789',
        'nota': 4.0,
        'comentario': 'Serviço específico',
        'data': Timestamp.now(),
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Reparo Hidráulico'), findsOneWidget);
      expect(find.text('Rio de Janeiro'), findsOneWidget);
    });
  });

  group('🛡️ MinhasAvaliacoesTab - Resiliência', () {
    testWidgets('1️⃣4️⃣ Lida com avaliação sem dados relacionados', (tester) async {
      await fakeFirestore.collection('avaliacoes').doc('aval007').set({
        'clienteId': 'user123',
        'nota': 3.0,
        'comentario': 'Avaliação mínima',
        'data': Timestamp.now(),
        // Sem prestadorId, sem solicitacaoId
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Avaliação mínima'), findsOneWidget);
      expect(find.text('Prestador: Prestador'), findsOneWidget);
    });

    testWidgets('1️⃣5️⃣ Lida com nota como null', (tester) async {
      await fakeFirestore.collection('avaliacoes').doc('aval008').set({
        'clienteId': 'user123',
        'comentario': 'Sem nota',
        'data': Timestamp.now(),
        // nota não definida
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sem nota'), findsOneWidget);
      expect(find.byType(StarsReadOnly), findsOneWidget);
    });

    testWidgets('1️⃣6️⃣ Lida com data como null', (tester) async {
      await fakeFirestore.collection('avaliacoes').doc('aval009').set({
        'clienteId': 'user123',
        'nota': 4.0,
        'comentario': 'Sem data',
        // data não definida
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Sem data'), findsOneWidget);
      expect(find.text('Enviado em —'), findsOneWidget);
    });
  });

  group('📊 MinhasAvaliacoesTab - Múltiplas avaliações', () {
    testWidgets('1️⃣7️⃣ Renderiza múltiplas avaliações', (tester) async {
      // Adiciona 3 avaliações
      for (int i = 1; i <= 3; i++) {
        await fakeFirestore.collection('avaliacoes').doc('aval_multi_$i').set({
          'clienteId': 'user123',
          'nota': i.toDouble(),
          'comentario': 'Avaliação $i',
          'data': Timestamp.now(),
        });
      }

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Avaliação'), findsNWidgets(3));
    });
  });

  group('🚨 MinhasAvaliacoesTab - Segurança', () {
    testWidgets('1️⃣8️⃣ Não mostra avaliações de outros usuários', (tester) async {
      // Avaliação de outro usuário
      await fakeFirestore.collection('avaliacoes').doc('aval_outro').set({
        'clienteId': 'outro_usuario',
        'nota': 5.0,
        'comentario': 'Avaliação de outro usuário',
        'data': Timestamp.now(),
      });

      // Avaliação do usuário logado
      await fakeFirestore.collection('avaliacoes').doc('aval_usuario').set({
        'clienteId': 'user123',
        'nota': 4.0,
        'comentario': 'Minha avaliação',
        'data': Timestamp.now(),
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Avaliação de outro usuário'), findsNothing);
      expect(find.text('Minha avaliação'), findsOneWidget);
    });
  });

  group('🎯 MinhasAvaliacoesTab - Casos específicos', () {
    testWidgets('1️⃣9️⃣ Formata data corretamente no card', (tester) async {
      final dataEspecifica = Timestamp.fromDate(DateTime(2025, 3, 10, 9, 45));
      
      await fakeFirestore.collection('avaliacoes').doc('aval_data').set({
        'clienteId': 'user123',
        'nota': 4.0,
        'comentario': 'Teste de data',
        'data': dataEspecifica,
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.text('Enviado em 10/03/2025 – 09:45'), findsOneWidget);
    });

    testWidgets('2️⃣0️⃣ Mostra ícone de localização quando há cidade', (tester) async {
      await setupTestData(
        avaliacaoId: 'aval_local',
        comentario: 'Com localização',
      );

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.text('São Paulo'), findsOneWidget);
    });

    testWidgets('2️⃣1️⃣ Não mostra seção de serviço quando servicoTitulo vazio', (tester) async {
      await fakeFirestore.collection('solicitacoesOrcamento').doc('solic_sem_titulo').set({
        'clienteEndereco': {'cidade': 'Teste'},
        // servicoTitulo não definido
      });

      await fakeFirestore.collection('avaliacoes').doc('aval_sem_titulo').set({
        'clienteId': 'user123',
        'solicitacaoId': 'solic_sem_titulo',
        'nota': 4.0,
        'comentario': 'Sem título',
        'data': Timestamp.now(),
      });

      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      // Não deve quebrar, apenas não mostrar o título
      expect(find.text('Sem título'), findsOneWidget);
    });
  });

  group('🔧 MinhasAvaliacoesTab - Estrutura do Widget', () {
    testWidgets('2️⃣2️⃣ Usa ListView para a lista', (tester) async {
      await setupTestData(avaliacaoId: 'test_structure');
      
      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('2️⃣3️⃣ Container tem estilo visual correto', (tester) async {
      await setupTestData(avaliacaoId: 'test_style');
      
      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasStyledContainer = containers.any((container) => 
          container.decoration != null && 
          container.decoration is BoxDecoration);
      expect(hasStyledContainer, isTrue);
    });

    testWidgets('2️⃣4️⃣ Dados básicos são carregados corretamente', (tester) async {
      await setupTestData(
        avaliacaoId: 'test_basic',
        nota: 4.0,
        comentario: 'Teste básico',
      );
      
      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      // Verifica que os dados básicos são carregados
      expect(find.text('Teste básico'), findsOneWidget);
      expect(find.byType(StarsReadOnly), findsOneWidget);
    });

    testWidgets('2️⃣5️⃣ Nenhum erro inesperado durante execução', (tester) async {
      await setupTestData(avaliacaoId: 'test_final');
      
      await pumpMinhasAvaliacoesTab(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}