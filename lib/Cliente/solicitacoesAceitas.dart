import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'rotasNavegacao.dart';

class SolicitacoesAceitasScreen extends StatelessWidget {
  const SolicitacoesAceitasScreen({super.key});

  static const _colSolic = 'solicitacoesOrcamento';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection(_colSolic)
        .where('clienteId', isEqualTo: uid)
        .where('status', isEqualTo: 'aceita')
        .orderBy('aceitaEm', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Solicitações'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: Column(
        children: [
          Tabs(
            active: TabKind.aceitas,
            onTapEnviadas: () => context.goEnviadas(),
            onTapRespondidas: () => context.goRespondidas(),
            onTapAceitas: () {},
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhum orçamento aceito ainda.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final id = doc.id;
                    final d = doc.data();
                    return CardAceita(id: id, dados: d);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 2),
    );
  }
}

/* ========================= Widgets ========================= */

enum TabKind { enviadas, respondidas, aceitas }

class Tabs extends StatelessWidget {
  final TabKind active;
  final VoidCallback onTapEnviadas;
  final VoidCallback onTapRespondidas;
  final VoidCallback onTapAceitas;

  const Tabs({
    required this.active,
    required this.onTapEnviadas,
    required this.onTapRespondidas,
    required this.onTapAceitas,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String text, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: selected ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.deepPurple : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  width: 56,
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Enviadas', active == TabKind.enviadas, onTapEnviadas),
        tab('Respondidas', active == TabKind.respondidas, onTapRespondidas),
        tab('Aceitas', active == TabKind.aceitas, onTapAceitas),
      ],
    );
  }
}

/* ========================= Categoria Repo ========================= */

class CategoriaRepoAceita {
  static final Map<String, String> _cache = {};
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<String> nome(String id) async {
    if (id.isEmpty) return '';
    if (_cache.containsKey(id)) return _cache[id]!;
    final snap = await firestore.collection('categoriasProfissionais').doc(id).get();
    final n = (snap.data()?['nome'] ?? '').toString();
    _cache[id] = n;
    return n;
  }
}

/* ========================= Card Aceita ========================= */

class CardAceita extends StatelessWidget {
  final String id;
  final Map<String, dynamic> dados;
  final FirebaseFirestore? firestore; // 👈 injeção adicionada

  const CardAceita({
    required this.id,
    required this.dados,
    this.firestore,
  });

  String _fmtMoeda(num? v) => v == null
      ? '—'
      : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

  String _fmtData(dynamic ts) =>
      ts is Timestamp ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '—';

  @override
  Widget build(BuildContext context) {
    final fs = firestore ?? FirebaseFirestore.instance;
    final prestadorId = (dados['prestadorId'] ?? '').toString();

    final servico = (dados['servicoTitulo'] ?? '').toString();
    final valor = (dados['valorProposto'] as num?);
    final dataInicio = dados['dataInicioSugerida'];
    final dataFinal = dados['dataFinalPrevista'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? '').toString();

              final catId = (u['categoriaProfissionalId'] ?? '').toString();

              return Row(
                children: [
                  const Icon(Icons.person, size: 28, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: CategoriaRepoAceita.nome(catId),
                      builder: (context, s2) {
                        final cat = (s2.data ?? '').toString();
                        return Text(
                          nome.isEmpty ? 'Prestador' : '$nome – $cat',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  const Text(
                    'Aceita',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),
          if (servico.isNotEmpty)
            Text(
              servico,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple,
              ),
            ),
          _linhaInfo('Valor proposto:', _fmtMoeda(valor)),
          _linhaInfo('Início previsto:', _fmtData(dataInicio)),
          _linhaInfo('Término previsto:', _fmtData(dataFinal)),
          const SizedBox(height: 10),
          const Text('Ver orçamento'),
          const Text('Ver solicitação'),
          const Text('Cancelar serviço'),
        ],
      ),
    );
  }

  Widget _linhaInfo(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          children: [
            TextSpan(
              text: '$k ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}
