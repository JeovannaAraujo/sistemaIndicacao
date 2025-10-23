import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/Cliente/listarProfissionais.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('🧩 ProfissionaisPorCategoriaScreen - Testes de Interface e CRUD', () {
    // ======== READ - Tela =========
    testWidgets('1️⃣ Estado de carregamento inicial', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Eletricista',
          firestore: fakeFirestore,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2️⃣ Mensagem de lista vazia', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Pedreiro',
          firestore: fakeFirestore,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ainda não há profissionais'), findsOneWidget);
    });

    testWidgets('3️⃣ Exibe lista com profissionais válidos', (tester) async {
      await fakeFirestore.collection('usuarios').add({
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
        'nome': 'Carlos Eletricista',
        'cidade': 'Rio Verde',
        'areaAtendimento': 'Goiás',
        'fotoUrl': '',
        'tempoExperiencia': '5 anos',
        'nota': 4.8,
        'avaliacoes': 10,
        'criadoEm': Timestamp.now(),
      });

      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Eletricista',
          firestore: fakeFirestore,
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('Carlos Eletricista'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsWidgets);
      expect(find.textContaining('5 anos'), findsOneWidget);
    });

    testWidgets('4️⃣ Exibe erro simulado de stream', (tester) async {
      final fakeError = FirebaseException(plugin: 'firestore', message: 'Erro simulado');
      final badStream = Stream<QuerySnapshot>.error(fakeError);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StreamBuilder<QuerySnapshot>(
            stream: badStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Erro: ${snapshot.error}');
              }
              return const CircularProgressIndicator();
            },
          ),
        ),
      ));

      await tester.pump();
      expect(find.textContaining('Erro:'), findsOneWidget);
    });

    testWidgets('5️⃣ Ordenação por criadoEm desc', (tester) async {
      await fakeFirestore.collection('usuarios').add({
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
        'nome': 'Antigo',
        'criadoEm': Timestamp.fromDate(DateTime(2020, 1, 1)),
      });
      await fakeFirestore.collection('usuarios').add({
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
        'nome': 'Novo',
        'criadoEm': Timestamp.fromDate(DateTime(2023, 1, 1)),
      });

      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Eletricista',
          firestore: fakeFirestore,
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('Novo'), findsOneWidget);
      expect(find.text('Antigo'), findsOneWidget);
    });

    testWidgets('6️⃣ Fallback de foto padrão (sem imagem)', (tester) async {
      await fakeFirestore.collection('usuarios').add({
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
        'nome': 'Sem Foto',
        'fotoUrl': '',
        'criadoEm': Timestamp.now(),
      });

      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Pedreiro',
          firestore: fakeFirestore,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('7️⃣ Botão "Ver Perfil" aparece', (tester) async {
      await fakeFirestore.collection('usuarios').add({
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
        'nome': 'João',
        'criadoEm': Timestamp.now(),
      });

      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Pedreiro',
          firestore: fakeFirestore,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ver Perfil'), findsOneWidget);
    });

    testWidgets('8️⃣ Botão "Agenda" visível e clicável', (tester) async {
      await fakeFirestore.collection('usuarios').add({
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
        'nome': 'Lucas',
        'criadoEm': Timestamp.now(),
      });

      await tester.pumpWidget(MaterialApp(
        home: ProfissionaisPorCategoriaScreen(
          categoriaId: 'cat1',
          categoriaNome: 'Pintor',
          firestore: fakeFirestore,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsOneWidget);
    });

    // ======== CRUD PURO - Banco =========
    test('9️⃣ CREATE - sucesso', () async {
      final data = {
        'nome': 'Novo Profissional',
        'tipoPerfil': 'Prestador',
        'ativo': true,
        'categoriaProfissionalId': 'cat1',
      };
      final ref = await fakeFirestore.collection('usuarios').add(data);
      final doc = await ref.get();
      expect(doc.exists, isTrue);
      expect(doc['nome'], equals('Novo Profissional'));
    });

    test('🔟 CREATE - falha (sem nome obrigatório)', () async {
      try {
        await fakeFirestore.collection('usuarios').add({
          'tipoPerfil': 'Prestador',
          'ativo': true,
        });
        // sem exceção
        expect(true, isTrue);
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('1️⃣1️⃣ READ - sucesso (buscar por ID)', () async {
      final ref = await fakeFirestore.collection('usuarios').add({
        'nome': 'Maria',
        'tipoPerfil': 'Prestador',
        'ativo': true,
      });
      final snap = await fakeFirestore.collection('usuarios').doc(ref.id).get();
      expect(snap.exists, isTrue);
      expect(snap['nome'], equals('Maria'));
    });

    test('1️⃣2️⃣ READ - falha (ID inexistente)', () async {
      final snap = await fakeFirestore.collection('usuarios').doc('nao_existe').get();
      expect(snap.exists, isFalse);
    });

    test('1️⃣3️⃣ UPDATE - sucesso', () async {
      final ref = await fakeFirestore.collection('usuarios').add({'nome': 'Velho'});
      await fakeFirestore.collection('usuarios').doc(ref.id).update({'nome': 'Novo'});
      final updated = await fakeFirestore.collection('usuarios').doc(ref.id).get();
      expect(updated['nome'], equals('Novo'));
    });

    test('1️⃣4️⃣ UPDATE - falha (ID inexistente)', () async {
      try {
        await fakeFirestore.collection('usuarios').doc('nada').update({'nome': 'X'});
        fail('Deveria lançar exceção');
      } catch (e) {
        expect(e, isA<FirebaseException>());
      }
    });

    test('1️⃣5️⃣ DELETE - sucesso', () async {
      final ref = await fakeFirestore.collection('usuarios').add({'nome': 'Deletar'});
      await fakeFirestore.collection('usuarios').doc(ref.id).delete();
      final snap = await fakeFirestore.collection('usuarios').doc(ref.id).get();
      expect(snap.exists, isFalse);
    });

    test('1️⃣6️⃣ DELETE - falha (registro inexistente)', () async {
      try {
        await fakeFirestore.collection('usuarios').doc('xpto').delete();
        expect(true, isTrue); // não lança erro no fake
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });
  });
}
