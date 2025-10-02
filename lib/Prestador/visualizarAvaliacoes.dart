// visualizarAvaliacoes.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Info básica do cliente para exibir em cada avaliação
class _ClienteInfo {
  final String nome;
  final String? fotoUrl;
  const _ClienteInfo({required this.nome, this.fotoUrl});
}

class VisualizarAvaliacoesScreen extends StatefulWidget {
  final String prestadorId;
  final String servicoId;     // pode vir vazio; compatibilidade futura
  final String servicoTitulo; // ex.: "Assentamento"

  const VisualizarAvaliacoesScreen({
    super.key,
    required this.prestadorId,
    required this.servicoId,
    required this.servicoTitulo,
  });

  @override
  State<VisualizarAvaliacoesScreen> createState() =>
      _VisualizarAvaliacoesScreenState();
}

class _VisualizarAvaliacoesScreenState extends State<VisualizarAvaliacoesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _fs = FirebaseFirestore.instance;

  // ======== ESTADO DOS FILTROS (padronizados nas duas abas) ========
  // Prestador
  bool _pSomenteMidia = false;
  int _pEstrelas = 0; // 0=todas, 1..5 (exatas)

  // Serviço
  bool _sSomenteMidia = false;
  int _sEstrelas = 0; // 0=todas, 1..5 (exatas)

  // ======== CACHE de clientes (nome/foto) ========
  final Map<String, _ClienteInfo> _clienteCache = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ================== HELPERS ==================

  // Lê nota em diferentes nomes de campo
  double? _nota(Map<String, dynamic> m) {
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

  bool _temMidia(Map<String, dynamic> m) {
    final imgs = m['imagens'];
    if (imgs is List) return imgs.isNotEmpty;
    if (imgs is String) return imgs.trim().isNotEmpty;
    return false;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _aplicarFiltros({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool somenteMidia,
    required int estrelasExatas, // 0=todas
  }) {
    return docs.where((d) {
      final m = d.data();
      if (somenteMidia && !_temMidia(m)) return false;
      if (estrelasExatas > 0) {
        final n = _nota(m) ?? 0.0;
        if (n.round() != estrelasExatas) return false; // ★ filtro EXATO
      }
      return true;
    }).toList();
  }

  // Busca nome/foto do cliente com cache
  Future<_ClienteInfo> _getClienteInfo(String clienteId) async {
    if (clienteId.isEmpty) return const _ClienteInfo(nome: 'Cliente');
    if (_clienteCache.containsKey(clienteId)) return _clienteCache[clienteId]!;
    try {
      final doc = await _fs.collection('usuarios').doc(clienteId).get();
      final data = doc.data() ?? {};
      final nome = (data['nome'] as String?)?.trim();
      final foto = (data['fotoUrl'] as String?)?.trim();
      final info = _ClienteInfo(
        nome: (nome == null || nome.isEmpty) ? 'Cliente' : nome,
        fotoUrl: (foto != null && foto.isNotEmpty) ? foto : null,
      );
      _clienteCache[clienteId] = info;
      return info;
    } catch (_) {
      return const _ClienteInfo(nome: 'Cliente');
    }
  }

  // ================== CONSULTAS ==================

  // Avaliações daquele SERVIÇO
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamAvaliacoesDoServico() {
    return _fs
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .where('servicoTitulo', isEqualTo: widget.servicoTitulo)
        .orderBy('criadoEm', descending: true)
        .snapshots();
  }

  // Média/quantidade do SERVIÇO (conjunto completo – não muda com filtros)
  Future<Map<String, num>> _mediaQtdServico() async {
    double soma = 0;
    int qtd = 0;

    final snap = await _fs
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .where('servicoTitulo', isEqualTo: widget.servicoTitulo)
        .get();

    for (final d in snap.docs) {
      final n = _nota(d.data());
      if (n != null) {
        soma += n;
        qtd++;
      }
    }

    // Fallback se passar a salvar servicoId
    if (qtd == 0 && widget.servicoId.isNotEmpty) {
      for (final campo in const ['servicoId', 'servico.id', 'servicoIdRef']) {
        final s = await _fs
            .collection('avaliacoes')
            .where(campo, isEqualTo: widget.servicoId)
            .get();
        if (s.docs.isNotEmpty) {
          for (final d in s.docs) {
            final n = _nota(d.data());
            if (n != null) {
              soma += n;
              qtd++;
            }
          }
          break;
        }
      }
    }

    final media = qtd == 0 ? 0 : (soma / qtd);
    return {'media': media, 'qtd': qtd};
  }

  // Avaliações do PRESTADOR (todas)
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamAvaliacoesDoPrestador() {
    return _fs
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .orderBy('criadoEm', descending: true)
        .snapshots();
  }

  // Média/quantidade do PRESTADOR (conjunto completo – não muda com filtros)
  Future<Map<String, num>> _mediaQtdPrestador() async {
    final snap = await _fs
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .get();

    double soma = 0;
    int qtd = 0;
    for (final d in snap.docs) {
      final n = _nota(d.data());
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
          children: [_abaServicoComFiltros(), _abaPrestadorComFiltros()],
        ),
      ),
    );
  }

  // --------- ABA: Serviço (header PINNED; 1 Divider antes dos filtros) ---------
  Widget _abaServicoComFiltros() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamAvaliacoesDoServico(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];

        final filtrados = _aplicarFiltros(
          docs: docs,
          somenteMidia: _sSomenteMidia,
          estrelasExatas: _sEstrelas,
        );

        return CustomScrollView(
          slivers: [
            // ===== CABEÇALHO FIXO (não rola) =====
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeaderDelegate(
                height: 96, // altura fixa segura
                child: FutureBuilder<Map<String, num>>(
                  future: _mediaQtdServico(),
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

            // ✅ Única linha antes dos filtros
            const SliverToBoxAdapter(child: Divider(height: 1)),

            // ===== Filtros (ROLA) =====
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _BarraFiltrosPadrao(
                  total: docs.length,
                  comMidia: docs.where((d) => _temMidia(d.data())).length,
                  somenteMidia: _sSomenteMidia,
                  estrelas: _sEstrelas,
                  onToggleMidia: (v) => setState(() => _sSomenteMidia = v),
                  onChangeEstrelas: (v) => setState(() => _sEstrelas = v),
                ),
              ),
            ),

            // ===== Lista (ROLA) =====
            _SliverListaAvaliacoes(
              docs: filtrados,
              nota: _nota,
              getClienteInfo: _getClienteInfo,
            ),
          ],
        );
      },
    );
  }

  // --------- ABA: Prestador (header PINNED; 1 Divider antes dos filtros) ---------
  Widget _abaPrestadorComFiltros() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamAvaliacoesDoPrestador(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];

        final filtrados = _aplicarFiltros(
          docs: docs,
          somenteMidia: _pSomenteMidia,
          estrelasExatas: _pEstrelas,
        );

        return CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeaderDelegate(
                height: 84,
                child: FutureBuilder<Map<String, num>>(
                  future: _mediaQtdPrestador(),
                  builder: (context, m) {
                    final media = (m.data?['media'] ?? 0).toDouble();
                    final qtd = (m.data?['qtd'] ?? 0).toInt();
                    return _HeaderPrestador(media: media, qtd: qtd);
                  },
                ),
              ),
            ),

            // ✅ Única linha antes dos filtros
            const SliverToBoxAdapter(child: Divider(height: 1)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _BarraFiltrosPadrao(
                  total: docs.length,
                  comMidia: docs.where((d) => _temMidia(d.data())).length,
                  somenteMidia: _pSomenteMidia,
                  estrelas: _pEstrelas,
                  onToggleMidia: (v) => setState(() => _pSomenteMidia = v),
                  onChangeEstrelas: (v) => setState(() => _pEstrelas = v),
                ),
              ),
            ),

            _SliverListaAvaliacoes(
              docs: filtrados,
              nota: _nota,
              getClienteInfo: _getClienteInfo,
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

/// Delegate do SliverPersistentHeader com altura FIXA.
/// Corrige o erro "layoutExtent exceeds paintExtent" forçando o child
/// a ocupar exatamente a área do header.
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
  bool shouldRebuild(covariant _PinnedHeaderDelegate old) {
    return height != old.height || child != old.child;
    // Se quiser rebuildar quando mudar tema, pode retornar true.
  }
}

