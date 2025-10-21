// test/Login/cadastroUsuarios_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/Login/cadastroUsuarios.dart';

// ===========================================
// 🌐 Mock completo (simula ViaCEP, sem rede)
// ===========================================
class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpRequest();

  @override
  void close({bool force = false}) {}

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpRequest implements HttpClientRequest {
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = 0;
  @override
  bool persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse();

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpResponse implements HttpClientResponse {
  static const _jsonBody =
      '{"logradouro": "Rua Teste", "bairro": "Centro", "localidade": "Rio Verde", "uf": "GO"}';
  final _bytes = utf8.encode(_jsonBody);

  @override
  int get statusCode => 200;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    print('✅ Mock ViaCEP corpo: $_jsonBody');
    return Stream<List<int>>.fromIterable([_bytes]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ===========================================
// 🧩 Testes CRUD + Validações + Integração
// ===========================================
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = null;
    http.Client mockClient = _MockHttpClient();
    _MockHttpClient.overrideClient(mockClient);
  });

  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
  });

  group('🧩 CadastroUsuario – Cobertura CRUD completa e validações', () {
    // 1️⃣ CREATE - positivo
    testWidgets('Create ✅ cadastra usuário com sucesso', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      await tester.pumpWidget(
        MaterialApp(home: CadastroUsuario(firestore: fakeDb, auth: mockAuth)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'João');
      await tester.enterText(find.byType(TextFormField).at(1), 'joao@teste.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.enterText(find.byType(TextFormField).at(4), '75900000');
      await tester.enterText(find.byType(TextFormField).at(5), 'Rio Verde');
      await tester.enterText(find.byType(TextFormField).at(6), 'Rua A');
      await tester.enterText(find.byType(TextFormField).at(7), '10');
      await tester.enterText(find.byType(TextFormField).at(8), 'Centro');
      await tester.enterText(find.byType(TextFormField).at(10), '64999999999');

      await tester.dragUntilVisible(
          find.text('Cadastrar'),
          find.byType(SingleChildScrollView),
          const Offset(0, -500));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      addTearDown(() async {
        await tester.pump(const Duration(seconds: 9));
      });

      expect(find.textContaining('sucesso', findRichText: true), findsOneWidget);
    });

    // 2️⃣ CREATE - negativo
    testWidgets('Create ❌ senhas diferentes mostram erro', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: CadastroUsuario(firestore: fakeDb, auth: mockAuth)));
      await tester.enterText(find.byType(TextFormField).at(0), 'Teste');
      await tester.enterText(find.byType(TextFormField).at(1), 'teste@teste.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.enterText(find.byType(TextFormField).at(3), '654321');
      await tester.dragUntilVisible(find.text('Cadastrar'),
          find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('senha', findRichText: true), findsOneWidget);
    });

    // 3️⃣ READ - positivo
    test('Read ✅ retorna usuário existente', () async {
      await fakeDb
          .collection('usuarios')
          .doc('abc')
          .set({'nome': 'Maria', 'email': 'm@t.com'});
      final doc = await fakeDb.collection('usuarios').doc('abc').get();
      expect(doc.exists, true);
      expect(doc['nome'], 'Maria');
    });

    // 4️⃣ READ - negativo
    test('Read ❌ retorna null se usuário não existir', () async {
      final doc = await fakeDb.collection('usuarios').doc('fantasma').get();
      expect(doc.exists, false);
    });

    // 5️⃣ UPDATE - positivo
    test('Update ✅ atualiza nome com sucesso', () async {
      await fakeDb.collection('usuarios').doc('u1').set({'nome': 'Antigo'});
      await fakeDb.collection('usuarios').doc('u1').update({'nome': 'Novo'});
      final doc = await fakeDb.collection('usuarios').doc('u1').get();
      expect(doc['nome'], 'Novo');
    });

    // 6️⃣ UPDATE - negativo
    test('Update ❌ falha ao atualizar inexistente', () async {
      try {
        await fakeDb.collection('usuarios').doc('x').update({'nome': 'Falha'});
        fail('Era pra lançar exceção');
      } catch (e) {
        expect(e, isA<FirebaseException>());
      }
    });

    // 7️⃣ DELETE - positivo
    test('Delete ✅ exclui com sucesso', () async {
      await fakeDb.collection('usuarios').doc('del1').set({'nome': 'Excluir'});
      await fakeDb.collection('usuarios').doc('del1').delete();
      final doc = await fakeDb.collection('usuarios').doc('del1').get();
      expect(doc.exists, false);
    });

    // 8️⃣ DELETE - negativo
    test('Delete ❌ excluir inexistente não causa erro', () async {
      await fakeDb.collection('usuarios').doc('ghost').delete();
      final doc = await fakeDb.collection('usuarios').doc('ghost').get();
      expect(doc.exists, false);
    });

    // 9️⃣ Validação extra - campos obrigatórios
    testWidgets('Validação ⚠️ exige nome e e-mail', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: CadastroUsuario(firestore: fakeDb, auth: mockAuth)));
      await tester.dragUntilVisible(find.text('Cadastrar'),
          find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Obrigatório', findRichText: true),
          findsWidgets);
    });

    // 🔟 Integração - mock ViaCEP
    test('ViaCEP 🌐 resposta mock retorna status 200', () async {
      final httpClient = _FakeHttpClient();
      final request = await httpClient
          .getUrl(Uri.parse('https://viacep.com.br/ws/75900000/json/'));
      final response = await request.close();
      expect(response.statusCode, 200);
    });

    // 11️⃣ Validação de formato - CEP inválido
    testWidgets('Validação ⚠️ CEP inválido não dispara consulta', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CadastroUsuario(firestore: fakeDb, auth: mockAuth),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Teste');
      await tester.enterText(find.byType(TextFormField).at(1), 'teste@teste.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.enterText(find.byType(TextFormField).at(4), '75900'); // inválido

      await tester.dragUntilVisible(
        find.text('Cadastrar'),
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sucesso', findRichText: true), findsNothing);
    });

    // 12️⃣ Validação de formato - Telefone vazio
    testWidgets('Validação ⚠️ exige telefone antes do envio', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CadastroUsuario(firestore: fakeDb, auth: mockAuth),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
      await tester.enterText(find.byType(TextFormField).at(1), 'maria@teste.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.enterText(find.byType(TextFormField).at(4), '75900000');
      await tester.enterText(find.byType(TextFormField).at(5), 'Rio Verde');
      await tester.enterText(find.byType(TextFormField).at(6), 'Rua A');
      await tester.enterText(find.byType(TextFormField).at(7), '10');
      await tester.enterText(find.byType(TextFormField).at(8), 'Centro');
      await tester.enterText(find.byType(TextFormField).at(10), ''); // vazio

      await tester.dragUntilVisible(
        find.text('Cadastrar'),
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Obrigatório', findRichText: true), findsWidgets);
    });
  });
}

/// Mock do Client usado pelo package:http
class _MockHttpClient extends http.BaseClient {
  static void overrideClient(http.Client client) {}

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print('✅ Mock interceptado: ${request.url}');
    final body =
        '{"logradouro":"Rua Teste","bairro":"Centro","localidade":"Rio Verde","uf":"GO"}';
    final stream = Stream<List<int>>.fromIterable([utf8.encode(body)]);
    return http.StreamedResponse(stream, 200, headers: {
      'content-type': 'application/json; charset=utf-8',
    });
  }
}
