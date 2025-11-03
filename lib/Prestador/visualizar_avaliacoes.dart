import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Info básica do cliente para exibir em cada avaliação
class ClienteInfo {
  final String nome;
  final String? fotoUrl;
  const ClienteInfo({required this.nome, this.fotoUrl});
}

class VisualizarAvaliacoesScreen extends StatefulWidget {
  final String prestadorId;
  final String servicoId;
  final String servicoTitulo;
  final FirebaseFirestore? firestore;

  const VisualizarAvaliacoesScreen({
    super.key,
    required this.prestadorId,
    required this.servicoId,
    required this.servicoTitulo,
    this.firestore,
  });

  @override
  State<VisualizarAvaliacoesScreen> createState() =>
      VisualizarAvaliacoesScreenState();
}

class VisualizarAvaliacoesScreenState extends State<VisualizarAvaliacoesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tab;
  late FirebaseFirestore db;

  // ======== ESTADO DOS FILTROS ========
  bool pSomenteMidia = false;
  int pEstrelas = 0;

  bool sSomenteMidia = false;
  int sEstrelas = 0;

  // ======== CACHE ========
  final Map<String, String> clienteCache = {};

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tab.dispose();
    super.dispose();
  }

  // ================== HELPERS ==================
  double? nota(Map<String, dynamic> m) {
    final v = m['nota'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool temMidia(Map<String, dynamic> m) {
    final imgs = m['imagemUrl'];
    if (imgs is String) return imgs.trim().isNotEmpty;
    return false;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> aplicarFiltros({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool somenteMidia,
    required int estrelasExatas,
  }) {
    return docs.where((d) {
      final m = d.data();
      if (somenteMidia && !temMidia(m)) return false;
      if (estrelasExatas > 0) {
        final n = nota(m) ?? 0.0;
        if (n.round() != estrelasExatas) return false;
      }
      return true;
    }).toList();
  }

  Future<String> getClienteNome(String clienteId) async {
    if (clienteId.isEmpty) return 'Cliente';
    if (clienteCache.containsKey(clienteId)) return clienteCache[clienteId]!;

    try {
      final doc = await db.collection('usuarios').doc(clienteId).get();
      final nome = (doc.data()?['nome'] as String?)?.trim();
      final nomeFinal = (nome == null || nome.isEmpty) ? 'Cliente' : nome;
      clienteCache[clienteId] = nomeFinal;
      return nomeFinal;
    } catch (_) {
      return 'Cliente';
    }
  }

  // ================== CONSULTAS CORRETAS ==================

  /// 🔹 AVALIAÇÕES DO SERVIÇO: Apenas deste serviço específico
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAvaliacoesDoServico() {
    if (widget.servicoId.isEmpty) {
      return const Stream.empty();
    }

    // ✅ Filtro DIRETO no Firestore: apenas avaliações deste serviço
    return db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .where('servicoId', isEqualTo: widget.servicoId)
        .orderBy('data', descending: true)
        .snapshots();
  }

  /// 🔹 MÉDIA DO SERVIÇO: Apenas deste serviço específico
  Future<Map<String, num>> mediaQtdServico() async {
    if (widget.servicoId.isEmpty) return {'media': 0, 'qtd': 0};

    final snap = await db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .where('servicoId', isEqualTo: widget.servicoId) // ✅ Apenas este serviço
        .get();

    double soma = 0;
    int qtd = 0;
    
    for (final d in snap.docs) {
      final n = nota(d.data());
      if (n != null) {
        soma += n;
        qtd++;
      }
    }
    
    final media = qtd == 0 ? 0 : (soma / qtd);
    return {'media': media, 'qtd': qtd};
  }

  /// 🔹 AVALIAÇÕES DO PRESTADOR: TODAS as avaliações (todos os serviços)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAvaliacoesDoPrestador() {
    return db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .orderBy('data', descending: true)
        .snapshots();
  }

  /// 🔹 MÉDIA DO PRESTADOR: TODAS as avaliações (todos os serviços)
  Future<Map<String, num>> mediaQtdPrestador() async {
    final snap = await db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId) // ✅ Todas as avaliações
        .get();

    double soma = 0;
    int qtd = 0;
    for (final d in snap.docs) {
      final n = nota(d.data());
      if (n != null) {
        soma += n;
        qtd++;
      }
    }
    final media = qtd == 0 ? 0 : (soma / qtd);
    return {'media': media, 'qtd': qtd};
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliações'),
        bottom: TabBar(
          controller: tab,
          tabs: const [
            Tab(text: 'Avaliações do serviço'),
            Tab(text: 'Avaliações do Prestador'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tab,
        children: [abaServicoComFiltros(), abaPrestadorComFiltros()],
      ),
    );
  }

  // --------- ABA: Serviço (APENAS este serviço) ---------
  Widget abaServicoComFiltros() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: streamAvaliacoesDoServico(),
      builder: (context, snap) {
       
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snap.data?.docs ?? const [];

        final filtrados = aplicarFiltros(
          docs: docs,
          somenteMidia: sSomenteMidia,
          estrelasExatas: sEstrelas,
        );


        return CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: PinnedHeaderDelegate(
                height: 96,
                child: FutureBuilder<Map<String, num>>(
                  future: mediaQtdServico(),
                  builder: (context, m) {
                    final media = (m.data?['media'] ?? 0).toDouble();
                    final qtd = (m.data?['qtd'] ?? 0).toInt();
                    return HeaderServico(
                      media: media,
                      qtd: qtd,
                      titulo: widget.servicoTitulo,
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: BarraFiltrosPadrao(
                  total: docs.length,
                  comMidia: docs.where((d) => temMidia(d.data())).length,
                  somenteMidia: sSomenteMidia,
                  estrelas: sEstrelas,
                  onToggleMidia: (v) => setState(() => sSomenteMidia = v),
                  onChangeEstrelas: (v) => setState(() => sEstrelas = v),
                ),
              ),
            ),
            SliverListaAvaliacoes(
              docs: filtrados,
              getClienteNome: getClienteNome,
            ),
          ],
        );
      },
    );
  }

  // --------- ABA: Prestador (TODOS os serviços) ---------
  Widget abaPrestadorComFiltros() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: streamAvaliacoesDoPrestador(),
      builder: (context, snap) {
        
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];

        final filtrados = aplicarFiltros(
          docs: docs,
          somenteMidia: pSomenteMidia,
          estrelasExatas: pEstrelas,
        );


        return CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: PinnedHeaderDelegate(
                height: 84,
                child: FutureBuilder<Map<String, num>>(
                  future: mediaQtdPrestador(),
                  builder: (context, m) {
                    final media = (m.data?['media'] ?? 0).toDouble();
                    final qtd = (m.data?['qtd'] ?? 0).toInt();
                    return HeaderPrestador(media: media, qtd: qtd);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: BarraFiltrosPadrao(
                  total: docs.length,
                  comMidia: docs.where((d) => temMidia(d.data())).length,
                  somenteMidia: pSomenteMidia,
                  estrelas: pEstrelas,
                  onToggleMidia: (v) => setState(() => pSomenteMidia = v),
                  onChangeEstrelas: (v) => setState(() => pEstrelas = v),
                ),
              ),
            ),
            SliverListaAvaliacoes(
              docs: filtrados,
              getClienteNome: getClienteNome,
            ),
          ],
        );
      },
    );
  }

  Future getClienteInfo(String s) async {}
}