// ---------- Conteúdo do header da aba de SERVIÇO ----------
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
          // Título do serviço (uma linha)
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          // Linha da nota (sem quebra)
          Row(
            children: [
              Text(
                media.toStringAsFixed(1),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star, size: starSize, color: Colors.amber),
              const Icon(Icons.star, size: starSize, color: Colors.amber),
              const Icon(Icons.star, size: starSize, color: Colors.amber),
              const Icon(Icons.star, size: starSize, color: Colors.amber),
              const Icon(Icons.star, size: starSize, color: Colors.amber),
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

// ---------- Conteúdo do header da aba de PRESTADOR ----------
class _HeaderPrestador extends StatelessWidget {
  final double media;
  final int qtd;

  const _HeaderPrestador({
    required this.media,
    required this.qtd,
  });

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
          const Icon(Icons.star, size: starSize, color: Colors.amber),
          const Icon(Icons.star, size: starSize, color: Colors.amber),
          const Icon(Icons.star, size: starSize, color: Colors.amber),
          const Icon(Icons.star, size: starSize, color: Colors.amber),
          const Icon(Icons.star, size: starSize, color: Colors.amber),
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

// ---------- Barra de filtros ----------
class _BarraFiltrosPadrao extends StatelessWidget {
  final int total;
  final int comMidia;
  final bool somenteMidia;
  final int estrelas; // 0=todas, 1..5 (exato)
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
  final int value; // 0..5
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

// ======== SLIVER: Lista de avaliações ========
class _SliverListaAvaliacoes extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final double? Function(Map<String, dynamic>) nota;
  final Future<_ClienteInfo> Function(String clienteId) getClienteInfo;

  const _SliverListaAvaliacoes({
    required this.docs,
    required this.nota,
    required this.getClienteInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('Nenhuma avaliação com os filtros atuais.'),
        ),
      );
    }

    return SliverList.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i].data();
        final titulo = (d['servicoTitulo'] as String?) ?? '';
        final comentario = (d['comentario'] as String?) ?? '';
        final n = (nota(d) ?? 0.0).round(); // exibimos estrelas inteiras
        final ts = d['criadoEm'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();

        final clienteId = (d['clienteId'] as String?) ?? '';

        return Padding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 8 : 8, 16, 8),
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
                  if (titulo.isNotEmpty)
                    Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),

                  // FOTO + NOME DO CLIENTE
                  if (clienteId.isNotEmpty)
                    FutureBuilder<_ClienteInfo>(
                      future: getClienteInfo(clienteId),
                      builder: (context, snap) {
                        final info =
                            snap.data ?? const _ClienteInfo(nome: 'Cliente');

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
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
  }
}
