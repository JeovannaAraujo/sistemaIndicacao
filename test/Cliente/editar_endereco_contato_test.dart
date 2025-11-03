import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:myapp/Cliente/editar_endereco_contato.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
  });

  group('🧪 Testes da tela EditarEnderecoContatoScreen', () {
    testWidgets('1️⃣ Renderiza tela corretamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditarEnderecoContatoScreen(
            userId: 'u1',
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar Endereço e Contato'), findsOneWidget);
      expect(find.text('Contato'), findsOneWidget);
      expect(find.text('Endereço'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('2️⃣ Carrega dados do Firestore e aplica máscaras', (tester) async {
      await fakeFirestore.collection('usuarios').doc('u2').set({
        'endereco': {
          'whatsapp': '62999999999',
          'cep': '12345678',
          'cidade': 'Rio Verde',
          'rua': 'Rua das Flores',
          'numero': '45',
          'bairro': 'Centro',
          'complemento': 'Apto 2',
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EditarEnderecoContatoScreen(
            userId: 'u2',
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('(62) 99999-9999'), findsOneWidget);
      expect(find.text('12345-678'), findsOneWidget);
      expect(find.text('Rio Verde'), findsOneWidget);
      expect(find.text('Rua das Flores'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Centro'), findsOneWidget);
      expect(find.text('Apto 2'), findsOneWidget);
    });

    testWidgets('3️⃣ Valida campos obrigatórios e exibe erro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditarEnderecoContatoScreen(
            userId: 'u3',
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rola até o final para garantir que o botão fique visível
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Rola de volta pra cima pra ver os erros
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.textContaining('Informe o WhatsApp'), findsOneWidget);
      expect(find.textContaining('Informe o CEP'), findsOneWidget);
      expect(find.textContaining('Informe a cidade'), findsOneWidget);
    });

    testWidgets('4️⃣ Permite alterar e salvar dados corretamente', (tester) async {
      await fakeFirestore.collection('usuarios').doc('u4').set({
        'endereco': {
          'whatsapp': '62999999999',
          'cep': '12345678',
          'cidade': 'Goiânia',
          'rua': 'Av. Brasil',
          'numero': '100',
          'bairro': 'Centro',
          'complemento': '',
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: EditarEnderecoContatoScreen(
            userId: 'u4',
            firestore: fakeFirestore,
            auth: mockAuth,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Cidade'), 'Mineiros');
      await tester.enterText(find.widgetWithText(TextFormField, 'Número'), '101');

      // Rola pra baixo pro botão
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final doc = await fakeFirestore.collection('usuarios').doc('u4').get();
      final endereco = (doc.data()?['endereco'] ?? {}) as Map<String, dynamic>;

      expect(endereco['cidade'], equals('Mineiros'));
      expect(endereco['numero'], equals('101'));
    });

    testWidgets('5️⃣ Cancela e volta para a tela anterior', (tester) async {
      await fakeFirestore.collection('usuarios').doc('u5').set({
        'endereco': {'whatsapp': '62988888888'}
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => EditarEnderecoContatoScreen(
                userId: 'u5',
                firestore: fakeFirestore,
                auth: mockAuth,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Rola até o botão "Cancelar"
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(EditarEnderecoContatoScreen), findsNothing);
    });
  });
}
