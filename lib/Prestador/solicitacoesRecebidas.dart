// lib/Prestador/solicitacoesRecebidas.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'detalhesSolicitacao.dart';

class SolicitacoesRecebidasScreen extends StatefulWidget {
  const SolicitacoesRecebidasScreen({super.key});

  @override
  State<SolicitacoesRecebidasScreen> createState() =>
      _SolicitacoesRecebidasScreenState();
}

class _SolicitacoesRecebidasScreenState
    extends State<SolicitacoesRecebidasScreen>
    with SingleTickerProviderStateMixin {
  static const String colSolicitacoes = 'solicitacoesOrcamento';

  late final TabController _tab;
  late final String _prestadorId;
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _prestadorId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Stream das solicitações por status
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamSolicitacoes({
    required bool recebidas,
  }) {
    final fs = FirebaseFirestore.instance;
    final ref = fs
        .collection(colSolicitacoes)
        .where('prestadorId', isEqualTo: _prestadorId);

    if (recebidas) {
      // novas / não respondidas
      return ref
          .where('status', isEqualTo: 'pendente')
          .orderBy('criadoEm', descending: true)
          .snapshots();
    } else {
      // já respondidas / tratadas
      return ref
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
  }

  String _enderecoLinha(Map<String, dynamic>? e) {
    final m = (e ?? {});
    String ln = '';
    if ((m['rua'] ?? '').toString().isNotEmpty) {
      ln = '${m['rua']}';
      if ((m['numero'] ?? '').toString().isNotEmpty) {
        ln += ', Nº ${m['numero']}';
      }
      if ((m['complemento'] ?? '').toString().isNotEmpty) {
        ln += ', ${m['complemento']}';
      }
    }
    final bairro = (m['bairro'] ?? '').toString();
    final cep = (m['cep'] ?? '').toString();
    final cidade = (m['cidade'] ?? '').toString();

    final partes = <String>[
      if (ln.isNotEmpty) ln,
      if (bairro.isNotEmpty) bairro,
      if (cep.isNotEmpty) 'CEP $cep',
      if (cidade.isNotEmpty) cidade,
    ];
    return partes.join('. ');
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
          controller: _tab,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Recebidas'),
            Tab(text: 'Respondidas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ListaSolicitacoes(
            stream: _streamSolicitacoes(recebidas: true),
            moeda: _moeda,
          ),
          _ListaSolicitacoes(
            stream: _streamSolicitacoes(recebidas: false),
            moeda: _moeda,
          ),
        ],
      ),
    );
  }
}

class _ListaSolicitacoes extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final NumberFormat moeda;

  const _ListaSolicitacoes({required this.stream, required this.moeda});

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
            final estimativa = (d['estimativaValor'] is num)
                ? moeda.format((d['estimativaValor'] as num).toDouble())
                : '—';
            final dataDesejada = (d['dataDesejada'] is Timestamp)
                ? DateFormat(
                    'dd/MM/yyyy',
                  ).format((d['dataDesejada'] as Timestamp).toDate())
                : '—';
            final endereco = (d['clienteEndereco'] is Map<String, dynamic>)
                ? (d['clienteEndereco'] as Map<String, dynamic>)
                : <String, dynamic>{};
            final enderecoStr = _enderecoLinha(endereco);

            // 1) Pega o servicoId da solicitação
            final servicoId =
                (d['servicoId'] ??
                        d['ServicoId'] ?? // fallback caso venha capitalizado
                        '')
                    .toString();

            // 2) (fallback opcional) se não tiver servicoId, tenta usar categoriaId direto
            final categoriaIdFallback =
                (d['categoriaId'] ??
                        d['servicoCategoriaId'] ?? // nomes antigos
                        '')
                    .toString();

            return _SolicCard(
              titulo: titulo,
              cliente: cliente,
              dataDesejada: dataDesejada,
              endereco: enderecoStr,
              estimativa: estimativa,
              status: (d['status'] ?? '').toString(),
              onVerDetalhes: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetalhesSolicitacaoScreen(docId: docId),
                  ),
                );
              },

              // passa servicoId (regra principal) e um possível categoriaId de fallback
              servicoId: servicoId,
              categoriaIdFallback: categoriaIdFallback,
            );
          },
        );
      },
    );
  }

  String _enderecoLinha(Map<String, dynamic>? e) {
    final m = (e ?? {});
    String ln = '';
    if ((m['rua'] ?? '').toString().isNotEmpty) {
      ln = '${m['rua']}';
      if ((m['numero'] ?? '').toString().isNotEmpty) {
        ln += ', Nº ${m['numero']}';
      }
      if ((m['complemento'] ?? '').toString().isNotEmpty) {
        ln += ', ${m['complemento']}';
      }
    }
    final bairro = (m['bairro'] ?? '').toString();
    final cep = (m['cep'] ?? '').toString();
    final cidade = (m['cidade'] ?? '').toString();

    final partes = <String>[
      if (ln.isNotEmpty) ln,
      if (bairro.isNotEmpty) bairro,
      if (cep.isNotEmpty) 'CEP $cep',
      if (cidade.isNotEmpty) cidade,
    ];
    return partes.join('. ');
  }
}

