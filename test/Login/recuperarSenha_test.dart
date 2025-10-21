import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myapp/Login/recuperarSenha.dart';

// =============================================================
// 🔹 Mock corrigido e estável
// =============================================================
class MockAuth extends Mock implements FirebaseAuth {}

Future<void> settleShort(WidgetTester tester, [int repeat = 10]) async {
  for (int i = 0; i < repeat; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 🔧 Registra tipos para evitar erro “Bad state”
    registerFallbackValue('');
  });

  group('💌 RecuperarSenhaScreen – Testes com injeção de dependência', () {
    late MockAuth mockAuth;

    setUp(() {
      mockAuth = MockAuth();

      // 🔧 Stub padrão (necessário para não quebrar)
      when(() => mockAuth.setLanguageCode(any())).thenAnswer((_) async => Future.value());
      when(() => mockAuth.sendPasswordResetEmail(email: any(named: 'email')))
          .thenAnswer((_) async => Future.value());
    });

    // =============================================================
    // 1️⃣ Renderização básica
    // =============================================================
    testWidgets('Renderiza campo de e-mail e botão de envio', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));

      expect(find.text('Recuperar Senha'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Enviar link'), findsOneWidget);
    });

    // =============================================================
    // 2️⃣ Validação de formulário
    // =============================================================
    testWidgets('Exibe erro se o campo de e-mail estiver vazio', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu e-mail'), findsOneWidget);
    });

    testWidgets('Exibe erro se o e-mail for inválido', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));
      await tester.enterText(find.byType(TextFormField), 'emailInvalido');
      await tester.tap(find.text('Enviar link'));
      await tester.pumpAndSettle();

      expect(find.text('E-mail inválido'), findsOneWidget);
    });

    // =============================================================
    // 3️⃣ Fluxo de sucesso (senha enviada)
    // =============================================================
    testWidgets('Exibe mensagem de sucesso após enviar o e-mail', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));

      await tester.enterText(find.byType(TextFormField), 'teste@exemplo.com');
      await tester.tap(find.text('Enviar link'));
      await settleShort(tester, 10);

      expect(find.textContaining('link para redefinir'), findsOneWidget);
    });

    // =============================================================
    // 4️⃣ Erros simulados de autenticação
    // =============================================================
    testWidgets('Exibe mensagem se o e-mail não for encontrado', (tester) async {
      when(() => mockAuth.sendPasswordResetEmail(email: any(named: 'email')))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));

      await tester.enterText(find.byType(TextFormField), 'nao@existe.com');
      await tester.tap(find.text('Enviar link'));
      await settleShort(tester);

      expect(find.textContaining('Não há usuário registrado'), findsOneWidget);
    });

    testWidgets('Exibe mensagem de e-mail inválido', (tester) async {
      when(() => mockAuth.sendPasswordResetEmail(email: any(named: 'email')))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));

      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));

      await tester.enterText(find.byType(TextFormField), 'teste@');
      await tester.tap(find.text('Enviar link'));
      await settleShort(tester);

      expect(find.textContaining('E-mail inválido'), findsOneWidget);
    });

    testWidgets('Exibe mensagem de erro genérico', (tester) async {
      when(() => mockAuth.sendPasswordResetEmail(email: any(named: 'email')))
          .thenThrow(FirebaseAuthException(code: 'unknown'));

      await tester.pumpWidget(MaterialApp(
        home: RecuperarSenhaScreen(auth: mockAuth),
      ));

      await tester.enterText(find.byType(TextFormField), 'teste@exemplo.com');
      await tester.tap(find.text('Enviar link'));
      await settleShort(tester);

      expect(find.textContaining('Erro ao enviar o e-mail'), findsOneWidget);
    });
  });
}
