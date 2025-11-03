import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/visualizar_perfil_prestador.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  // -------------------- READ --------------------
  group('📖 READ (Leitura)', () {
    test('1️⃣ ServicoItem.formatPreco converte número corretamente', () {
      const item = ServicoItem(
        serviceId: 's1',
        prestadorId: 'p1',
        data: {},
      );
      expect(item.formatPreco(50), 'R\$50,00');
      expect(item.formatPreco('1.200,50'), 'R\$1200,50');
    });

    test('2️⃣ ServicoItem.formatPreco lida com nulos', () {
      const item = ServicoItem(
        serviceId: 's1',
        prestadorId: 'p1',
        data: {},
      );
      expect(item.formatPreco(null), 'R\$0,00');
      expect(item.formatPreco('abc'), 'R\$0,00');
    });
  });

  // -------------------- CREATE --------------------
  group('🧩 CREATE (Criação)', () {
    testWidgets('3️⃣ Renderiza cabeçalho do prestador com média simulada', (tester) async {
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'p1',
        'nota': 5,
        'solicitacaoId': 'sol1',
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Header(
            prestadorId: 'p1',
            nome: 'João da Silva',
            email: 'joao@email.com',
            fotoUrl: '',
            categoria: 'Eletricista',
            cidade: 'Rio Verde',
            whatsapp: '64 99999-9999',
            nota: 4.5,
            avaliacoes: 12,
            firestore: fakeDb, // ✅ injeta fakeDb
          ),
        ),
      ));

      // 🔹 Dá tempo pro FutureBuilder resolver
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('João da Silva'), findsOneWidget);
      expect(find.textContaining('Eletricista'), findsOneWidget);
      expect(find.textContaining('Rio Verde'), findsOneWidget);
      expect(find.textContaining('5.0'), findsWidgets);
    });

    testWidgets('4️⃣ Mostra texto padrão quando campos vazios', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Header(
            prestadorId: 'p1',
            nome: '',
            email: '',
            fotoUrl: '',
            categoria: '',
            cidade: '',
            whatsapp: '',
            nota: null,
            avaliacoes: null,
            firestore: fakeDb, // ✅ injeta fakeDb
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Categoria não informada'), findsOneWidget);
      expect(find.text('Cidade não informada'), findsOneWidget);
    });
  });

  // -------------------- UPDATE --------------------
  group('🧠 UPDATE (Atualização)', () {
    test('5️⃣ ServicoItem.abreviacaoUnidade retorna sigla do FakeFirestore', () async {
      await fakeDb
          .collection(VisualizarPerfilPrestador.colUnidades)
          .doc('u1')
          .set({'abreviacao': 'm²'});

      final item = ServicoItem(
        serviceId: 's1',
        prestadorId: 'p1',
        data: const {},
        firestore: fakeDb,
      );

      final res = await item.abreviacaoUnidade('u1');
      expect(res, 'm²');
    });

    test('6️⃣ ServicoItem.imagemDaCategoria retorna URL do FakeFirestore', () async {
      await fakeDb
          .collection(VisualizarPerfilPrestador.colCategoriasServ)
          .doc('c1')
          .set({'imagemUrl': 'https://exemplo.com/img.jpg'});

      final item = ServicoItem(
        serviceId: 's1',
        prestadorId: 'p1',
        data: const {},
        firestore: fakeDb,
      );

      final res = await item.imagemDaCategoria('c1');
      expect(res, 'https://exemplo.com/img.jpg');
    });
  });

  // -------------------- DELETE --------------------
  group('🗑️ DELETE (Falhas / Limpeza)', () {
    test('7️⃣ abreviacaoUnidade retorna vazio quando id é nulo ou inexistente', () async {
      final item = ServicoItem(
        serviceId: 's1',
        prestadorId: 'p1',
        data: const {},
        firestore: fakeDb,
      );

      expect(await item.abreviacaoUnidade(''), '');
    });

    test('8️⃣ imagemDaCategoria retorna vazio quando id é nulo ou inexistente', () async {
      final item = ServicoItem(
        serviceId: 's1',
        prestadorId: 'p1',
        data: const {},
        firestore: fakeDb,
      );

      expect(await item.imagemDaCategoria(''), '');
    });
  });

  // -------------------- INTERFACE --------------------
  group('🎨 INTERFACE', () {
    testWidgets('9️⃣ Renderiza lista de serviços vazia', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListaServicos(
            prestadorId: 'p1',
            firestore: fakeDb,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Nenhum serviço cadastrado'), findsOneWidget);
    });

    testWidgets('🔟 Renderiza ServicoItem com média e avaliações', (tester) async {
      // simula avaliação real
      await fakeDb.collection('avaliacoes').add({
        'prestadorId': 'p1',
        'solicitacaoId': 'sol1',
        'nota': 5,
      });

      await fakeDb.collection('solicitacoesOrcamento').doc('sol1').set({
        'servicoId': 's1',
      });

      final data = {
        'titulo': 'Teste Serviço',
        'descricao': 'Descrição top',
        'categoriaId': 'c1',
        'unidadeId': 'u1',
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ServicoItem(
            serviceId: 's1',
            prestadorId: 'p1',
            data: data,
            firestore: fakeDb,
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('Teste Serviço'), findsOneWidget);
      expect(find.textContaining('5.0'), findsWidgets);
      expect(find.textContaining('1 avaliação'), findsWidgets);
    });
  });
}
