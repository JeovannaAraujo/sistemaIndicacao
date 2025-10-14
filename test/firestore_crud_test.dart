import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  final firestore = FakeFirebaseFirestore();

  group('📘 Firestore CRUD', () {
    test('1️⃣ Criar e ler documento', () async {
      await firestore.collection('usuarios').add({'nome': 'Jeovanna'});
      final snap = await firestore.collection('usuarios').get();

      expect(snap.docs.isNotEmpty, true);
      expect(snap.docs.first['nome'], 'Jeovanna');
    });

    test('2️⃣ Atualizar documento existente', () async {
      final doc = await firestore.collection('servicos').add({'ativo': true});
      await doc.update({'ativo': false});

      final atualizado = await doc.get();
      expect(atualizado['ativo'], false);
    });

    test('3️⃣ Excluir documento', () async {
      final doc = await firestore.collection('teste').add({'x': 1});
      await doc.delete();

      final existe = await doc.get();
      expect(existe.exists, false);
    });
  });
}
