import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:myapp/Cliente/editar_perfil_cliente.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseStorage mockStorage;

  setUpAll(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockStorage = MockFirebaseStorage();
  });

  group('🧪 Testes da tela EditarPerfilCliente', () {
    testWidgets('1️⃣ Renderiza tela corretamente', (tester) async {
      await fakeFirestore.collection('usuarios').doc('u1').set({
        'nome': 'Maria Teste',
        'email': 'maria@teste.com',
        'tipoPerfil': 'Cliente',
        'endereco': {'whatsapp': '62999999999', 'cidade': 'Rio Verde'},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilCliente(
            userId: 'u1',
            firestore: fakeFirestore,
            auth: mockAuth,
            storage: mockStorage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Editar Perfil'), findsOneWidget);
      expect(find.text('Informações Pessoais'), findsOneWidget);
      expect(find.text('Endereço e Contato'), findsOneWidget);
    });

    testWidgets('2️⃣ Exibe dados carregados do Firestore', (tester) async {
      await fakeFirestore.collection('usuarios').doc('u2').set({
        'nome': 'João da Silva',
        'email': 'joao@teste.com',
        'tipoPerfil': 'Cliente',
        'endereco': {'cidade': 'Goiânia', 'whatsapp': '62988888888'},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilCliente(
            userId: 'u2',
            firestore: fakeFirestore,
            auth: mockAuth,
            storage: mockStorage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pode aparecer mais de uma vez (campo + topo)
      expect(find.text('João da Silva'), findsWidgets);
      expect(find.text('joao@teste.com'), findsOneWidget);
    });

    testWidgets('3️⃣ Permite alterar nome e salvar', (tester) async {
      await fakeFirestore.collection('usuarios').doc('u3').set({
        'nome': 'Ana Original',
        'email': 'ana@teste.com',
        'tipoPerfil': 'Cliente',
        'endereco': {'cidade': 'Mineiros'},
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilCliente(
            userId: 'u3',
            firestore: fakeFirestore,
            auth: mockAuth,
            storage: mockStorage,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Encontra o campo de nome e altera
      final nomeField = find.byType(TextFormField).first;
      await tester.enterText(nomeField, 'Ana Atualizada');

      // Rola até o botão salvar
      await tester.scrollUntilVisible(
        find.text('Salvar Alterações'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final doc = await fakeFirestore.collection('usuarios').doc('u3').get();
      expect(doc.data()?['nome'], equals('Ana Atualizada'));
    });

    testWidgets('4️⃣ Cancela e volta para a tela anterior', (tester) async {
      // Configurar dados
      await fakeFirestore.collection('usuarios').doc('u4').set({
        'nome': 'Teste User',
        'email': 'teste@teste.com',
        'tipoPerfil': 'Cliente',
        'endereco': {'cidade': 'Test City', 'whatsapp': '62999999999'},
      });

      // Criar um navigator simples com rota inicial e rota de edição
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) {
                  return EditarPerfilCliente(
                    userId: 'u4',
                    firestore: fakeFirestore,
                    auth: mockAuth,
                    storage: mockStorage,
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que a tela está visível
      expect(find.text('Editar Perfil'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Rola até o botão e toca nele
      await tester.scrollUntilVisible(
        find.text('Cancelar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // ✅ Verificar que o pop foi chamado e o widget não está mais visível
      expect(find.byType(EditarPerfilCliente), findsNothing);
    });
  });
}
