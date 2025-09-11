import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MinhasAvaliacoesTab extends StatelessWidget {
  const MinhasAvaliacoesTab({super.key});

  String _fmtData(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return DateFormat('dd/MM/yyyy').format(d);
  }

  /// Tenta montar um texto de duração:
  /// - Se houver tempoEstimadoValor/unidade -> "6 dias", "3 horas", etc.
  /// - Senão, diferença entre dataInicioSugerida e dataFinalizacaoReal/Prevista.
  String _duracaoFromSolic(Map<String, dynamic>? s) {
    if (s == null) return '—';
    final num? v = (s['tempoEstimadoValor'] as num?);
    final un = (s['tempoEstimadoUnidade'] ?? '').toString().trim();
    if (v != null && v > 0 && un.isNotEmpty) {
      final plural = v == 1 ? '' : 's';
      return '${v.toString().replaceAll('.0', '')} $un$plural';
    }
    final ini = s['dataInicioSugerida'];
    final fim = s['dataFinalizacaoReal'] ?? s['dataFinalPrevista'];
    if (ini is Timestamp && fim is Timestamp) {
      final d1 = DateTime(
        ini.toDate().year,
        ini.toDate().month,
        ini.toDate().day,
      );
      final d2 = DateTime(
        fim.toDate().year,
        fim.toDate().month,
        fim.toDate().day,
      );
      final dias = d2.difference(d1).inDays.abs();
      final total = (dias <= 0) ? 1 : dias + 1;
      return '$total ${total == 1 ? "dia" : "dias"}';
    }
    return '—';
  }

  /// ✅ NOVO: garante que a solicitação ligada à avaliação esteja marcada como "avaliada"
  /// e registra no histórico (executa uma única vez por doc).
  Future<void> _marcarAvaliadaSeNecessario({
    required String solicitacaoId,
    required String clienteUid,
    required double nota,
    required String comentario,
  }) async {
    if (solicitacaoId.isEmpty) return;
    final fs = FirebaseFirestore.instance;
    final ref = fs.collection('solicitacoesOrcamento').doc(solicitacaoId);

    await fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = (snap.data() ?? {});
      final statusAtual = (data['status'] ?? '').toString();

      // só transiciona finalizada -> avaliada
      if (statusAtual == 'finalizada') {
        tx.update(ref, {
          'status': 'avaliada',
          'avaliadaEm': FieldValue.serverTimestamp(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        });

        final histRef = ref.collection('historico').doc();
        tx.set(histRef, {
          // chaves compatíveis com seu padrão anterior
          'tipo': 'avaliada_cliente',
          'quando': FieldValue.serverTimestamp(),
          'por': clienteUid,

          // chaves novas padronizadas
          'em': FieldValue.serverTimestamp(),
          'porUid': clienteUid,
          'porRole': 'Cliente',
          'statusDe': statusAtual,
          'statusPara': 'avaliada',
          'mensagem': 'Cliente avaliou o serviço.',
          'nota': nota,
          'comentario': comentario,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection('avaliacoes')
        .where('clienteId', isEqualTo: uid)
        .orderBy('criadoEm', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Você ainda não avaliou nenhum serviço.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final av = docs[i].data();

            final titulo = (av['servicoTitulo'] ?? '').toString();
            final valorTxt = (av['valorTexto'] ?? '').toString();
            final nota = (av['nota'] as num?)?.toDouble() ?? 0;
            final comentario = (av['comentario'] ?? '').toString();
            final criadoEm = av['criadoEm'] is Timestamp
                ? DateFormat(
                    'dd/MM/yyyy – HH:mm',
                  ).format((av['criadoEm'] as Timestamp).toDate())
                : '—';

            final prestadorId = (av['prestadorId'] ?? '').toString();
            final solicitacaoId = (av['solicitacaoId'] ?? '').toString();

            // Busca em paralelo: nome do prestador + solicitação (para período e duração)
            final fut = Future.wait([
              if (prestadorId.isNotEmpty)
                FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(prestadorId)
                    .get()
              else
                Future.value(null),
              if (solicitacaoId.isNotEmpty)
                FirebaseFirestore.instance
                    .collection('solicitacoesOrcamento')
                    .doc(solicitacaoId)
                    .get()
              else
                Future.value(null),
            ]);

            return FutureBuilder<List<dynamic>>(
              future: fut,
              builder: (context, fsnap) {
                String prestadorNome = 'Prestador';
                String periodo = '';
                String duracao = '—';

                if (fsnap.hasData) {
                  final DocumentSnapshot<Map<String, dynamic>>? u =
                      fsnap.data![0] as DocumentSnapshot<Map<String, dynamic>>?;
                  final DocumentSnapshot<Map<String, dynamic>>? s =
                      fsnap.data!.length > 1
                      ? fsnap.data![1]
                            as DocumentSnapshot<Map<String, dynamic>>?
                      : null;

                  final udata = u?.data() ?? const <String, dynamic>{};
                  prestadorNome = (udata['nome'] ?? 'Prestador').toString();

                  final sdata = s?.data();
                  if (sdata != null) {
                    final ini = _fmtData(sdata['dataInicioSugerida']);
                    final fim = _fmtData(
                      sdata['dataFinalizacaoReal'] ??
                          sdata['dataFinalPrevista'],
                    );
                    if (ini != '—' || fim != '—') periodo = '$ini – $fim';
                    duracao = _duracaoFromSolic(sdata);

                    // ✅ NOVO: ao exibir a avaliação, garante status "avaliada" + histórico
                    _marcarAvaliadaSeNecessario(
                      solicitacaoId: solicitacaoId,
                      clienteUid: uid,
                      nota: nota,
                      comentario: comentario,
                    );
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titulo.isNotEmpty)
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'Prestador: $prestadorNome',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                      if (periodo.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              periodo,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],

                      if (duracao.isNotEmpty && duracao != '—') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.timelapse, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Duração: $duracao',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],

                      if (valorTxt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          valorTxt,
                          style: const TextStyle(
                            color: Color(0xFF5E35B1),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),
                      _StarsReadOnly(rating: nota),

                      const SizedBox(height: 6),
                      Text(
                        comentario.isEmpty ? 'Sem comentário' : comentario,
                        style: const TextStyle(fontSize: 13.5),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        'Enviado em $criadoEm',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/* ===================== WIDGET DE APOIO (somente leitura) ===================== */

class _StarsReadOnly extends StatelessWidget {
  final double rating;
  const _StarsReadOnly({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          rating >= i + 1 ? Icons.star : Icons.star_border,
          size: 18,
          color: const Color(0xFFFFC107),
        ),
      ),
    );
  }
}
