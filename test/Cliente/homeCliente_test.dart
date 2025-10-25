import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:myapp/Cliente/homeCliente.dart';
import 'package:myapp/Cliente/visualizarPerfilPrestador.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();

    mockUser = MockUser(
      uid: 'uid123',
      email: 'jeovanna@example.com',
      displayName: 'Jeovanna',
    );
    mockAuth = MockFirebaseAuth(mockUser: mockUser);

    // 🔹 Garante que o usuário esteja realmente logado
    await mockAuth.signInWithEmailAndPassword(
      email: mockUser.email!,
      password: '123456',
    );

    await fakeDb.collection('usuarios').doc(mockUser.uid).set({
      'nome': 'Jeovanna',
      'cidade': 'Rio Verde',
      'whatsApp': '(64) 99999-9999',
      'ativo': true,
      'tipoPerfil': 'Cliente',
    });

    // Cria coleção de avaliações e prestadores simulados
    await fakeDb.collection('avaliacoes').add({
      'prestadorId': 'p1',
      'nota': 5.0,
    });
    await fakeDb.collection('usuarios').doc('p1').set({
      'nome': 'Carlos Silva',
      'ativo': true,
      'tipoPerfil': 'Prestador',
      'categoriaProfissionalId': 'cat1',
    });
    await fakeDb.collection('categoriasProfissionais').doc('cat1').set({
      'nome': 'Eletricista',
    });
  });

  Future<void> _buildHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(firestore: fakeDb, auth: mockAuth),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('🏠 Estrutura inicial', () {
    testWidgets('1️⃣ Exibe título "Indica Aí"', (tester) async {
      await _buildHomeScreen(tester);
      expect(find.textContaining('Indica Aí'), findsWidgets);
    });

    testWidgets('2️⃣ Exibe campo de busca', (tester) async {
      await _buildHomeScreen(tester);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('🧭 Drawer e itens de menu', () {
    testWidgets('7️⃣ Drawer contém nome do usuário logado', (tester) async {
      await _buildHomeScreen(tester);

      // 🔹 Abre o Drawer
      final scaffoldState =
          tester.firstState(find.byType(Scaffold)) as ScaffoldState;
      scaffoldState.openDrawer();
      await tester.pump();

      // 🔁 Aguarda até o Drawer renderizar algo
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // 🔹 Agora verifica se "Jeovanna" aparece
      expect(
        find.textContaining('Jeovanna'),
        findsWidgets,
        reason: 'O nome do usuário deveria aparecer no Drawer',
      );

      // 🔹 Agora verifica se renderizou corretamente
      expect(
        find.textContaining('Jeovanna'),
        findsWidgets,
        reason: 'O nome do usuário deveria aparecer no Drawer',
      );
      expect(
        find.textContaining('Rio Verde'),
        findsWidgets,
        reason: 'A cidade deveria aparecer no Drawer',
      );
      expect(
        find.textContaining('(64) 99999-9999'),
        findsWidgets,
        reason: 'O WhatsApp deveria aparecer no Drawer',
      );
    });

    testWidgets('8️⃣ Drawer fecha ao clicar fora', (tester) async {
      await _buildHomeScreen(tester);
      final scaffoldState =
          tester.firstState(find.byType(Scaffold)) as ScaffoldState;

      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);

      // simula clique fora do Drawer
      await tester.tapAt(const Offset(500, 500));
      await tester.pumpAndSettle();

      expect(
        find.byType(Drawer),
        findsNothing,
        reason: 'O Drawer deveria fechar ao clicar fora dele',
      );
    });
  });

  group('📊 Profissionais em destaque', () {
    testWidgets('11️⃣ Profissionais em destaque exibe lista', (tester) async {
      await _buildHomeScreen(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Carlos Silva'), findsWidgets);
    });

    testWidgets('12️⃣ Exibe profissional após carregar', (tester) async {
      await _buildHomeScreen(tester);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Carlos Silva'), findsWidgets);
      expect(find.textContaining('Eletricista'), findsWidgets);
    });
  });

  group('⚙️ Lógica de estado interno', () {
    testWidgets('16️⃣ selectedIndex inicial é 0', (tester) async {
      await _buildHomeScreen(tester);
      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;
      expect(state.selectedIndex, equals(0));
    });

    testWidgets('17️⃣ onItemTapped altera índice', (tester) async {
      await _buildHomeScreen(tester);
      final state = tester.state(find.byType(HomeScreen)) as HomeScreenState;
      state.onItemTapped(2);
      expect(state.selectedIndex, equals(2));
    });
  });

  group('🚀 Navegação final', () {
    testWidgets('19️⃣ Toque em profissional abre VisualizarPerfilPrestador', (
      tester,
    ) async {
      await _buildHomeScreen(tester);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final profTile = find.textContaining('Carlos Silva');
      expect(profTile, findsOneWidget);

      await tester.tap(profTile);
      await tester.pumpAndSettle();

      // Verifica se abriu a tela correta
      expect(
        find.byWidgetPredicate((widget) => widget is VisualizarPerfilPrestador),
        findsOneWidget,
      );
    });
    group('🧩 Drawer e informações do usuário', () {
      testWidgets('20️⃣ Exibe WhatsApp do usuário logado', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(find.textContaining('(64) 99999-9999'), findsWidgets);
      });

      testWidgets('21️⃣ Exibe cidade do usuário logado', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(find.textContaining('Rio Verde'), findsWidgets);
      });

      testWidgets('22️⃣ Exibe botão "Ver perfil"', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(find.text('Ver perfil'), findsWidgets);
      });

      testWidgets('23️⃣ Drawer exibe ícone de WhatsApp', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is FaIcon && widget.icon == FontAwesomeIcons.whatsapp,
          ),
          findsWidgets,
        );
      });
    });

    group('📋 Itens do Drawer', () {
      testWidgets('24️⃣ Contém item "Solicitações"', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(find.text('Solicitações'), findsWidgets);
      });

      testWidgets('25️⃣ Contém item "Serviços Finalizados"', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(find.text('Serviços Finalizados'), findsWidgets);
      });

      testWidgets('26️⃣ Contém item "Sair"', (tester) async {
        await _buildHomeScreen(tester);
        final scaffoldState =
            tester.firstState(find.byType(Scaffold)) as ScaffoldState;
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();
        expect(find.text('Sair'), findsWidgets);
      });
    });

    group('🎨 Categorias fixas', () {
      testWidgets('27️⃣ Exibe 6 categorias fixas', (tester) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('Eletricista'), findsWidgets);
        expect(find.textContaining('Pedreiro'), findsWidgets);
        expect(find.textContaining('Encanador'), findsWidgets);
        expect(find.textContaining('Diarista'), findsWidgets);
        expect(find.textContaining('Pintor'), findsWidgets);
        expect(find.textContaining('Montador'), findsWidgets);
      });

      testWidgets('28️⃣ Categoria "Eletricista" tem ícone de raio', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.flash_on), findsWidgets);
      });

      testWidgets('29️⃣ Categoria "Pedreiro" tem ícone de construção', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.construction), findsWidgets);
      });

      testWidgets('30️⃣ Categoria "Encanador" tem ícone de água', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.water_drop), findsWidgets);
      });
    });

    group('📊 Profissionais em destaque (interações)', () {
      testWidgets('31️⃣ Lista contém profissional "Carlos Silva"', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('Carlos Silva'), findsWidgets);
      });

      testWidgets('32️⃣ Exibe a categoria "Eletricista" do profissional', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('Eletricista'), findsWidgets);
      });

      testWidgets('33️⃣ Exibe avaliação do profissional', (tester) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('5.0'), findsWidgets);
      });

      testWidgets('34️⃣ Exibe texto de quantidade de avaliações', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('1 avaliação'), findsWidgets);
      });

      testWidgets('35️⃣ Ícone de estrela está visível', (tester) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.star), findsWidgets);
      });

      testWidgets('36️⃣ Ícone de seta de navegação está visível', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.arrow_forward_ios), findsWidgets);
      });

      testWidgets('37️⃣ Título principal é "Indica Aí"', (tester) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('Indica Aí'), findsWidgets);
      });

      testWidgets(
        '38️⃣ Subtítulo "Encontre os melhores profissionais..." aparece',
        (tester) async {
          await _buildHomeScreen(tester);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Encontre os melhores profissionais'),
            findsWidgets,
          );
        },
      );

      testWidgets('39️⃣ Campo de busca tem ícone de lupa', (tester) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.search), findsWidgets);
      });

      testWidgets('40️⃣ BottomNavigationBar exibe item "Início"', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.text('Início'), findsWidgets);
      });

      testWidgets('41️⃣ BottomNavigationBar exibe item "Perfil"', (
        tester,
      ) async {
        await _buildHomeScreen(tester);
        await tester.pumpAndSettle();
        expect(find.text('Perfil'), findsWidgets);
      });
    });
  });
}
