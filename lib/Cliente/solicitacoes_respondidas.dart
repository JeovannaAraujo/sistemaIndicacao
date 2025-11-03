import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'rotas_navegacao.dart';
import 'visualizar_resposta.dart';

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
      backgroundColor: const Color(0xFFF6F6FB),
      appBar: AppBar(
        title: const Text('Solicitações'),
        backgroundColor: const Color(0xFFF6F6FB),
        elevation: 0.3,
      ),
      body: Column(
        children: [
          Tabs(
            active: TabKind.respondidas,
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
                    return PropostaCard(
                      docId: id,
                      dados: d,
                    );
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

/* ========================= Abas ========================= */

enum TabKind { enviadas, respondidas, aceitas }

class Tabs extends StatelessWidget {
  final TabKind active;
  final VoidCallback onTapEnviadas;
  final VoidCallback onTapRespondidas;
  final VoidCallback onTapAceitas;

  const Tabs({super.key, 
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

/* ========================= Cache de categoria ========================= */

class CategoriaRepo {
  static final Map<String, String> cache = {};
  static FirebaseFirestore? _firestore; // ✅ injeção mockável

  static void setFirestore(FirebaseFirestore? fs) {
    _firestore = fs;
  }

  static Future<String> nome(String id) async {
    if (id.isEmpty) return '';
    if (cache.containsKey(id)) return cache[id]!;
    final db = _firestore ?? FirebaseFirestore.instance; // ✅ usa mock se existir
    final snap =
        await db.collection('categoriasProfissionais').doc(id).get();
    final n = (snap.data()?['nome'] ?? '').toString();
    cache[id] = n;
    return n;
  }
}

/* ========================= Card ========================= */

class PropostaCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> dados;
  final FirebaseFirestore? firestore; // ✅ novo campo

  const PropostaCard({
    super.key,
    required this.docId,
    required this.dados,
    this.firestore, // ✅ opcional para testes
  });

  String _fmtDataHora(dynamic ts) {
    if (ts is! Timestamp) return '—';
    return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(ts.toDate());
  }

  String _fmtQtd(dynamic qtd, String un) {
    if (qtd == null) return '—';
    String valor = qtd.toString().replaceAll('.0', '');
    if (un.isNotEmpty) valor += ' $un';
    return valor;
  }

  @override
  Widget build(BuildContext context) {
    final fs = firestore ?? FirebaseFirestore.instance; // ✅ usa fakeDb se houver
    final prestadorId = (dados['prestadorId'] ?? '').toString();

    final servicoTitulo = (dados['servicoTitulo'] ?? '').toString();
    final descricao = (dados['descricaoDetalhada'] ?? '').toString();
    final quantidade = (dados['quantidade'] ?? '').toString();
    final unidadeSelecionadaId =
        (dados['unidadeSelecionadaId'] ?? '').toString();
    final servicoUnidadeId = (dados['servicoUnidadeId'] ?? '').toString();

    Future<String> buscarAbreviacaoUnidade() async {
      final db = firestore ?? FirebaseFirestore.instance; // ✅ idem
      final unidadeId =
          unidadeSelecionadaId.isNotEmpty ? unidadeSelecionadaId : servicoUnidadeId;
      if (unidadeId.isEmpty) return '';
      final snap = await db.collection('unidades').doc(unidadeId).get();
      return (snap.data()?['abreviacao'] ?? '').toString();
    }

    final dataEnvio =
        dados['criadoEm'] ?? dados['enviadaEm'] ?? dados['respondidaEm'];
    final dataFmt = _fmtDataHora(dataEnvio);

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
          // ====== Cabeçalho ======
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
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
                          future: CategoriaRepo.nome(catId),
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

          const SizedBox(height: 8),

          if (servicoTitulo.isNotEmpty)
            Text(
              servicoTitulo,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple,
                fontSize: 15,
              ),
            ),

          const SizedBox(height: 8),

          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              children: [
                const TextSpan(
                  text: 'Descrição: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: descricao),
              ],
            ),
          ),

          const SizedBox(height: 3),
          FutureBuilder<String>(
            future: buscarAbreviacaoUnidade(),
            builder: (context, snapshot) {
              final un = snapshot.data ?? '';
              return RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                  children: [
                    const TextSpan(
                      text: 'Quantidade: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: _fmtQtd(quantidade, un)),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 3),
          Text(
            'Enviada em: $dataFmt',
            style: const TextStyle(color: Colors.black54, fontSize: 12.5),
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisualizarRespostaScreen(docId: docId),
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
                'Ver Orçamento',
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
    );
  }
}