/// Cache por CATEGORIA para imagem
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

/// Resolve a imagem da categoria partindo do SERVIÇO:
/// servicos/{servicoId} -> categoriaId -> categoriasServicos/{categoriaId}.imagemUrl
class _CategoriaThumbByServico {
  static const String colServicos = 'servicos';

  // cache final: servicoId -> imagemUrl
  static final Map<String, String> _cacheServicoToUrl = {};

  static Future<String> getUrlFromServico(String servicoId) async {
    if (servicoId.isEmpty) return '';

    // cache direto por serviço
    if (_cacheServicoToUrl.containsKey(servicoId)) {
      return _cacheServicoToUrl[servicoId]!;
    }

    try {
      // pega o documento do serviço
      final servDoc = await FirebaseFirestore.instance
          .collection(colServicos)
          .doc(servicoId)
          .get();

      final servData = servDoc.data();
      if (servData == null) {
        _cacheServicoToUrl[servicoId] = '';
        return '';
      }

      final categoriaId =
          (servData['categoriaId'] ??
                  servData['categoriaServicoId'] ?? // nomes antigos
                  '')
              .toString();

      if (categoriaId.isEmpty) {
        _cacheServicoToUrl[servicoId] = '';
        return '';
      }

      // pega a url da categoria (com cache por categoria)
      final url = await _CategoriaThumbCache.getUrl(categoriaId);
      _cacheServicoToUrl[servicoId] = url;
      return url;
    } catch (_) {
      return '';
    }
  }
}

class _SolicCard extends StatelessWidget {
  final String titulo;
  final String cliente;
  final String dataDesejada;
  final String endereco;
  final String estimativa;
  final String status;
  final VoidCallback onVerDetalhes;

  /// regra principal: buscar imagem via servicoId -> categoriaId -> imagemUrl
  final String servicoId;

  /// fallback: caso a solicitação antiga traga diretamente a categoria
  final String categoriaIdFallback;

  const _SolicCard({
    required this.titulo,
    required this.cliente,
    required this.dataDesejada,
    required this.endereco,
    required this.estimativa,
    required this.onVerDetalhes,
    required this.status,
    required this.servicoId,
    required this.categoriaIdFallback,
  });

  @override
  Widget build(BuildContext context) {
    final Future<String> futureThumb = servicoId.isNotEmpty
        ? _CategoriaThumbByServico.getUrlFromServico(servicoId)
        : _CategoriaThumbCache.getUrl(categoriaIdFallback);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1EAFE), Colors.white],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // THUMB: imagem da CATEGORIA do serviço (resolvida via servicoId)
          FutureBuilder<String>(
            future: futureThumb,
            builder: (context, snap) {
              final url = snap.data ?? '';
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
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

          // conteúdo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Cliente: $cliente', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'Data Desejada: $dataDesejada',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Estimativa: $estimativa',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onVerDetalhes,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Ver detalhes'),
                  ),
                ),
              ],
            ),
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
        return Colors.green.shade700;
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

/// *Exemplo* de tela de detalhes mínima.
/// (no seu app você usa DetalhesSolicitacaoScreen real)
class _SolicitacaoDetalheScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _SolicitacaoDetalheScreen({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solicitação #$docId')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(data.toString()),
      ),
    );
  }
}