/* ============================ 
   WIDGETS REUTILIZÁVEIS 
   ============================ */

class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  PinnedHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        elevation: overlapsContent ? 1 : 0,
        child: child,
      ),
    );
  }

  @override
  double get maxExtent => height;
  @override
  double get minExtent => height;
  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate old) =>
      height != old.height || child != old.child;
}

class HeaderServico extends StatelessWidget {
  final double media;
  final int qtd;
  final String titulo;
  const HeaderServico({super.key, 
    required this.media,
    required this.qtd,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    const starSize = 16.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                media.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(
                5,
                (i) =>
                    const Icon(Icons.star, size: starSize, color: Colors.amber),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '($qtd avaliações)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeaderPrestador extends StatelessWidget {
  final double media;
  final int qtd;
  const HeaderPrestador({super.key, required this.media, required this.qtd});

  @override
  Widget build(BuildContext context) {
    const starSize = 16.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            media.toStringAsFixed(1),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          ...List.generate(
            5,
            (i) => const Icon(Icons.star, size: starSize, color: Colors.amber),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '($qtd avaliações)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ======== SLIVER: Lista de avaliações ========
class SliverListaAvaliacoes extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Future<String> Function(String clienteId) getClienteNome;

  const SliverListaAvaliacoes({super.key, 
    required this.docs,
    required this.getClienteNome,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Nenhuma avaliação encontrada',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i];
        final data = d.data();
        
        final comentario = (data['comentario'] as String?) ?? '';
        final nota = (data['nota'] as num?)?.toDouble() ?? 0.0;
        final n = nota.round();
        final ts = data['data'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();

        final clienteId = (data['clienteId'] as String?) ?? '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0x11000000)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FOTO + NOME DO CLIENTE
                  if (clienteId.isNotEmpty)
                    FutureBuilder<String>(
                      future: getClienteNome(clienteId),
                      builder: (context, snapCli) {
                        final nome = snapCli.data ?? 'Cliente';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFEDE7FF),
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Color(0xFF5B33D6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Estrelas + data
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (idx) => Icon(
                          idx < n ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (dt != null)
                        Text(
                          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),

                  if (comentario.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comentario),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Barra de filtros ----------
class BarraFiltrosPadrao extends StatelessWidget {
  final int total;
  final int comMidia;
  final bool somenteMidia;
  final int estrelas;
  final ValueChanged<bool> onToggleMidia;
  final ValueChanged<int> onChangeEstrelas;

  const BarraFiltrosPadrao({super.key, 
    required this.total,
    required this.comMidia,
    required this.somenteMidia,
    required this.estrelas,
    required this.onToggleMidia,
    required this.onChangeEstrelas,
  });

  static const double _pillHeight = 54;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FiltroPill(
            label: 'Todas',
            count: total,
            selected: !somenteMidia && estrelas == 0,
            width: double.infinity,
            height: _pillHeight,
            onTap: () {
              onToggleMidia(false);
              onChangeEstrelas(0);
            },
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: FiltroPill(
            label: 'Com Mídia',
            count: comMidia,
            selected: somenteMidia,
            width: double.infinity,
            height: _pillHeight,
            onTap: () => onToggleMidia(true),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: DropdownEstrelasExato(
            value: estrelas,
            onChanged: onChangeEstrelas,
            width: double.infinity,
            height: _pillHeight,
          ),
        ),
      ],
    );
  }
}

class FiltroPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  const FiltroPill({super.key, 
    required this.label,
    required this.count,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF5B33D6);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x115B33D6) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DropdownEstrelasExato extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double width;
  final double height;

  const DropdownEstrelasExato({super.key, 
    required this.value,
    required this.onChanged,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF5B33D6);
    const itens = [0, 1, 2, 3, 4, 5];

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onChanged: (v) => onChanged(v ?? 0),
          items: itens
              .map(
                (v) => DropdownMenuItem<int>(
                  value: v,
                  child: Text(v == 0 ? 'Todas' : '$v ★'),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => itens
              .map(
                (v) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estrelas ★',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        v == 0 ? 'Todas' : '$v ★',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}