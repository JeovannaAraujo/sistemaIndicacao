import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'rotasNavegacao.dart';

class SolicitacoesRespondidasScreen extends StatelessWidget {
  const SolicitacoesRespondidasScreen({super.key});

  static const _colSolic = 'solicitacoesOrcamento';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection(_colSolic)
        .where('clienteId', isEqualTo: uid)
        .where('status', isEqualTo: 'respondida')
        .orderBy('respondidaEm', descending: true)
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
          _Tabs(
            active: _TabKind.respondidas,
            onTapEnviadas: () => context.goEnviadas(),
            onTapRespondidas: () {}, // já está nesta aba
            onTapAceitas: () => context.goAceitas(),
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
                    child: Text('Nenhuma proposta recebida ainda.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final id = docs[i].id;
                    final d = docs[i].data();
                    return _PropostaCard(docId: id, dados: d);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // ✅ Bottom bar fixa nas telas de solicitações
      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 2),
    );
  }
}

/* ========================= Widgets ========================= */

enum _TabKind { enviadas, respondidas, aceitas }

class _Tabs extends StatelessWidget {
  final _TabKind active;
  final VoidCallback onTapEnviadas;
  final VoidCallback onTapRespondidas;
  final VoidCallback onTapAceitas;

  const _Tabs({
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
        tab('Enviadas', active == _TabKind.enviadas, onTapEnviadas),
        tab('Respondidas', active == _TabKind.respondidas, onTapRespondidas),
        tab('Aceitas', active == _TabKind.aceitas, onTapAceitas),
      ],
    );
  }
}

/* ========================= Cache para nome da categoria ========================= */

class _CategoriaRepo {
  static final Map<String, String> _cache = {};
  static Future<String> nome(String id) async {
    if (id.isEmpty) return '';
    if (_cache.containsKey(id)) return _cache[id]!;
    final snap = await FirebaseFirestore.instance
        .collection('categoriasProfissionais')
        .doc(id)
        .get();
    final n = (snap.data()?['nome'] ?? '').toString();
    _cache[id] = n;
    return n;
  }
}

/* ========================= Card (com cabeçalho estilo mock) ========================= */

class _PropostaCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> dados;

  const _PropostaCard({required this.docId, required this.dados});

  String _fmtMoeda(num? v) => v == null
      ? '—'
      : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

  String _fmtDataTs(dynamic ts) =>
      ts is Timestamp ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '—';

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // IDs
    final prestadorId = (dados['prestadorId'] ?? '').toString();

    // Dados da proposta
    final servico = (dados['servicoTitulo'] ?? '').toString();
    final valorProposto = (dados['valorProposto'] as num?);
    final tempoValor = (dados['tempoEstimadoValor'] as num?);
    final tempoUn = (dados['tempoEstimadoUnidade'] ?? '').toString();
    final dataInicioSug = dados['dataInicioSugerida'];
    final dataFinalPrev = dados['dataFinalPrevista'];
    final observacoes = (dados['observacoesPrestador'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------- Cabeçalho: foto, nome, "Profissão • 📍 Local" --------
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? '').toString();
              final fotoUrl = (u['fotoUrl'] ?? '').toString();

              // Local
              final end = (u['endereco'] is Map)
                  ? (u['endereco'] as Map).cast<String, dynamic>()
                  : <String, dynamic>{};
              String cidade = (end['cidade'] ?? u['cidade'] ?? '').toString();
              String uf = (end['uf'] ?? u['uf'] ?? '').toString();
              String local = cidade.trim();
              if (uf.isNotEmpty &&
                  !RegExp('\\b$uf\\b', caseSensitive: false).hasMatch(local)) {
                local = local.isEmpty ? uf : '$local, $uf';
              }

              // Categoria
              final catId =
                  (u['categoriaProfissionalId'] ??
                          dados['categoriaProfissionalId'] ??
                          '')
                      .toString();

              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade300,
                      child: (fotoUrl.isNotEmpty)
                          ? Image.network(fotoUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.person,
                              size: 28,
                              color: Colors.white70,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome.isEmpty ? 'Prestador' : nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<String>(
                          future: _CategoriaRepo.nome(catId),
                          builder: (context, s2) {
                            final profissao = (s2.data?.isNotEmpty == true)
                                ? s2.data!
                                : '';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    profissao,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '•',
                                  style: TextStyle(color: Colors.black26),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    local.isEmpty ? '—' : local,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // -------- Dados da proposta --------
          _kv('Serviço:', servico.isEmpty ? '—' : servico, boldValue: true),
          _kv('Valor Total Proposto:', _fmtMoeda(valorProposto)),
          _kv('Forma de cobrança:', tempoUn == 'hora' ? 'hora' : 'm²'),
          _kv(
            'Tempo estimado:',
            (tempoValor == null || tempoUn.isEmpty)
                ? '—'
                : '$tempoValor $tempoUn${tempoValor == 1 ? '' : 's'}',
          ),
          _kv('Data de início:', _fmtDataTs(dataInicioSug)),
          _kv('Data final:', _fmtDataTs(dataFinalPrev)),
          _kv('Observações:', observacoes.isEmpty ? '—' : observacoes),

          const SizedBox(height: 12),

          // -------- Ações --------
          Row(
            children: [
              Expanded(
                child: _PrimaryGradientButton(
                  text: 'Aceitar Orçamento',
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser!.uid;

                    // 1) Atualiza status
                    await fs
                        .collection(SolicitacoesRespondidasScreen._colSolic)
                        .doc(docId)
                        .update({
                          'status': 'aceita',
                          'aceitaEm': FieldValue.serverTimestamp(),
                          'aceitaPor': uid,
                        });

                    // 2) Historiza
                    await fs
                        .collection(SolicitacoesRespondidasScreen._colSolic)
                        .doc(docId)
                        .collection('historico')
                        .add({
                          'tipo': 'cliente_aceitou',
                          'quando': FieldValue.serverTimestamp(),
                          'por': uid,
                          'valorProposto': valorProposto,
                        });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Orçamento aceito!')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    final motivoCtl = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Recusar orçamento'),
                        content: TextField(
                          controller: motivoCtl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Opcional: informe o motivo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Recusar'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    final uid = FirebaseAuth.instance.currentUser!.uid;

                    await fs
                        .collection(SolicitacoesRespondidasScreen._colSolic)
                        .doc(docId)
                        .update({
                          'status': 'recusadaCliente',
                          'recusadaClienteEm': FieldValue.serverTimestamp(),
                          'recusadaClientePor': uid,
                          'recusaMotivoCliente': motivoCtl.text.trim(),
                        });

                    await fs
                        .collection(SolicitacoesRespondidasScreen._colSolic)
                        .doc(docId)
                        .collection('historico')
                        .add({
                          'tipo': 'cliente_recusou',
                          'quando': FieldValue.serverTimestamp(),
                          'por': uid,
                          'motivo': motivoCtl.text.trim(),
                        });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Orçamento recusado.')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEDE7F6),
                    foregroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Recusar Orçamento'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool boldValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13.5),
          children: [
            TextSpan(
              text: '$k ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: v,
              style: TextStyle(
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* Botão roxo com gradiente (mesmo do design) */
class _PrimaryGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryGradientButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
