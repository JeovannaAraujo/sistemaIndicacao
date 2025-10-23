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
  final String servicoId; // pode vir vazio
  final String servicoTitulo; // ex.: "Assentamento"
  final FirebaseFirestore? firestore; // injeção para testes

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
  final Map<String, ClienteInfo> clienteCache = {};
  final Map<String, Map<String, dynamic>> servicoCache = {};

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
    for (final k in const ['nota', 'rating', 'estrelas', 'notaGeral']) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    final aval = m['avaliacao'];
    if (aval is Map<String, dynamic>) {
      for (final k in const ['nota', 'rating', 'estrelas', 'notaGeral']) {
        final v = aval[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v);
          if (d != null) return d;
        }
      }
    }
    return null;
  }

  bool temMidia(Map<String, dynamic> m) {
    final imgs = m['imagens'] ?? m['imagemUrl'];
    if (imgs is List) return imgs.isNotEmpty;
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

  Future<ClienteInfo> getClienteInfo(String clienteId) async {
    if (clienteId.isEmpty) return const ClienteInfo(nome: 'Cliente');
    if (clienteCache.containsKey(clienteId)) return clienteCache[clienteId]!;

    try {
      final doc = await db.collection('usuarios').doc(clienteId).get();
      final data = doc.data() ?? {};
      final nome = (data['nome'] as String?)?.trim();
      final foto = (data['fotoUrl'] as String?)?.trim();
      final info = ClienteInfo(
        nome: (nome == null || nome.isEmpty) ? 'Cliente' : nome,
        fotoUrl: (foto != null && foto.isNotEmpty) ? foto : null,
      );
      clienteCache[clienteId] = info;
      return info;
    } catch (_) {
      return const ClienteInfo(nome: 'Cliente');
    }
  }

  /// 🔹 Busca os dados do serviço vinculado a uma solicitação
  Future<Map<String, dynamic>?> getServicoDaSolicitacao(
    String solicitacaoId,
  ) async {
    if (solicitacaoId.isEmpty) return null;
    if (servicoCache.containsKey(solicitacaoId))
      return servicoCache[solicitacaoId];

    try {
      final doc = await db
          .collection('solicitacoesOrcamento')
          .doc(solicitacaoId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final servico = {
        'servicoId': data['servicoId'],
        'servicoTitulo': data['servicoTitulo'],
        'servicoDescricao': data['servicoDescricao'],
      };

      servicoCache[solicitacaoId] = servico;
      return servico;
    } catch (e) {
      print('Erro ao buscar serviço da solicitação: $e');
      return null;
    }
  }

  // ================== CONSULTAS ==================
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAvaliacoesDoServico() {
    return db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .orderBy('data', descending: true)
        .snapshots();
  }

  /// 🔹 Calcula a média de avaliações do prestador **para o serviço atual**
  Future<Map<String, num>> mediaQtdServico() async {
    double soma = 0;
    int qtd = 0;

    // 1️⃣ Buscar todas as solicitações que tenham esse serviçoId
    final solicitacoesSnap = await db
        .collection('solicitacoesOrcamento')
        .where('servicoId', isEqualTo: widget.servicoId)
        .get();

    if (solicitacoesSnap.docs.isEmpty) return {'media': 0, 'qtd': 0};

    // 2️⃣ Extrair os IDs dessas solicitações
    final idsSolic = solicitacoesSnap.docs.map((d) => d.id).toList();

    // 3️⃣ Buscar todas as avaliações associadas a essas solicitações
    final avalSnap = await db
        .collection('avaliacoes')
        .where('solicitacaoId', whereIn: idsSolic)
        .get();

    for (final d in avalSnap.docs) {
      final n = nota(d.data());
      if (n != null) {
        soma += n;
        qtd++;
      }
    }

    final media = qtd == 0 ? 0 : soma / qtd;
    return {'media': media, 'qtd': qtd};
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAvaliacoesDoPrestador() {
    return db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .orderBy('data', descending: true)
        .snapshots();
  }

  Future<Map<String, num>> mediaQtdPrestador() async {
    final snap = await db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Avaliações'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Avaliações do serviço'),
              Tab(text: 'Avaliações do Prestador'),
            ],
          ),
        ),
        body: TabBarView(
          controller: tab,
          children: [abaServicoComFiltros(), abaPrestadorComFiltros()],
        ),
      ),
    );
  }

  // --------- ABA: Serviço ---------
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
              delegate: _PinnedHeaderDelegate(
                height: 96,
                child: FutureBuilder<Map<String, num>>(
                  future: mediaQtdServico(),
                  builder: (context, m) {
                    final media = (m.data?['media'] ?? 0).toDouble();
                    final qtd = (m.data?['qtd'] ?? 0).toInt();
                    return _HeaderServico(
                      media: media,
                      qtd: qtd,
                      titulo: widget.servicoTitulo,
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _BarraFiltrosPadrao(
                  total: docs.length,
                  comMidia: docs.where((d) => temMidia(d.data())).length,
                  somenteMidia: sSomenteMidia,
                  estrelas: sEstrelas,
                  onToggleMidia: (v) => setState(() => sSomenteMidia = v),
                  onChangeEstrelas: (v) => setState(() => sEstrelas = v),
                ),
              ),
            ),
            _SliverListaAvaliacoes(
              docs: filtrados,
              nota: nota,
              getClienteInfo: getClienteInfo,
              getServicoDaSolicitacao: getServicoDaSolicitacao,
            ),
          ],
        );
      },
    );
  }

  // --------- ABA: Prestador ---------
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
              delegate: _PinnedHeaderDelegate(
                height: 84,
                child: FutureBuilder<Map<String, num>>(
                  future: mediaQtdPrestador(),
                  builder: (context, m) {
                    final media = (m.data?['media'] ?? 0).toDouble();
                    final qtd = (m.data?['qtd'] ?? 0).toInt();
                    return _HeaderPrestador(media: media, qtd: qtd);
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _BarraFiltrosPadrao(
                  total: docs.length,
                  comMidia: docs.where((d) => temMidia(d.data())).length,
                  somenteMidia: pSomenteMidia,
                  estrelas: pEstrelas,
                  onToggleMidia: (v) => setState(() => pSomenteMidia = v),
                  onChangeEstrelas: (v) => setState(() => pEstrelas = v),
                ),
              ),
            ),
            _SliverListaAvaliacoes(
              docs: filtrados,
              nota: nota,
              getClienteInfo: getClienteInfo,
              getServicoDaSolicitacao: getServicoDaSolicitacao,
            ),
          ],
        );
      },
    );
  }
}

