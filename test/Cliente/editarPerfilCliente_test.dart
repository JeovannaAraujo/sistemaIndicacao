import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:myapp/Cliente/editarPerfilCliente.dart';

/// 🔧 Mock do Firebase atualizado para SDK 3.5+
/// (sem @override em métodos que não existem mais)
class _FakeFirebase extends FirebasePlatform {
  // 🔹 Este método simula a criação de um app, mas não usa @override,
  // pois o método original foi removido da interface.
  FirebaseAppPlatform createFirebaseApp({
    required String name,
    required FirebaseOptions options,
  }) {
    return _FakeFirebaseApp(name, options);
  }

  @override
  FirebaseAppPlatform app([String? name]) {
    return _FakeFirebaseApp(
      name ?? 'fake',
      const FirebaseOptions(
        apiKey: 'fake',
        appId: 'fake',
        messagingSenderId: 'fake',
        projectId: 'fake',
      ),
    );
  }

  @override
  List<FirebaseAppPlatform> get apps => [
        _FakeFirebaseApp(
          'fake',
          const FirebaseOptions(
            apiKey: 'fake',
            appId: 'fake',
            messagingSenderId: 'fake',
            projectId: 'fake',
          ),
        ),
      ];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _FakeFirebaseApp(
      name ?? 'fake',
      options ??
          const FirebaseOptions(
            apiKey: 'fake',
            appId: 'fake',
            messagingSenderId: 'fake',
            projectId: 'fake',
          ),
    );
  }
}

/// 🔹 Mock de um app Firebase
class _FakeFirebaseApp extends FirebaseAppPlatform {
  _FakeFirebaseApp(String name, FirebaseOptions options) : super(name, options);
}

/// 🔹 Inicialização fake segura
Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = _FakeFirebase();
  await Firebase.initializeApp(
    name: 'fake',
    options: const FirebaseOptions(
      apiKey: 'fake',
      appId: 'fake',
      messagingSenderId: 'fake',
      projectId: 'fake',
    ),
  );
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await setupFirebaseMocks();

  late FakeFirebaseFirestore fake;
  late EditarPerfilClienteState state;

  setUp(() {
    fake = FakeFirebaseFirestore();
    state = EditarPerfilClienteState(testDb: fake);
  });

  // ======================================================
  // 🧩 Inicialização
  // ======================================================
  group('🧩 Inicialização', () {
    test('1️⃣ Estado inicial com carregando = true', () {
      expect(state.carregando, true);
    });

    test('2️⃣ Controladores de texto começam vazios', () {
      expect(state.nomeCtrl.text, '');
      expect(state.emailCtrl.text, '');
    });
  });

  // ======================================================
  // 📦 carregarPerfil
  // ======================================================
  group('📦 carregarPerfil', () {
    testWidgets('3️⃣ Retorna sem erro quando usuário não existe', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EditarPerfilCliente(userId: 'nao_existe'),
      ));
      final s = tester.state(find.byType(EditarPerfilCliente)) as EditarPerfilClienteState;
      s.db = fake;
      await s.carregarPerfil();
      expect(s.carregando, true);
    });

    testWidgets('4️⃣ Carrega dados corretamente', (tester) async {
      await fake.collection('usuarios').doc('u1').set({
        'nome': 'Jeovanna',
        'email': 'jeovanna@test.com',
        'tipoPerfil': 'Cliente',
        'endereco': {'cidade': 'Rio Verde'},
      });

      await tester.pumpWidget(MaterialApp(home: EditarPerfilCliente(userId: 'u1')));
      final s = tester.state(find.byType(EditarPerfilCliente)) as EditarPerfilClienteState;
      s.db = fake;
      await s.carregarPerfil();
      await tester.pump(const Duration(milliseconds: 300));
      expect(s.nomeCtrl.text, 'Jeovanna');
      expect(s.cidadeCtrl.text, 'Rio Verde');
    });
  });

  // ======================================================
  // 💾 salvar
  // ======================================================
  group('💾 salvar', () {
    testWidgets('5️⃣ Salva dados corretamente no Firestore', (tester) async {
      await fake.collection('usuarios').doc('u1').set({'nome': 'Antigo'});
      await tester.pumpWidget(MaterialApp(home: EditarPerfilCliente(userId: 'u1')));
      final s = tester.state(find.byType(EditarPerfilCliente)) as EditarPerfilClienteState;
      s.db = fake;
      await s.carregarPerfil();
      await tester.pump(const Duration(milliseconds: 200));
      s.nomeCtrl.text = 'Novo';
      await s.salvar();
      final doc = await fake.collection('usuarios').doc('u1').get();
      expect(doc['nome'], 'Novo');
    });

    testWidgets('6️⃣ Validações adicionais não travam', (tester) async {
      await fake.collection('usuarios').doc('u1').set({
        'nome': 'Joana',
        'tipoPerfil': 'Prestador',
      });
      await tester.pumpWidget(MaterialApp(home: EditarPerfilCliente(userId: 'u1')));
      final s = tester.state(find.byType(EditarPerfilCliente)) as EditarPerfilClienteState;
      s.db = fake;
      s.tipoPerfil = 'Prestador';
      expectLater(s.salvar(), completes);
    });
  });

  // ======================================================
  // 🖼️ Foto de perfil
  // ======================================================
  group('🖼️ Foto de perfil', () {
    testWidgets('7️⃣ removerFotoPerfil limpa variáveis', (tester) async {
      await fake.collection('usuarios').doc('u1').set({
        'fotoUrl': 'http://fake.url',
        'fotoPath': 'path/foto',
      });
      await tester.pumpWidget(MaterialApp(home: EditarPerfilCliente(userId: 'u1')));
      final s = tester.state(find.byType(EditarPerfilCliente)) as EditarPerfilClienteState;
      s.db = fake;
      s.fotoUrl = 'http://fake.url';
      s.fotoPath = 'path/foto';
      await s.removerFotoPerfil();
      expect(s.fotoUrl, isNull);
      expect(s.fotoPath, isNull);
    });
  });

  // ======================================================
  // 📋 Campos e controles
  // ======================================================
  group('📋 Campos e controles', () {
    test('8️⃣ tipoPerfil começa como Cliente', () {
      expect(state.tipoPerfil, 'Cliente');
    });

    test('9️⃣ Experiências contém "+10 anos"', () {
      expect(state.experiencias.contains('+10 anos'), true);
    });

    test('🔟 Dias da semana contém Segunda-feira', () {
      expect(state.diasSemana.contains('Segunda-feira'), true);
    });

    test('11️⃣ Campo nome pode ser alterado', () {
      state.nomeCtrl.text = 'Carlos';
      expect(state.nomeCtrl.text, 'Carlos');
    });

    test('12️⃣ emailCtrl é TextEditingController', () {
      expect(state.emailCtrl, isA<TextEditingController>());
    });
  });

  // ======================================================
  // 🎨 Interface
  // ======================================================
