import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:myapp/Prestador/editar_perfil_prestador.dart';

// 🔁 Função para evitar travamentos em streams infinitas
Future<void> settleShort(WidgetTester tester, [int maxMs = 2000]) async {
  final end = DateTime.now().add(Duration(milliseconds: maxMs));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.any(find.byType(CircularProgressIndicator))) break;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseStorage fakeStorage;
  const userId = 'prest123';

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: userId, email: 'teste@prest.com'),
    );
    fakeStorage = MockFirebaseStorage();

    await fakeDb.collection('usuarios').doc(userId).set({
      'nome': 'João Prestador',
      'email': 'teste@prest.com',
      'tipoPerfil': 'Prestador',
      'descricao': 'Serviços elétricos',
      'tempoExperiencia': '3-5 anos',
      'endereco': {'cidade': 'Rio Verde', 'whatsapp': '62999999999'},
    });

    await fakeDb.collection('categoriasProfissionais').doc('eletricista').set({
      'nome': 'Eletricista',
      'ativo': true,
    });
  });

  // ============================================================
  testWidgets('🟢 Carrega dados e renderiza nome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 800,
          child: Scaffold(
            body: EditarPerfilPrestador(
              userId: userId,
              firestore: fakeDb,
              auth: mockAuth,
              storage: fakeStorage,
            ),
          ),
        ),
      ),
    );

    await settleShort(tester);

    expect(find.text('João Prestador'), findsWidgets);
    expect(find.text('Rio Verde'), findsWidgets);
  });

  // ============================================================
  testWidgets('⚠️ Mostra erro se categoria inativa', (tester) async {
    await fakeDb.collection('categoriasProfissionais').doc('pedreiro').set({
      'nome': 'Pedreiro',
      'ativo': false,
    });

    await fakeDb.collection('usuarios').doc(userId).update({
      'categoriaProfissionalId': 'pedreiro',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 800,
          child: Scaffold(
            body: EditarPerfilPrestador(
              userId: userId,
              firestore: fakeDb,
              auth: mockAuth,
              storage: fakeStorage,
            ),
          ),
        ),
      ),
    );

    await settleShort(tester);

    final salvar = find.text('Salvar');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('não está mais ativa'), findsOneWidget);
  });

  // ============================================================
  testWidgets('🖼️ Remove foto de perfil', (tester) async {
    await fakeDb.collection('usuarios').doc(userId).update({
      'fotoUrl': 'https://fakeurl.com/perfil.jpg',
      'fotoPath': 'usuarios/prest123/perfil.jpg',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 800,
          child: Scaffold(
            body: EditarPerfilPrestador(
              userId: userId,
              firestore: fakeDb,
              auth: mockAuth,
              storage: fakeStorage,
            ),
          ),
        ),
      ),
    );

    await settleShort(tester);

    final remover = find.text('Remover foto');
    await tester.ensureVisible(remover);
    await tester.tap(remover, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2)); // ✅ aguarda Firestore e setState

    // Verifica estado interno
    final state =
        tester.state<EditarPerfilPrestadorState>(find.byType(EditarPerfilPrestador));
    expect(state.fotoUrl, isNull);

    // Verifica Firestore
    final doc = await fakeDb.collection('usuarios').doc(userId).get();
    expect(doc.data()?['fotoUrl'], isNull);
    expect(doc.data()?['fotoPath'], isNull);
  });

  // ============================================================
  testWidgets('🟣 Atualiza nome e salva com sucesso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 800,
          child: Scaffold(
            body: EditarPerfilPrestador(
              userId: userId,
              firestore: fakeDb,
              auth: mockAuth,
              storage: fakeStorage,
            ),
          ),
        ),
      ),
    );

    await settleShort(tester);

    await tester.enterText(find.byType(TextFormField).first, 'José Técnico');
    final salvar = find.text('Salvar');
    await tester.ensureVisible(salvar);
    await tester.tap(salvar, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));

    final doc = await fakeDb.collection('usuarios').doc(userId).get();
    expect(doc.data()?['nome'], 'José Técnico');
  });

  // ============================================================
  testWidgets('🗑️ Exclui conta e serviços associados', (tester) async {
    await fakeDb.collection('servicos').add({
      'prestadorId': userId,
      'nome': 'Serviço de teste',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 800,
          child: Scaffold(
            body: EditarPerfilPrestador(
              userId: userId,
              firestore: fakeDb,
              auth: mockAuth,
              storage: fakeStorage,
            ),
          ),
        ),
      ),
    );

    await settleShort(tester);

    final excluir = find.text('Excluir Conta');
    await tester.ensureVisible(excluir);
    await tester.tap(excluir, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    // Aguarda o diálogo abrir
    final confirmar = find.text('Excluir');
    expect(confirmar, findsOneWidget);
    await tester.tap(confirmar, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));

    final userDoc = await fakeDb.collection('usuarios').doc(userId).get();
    expect(userDoc.exists, false);
  });

  // ============================================================
  testWidgets('↩️ Botão Cancelar retorna à tela anterior', (tester) async {
    bool saiuDaTela = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          // ignore: deprecated_member_use
          onPopPage: (route, result) {
            saiuDaTela = true;
            return route.didPop(result);
          },
          pages: [
            const MaterialPage(child: SizedBox()),
            MaterialPage(
              child: SizedBox(
                height: 800,
                child: Scaffold(
                  body: EditarPerfilPrestador(
                    userId: userId,
                    firestore: fakeDb,
                    auth: mockAuth,
                    storage: fakeStorage,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await settleShort(tester);

    final cancelar = find.text('Cancelar');
    await tester.ensureVisible(cancelar);
    await tester.tap(cancelar, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 800));

    expect(saiuDaTela, isTrue);
  });
}
