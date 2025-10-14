import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('🧩 Autenticação Firebase', () {
    test('1️⃣ Criar e logar usuário com sucesso', () async {
      final auth = MockFirebaseAuth(signedIn: false);

      await auth.createUserWithEmailAndPassword(
        email: 'jeovanna@teste.com',
        password: '12345678',
      );

      final login = await auth.signInWithEmailAndPassword(
        email: 'jeovanna@teste.com',
        password: '12345678',
      );

      expect(login.user, isNotNull);
      expect(login.user!.email, 'jeovanna@teste.com');
    });

    test('2️⃣ Login de usuário inexistente retorna mock padrão', () async {
      final auth = MockFirebaseAuth(signedIn: false);

      final result = await auth.signInWithEmailAndPassword(
        email: 'naoexiste@teste.com',
        password: 'senha123',
      );

      // O mock retorna um usuário genérico, então apenas validamos o tipo
      expect(result.user, isA<MockUser>());
    });
  });
}