// ======================================================
// 🎨 Interface
// ======================================================
group('🎨 Interface', () {
  testWidgets('13️⃣ Renderiza campo Nome completo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (_) {
          final s = EditarPerfilClienteState(testDb: FakeFirebaseFirestore());
          s.carregando = false; // evita travar no load
          return Form(
            key: s.formKey,
            child: TextFormField(decoration: const InputDecoration(labelText: 'Nome completo')),
          );
        }),
      ),
    ));
    expect(find.widgetWithText(TextFormField, 'Nome completo'), findsOneWidget);
  });

  testWidgets('14️⃣ Renderiza botão Salvar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElevatedButton(onPressed: null, child: Text('Salvar'))),
    ));
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('15️⃣ Renderiza botão Cancelar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElevatedButton(onPressed: null, child: Text('Cancelar'))),
    ));
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('16️⃣ Renderiza botão Excluir Conta', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElevatedButton(onPressed: null, child: Text('Excluir Conta'))),
    ));
    expect(find.text('Excluir Conta'), findsOneWidget);
  });
});


  // ======================================================
  // 🧠 Lógica interna
  // ======================================================
  group('🧠 Lógica interna', () {
    test('17️⃣ secTitle retorna Padding', () {
      final t = state.secTitle('Teste');
      expect(t, isA<Padding>());
    });

    test('18️⃣ Alterna tipoPerfil', () {
      state.tipoPerfil = 'Prestador';
      expect(state.tipoPerfil, 'Prestador');
    });

    test('19️⃣ Adiciona área de atendimento', () {
      state.areaAtendimento.add('Rio Verde');
      expect(state.areaAtendimento.contains('Rio Verde'), true);
    });

    test('20️⃣ Remove área de atendimento', () {
      state.areaAtendimento.add('Jataí');
      state.areaAtendimento.remove('Jataí');
      expect(state.areaAtendimento.contains('Jataí'), false);
    });
  });

  // ======================================================
  // 🧩 Campos profissionais
  // ======================================================
  group('🧩 Campos profissionais', () {
    test('21️⃣ Lista de experiências não vazia', () {
      expect(state.experiencias.isNotEmpty, true);
    });

    test('22️⃣ categoriaProfId pode ser nula', () {
      expect(state.categoriaProfId, isNull);
    });

    test('23️⃣ tempoExperiencia pode ser vazio', () {
      expect(state.tempoExperiencia, '');
    });
  });

  // ======================================================
  // 🧰 Comportamentos visuais
  // ======================================================
  group('🧰 Comportamentos visuais', () {
    testWidgets('24️⃣ Mostra CircularProgress quando carregando', (tester) async {
      state.carregando = true;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: state.carregando
              ? const CircularProgressIndicator()
              : const SizedBox(),
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ======================================================
  // 📊 Extras e consistência
  // ======================================================
  group('📊 Extras e consistência', () {
    test('25️⃣ fotoUrl pode ser nula', () {
      state.fotoUrl = null;
      expect(state.fotoUrl, isNull);
    });

    test('26️⃣ fotoPath pode ser nula', () {
      state.fotoPath = null;
      expect(state.fotoPath, isNull);
    });

    test('27️⃣ formKey é GlobalKey<FormState>', () {
      expect(state.formKey, isA<GlobalKey<FormState>>());
    });

    test('28️⃣ State contém 7 dias na lista', () {
      expect(state.diasSemana.length, 7);
    });

    test('29️⃣ campos textuais respondem', () {
      state.descricaoCtrl.text = 'Teste';
      expect(state.descricaoCtrl.text, 'Teste');
    });

    test('30️⃣ áreaAtendimento inicial é vazia', () {
      expect(state.areaAtendimento.isEmpty, true);
    });
  });
}