/* ============================ 
   WIDGETS REUTILIZÁVEIS 
   ============================ */

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _PinnedHeaderDelegate({required this.height, required this.child});

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
  bool shouldRebuild(covariant _PinnedHeaderDelegate old) =>
      height != old.height || child != old.child;
}

class _HeaderServico extends StatelessWidget {
  final double media;
  final int qtd;
  final String titulo;
  const _HeaderServico({
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

class _HeaderPrestador extends StatelessWidget {
  final double media;
  final int qtd;
  const _HeaderPrestador({required this.media, required this.qtd});

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
class _SliverListaAvaliacoes extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final double? Function(Map<String, dynamic>) nota;
  final Future<ClienteInfo> Function(String clienteId) getClienteInfo;
  final Future<Map<String, dynamic>?> Function(String solicitacaoId)
  getServicoDaSolicitacao;

  const _SliverListaAvaliacoes({
    required this.docs,
    required this.nota,
    required this.getClienteInfo,
    required this.getServicoDaSolicitacao,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Nenhuma avaliação com os filtros atuais.')),
      );
    }

    return SliverList.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i].data();
        String titulo = (d['servicoTitulo'] as String?) ?? '';
        final solicitacaoId = (d['solicitacaoId'] as String?) ?? '';
        final comentario = (d['comentario'] as String?) ?? '';
        final n = (nota(d) ?? 0.0).round();
        final ts = d['data'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();

        final clienteId = (d['clienteId'] as String?) ?? '';

        return FutureBuilder<Map<String, dynamic>?>(
          future: (titulo.isEmpty && solicitacaoId.isNotEmpty)
              ? getServicoDaSolicitacao(solicitacaoId)
              : Future.value({'servicoTitulo': titulo}),
          builder: (context, snapServ) {
            final servicoTitulo =
                snapServ.data?['servicoTitulo'] ?? titulo ?? '';

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      if (servicoTitulo.isNotEmpty)
                        Text(
                          servicoTitulo,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                      // FOTO + NOME DO CLIENTE

                      // FOTO + NOME DO CLIENTE
                      if (clienteId.isNotEmpty)
                        FutureBuilder<ClienteInfo>(
                          future: getClienteInfo(clienteId),
                          builder: (context, snapCli) {
                            final info =
                                snapCli.data ??
                                const ClienteInfo(nome: 'Cliente');

                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                bottom: 6.0,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFFEDE7FF),
                                    backgroundImage: (info.fotoUrl != null)
                                        ? NetworkImage(info.fotoUrl!)
                                        : null,
                                    child: (info.fotoUrl == null)
                                        ? const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Color(0xFF5B33D6),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      info.nome,
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
      },
    );
  }
}

// ---------- Barra de filtros ----------
class _BarraFiltrosPadrao extends StatelessWidget {
  final int total;
  final int comMidia;
  final bool somenteMidia;
  final int estrelas;
  final ValueChanged<bool> onToggleMidia;
  final ValueChanged<int> onChangeEstrelas;

  const _BarraFiltrosPadrao({
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
          child: _FiltroPill(
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
          child: _FiltroPill(
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
          child: _DropdownEstrelasExato(
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

class _FiltroPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _FiltroPill({
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

class _DropdownEstrelasExato extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double width;
  final double height;

  const _DropdownEstrelasExato({
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
