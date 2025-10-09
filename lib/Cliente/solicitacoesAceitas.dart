// lib/Cliente/solicitacoesAceitas.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/Cliente/visualizarSolicitacao.dart';
import 'visualizarResposta.dart';
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
  final String id;
  final Map<String, dynamic> dados;
  const _CardAceita({required this.id, required this.dados});

  String _fmtMoeda(num? v) => v == null
      ? '—'
      : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  String _fmtData(dynamic ts) =>
      ts is Timestamp ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : '—';

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
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
          // ===== CABEÇALHO (imagem, nome, categoria e cidade) =====
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? '').toString();
              final foto = (u['fotoUrl'] ?? '').toString();

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

              final catId = (u['categoriaProfissionalId'] ?? '').toString();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade300,
                      child: foto.isNotEmpty
                          ? Image.network(foto, fit: BoxFit.cover)
                          : const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 28,
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
                            final cat = (s2.data ?? '').toString();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    cat,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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

          const SizedBox(height: 10),

          // ===== Nome do serviço =====
          if (servico.isNotEmpty)
            Text(
              servico,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple,
                fontSize: 15,
              ),
            ),

          const SizedBox(height: 8),

          // ===== Informações principais (sem tempo nem observações) =====
          _linhaInfo('Valor proposto:', _fmtMoeda(valor)),
          _linhaInfo('Início previsto:', _fmtData(dataInicio)),
          _linhaInfo('Término previsto:', _fmtData(dataFinal)),

          const SizedBox(height: 14),

          // ===== BOTÕES =====
          // ===== BOTÕES =====
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisualizarRespostaScreen(docId: id),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Ver orçamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisualizarSolicitacaoScreen(docId: id),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Ver solicitação',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: () => _confirmarCancelamento(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF5252),
                        Color(0xFFD50000),
                      ], // 🔥 gradiente vermelho
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancelar serviço',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  Future<void> _confirmarCancelamento(BuildContext context) async {
    final motivoCtl = TextEditingController();
    final confirmar = await showDialog<bool>(
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
                border: OutlineInputBorder(),
                hintText: 'Ex.: imprevisto, mudança de planos...',
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

    if (confirmar == true && motivoCtl.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('solicitacoesOrcamento')
          .doc(id)
          .update({
            'status': 'cancelada',
            'motivoCancelamento': motivoCtl.text.trim(),
            'canceladaEm': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço cancelado com sucesso.')),
        );
      }
    }
  }
}
