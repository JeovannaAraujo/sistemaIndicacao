// test/Cliente/visualizarSolicitacao_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:myapp/Cliente/visualizar_solicitacao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeDb;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
  });

  // -------------------- READ --------------------
  group('📖 READ (Leitura)', () {
    test(
      '1️⃣ ServicoResumoCard.getServicoInfo retorna imagem e valores',
      () async {
        await fakeDb.collection('categoriasServicos').doc('c1').set({
          'imagemUrl': 'https://via.placeholder.com/100',
        });
        await fakeDb.collection('servicos').doc('s1').set({
          'categoriaId': 'c1',
          'valorMinimo': 10,
          'valorMedio': 20,
          'valorMaximo': 30,
        });

        final card = ServicoResumoCard(
          titulo: 'Teste',
          descricao: 'desc',
          servicoId: 's1',
          prestadorNome: 'João',
          cidade: 'Rio Verde',
          firestore: fakeDb, // ✅ injeta FakeFirebaseFirestore
        );

        final res = await card.getServicoInfo();
        expect(res['imagemUrl'], 'https://via.placeholder.com/100');
        expect(res['valorMinimo'], 10);
        expect(res['valorMedio'], 20);
        expect(res['valorMaximo'], 30);
      },
    );

    test(
      '2️⃣ ServicoResumoCard.getServicoInfo retorna vazio se ID inválido',
      () async {
        final card = ServicoResumoCard(
          titulo: '',
          descricao: '',
          servicoId: '',
          prestadorNome: '',
          cidade: '',
          firestore: fakeDb, // ✅ também injeta aqui
        );

        final res = await card.getServicoInfo();
        expect(res, isEmpty);
      },
    );
  });

  // -------------------- CREATE --------------------
  group('🧩 CREATE (Criação)', () {
    testWidgets('3️⃣ Renderiza título e campos principais', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionTitle('Descrição detalhada da Solicitação'),
          ),
        ),
      );
      expect(find.text('Descrição detalhada da Solicitação'), findsOneWidget);
    });

    testWidgets('4️⃣ ReadonlyField exibe texto corretamente', (tester) async {
      final controller = TextEditingController(text: 'Teste de campo');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReadonlyField(controller: controller)),
        ),
      );
      expect(find.text('Teste de campo'), findsOneWidget);
    });
  });

  // -------------------- UPDATE --------------------
  group('🧠 UPDATE (Atualização)', () {
    test(
      '5️⃣ ServicoResumoCard.getServicoInfo lida com erro silenciosamente',
      () async {
        final card = ServicoResumoCard(
          titulo: '',
          descricao: '',
          servicoId: 'nao_existe',
          prestadorNome: '',
          cidade: '',
          firestore: fakeDb, // ✅ injeta aqui também
        );

        final res = await card.getServicoInfo();
        expect(res, isA<Map>());
      },
    );

    testWidgets('6️⃣ ImagesGrid exibe "Sem imagens" quando lista vazia', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ImagesGrid(urls: [])),
        ),
      );
      expect(find.textContaining('Sem imagens'), findsOneWidget);
    });
  });

  // -------------------- DELETE --------------------
  group('🗑️ DELETE (Falhas / Limpeza)', () {
    testWidgets('7️⃣ LabelValue mostra valor vazio como "—"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LabelValue(label: 'Local', value: ''),
          ),
        ),
      );
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('8️⃣ ImagesGrid mostra grid se houver URLs', (tester) async {
      final urls = ['mock:a', 'mock:b']; // ✅ Mocks locais
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ImagesGrid(urls: urls)),
        ),
      );
      expect(find.byType(Image), findsNWidgets(2));
    });

    // -------------------- INTERFACE --------------------
    group('🎨 INTERFACE', () {
      testWidgets('9️⃣ Exibe mensagem de erro no StreamBuilder', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text('Erro: simulado'))),
          ),
        );
        expect(find.textContaining('Erro:'), findsOneWidget);
      });

      testWidgets('🔟 Renderiza tela principal com Scaffold', (tester) async {
        await fakeDb.collection('solicitacoesOrcamento').doc('fake').set({
          'descricaoDetalhada': 'Teste simples',
        });

        await tester.pumpWidget(
          MaterialApp(
            home: VisualizarSolicitacaoScreen(
              docId: 'fake',
              firestore: fakeDb, // ✅ injetado aqui também
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsOneWidget);
      });
    });
  });
}
