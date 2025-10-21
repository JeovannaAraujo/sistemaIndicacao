// =============================================================
// ✅ LoginScreen Test — versão final corrigida e funcional
// =============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/Login/login.dart';

// =============================================================
// 🧱 Fakes das telas Home (para evitar Firebase real)
// =============================================================
class FakeHomeCliente extends StatelessWidget {
  const FakeHomeCliente({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('HomeClienteMock')));
}

class FakeHomePrestador extends StatelessWidget {
  const FakeHomePrestador({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('HomePrestadorMock')));
}

// =============================================================
// 🔹 Mocks auxiliares
// =============================================================
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route<dynamic> {}

class MockAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUserInstance extends Mock implements User {}

// Helper para estabilizar animações / navegações
Future<void> settleShort(WidgetTester tester, [int repeat = 10]) async {
  for (int i = 0; i < repeat; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(FakeRoute());
    SharedPreferences.setMockInitialValues({});
  });

  group('🧩 LoginScreen – Cobertura CRUD lógica e UI', () {
    late FakeFirebaseFirestore fakeDb;
    late FirebaseAuth mockAuth;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      mockAuth = MockAuth();
    });

    // =============================================================
    // 1️⃣ Renderização básica
    // =============================================================
    testWidgets('Renderiza campos de e-mail e senha', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(auth: MockFirebaseAuth(), firestore: fakeDb),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Criar conta'), findsOneWidget);
    });

    // =============================================================
    // 2️⃣ Login de cliente com redirecionamento mockado
    // =============================================================
    testWidgets('Realiza login e redireciona para HomeCliente', (tester) async {
      final user = MockUser(uid: 'cli123', email: 'cli@teste.com');
      final mockFirebaseAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

      await fakeDb.collection('usuarios').doc('cli123').set({
        'email': 'cli@teste.com',
        'tipoPerfil': 'cliente',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            auth: mockFirebaseAuth,
            firestore: fakeDb,
            homeClienteBuilder: (_) => const FakeHomeCliente(),
            homePrestadorBuilder: (_) => const FakeHomePrestador(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'cli@teste.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Entrar'));
      await settleShort(tester, 15);

      expect(find.text('HomeClienteMock'), findsOneWidget);
    });

    // =============================================================
    // 3️⃣ Login de prestador com redirecionamento mockado
    // =============================================================
    testWidgets('Realiza login e redireciona para HomePrestador', (tester) async {
      final user = MockUser(uid: 'prest123', email: 'prest@teste.com');
      final mockFirebaseAuth = MockFirebaseAuth(mockUser: user, signedIn: true);

      await fakeDb.collection('usuarios').doc('prest123').set({
        'email': 'prest@teste.com',
        'tipoPerfil': 'prestador',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            auth: mockFirebaseAuth,
            firestore: fakeDb,
            homeClienteBuilder: (_) => const FakeHomeCliente(),
            homePrestadorBuilder: (_) => const FakeHomePrestador(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'prest@teste.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Entrar'));
      await settleShort(tester, 15);

      expect(find.text('HomePrestadorMock'), findsOneWidget);
    });

    // =============================================================
    // 4️⃣ Erros de autenticação
    // =============================================================
    testWidgets('Exibe erro de usuário não encontrado', (tester) async {
      when(() => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(auth: mockAuth, firestore: fakeDb),
      ));

      await tester.enterText(find.byType(TextFormField).first, 'nao@existe.com');
      await tester.enterText(find.byType(TextFormField).last, 'senha123');
      await tester.tap(find.text('Entrar'));
      await settleShort(tester);

      expect(find.textContaining('E-mail não cadastrado'), findsOneWidget);
    });

    testWidgets('Exibe erro de senha incorreta', (tester) async {
      when(() => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(auth: mockAuth, firestore: fakeDb),
      ));

      await tester.enterText(find.byType(TextFormField).first, 'cli@teste.com');
      await tester.enterText(find.byType(TextFormField).last, 'senhaErrada');
      await tester.tap(find.text('Entrar'));
      await settleShort(tester);

      expect(find.textContaining('Senha incorreta'), findsOneWidget);
    });

    testWidgets('Exibe erro de e-mail inválido', (tester) async {
      when(() => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'invalid-email'));

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(auth: mockAuth, firestore: fakeDb),
      ));

      await tester.enterText(find.byType(TextFormField).first, 'emailInvalido');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Entrar'));
      await settleShort(tester);

      expect(find.textContaining('E-mail inválido'), findsOneWidget);
    });

    testWidgets('Exibe erro de usuário desativado', (tester) async {
      when(() => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenThrow(FirebaseAuthException(code: 'user-disabled'));

      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(auth: mockAuth, firestore: fakeDb),
      ));

      await tester.enterText(find.byType(TextFormField).first, 'cli@teste.com');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Entrar'));
      await settleShort(tester);

      expect(find.textContaining('Usuário desativado'), findsOneWidget);
    });
  });

  // =============================================================
  // 🧠 Funções internas isoladas
  // =============================================================
  group('🧠 Funções internas isoladas do LoginScreen', () {
    late LoginScreenState state;
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      state = LoginScreenState(firestore: fakeDb);
    });

    test('normalizePerfil converte corretamente diferentes entradas', () {
      expect(state.normalizePerfil('admin'), 'Administrador');
      expect(state.normalizePerfil('prestador'), 'Prestador');
      expect(state.normalizePerfil('cliente'), 'Cliente');
      expect(state.normalizePerfil(null), 'Cliente');
      expect(state.normalizePerfil('user'), 'Cliente');
    });

    test('copiarSubcolecao copia documentos entre usuários', () async {
      final col = fakeDb.collection('usuarios');
      await col.doc('antigo').collection('servicos').add({'nome': 'Pintura'});

      await state.copiarSubcolecao(
        usuariosCol: col,
        antigoId: 'antigo',
        novoUid: 'novo',
        subcolecao: 'servicos',
        firestore: fakeDb,
      );

      final novos = await col.doc('novo').collection('servicos').get();
      expect(novos.docs.first['nome'], 'Pintura');
    });

    test('migrarUsuarioSeNecessario cria novo documento se inexistente', () async {
      await state.migrarUsuarioSeNecessario(
        uid: 'u1',
        email: 'teste@novo.com',
        firestore: fakeDb,
      );

      final doc = await fakeDb.collection('usuarios').doc('u1').get();
      expect(doc.exists, isTrue);
      expect(doc['migrado'], isTrue);
    });

    test('migrarUsuarioSeNecessario migra documento existente', () async {
      final col = fakeDb.collection('usuarios');
      await col.add({
        'email': 'antigo@teste.com',
        'tipoPerfil': 'prestador',
      });

      await state.migrarUsuarioSeNecessario(
        uid: 'novoUid',
        email: 'antigo@teste.com',
        firestore: fakeDb,
      );

      final migrado = await col.doc('novoUid').get();
      expect(migrado.exists, isTrue);
      expect(migrado['migrado'], isTrue);
      expect(migrado['tipoPerfil'], 'Prestador');
    });
  });
}
