// lib/Prestador/visualizarAvaliacoesPrestador.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClienteInfo {
  final String nome;
  final String? fotoUrl;

  const ClienteInfo({required this.nome, this.fotoUrl});
}

class VisualizarAvaliacoesPrestador extends StatefulWidget {
  final String prestadorId;
  final FirebaseFirestore? firestore;

  const VisualizarAvaliacoesPrestador({
    super.key,
    required this.prestadorId,
    this.firestore,
  });

  @override
  State<VisualizarAvaliacoesPrestador> createState() =>
      VisualizarAvaliacoesPrestadorState();
}

class VisualizarAvaliacoesPrestadorState
    extends State<VisualizarAvaliacoesPrestador> {
  late final FirebaseFirestore firestore;
  late String prestadorId;

  bool somenteMidia = false;
  int estrelas = 0;

  final Map<String, ClienteInfo> clienteCache = {};

  @override
  void initState() {
    super.initState();
    firestore = widget.firestore ?? FirebaseFirestore.instance;
    prestadorId = widget.prestadorId;
  }

  double? nota(Map<String, dynamic> m) {
    final v = m['nota'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool temMidia(Map<String, dynamic> m) {
    final img = m['imagemUrl'];
    if (img is String) return img.trim().isNotEmpty;
    if (img is List) return img.isNotEmpty;
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
      final doc = await firestore.collection('usuarios').doc(clienteId).get();
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

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAvaliacoesDoPrestador() {
    return firestore
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: prestadorId)
        .orderBy('data', descending: true)
        .snapshots();
  }

  Future<Map<String, num>> mediaQtdPrestador() async {
    final snap = await firestore
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: prestadorId)
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

    final media = qtd == 0 ? 0 : soma / qtd;
    return {'media': media, 'qtd': qtd};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliações do Prestador')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streamAvaliacoesDoPrestador(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? const [];

          final filtrados = aplicarFiltros(
            docs: docs,
            somenteMidia: somenteMidia,
            estrelasExatas: estrelas,
          );

          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: PinnedHeaderDelegate(
                  height: 110,
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
              // 👉 Filtros no mesmo estilo dos outros módulos
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: BarraFiltrosPadrao(
                    total: docs.length,
                    comMidia:
                        docs.where((d) => temMidia(d.data())).length,
                    somenteMidia: somenteMidia,
                    estrelas: estrelas,
                    onToggleMidia: (v) => setState(() => somenteMidia = v),
                    onChangeEstrelas: (v) => setState(() => estrelas = v),
                  ),
                ),
              ),
              SliverListaAvaliacoes(
                docs: filtrados,
                nota: nota,
                getClienteInfo: getClienteInfo,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ======================= COMPONENTES =======================

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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FiltroPill(
            label: 'Todas',
            count: total,
            selected: !somenteMidia && estrelas == 0,
            onTap: () {
              onToggleMidia(false);
              onChangeEstrelas(0);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FiltroPill(
            label: 'Com Mídia',
            count: comMidia,
            selected: somenteMidia,
            onTap: () => onToggleMidia(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownEstrelasExato(
            value: estrelas,
            onChanged: onChangeEstrelas,
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
  final VoidCallback onTap;

  const FiltroPill({super.key, 
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF5B33D6);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x115B33D6) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '($count)',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DropdownEstrelasExato extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const DropdownEstrelasExato({super.key, 
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF5B33D6);
    const itens = [0, 1, 2, 3, 4, 5];
    return Container(
      height: 54,
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
              .map((v) => DropdownMenuItem<int>(
                    value: v,
                    child: Text(v == 0 ? 'Todas' : '$v ★'),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  PinnedHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  double get maxExtent => height;
  @override
  double get minExtent => height;
  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate old) => true;
}

class HeaderPrestador extends StatelessWidget {
  final double media;
  final int qtd;

  const HeaderPrestador({super.key, required this.media, required this.qtd});

  @override
  Widget build(BuildContext context) {
    final arred = media.isNaN ? 0 : media;
    final int cheias = arred.floor();
    final bool meia = (arred - cheias) >= 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            arred.toStringAsFixed(1),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          ...List.generate(
            5,
            (i) {
              if (i < cheias) {
                return const Icon(Icons.star, color: Colors.amber, size: 18);
              } else if (i == cheias && meia) {
                return const Icon(Icons.star_half,
                    color: Colors.amber, size: 18);
              } else {
                return const Icon(Icons.star_border,
                    color: Colors.amber, size: 18);
              }
            },
          ),
          const SizedBox(width: 8),
          Text('($qtd avaliações)',
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class SliverListaAvaliacoes extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final double? Function(Map<String, dynamic>) nota;
  final Future<ClienteInfo> Function(String clienteId) getClienteInfo;

  const SliverListaAvaliacoes({super.key, 
    required this.docs,
    required this.nota,
    required this.getClienteInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Nenhuma avaliação encontrada.')),
      );
    }

    return SliverList.builder(
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i].data();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('solicitacoesOrcamento')
                .doc(d['solicitacaoId'])
                .get(),
            builder: (context, solSnap) {
              String servicoTitulo = '';
              if (solSnap.hasData && solSnap.data?.data() != null) {
                final solData = solSnap.data!.data()!;
                servicoTitulo = (solData['servicoTitulo'] ?? '').toString();
              }

              final comentario = (d['comentario'] ?? '').toString();
              final n = (nota(d) ?? 0.0).round();
              final ts = d['data'];
              DateTime? dt;
              if (ts is Timestamp) dt = ts.toDate();
              final clienteId = (d['clienteId'] as String?) ?? '';

              return Card(
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B33D6),
                          ),
                        ),
                      const SizedBox(height: 6),
                      if (clienteId.isNotEmpty)
                        FutureBuilder<ClienteInfo>(
                          future: getClienteInfo(clienteId),
                          builder: (context, snap) {
                            final info =
                                snap.data ?? const ClienteInfo(nome: 'Cliente');
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFEDE7FF),
                                  backgroundImage: (info.fotoUrl != null)
                                      ? NetworkImage(info.fotoUrl!)
                                      : null,
                                  child: (info.fotoUrl == null)
                                      ? const Icon(Icons.person,
                                          size: 16, color: Color(0xFF5B33D6))
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
                            );
                          },
                        ),
                      const SizedBox(height: 6),
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
                      if (d['imagemUrl'] != null &&
                          (d['imagemUrl'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              d['imagemUrl'],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
