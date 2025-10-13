import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'detalhesSolicitacao.dart';
import 'visualizarResposta.dart';
import 'solicitacoesRecebidas.dart';
import 'rotasNavegacao.dart';

class SolicitacoesRespondidasScreen extends StatefulWidget {
  const SolicitacoesRespondidasScreen({super.key});

  @override
  State<SolicitacoesRespondidasScreen> createState() =>
      _SolicitacoesRespondidasScreenState();
}

class _SolicitacoesRespondidasScreenState
    extends State<SolicitacoesRespondidasScreen>
    with SingleTickerProviderStateMixin {
  static const String colSolicitacoes = 'solicitacoesOrcamento';
  late final String _prestadorId;
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _prestadorId = FirebaseAuth.instance.currentUser!.uid;
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SolicitacoesRecebidasScreen(),
          ),
        );
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamSolicitacoes() {
    return FirebaseFirestore.instance
        .collection(colSolicitacoes)
        .where('prestadorId', isEqualTo: _prestadorId)
        .where(
          'status',
          whereIn: [
            'respondida',
            'aceita',
            'recusada',
            'cancelada',
            'finalizada',
          ],
        )
        .orderBy('criadoEm', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Solicitações'),
        backgroundColor: Colors.white,
        elevation: 0.3,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Recebidas'),
            Tab(text: 'Respondidas'),
          ],
        ),
      ),
      body: _ListaSolicitacoes(
        stream: _streamSolicitacoes(),
        moeda: _moeda,
        recebidas: false,
      ),
      bottomNavigationBar: const PrestadorBottomNav(selectedIndex: 1),
    );
  }
}

// ======== COMPONENTES AUXILIARES (idênticos ao arquivo anterior) ========

class _ListaSolicitacoes extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final NumberFormat moeda;
  final bool recebidas;

  const _ListaSolicitacoes({
    required this.stream,
    required this.moeda,
    required this.recebidas,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhuma solicitação.'));
        }

        final docs = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final docId = docs[i].id;
            final titulo = (d['servicoTitulo'] ?? '').toString();
            final cliente = (d['clienteNome'] ?? '').toString();
            final status = (d['status'] ?? '').toString();

            String estimativa;
            if (status == 'finalizada') {
              final valorProposto = (d['valorProposto'] is num)
                  ? moeda.format((d['valorProposto'] as num).toDouble())
                  : '—';
              estimativa = valorProposto;
            } else {
              estimativa = (d['estimativaValor'] is num)
                  ? moeda.format((d['estimativaValor'] as num).toDouble())
                  : '—';
            }

            final dataDesejada = (d['dataDesejada'] is Timestamp)
                ? DateFormat(
                    'dd/MM/yyyy',
                  ).format((d['dataDesejada'] as Timestamp).toDate())
                : '—';
            final endereco =
                (d['clienteEndereco'] as Map<String, dynamic>?) ?? {};
            final enderecoStr = _enderecoLinha(endereco);

            return _SolicCard(
              docId: docId,
              titulo: titulo,
              cliente: cliente,
              dataDesejada: dataDesejada,
              endereco: enderecoStr,
              estimativa: estimativa,
              status: status,
              recebidas: false,
              servicoId: (d['servicoId'] ?? '').toString(),
              categoriaIdFallback:
                  (d['categoriaId'] ?? d['servicoCategoriaId'] ?? '')
                      .toString(),
              onVerDetalhes: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        VisualizarRespostaPrestadorScreen(docId: docId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _enderecoLinha(Map<String, dynamic>? e) {
    final m = e ?? {};
    final partes = <String>[];
    if ((m['rua'] ?? '').toString().isNotEmpty) partes.add('${m['rua']}');
    if ((m['numero'] ?? '').toString().isNotEmpty)
      partes.add('Nº ${m['numero']}');
    if ((m['bairro'] ?? '').toString().isNotEmpty) partes.add(m['bairro']);
    if ((m['cidade'] ?? '').toString().isNotEmpty) partes.add(m['cidade']);
    return partes.join(', ');
  }
}

class _CategoriaThumbCache {
  static final Map<String, String> _cache = {};
  static const String colCategorias = 'categoriasServicos';

  static Future<String> getUrl(String categoriaId) async {
    if (categoriaId.isEmpty) return '';
    if (_cache.containsKey(categoriaId)) return _cache[categoriaId]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(colCategorias)
          .doc(categoriaId)
          .get();
      final data = doc.data();
      final url = (data?['imagemUrl'] ?? data?['imageUrl'] ?? '').toString();
      _cache[categoriaId] = url;
      return url;
    } catch (_) {
      return '';
    }
  }
}

class _CategoriaThumbByServico {
  static const String colServicos = 'servicos';
  static final Map<String, String> _cacheServicoToUrl = {};
  static Future<String> getUrlFromServico(String servicoId) async {
    if (servicoId.isEmpty) return '';
    if (_cacheServicoToUrl.containsKey(servicoId))
      return _cacheServicoToUrl[servicoId]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(colServicos)
          .doc(servicoId)
          .get();
      final servData = doc.data();
      final categoriaId =
          (servData?['categoriaId'] ?? servData?['categoriaServicoId'] ?? '')
              .toString();
      final url = await _CategoriaThumbCache.getUrl(categoriaId);
      _cacheServicoToUrl[servicoId] = url;
      return url;
    } catch (_) {
      return '';
    }
  }
}

class _SolicCard extends StatelessWidget {
  final String docId;
  final String titulo, cliente, dataDesejada, endereco, estimativa, status;
  final bool recebidas;
  final String servicoId, categoriaIdFallback;
  final VoidCallback onVerDetalhes;

  const _SolicCard({
    required this.docId,
    required this.titulo,
    required this.cliente,
    required this.dataDesejada,
    required this.endereco,
    required this.estimativa,
    required this.status,
    required this.recebidas,
    required this.servicoId,
    required this.categoriaIdFallback,
    required this.onVerDetalhes,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = servicoId.isNotEmpty
        ? _CategoriaThumbByServico.getUrlFromServico(servicoId)
        : _CategoriaThumbCache.getUrl(categoriaIdFallback);
    final color = _statusColor(status);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E9FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String>(
                future: thumb,
                builder: (context, snap) {
                  final url = snap.data ?? '';
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade300,
                      image: url.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: url.isEmpty
                        ? const Icon(
                            Icons.image_outlined,
                            size: 22,
                            color: Colors.white70,
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Cliente: $cliente',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Data desejada: $dataDesejada',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.black54,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  endereco,
                  style: const TextStyle(fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (estimativa != '—') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Estimativa: ',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  estimativa,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          VisualizarRespostaPrestadorScreen(docId: docId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B2EFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Ver orçamento',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetalhesSolicitacaoScreen(docId: docId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B4CFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Ver solicitação',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'pendente':
        return Colors.orange.shade700;
      case 'respondida':
      case 'aceita':
        return const Color(0xFF4CAF50);
      case 'recusada':
      case 'cancelada':
        return Colors.red.shade700;
      case 'finalizada':
        return Colors.blueGrey.shade700;
      default:
        return Colors.black54;
    }
  }
}
