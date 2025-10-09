// lib/Cliente/visualizarPerfilPrestador.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'visualizarAgendaPrestador.dart';
import 'solicitarOrcamento.dart';
import '../Prestador/visualizarAvaliacoes.dart';

class VisualizarPerfilPrestador extends StatelessWidget {
  final String prestadorId;
  const VisualizarPerfilPrestador({super.key, required this.prestadorId});

  static const String colUsuarios = 'usuarios';
  static const String colCategoriasProf = 'categoriasProfissionais';
  static const String colServicos = 'servicos';
  static const String colUnidades = 'unidades';
  static const String colCategoriasServ = 'categoriasServicos';

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection(colUsuarios)
        .doc(prestadorId);

    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Erro ao carregar perfil.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Prestador não encontrado.'));
          }

          final d = Map<String, dynamic>.from(snap.data!.data() ?? {})
            ..removeWhere((_, v) => v == null);

          final nome = (d['nome'] ?? '').toString();
          final email = (d['email'] ?? '').toString();
          final fotoUrl = (d['fotoUrl'] ?? '').toString();
          final categoriaId = (d['categoriaProfissionalId'] ?? '').toString();
          final tempoExp = (d['tempoExperiencia'] ?? '').toString();
          final descricao = (d['descricao'] ?? '').toString();
          final nota = (d['nota'] is num)
              ? (d['nota'] as num).toDouble()
              : null;
          final avaliacoes = (d['avaliacoes'] is num)
              ? (d['avaliacoes'] as num).toInt()
              : null;

          final endereco = (d['endereco'] is Map)
              ? (d['endereco'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
          final cidade = (endereco['cidade'] ?? d['cidade'] ?? '').toString();
          final whatsapp = (endereco['whatsapp'] ?? d['whatsapp'] ?? '')
              .toString();

          final pagamentos = (d['meiosPagamento'] is List)
              ? List<String>.from(d['meiosPagamento'])
              : <String>[];

          final Future<DocumentSnapshot<Map<String, dynamic>>?> catFuture =
              categoriaId.isEmpty
              ? Future.value(null)
              : FirebaseFirestore.instance
                    .collection(colCategoriasProf)
                    .doc(categoriaId)
                    .get();

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: catFuture,
            builder: (context, catSnap) {
              String categoriaNome =
                  (catSnap.data?.data()?['nome']?.toString() ?? '');
              if (categoriaNome.isEmpty) {
                categoriaNome = (d['categoriaNome'] ?? '').toString();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      nome: nome,
                      email: email,
                      fotoUrl: fotoUrl,
                      categoria: categoriaNome,
                      cidade: cidade,
                      whatsapp: whatsapp,
                      nota: nota,
                      avaliacoes: avaliacoes,
                    ),

                    if (descricao.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(descricao, style: const TextStyle(fontSize: 14)),
                    ],

                    if (tempoExp.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Experiência: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: tempoExp),
                          ],
                        ),
                      ),
                    ],

                    if (pagamentos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Formas de Pagamento:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: pagamentos
                            .map(
                              (p) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  p.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Serviços Prestados',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await showAgendaPrestadorModal(
                              context,
                              prestadorId: prestadorId,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            side: const BorderSide(color: Colors.deepPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Agenda Prestador'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ListaServicos(prestadorId: prestadorId),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ================= CABEÇALHO =================
class _Header extends StatelessWidget {
  final String nome;
  final String email;
  final String fotoUrl;
  final String categoria;
  final String cidade;
  final String whatsapp;
  final double? nota;
  final int? avaliacoes;

  const _Header({
    required this.nome,
    required this.email,
    required this.fotoUrl,
    required this.categoria,
    required this.cidade,
    required this.whatsapp,
    required this.nota,
    required this.avaliacoes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEDE7F6), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: (fotoUrl.isNotEmpty)
                ? NetworkImage(fotoUrl)
                : null,
            child: (fotoUrl.isEmpty)
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        categoria.isEmpty
                            ? 'Categoria não informada'
                            : categoria,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Text(
                      '  |  ',
                      style: TextStyle(color: Colors.black45),
                    ),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        cidade.isEmpty ? 'Cidade não informada' : cidade,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (whatsapp.isNotEmpty)
                  Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        size: 16,
                        color: Color(0xFF25D366),
                      ),
                      const SizedBox(width: 6),
                      Text(whatsapp, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                const SizedBox(height: 6),
                if (nota != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        nota!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (avaliacoes != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${avaliacoes!} avaliações)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= LISTA DE SERVIÇOS =================
class _ListaServicos extends StatelessWidget {
  final String prestadorId;
  const _ListaServicos({required this.prestadorId});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection(VisualizarPerfilPrestador.colServicos)
        .where('prestadorId', isEqualTo: prestadorId)
        .where('ativo', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Erro ao carregar serviços.'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Nenhum serviço cadastrado por este prestador.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final s = docs[i].data();
            return _ServicoItem(
              serviceId: docs[i].id,
              prestadorId: prestadorId,
              data: s,
            );
          },
        );
      },
    );
  }
}

// ================= CARD DE SERVIÇO =================
class _ServicoItem extends StatelessWidget {
  final String serviceId;
  final String prestadorId;
  final Map<String, dynamic> data;
  const _ServicoItem({
    required this.serviceId,
    required this.prestadorId,
    required this.data,
  });

  String _formatPreco(dynamic v) {
    double? valor;
    if (v is num) valor = v.toDouble();
    if (v is String) {
      final cleaned = v
          .replaceAll('R\$', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      valor = double.tryParse(cleaned);
    }
    if (valor == null) return 'R\$0,00';
    return 'R\$${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<String> _abreviacaoUnidade(String? unidadeId) async {
    if (unidadeId == null || unidadeId.isEmpty) return '';
    final doc = await FirebaseFirestore.instance
        .collection(VisualizarPerfilPrestador.colUnidades)
        .doc(unidadeId)
        .get();
    final d = doc.data();
    if (d == null) return '';
    return (d['abreviacao'] ?? d['sigla'] ?? '').toString();
  }

  Future<String> _imagemDaCategoria(String? categoriaServicoId) async {
    if (categoriaServicoId == null || categoriaServicoId.isEmpty) return '';
    final doc = await FirebaseFirestore.instance
        .collection(VisualizarPerfilPrestador.colCategoriasServ)
        .doc(categoriaServicoId)
        .get();
    final d = doc.data();
    if (d == null) return '';
    return (d['imagemUrl'] ?? '').toString();
  }

  Future<Map<String, num>> _mediaQtdDoServicoPorAvaliacoes() async {
    final fs = FirebaseFirestore.instance;

    final avSnap = await fs
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: prestadorId)
        .get();

    double soma = 0.0;
    int qtd = 0;

    for (final av in avSnap.docs) {
      final avData = av.data();
      final solicId = (avData['solicitacaoId'] ?? '').toString();
      if (solicId.isEmpty) continue;

      final solic = await fs
          .collection('solicitacoesOrcamento')
          .doc(solicId)
          .get();
      final sData = solic.data();
      if (sData == null) continue;

      final sId = (sData['servicoId'] ?? '').toString();
      if (sId != serviceId) continue;

      final nRaw = avData['nota'];
      final n = nRaw is num
          ? nRaw.toDouble()
          : (nRaw is String ? double.tryParse(nRaw) ?? 0.0 : 0.0);

      if (n > 0) {
        soma += n;
        qtd += 1;
      }
    }

    final media = qtd > 0 ? (soma / qtd) : 0.0;
    return {'media': media, 'qtd': qtd};
  }

  @override
  Widget build(BuildContext context) {
    final titulo = (data['titulo'] ?? data['nome'] ?? '').toString();
    final descricao = (data['descricao'] ?? '').toString();

    final valorMin = data['valorMinimo'];
    final valorMed = data['valorMedio'];
    final valorMax = data['valorMaximo'];

    final unidadeId = (data['unidadeId'] ?? data['unidade'] ?? '').toString();
    final unidadeAbrevInline = (data['unidadeAbreviacao'] ?? '').toString();

    final imagemInline = (data['imagemUrl'] ?? '').toString();
    final categoriaServicoId =
        (data['categoriaServicoId'] ?? data['categoriaId'] ?? '').toString();

    final nota = (data['nota'] is num)
        ? (data['nota'] as num).toDouble()
        : null;
    final avaliacoes = (data['avaliacoes'] is num)
        ? (data['avaliacoes'] as num).toInt()
        : null;

    // === FUNÇÕES INTERNAS DE IMAGEM ===
    Widget thumb(String? url) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
          image: (url != null && url.isNotEmpty)
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
        ),
        child: (url == null || url.isEmpty)
            ? const Icon(Icons.handyman, color: Colors.deepPurple)
            : null,
      );
    }

    Widget thumbComImagem() {
      if (imagemInline.isNotEmpty) {
        return thumb(imagemInline);
      }
      return FutureBuilder<String>(
        future: _imagemDaCategoria(categoriaServicoId),
        builder: (context, snap) {
          final urlCategoria = snap.data ?? '';
          if (urlCategoria.isNotEmpty) {
            return thumb(urlCategoria);
          }
          return thumb('');
        },
      );
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisualizarAvaliacoesScreen(
                        prestadorId: prestadorId,
                        servicoId: serviceId,
                        servicoTitulo: titulo,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      (nota ?? 0).toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${(avaliacoes ?? 0)} avaliações)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbComImagem(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                      if (descricao.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FutureBuilder<String>(
                future: unidadeAbrevInline.isNotEmpty
                    ? Future.value(unidadeAbrevInline)
                    : _abreviacaoUnidade(unidadeId),
                builder: (context, snap) {
                  final unidadeAbrev = snap.data ?? '';
                  return Text(
                    'Mín: ${_formatPreco(valorMin)}   '
                    'Méd: ${_formatPreco(valorMed)}   '
                    'Máx: ${_formatPreco(valorMax)}'
                    '${unidadeAbrev.isNotEmpty ? '/$unidadeAbrev' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.deepPurple,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SolicitarOrcamentoScreen(
                        prestadorId: prestadorId,
                        servicoId: serviceId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Solicitar Orçamento',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
