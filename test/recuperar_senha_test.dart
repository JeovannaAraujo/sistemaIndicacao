import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('💌 Recuperação de senha', () {
    test('1️⃣ Envio de e-mail de redefinição bem-sucedido', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(email: 'jeovanna@teste.com'),
      );

      await auth.sendPasswordResetEmail(email: 'jeovanna@teste.com');

      // Verifica se o método foi executado sem erros
      expect(() async {
        await auth.sendPasswordResetEmail(email: 'jeovanna@teste.com');
      }, returnsNormally);
    });

    test('2️⃣ E-mail inválido não deve lançar erro, mas não faz nada', () async {
      final auth = MockFirebaseAuth();

      try {
        await auth.sendPasswordResetEmail(email: 'email_invalido');
        expect(true, true); // Passa porque o mock não lança erro real
      } catch (e) {
        fail('O MockFirebaseAuth não deveria lançar exceção neste caso.');
      }
    });
  });
}
