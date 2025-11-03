import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/Login/login.dart';

// ✅ Mock completo que evita qualquer acesso ao Firebase real
class MockHomeScreen extends StatelessWidget {
  const MockHomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Home Cliente Mock')));
}

class MockHomePrestadorScreen extends StatelessWidget {
  const MockHomePrestadorScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Home Prestador Mock')));
}

class MockCadastroScreen extends StatelessWidget {
  const MockCadastroScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Cadastro Mock')));
}

class MockRecuperarSenhaScreen extends StatelessWidget {
  const MockRecuperarSenhaScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Recuperar Senha Mock')));
}

// ✅ Configuração do Firebase para testes
Future<void> setupTestFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Configura SharedPreferences mock
  SharedPreferences.setMockInitialValues({});
  
  try {
    await Firebase.initializeApp(
      name: 'test',
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project',
      ),
    );
  } catch (e) {
    // Se já foi inicializado, ignora o erro
  }
}

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore mockFirestore;

  setUpAll(() async {
    await setupTestFirebase();
  });

  setUp(() async {
    mockAuth = MockFirebaseAuth(signedIn: false);
    mockFirestore = FakeFirebaseFirestore();
    // Reseta SharedPreferences antes de cada teste
    SharedPreferences.setMockInitialValues({});
  });

  // ✅ Widget wrapper melhorado
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
      routes: {
        '/home-cliente': (context) => const MockHomeScreen(),
        '/home-prestador': (context) => const MockHomePrestadorScreen(),
        '/cadastro': (context) => const MockCadastroScreen(),
        '/recuperar-senha': (context) => const MockRecuperarSenhaScreen(),
      },
      // Adiciona navegação básica
      navigatorKey: GlobalKey<NavigatorState>(),
    );
  }

  // ✅ Função auxiliar melhorada para bombear a tela de login
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    MockUser? mockUser,
    Map<String, dynamic>? userData,
  }) async {
    // Configura auth mock se fornecido
    if (mockUser != null) {
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: false);
    }

    // Prepara dados no firestore se fornecido
    if (userData != null && mockUser != null) {
      await mockFirestore
          .collection('usuarios')
          .doc(mockUser.uid)
          .set(userData);
    }

    // Cria o widget com as dependências mockadas
    final loginScreen = LoginScreen(
      auth: mockAuth,
      firestore: mockFirestore,
      homeClienteBuilder: (_) => const MockHomeScreen(),
      homePrestadorBuilder: (_) => const MockHomePrestadorScreen(),
    );

    await tester.pumpWidget(createTestableWidget(loginScreen));
    
    // Aguarda a renderização completa
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  // ✅ TESTE 1: Verifica se os elementos básicos estão presentes
  testWidgets('1️⃣ Exibe campos de e-mail, senha e botões principais', (tester) async {
    await pumpLoginScreen(tester);
    
    // Verifica campos de texto
    expect(find.byType(TextFormField), findsNWidgets(2));
    
    // Verifica textos usando diferentes abordagens
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    
    // Verifica também por tipos de widget específicos
    expect(find.byType(ElevatedButton), findsWidgets);
    expect(find.byType(TextButton), findsWidgets);
  });

  // ✅ TESTE 2: Validação de campos vazios
  testWidgets('2️⃣ Mostra erro se tentar logar sem preencher campos', (tester) async {
    await pumpLoginScreen(tester);
    
    // Encontra o botão Entrar de forma mais robusta
    final entrarButton = find.text('Entrar');
    expect(entrarButton, findsOneWidget);
    
    await tester.tap(entrarButton);
    await tester.pumpAndSettle();
    
    // Verifica mensagens de erro
    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
  });

  // ✅ TESTE 3: Login como cliente
  testWidgets(
    '3️⃣ Login com sucesso como CLIENTE redireciona para HomeScreen',
    (tester) async {
      final user = MockUser(
        email: 'cliente@teste.com',
        uid: '123',
        isEmailVerified: true,
      );

      await pumpLoginScreen(
        tester,
        mockUser: user,
        userData: {'tipoPerfil': 'cliente'},
      );

      // Preenche campos de forma mais robusta
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));
      
      await tester.enterText(textFields.at(0), 'cliente@teste.com');
      await tester.enterText(textFields.at(1), '123456');
      
      // Clica no botão Entrar
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Home Cliente Mock'), findsOneWidget);
    },
  );

  // ✅ TESTE 4: Login como prestador
  testWidgets(
    '4️⃣ Login com sucesso como PRESTADOR redireciona para HomePrestadorScreen',
    (tester) async {
      final user = MockUser(
        email: 'prestador@teste.com',
        uid: '999',
        isEmailVerified: true,
      );

      await pumpLoginScreen(
        tester,
        mockUser: user,
        userData: {'tipoPerfil': 'prestador'},
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'prestador@teste.com');
      await tester.enterText(textFields.at(1), 'senha123');
      
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Home Prestador Mock'), findsOneWidget);
    },
  );

  // ✅ TESTE 5: Usuário não encontrado
  testWidgets('5️⃣ Exibe erro quando usuário não é encontrado no Firestore', (tester) async {
    final user = MockUser(
      email: 'inexistente@teste.com',
      uid: 'notfound',
      isEmailVerified: true,
    );

    await pumpLoginScreen(tester, mockUser: user);

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'inexistente@teste.com');
    await tester.enterText(textFields.at(1), '123456');
    
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verifica se algum SnackBar foi exibido
    expect(find.byType(SnackBar), findsOneWidget);
  });

  // ✅ TESTE 6: Navegação para cadastro
  testWidgets('6️⃣ Botão "Criar conta" navega para tela de cadastro', (tester) async {
    await pumpLoginScreen(tester);
    
    final criarContaButton = find.text('Criar conta');
    expect(criarContaButton, findsOneWidget);
    
    await tester.tap(criarContaButton);
    await tester.pumpAndSettle();
    
    expect(find.text('Cadastro Mock'), findsOneWidget);
  });

  // ✅ TESTE 7: Navegação para recuperação de senha
  testWidgets(
    '7️⃣ Botão "Esqueci minha senha" navega para tela de recuperação',
    (tester) async {
      await pumpLoginScreen(tester);
      
      final esqueciSenhaButton = find.text('Esqueci minha senha');
      expect(esqueciSenhaButton, findsOneWidget);
      
      await tester.tap(esqueciSenhaButton);
      await tester.pumpAndSettle();

      expect(find.text('Recuperar Senha Mock'), findsOneWidget);
    },
  );

  // ✅ TESTE 8: Credenciais inválidas
  testWidgets('8️⃣ Exibe SnackBar quando credenciais são inválidas', (tester) async {
    await pumpLoginScreen(tester);

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'invalid@teste.com');
    await tester.enterText(textFields.at(1), 'wrongpassword');
    
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsOneWidget);
  });

  // ✅ TESTE 9: Tipo de perfil padrão (cliente)
  testWidgets(
    '9️⃣ Login usa cliente como padrão quando documento não tem tipoPerfil',
    (tester) async {
      final user = MockUser(
        email: 'notipo@teste.com',
        uid: '456',
        isEmailVerified: true,
      );

      await pumpLoginScreen(
        tester,
        mockUser: user,
        userData: {'nome': 'Usuário Sem Tipo'}, // Sem tipoPerfil
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'notipo@teste.com');
      await tester.enterText(textFields.at(1), '123456');
      
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Home Cliente Mock'), findsOneWidget);
    },
  );

  // ✅ TESTE 10: Tipo de perfil vazio
  testWidgets('🔟 Login funciona quando documento tem tipoPerfil vazio', (tester) async {
    final user = MockUser(
      email: 'vazio@teste.com',
      uid: '789',
      isEmailVerified: true,
    );

    await pumpLoginScreen(tester, mockUser: user, userData: {'tipoPerfil': ''});

    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'vazio@teste.com');
    await tester.enterText(textFields.at(1), '123456');
    
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Home Cliente Mock'), findsOneWidget);
  });
}