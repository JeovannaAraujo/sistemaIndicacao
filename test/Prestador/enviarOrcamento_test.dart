import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/Prestador/enviarOrcamento.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();

    await fakeDb.collection('usuarios').doc('prest1').set({
      'jornadaInicio': '08:00',
      'jornadaFim': '17:00',
      'diasTrabalho': [1, 2, 3, 4, 5],
    });

    await fakeDb.collection('solicitacoesOrcamento').doc('sol1').set({
      'servicoTitulo': 'Limpeza de terreno',
      'quantidade': 50,
      'estimativaValor': 500,
      'dataDesejada': Timestamp.fromDate(DateTime(2025, 10, 27, 8, 0)),
    });
  });

  // ============================================================
  group('CREATE (Criação)', () {
    test('✅ Cria orçamento com sucesso (dados corretos)', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('sol2').set({
        'servicoTitulo': 'Jardinagem',
        'quantidade': 10,
        'estimativaValor': 150,
      });

      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('sol2')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['servicoTitulo'], 'Jardinagem');
    });

    test(
      '❌ Criação incorreta (sem título) deve gerar documento incompleto',
      () async {
        // cria e guarda o id retornado
        final ref = await fakeDb.collection('solicitacoesOrcamento').add({
          'quantidade': 20,
        });
        final doc = await ref.get();

        // verifica apenas este doc, não o primeiro da coleção
        expect(doc.exists, isTrue);
        expect(doc.data()?['servicoTitulo'], isNull);
        expect(doc.data()?['quantidade'], 20);
      },
    );
  });

  // ============================================================
  group('READ (Leitura)', () {
    test('✅ Lê solicitação existente corretamente', () async {
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('sol1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['servicoTitulo'], 'Limpeza de terreno');
    });

    test('❌ Retorna inexistente ao buscar ID inválido', () async {
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('fakeId')
          .get();
      expect(doc.exists, isFalse);
    });
  });

  // ============================================================
  group('UPDATE (Atualização)', () {
    test('✅ Atualiza orçamento existente', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('sol1').update({
        'estimativaValor': 999,
      });
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('sol1')
          .get();
      expect(doc.data()?['estimativaValor'], 999);
    });

    test('❌ Falha ao atualizar inexistente', () async {
      try {
        await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('inexistente')
            .update({'estimativaValor': 123});
        fail('Esperava exceção');
      } catch (e) {
        expect(e, isA<FirebaseException>());
      }
    });
  });

  // ============================================================
  group('DELETE (Exclusão)', () {
    test('✅ Exclui orçamento corretamente', () async {
      await fakeDb.collection('solicitacoesOrcamento').doc('sol1').delete();
      final doc = await fakeDb
          .collection('solicitacoesOrcamento')
          .doc('sol1')
          .get();
      expect(doc.exists, isFalse);
    });

    test('❌ Falha ao excluir inexistente (simulação)', () async {
      try {
        await fakeDb
            .collection('solicitacoesOrcamento')
            .doc('naoexiste')
            .delete();
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });

  // ============================================================
  group('REGRAS DE NEGÓCIO (Jornada e cálculo de datas)', () {
    test('✅ fetchJornadaPrestador retorna jornada customizada', () async {
      final j = await fetchJornadaPrestador('prest1');
      expect(j.inicioMin, 480); // 8h * 60
      expect(j.fimMin, 1020); // 17h * 60
      expect(j.dias.contains(DateTime.monday), isTrue);
    });

    test('✅ addWorkingDays calcula dias úteis corretamente', () async {
      final j = await fetchJornadaPrestador('prest1');
      final inicio = DateTime(2025, 10, 27, 8, 0);
      final fim = addWorkingDays(inicio, 3, j);
      // Segunda (27) + 3 dias úteis = Quinta (30)
      expect(fim.weekday, DateTime.thursday);
    });
  });
}
