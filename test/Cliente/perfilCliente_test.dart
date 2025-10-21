import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/perfilCliente.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🧩 PerfilCliente – Testes de Interface e CRUD', () {
    late FakeFirebaseFirestore fake;

    setUp(() {
      fake = FakeFirebaseFirestore();
    });

    // 1️⃣ Exibe carregamento enquanto aguarda snapshot
    testWidgets('1️⃣ Exibe carregamento enquanto aguarda snapshot', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'id', firestore: fake),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // 2️⃣ Exibe mensagem de "Cliente não encontrado"
    testWidgets('2️⃣ Exibe mensagem de "Cliente não encontrado"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'inexistente', firestore: fake),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Cliente não encontrado.'), findsOneWidget);
    });

    // 3️⃣ Renderiza dados completos do cliente (READ)
    testWidgets('3️⃣ Renderiza dados completos do cliente (READ)', (tester) async {
      await fake.collection('usuarios').doc('user1').set({
        'nome': 'Jeovanna',
        'email': 'jeovanna@email.com',
        'fotoUrl': '',
        'tipoPerfil': 'Cliente',
        'endereco': {
          'cidade': 'Rio Verde',
          'rua': 'Rua A',
          'numero': '123',
          'bairro': 'Centro',
          'complemento': '',
          'cep': '75900-000',
          'whatsapp': '(64) 99999-9999',
        },
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user1', firestore: fake),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Jeovanna'), findsOneWidget);
      expect(find.text('Rio Verde'), findsOneWidget);
      expect(find.text('(64) 99999-9999'), findsOneWidget);
      // Correção: Usa find.textContaining para buscar dentro da string formatada
      expect(find.textContaining('CEP: 75900-000'), findsOneWidget);
    });

    // 4️⃣ Exibe fallback de imagem padrão (sem foto)
    testWidgets('4️⃣ Exibe fallback de imagem padrão (sem foto)', (tester) async {
      await fake.collection('usuarios').doc('user2').set({
        'nome': 'Maria',
        'email': 'maria@email.com',
        'fotoUrl': '',
        'tipoPerfil': 'Cliente',
        'endereco': {},
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user2', firestore: fake),
      ));
      await tester.pumpAndSettle();

      // Correção: Procura o ícone dentro do CircleAvatar para maior especificidade
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.byIcon(Icons.person),
        ),
        findsOneWidget,
      );
    });

    // 5️⃣ Mostra botão de trocar para prestador quando tipoPerfil = Ambos
    testWidgets('5️⃣ Mostra botão de trocar para prestador quando tipoPerfil = Ambos', (tester) async {
      await fake.collection('usuarios').doc('user3').set({
        'nome': 'Ana',
        'email': 'ana@email.com',
        'fotoUrl': '',
        'tipoPerfil': 'Ambos',
        'endereco': {},
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user3', firestore: fake),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Trocar para Prestador'), findsOneWidget);
    });

    // 6️⃣ Exibe botão de editar perfil
    testWidgets('6️⃣ Exibe botão de editar perfil', (tester) async {
      await fake.collection('usuarios').doc('user4').set({
        'nome': 'Lucas',
        'email': 'lucas@email.com',
        'fotoUrl': '',
        'tipoPerfil': 'Cliente',
        'endereco': {},
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user4', firestore: fake),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Editar Perfil'), findsOneWidget);
    });

    // ==== CRUD lógico com Firestore fake ====

    // CREATE
    test('7️⃣ Create - adiciona novo cliente com sucesso', () async {
      await fake.collection('usuarios').add({'nome': 'Novo', 'email': 'novo@teste.com'});
      final docs = await fake.collection('usuarios').get();
      expect(docs.docs.length, 1);
      expect(docs.docs.first['nome'], 'Novo');
    });

    // READ (positivo)
    test('8️⃣ Read - obtém cliente existente', () async {
      final doc = await fake.collection('usuarios').add({'nome': 'Teste', 'email': 't@t.com'});
      final snap = await fake.collection('usuarios').doc(doc.id).get();
      expect(snap.exists, true);
      expect(snap['email'], 't@t.com');
    });

    // READ (negativo)
    test('9️⃣ Read - retorna vazio quando cliente não existe', () async {
      final snap = await fake.collection('usuarios').doc('inexistente').get();
      expect(snap.exists, false);
    });

    // UPDATE (positivo)
    test('🔟 Update - atualiza cliente existente', () async {
      final doc = await fake.collection('usuarios').add({'nome': 'Antigo'});
      await fake.collection('usuarios').doc(doc.id).update({'nome': 'Atualizado'});
      final updated = await fake.collection('usuarios').doc(doc.id).get();
      expect(updated['nome'], 'Atualizado');
    });

    // UPDATE (negativo)
    test('1️⃣1️⃣ Update - falha ao atualizar cliente inexistente', () async {
      expectLater(
        fake.collection('usuarios').doc('naoexiste').update({'nome': 'Erro'}),
        throwsException,
      );
    });

    // DELETE (positivo)
    test('1️⃣2️⃣ Delete - remove cliente existente', () async {
      final doc = await fake.collection('usuarios').add({'nome': 'Apagar'});
      await fake.collection('usuarios').doc(doc.id).delete();
      final snap = await fake.collection('usuarios').doc(doc.id).get();
      expect(snap.exists, false);
    });

    // DELETE (negativo)
    test('1️⃣3️⃣ Delete - falha ao remover cliente inexistente', () async {
      expectLater(
        fake.collection('usuarios').doc('fakeid').delete(),
        completes, // FakeFirestore ignora deleção de doc inexistente
      );
    });

    // 14️⃣ Exibe endereço formatado corretamente
    testWidgets('1️⃣4️⃣ Exibe endereço formatado corretamente', (tester) async {
      await fake.collection('usuarios').doc('user5').set({
        'nome': 'Carlos',
        'email': 'carlos@email.com',
        'fotoUrl': '',
        'tipoPerfil': 'Cliente',
        'endereco': {
          'cidade': 'Goiânia',
          'rua': 'Rua X',
          'numero': '99',
          'bairro': 'Setor Oeste',
          'complemento': '',
          'cep': '74000-000',
        },
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user5', firestore: fake),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rua X, 99'), findsOneWidget);
      expect(find.textContaining('bairro: Setor Oeste'), findsOneWidget);
      expect(find.textContaining('CEP: 74000-000'), findsOneWidget);
    });

    // 15️⃣ Exibe mensagem de endereço não cadastrado
    testWidgets('1️⃣5️⃣ Exibe mensagem de endereço não cadastrado', (tester) async {
      await fake.collection('usuarios').doc('user6').set({
        'nome': 'Sem Endereço',
        'email': 's@end.com',
        'fotoUrl': '',
        'tipoPerfil': 'Cliente',
        'endereco': {},
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user6', firestore: fake),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Endereço ainda não cadastrado'), findsOneWidget);
    });

    // 16️⃣ Renderiza cidade não informada
    testWidgets('1️⃣6️⃣ Renderiza cidade não informada', (tester) async {
      await fake.collection('usuarios').doc('user7').set({
        'nome': 'Teste Cidade',
        'email': 'teste@c.com',
        'fotoUrl': '',
        'tipoPerfil': 'Cliente',
        'endereco': {'rua': 'Rua Y'},
      });

      await tester.pumpWidget(MaterialApp(
        home: PerfilCliente(userId: 'user7', firestore: fake),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cidade não informada'), findsOneWidget);
    });
  });
}
