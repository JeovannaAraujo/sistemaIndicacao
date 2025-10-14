import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  final auth = MockFirebaseAuth();
  final firestore = FakeFirebaseFirestore();

  group('🧪 Testes Firebase mockados', () {
    test('1️⃣ Criar e logar usuário', () async {
      await auth.createUserWithEmailAndPassword(
        email: 'teste@teste.com',
        password: '12345678',
      );

      final user = auth.currentUser;
      expect(user, isNotNull);
      expect(user!.email, 'teste@teste.com');
    });

    test('2️⃣ Gravar e ler dados no Firestore', () async {
      await firestore.collection('teste').add({'nome': 'Jeovanna'});
      final snapshot = await firestore.collection('teste').get();
      expect(snapshot.docs.isNotEmpty, true);
      expect(snapshot.docs.first['nome'], 'Jeovanna');
    });

    test('3️⃣ Calcular estimativa de valor', () {
      const valorMedio = 50.0;
      const quantidade = 3.0;
      const estimativa = valorMedio * quantidade;
      expect(estimativa, 150.0);
    });
  });
}
