// lib/Cliente/solicitacoesAceitas.dart
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
          _Tabs(
            active: _TabKind.aceitas,
            onTapEnviadas: () => context.goEnviadas(),
            onTapRespondidas: () => context.goRespondidas(),
            onTapAceitas: () {}, // já está nesta aba
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
                    final d = doc.data(); // 👈 agora 'd' está definido
                    return _CardAceita(id: id, dados: d);
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

/* ========================= Widgets básicos ========================= */

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

class _HeaderGradient extends StatelessWidget {
  final String title;
  const _HeaderGradient({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: Color(0xFF3D2469),
        ),
      ),
    );
  }
}

/* ========================= Repo simples de Categoria ========================= */

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

/* ========================= Card Aceita (estilo mock) ========================= */

class _CardAceita extends StatelessWidget {
  final String id; // 👈 novo
  final Map<String, dynamic> dados;
  const _CardAceita({required this.id, required this.dados});
  String _fmtMoeda(num? v) => v == null
      ? '—'
      : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  String _fmtDataTs(dynamic ts) =>
      ts is Timestamp ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '—';
  String _fmtDataDate(DateTime? d) =>
      d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);

  DateTime _addBusinessDays(DateTime start, int days) {
    var date = start;
    var added = 0;
    while (added < days) {
      date = date.add(const Duration(days: 1));
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        added++;
      }
    }
    return date;
    // (Se você tiver a jornada do prestador, encaixe aqui.)
  }

  DateTime? _calcDataFinalFallback(
    dynamic inicioTs,
    num? tempo,
    String unidade,
  ) {
    if (inicioTs is! Timestamp || tempo == null || tempo <= 0) return null;
    final start = inicioTs.toDate();
    if (unidade == 'hora') {
      return start.add(Duration(hours: tempo.ceil()));
    }
    // padrão: dias úteis
    return _addBusinessDays(start, tempo.ceil());
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    final prestadorId = (dados['prestadorId'] ?? '').toString();

    final servico = (dados['servicoTitulo'] ?? '').toString();
    final valorProposto = (dados['valorProposto'] as num?);
    final tempoValor = (dados['tempoEstimadoValor'] as num?);
    final tempoUn = (dados['tempoEstimadoUnidade'] ?? '').toString();
    final dataInicio = dados['dataInicioSugerida'];
    final dataFinalPrev = dados['dataFinalPrevista']; // preferencial
    final observacoes = (dados['observacoesPrestador'] ?? '').toString();

    // fallback para data final
    final DateTime? dataFinalCalc = dataFinalPrev is Timestamp
        ? dataFinalPrev.toDate()
        : _calcDataFinalFallback(dataInicio, tempoValor, tempoUn);

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
          // ---------- Cabeçalho com foto, nome, categoria • local ----------
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? '').toString();
              final fotoUrl = (u['fotoUrl'] ?? '').toString();

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
                  // Chip "Aceita"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Aceita',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // ---------- Informações ----------
          _kv('Serviço:', servico, boldValue: true),
          _kv('Valor Total Proposto:', _fmtMoeda(valorProposto)),
          _kv('Forma de cobrança:', tempoUn == 'hora' ? 'hora' : 'm²'),
          _kv(
            'Tempo estimado:',
            (tempoValor == null || tempoUn.isEmpty)
                ? '—'
                : '$tempoValor $tempoUn${tempoValor == 1 ? '' : 's'}',
          ),
          _kv('Data de início:', _fmtDataTs(dataInicio)),
          _kv(
            'Data final:',
            dataFinalPrev is Timestamp
                ? _fmtDataTs(dataFinalPrev)
                : _fmtDataDate(dataFinalCalc),
          ),
          _kv('Observações:', observacoes.isEmpty ? '—' : observacoes),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => _confirmarCancelamento(context),
                  child: const Text('Cancelar serviço'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCancelamento(BuildContext context) async {
    final motivoCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o motivo do cancelamento:'),
            const SizedBox(height: 8),
            TextField(
              controller: motivoCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex.: imprevisto, mudou necessidade...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final motivo = motivoCtl.text.trim();
      if (motivo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, informe o motivo.')),
        );
        return;
      }
      await _cancelarServico(context, motivo);
    }
  }

  Future<void> _cancelarServico(BuildContext context, String motivo) async {
    try {
      final fs = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Atualiza o doc principal
      await fs.collection('solicitacoesOrcamento').doc(id).update({
        'status': 'cancelada',
        'canceladaEm': FieldValue.serverTimestamp(),
        'motivoCancelamento': motivo,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      // (Opcional) registra no histórico
      await fs
          .collection('solicitacoesOrcamento')
          .doc(id)
          .collection('historico')
          .add({
            'tipo': 'cancelada_cliente',
            'quando': FieldValue.serverTimestamp(),
            'por': uid,
            'motivo': motivo,
          });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Serviço cancelado.')));
      }
      // A lista vai se atualizar sozinha pois o stream filtra status == 'aceita'
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao cancelar: $e')));
      }
    }
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
