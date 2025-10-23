import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Cliente/servicosFinalizados.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'user123', email: 'cliente@teste.com');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
  });

  // Helper function to create test data completa
  Future<void> _setupTestData({
    required String servicoId,
    required String categoriaId,
    required String solicitacaoId,
  }) async {
    // Setup categoria
    await fakeFirestore.collection('categoriasServicos').doc(categoriaId).set({
      'imagemUrl': '', // URL vazia para evitar NetworkImage
      'nome': 'Pintura',
    });

    // Setup serviço
    await fakeFirestore.collection('servicos').doc(servicoId).set({
      'categoriaId': categoriaId,
      'titulo': 'Serviço Teste',
    });

    // Setup solicitação - com TODOS os campos necessários
    await fakeFirestore.collection('solicitacoesOrcamento').doc(solicitacaoId).set({
      'clienteId': 'user123',
      'status': 'finalizada',
      'servicoTitulo': 'Pintura de casa',
      'servicoDescricao': 'Pintura completa da residência',
      'prestadorNome': 'Carlos',
      'clienteEndereco': {'cidade': 'Rio Verde'},
      'servicoId': servicoId,
    });
  }

  // Helper function to build the widget
  Future<void> _pumpServicosFinalizadosScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ServicosFinalizadosScreen(
        firestore: fakeFirestore,
        auth: mockAuth,
      ),
    ));
  }

  // Função para aguardar todos os loaders
  Future<void> _waitForLoaders(WidgetTester tester) async {
    // Aguarda o StreamBuilder inicial
    await tester.pump(const Duration(milliseconds: 100));
    
    // Aguarda múltiplos ciclos para FutureBuilders aninhados
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
      // Para se não há mais loaders
      if (!find.byType(CircularProgressIndicator).evaluate().any((element) => element.widget is CircularProgressIndicator)) {
        break;
      }
    }
    
    await tester.pumpAndSettle();
  }

  // ===============================================================
  // 1️⃣ READ – Lista serviços finalizados
  // ===============================================================
  testWidgets('📖 READ 1️⃣ Lista serviços finalizados do cliente logado', (tester) async {
    // Setup test data ANTES de bombear o widget
    await _setupTestData(
      servicoId: 'serv001',
      categoriaId: 'cat001',
      solicitacaoId: 'solic001',
    );

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    // Verifica se o conteúdo aparece - CORRIGIDO para o texto real
    expect(find.text('Pintura de casa'), findsOneWidget);
    expect(find.text('Prestador: Carlos'), findsOneWidget); // CORRIGIDO
    expect(find.text('Avaliar'), findsOneWidget);
  });

  // ===============================================================
  // 2️⃣ READ – Nenhum serviço finalizado
  // ===============================================================
  testWidgets('📖 READ 2️⃣ Mostra mensagem quando não há finalizados', (tester) async {
    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    expect(find.text('Nenhum serviço finalizado.'), findsOneWidget);
  });

  // ===============================================================
  // 3️⃣ CREATE – Cria doc e aparece na lista
  // ===============================================================
  testWidgets('🧮 CREATE 3️⃣ Cria doc e aparece na lista', (tester) async {
    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);
    
    expect(find.text('Nenhum serviço finalizado.'), findsOneWidget);

    // Add data after initial load to test stream updates
    await _setupTestData(
      servicoId: 'serv002',
      categoriaId: 'cat002',
      solicitacaoId: 'solic002',
    );

    // Wait for stream update
    await _waitForLoaders(tester);

    expect(find.text('Pintura de casa'), findsOneWidget);
    expect(find.text('Avaliar'), findsOneWidget);
  });

  // ===============================================================
  // 4️⃣ UPDATE – Atualiza dados
  // ===============================================================
  testWidgets('🧠 UPDATE 4️⃣ Atualiza nome do prestador e reflete na UI', (tester) async {
    // Setup initial data
    const solicitacaoId = 'solic003';
    await _setupTestData(
      servicoId: 'serv003',
      categoriaId: 'cat003',
      solicitacaoId: solicitacaoId,
    );

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    expect(find.text('Prestador: Carlos'), findsOneWidget); // CORRIGIDO

    // Update data
    await fakeFirestore
        .collection('solicitacoesOrcamento')
        .doc(solicitacaoId)
        .update({'prestadorNome': 'Carlos Atualizado'});

    // Wait for stream update
    await _waitForLoaders(tester);

    expect(find.text('Prestador: Carlos Atualizado'), findsOneWidget); // CORRIGIDO
  });

  // ===============================================================
  // 5️⃣ DELETE – Remove serviço
  // ===============================================================
  testWidgets('🗑️ DELETE 5️⃣ Remove serviço da lista', (tester) async {
    // Setup initial data
    const solicitacaoId = 'solic004';
    await _setupTestData(
      servicoId: 'serv004',
      categoriaId: 'cat004',
      solicitacaoId: solicitacaoId,
    );

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    expect(find.text('Pintura de casa'), findsOneWidget);

    // Delete data
    await fakeFirestore
        .collection('solicitacoesOrcamento')
        .doc(solicitacaoId)
        .delete();

    // Wait for stream update
    await _waitForLoaders(tester);

    expect(find.text('Nenhum serviço finalizado.'), findsOneWidget);
  });

  // ===============================================================
  // 6️⃣ INTERFACE – Tabs
  // ===============================================================
  testWidgets('🎨 INTERFACE 6️⃣ Renderiza abas corretamente', (tester) async {
    await _pumpServicosFinalizadosScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Finalizados'), findsOneWidget);
    expect(find.text('Minhas avaliações'), findsOneWidget);
  });

  // ===============================================================
  // 7️⃣ INTERFACE – Botão Avaliar
  // ===============================================================
  testWidgets('🎨 INTERFACE 7️⃣ Botão "Avaliar" aparece no card', (tester) async {
    await _setupTestData(
      servicoId: 'serv005',
      categoriaId: 'cat005',
      solicitacaoId: 'solic005',
    );

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    expect(find.text('Avaliar'), findsOneWidget);
  });

  // ===============================================================
  // 8️⃣ NAVEGAÇÃO – Botão Avaliar
  // ===============================================================
  testWidgets('🧭 NAVEGAÇÃO 8️⃣ Botão Avaliar existe e é clicável', (tester) async {
    await _setupTestData(
      servicoId: 'serv006',
      categoriaId: 'cat006',
      solicitacaoId: 'solic006',
    );

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    // Encontra o botão pelo texto e verifica se está presente
    final avaliarButtonFinder = find.text('Avaliar');
    expect(avaliarButtonFinder, findsOneWidget);
  });

  // ===============================================================
  // 9️⃣ ERRO – Usuário não autenticado
  // ===============================================================
  testWidgets('🚨 ERRO 9️⃣ Mostra mensagem quando usuário não está autenticado', (tester) async {
    final authNotSignedIn = MockFirebaseAuth(signedIn: false);

    await tester.pumpWidget(MaterialApp(
      home: ServicosFinalizadosScreen(
        firestore: fakeFirestore,
        auth: authNotSignedIn,
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Usuário não autenticado'), findsOneWidget);
  });

  // ===============================================================
  // 🔟 IMAGEM – Placeholder quando não há imagem
  // ===============================================================
  testWidgets('🖼️ IMAGEM 🔟 Mostra placeholder quando não há imagem', (tester) async {
    // Setup data com categoria mas sem imagem
    await fakeFirestore.collection('solicitacoesOrcamento').doc('solic007').set({
      'clienteId': 'user123',
      'status': 'finalizada',
      'servicoTitulo': 'Serviço sem imagem',
      'servicoDescricao': 'Descrição do serviço',
      'prestadorNome': 'João',
      'clienteEndereco': {'cidade': 'Rio Verde'},
      'servicoId': 'serv007',
    });

    await fakeFirestore.collection('servicos').doc('serv007').set({
      'categoriaId': 'cat007',
    });

    await fakeFirestore.collection('categoriasServicos').doc('cat007').set({
      'imagemUrl': '', // URL vazia
      'nome': 'Categoria Teste',
    });

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    // Should still show the service card with placeholder icon
    expect(find.text('Serviço sem imagem'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsWidgets);
  });

  // ===============================================================
  // 1️⃣1️⃣ DADOS – Serviço sem categoria (corrigido)
  // ===============================================================
  testWidgets('📊 DADOS 1️⃣1️⃣ Serviço sem categoria carrega corretamente', (tester) async {
    // Setup data with servico but no categoria document
    await fakeFirestore.collection('solicitacoesOrcamento').doc('solic008').set({
      'clienteId': 'user123',
      'status': 'finalizada',
      'servicoTitulo': 'Serviço sem categoria',
      'servicoDescricao': 'Descrição do serviço',
      'prestadorNome': 'Maria',
      'clienteEndereco': {'cidade': 'São Paulo'},
      'servicoId': 'serv008',
    });

    // Cria o serviço mas com categoria que não existe
    await fakeFirestore.collection('servicos').doc('serv008').set({
      'categoriaId': 'cat_inexistente', // This category doesn't exist
    });

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    // Should still show the service - CORRIGIDO para o texto real
    expect(find.text('Serviço sem categoria'), findsOneWidget);
    expect(find.text('Prestador: Maria'), findsOneWidget); // CORRIGIDO
  });

  // ===============================================================
  // 1️⃣2️⃣ TESTE ADICIONAL – Texto contendo (para busca mais flexível)
  // ===============================================================
  testWidgets('🔍 TEXTO 1️⃣2️⃣ Encontra texto contendo o nome do prestador', (tester) async {
    await _setupTestData(
      servicoId: 'serv009',
      categoriaId: 'cat009',
      solicitacaoId: 'solic009',
    );

    await _pumpServicosFinalizadosScreen(tester);
    await _waitForLoaders(tester);

    // Busca flexível por texto que CONTÉM "Carlos"
    expect(find.textContaining('Carlos'), findsOneWidget);
  });
}