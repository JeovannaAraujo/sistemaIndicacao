import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MinhasAvaliacoesTab extends StatelessWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const MinhasAvaliacoesTab({super.key, this.firestore, this.auth});

  String fmtData(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return DateFormat('dd/MM/yyyy – HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final fs = firestore ?? FirebaseFirestore.instance;
    final fa = auth ?? FirebaseAuth.instance;
    final uid = fa.currentUser!.uid;

    final stream = fs
        .collection('avaliacoes')
        .where('clienteId', isEqualTo: uid)
        .orderBy('data', descending: true)
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

            final comentario = (av['comentario'] ?? '').toString();
            final nota = (av['nota'] as num?)?.toDouble() ?? 0;
            final data = fmtData(av['data']);
            final imagemUrl = av['imagemUrl']?.toString();
            final prestadorId = (av['prestadorId'] ?? '').toString();
            final solicitacaoId = (av['solicitacaoId'] ?? '').toString();

            final fut = Future.wait([
              if (prestadorId.isNotEmpty)
                fs.collection('usuarios').doc(prestadorId).get()
              else
                Future.value(null),
              if (solicitacaoId.isNotEmpty)
                fs.collection('solicitacoesOrcamento').doc(solicitacaoId).get()
              else
                Future.value(null),
            ]);

            return FutureBuilder<List<dynamic>>(
              future: fut,
              builder: (context, fsnap) {
                String prestadorNome = 'Prestador';
                String servicoTitulo = '';
                String cidade = '';

                if (fsnap.hasData) {
                  final u =
                      fsnap.data![0] as DocumentSnapshot<Map<String, dynamic>>?;
                  final s = fsnap.data!.length > 1
                      ? fsnap.data![1]
                            as DocumentSnapshot<Map<String, dynamic>>?
                      : null;

                  final udata = u?.data() ?? const <String, dynamic>{};
                  final sdata = s?.data() ?? const <String, dynamic>{};

                  prestadorNome = (udata['nome'] ?? 'Prestador').toString();
                  servicoTitulo = (sdata['servicoTitulo'] ?? '').toString();
                  cidade = (sdata['clienteEndereco']?['cidade'] ?? '')
                      .toString();
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
                      if (servicoTitulo.isNotEmpty)
                        Text(
                          servicoTitulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'Prestador: $prestadorNome',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                        ),
                      ),
                      if (cidade.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cidade,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      StarsReadOnly(rating: nota),
                      const SizedBox(height: 6),
                      Text(
                        comentario.isEmpty ? 'Sem comentário' : comentario,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      if (imagemUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imagemUrl,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Enviado em $data',
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

class StarsReadOnly extends StatelessWidget {
  final double rating;
  const StarsReadOnly({super.key, required this.rating});

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
