// lib/Prestador/homePrestador.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../Login/login.dart';
import 'agendaPrestador.dart';
import 'editarServico.dart';
import 'visualizarAvaliacoes.dart';
import 'cadastroServicos.dart';
import 'servicosFinalizados.dart';
import 'rotasNavegacao.dart';

class HomePrestadorScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const HomePrestadorScreen({super.key, this.firestore, this.auth});

  @override
  State<HomePrestadorScreen> createState() => HomePrestadorScreenState();
}

class HomePrestadorScreenState extends State<HomePrestadorScreen> {
  late FirebaseFirestore db;
  late FirebaseAuth auth;
  User? user;

  @override
  void initState() {
    super.initState();
    // ✅ Correção mínima: garante instância padrão se não foi injetada
    db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;
    user = auth.currentUser;
  }

  Stream<int> pendentesCountStream(String prestadorId) {
    return db
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: prestadorId)
        .where('status', isEqualTo: 'pendente')
        .snapshots()
        .map((s) => s.size);
  }

  // ===================== ATALHOS (ícones coloridos + nome) =====================
  Widget _buildAtalhosIcones() {
    final uid = user?.uid;
    final atalhos = <Widget>[
      _IconOnlyAtalho(
        icon: Icons.check_circle,
        color: Colors.green,
        label: 'Finalizados',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ServicosFinalizadosPrestadorScreen(),
            ),
          );
        },
      ),
      _IconOnlyAtalho.withBadge(
        icon: Icons.assignment,
        color: Colors.orange,
        label: 'Solicitações',
        badgeStream: (uid != null)
            ? pendentesCountStream(uid)
            : const Stream.empty(),
        onTap: () => context.goSolicitacoes(replace: false),
      ),
      _IconOnlyAtalho(
        icon: Icons.calendar_month,
        color: Colors.blue,
        label: 'Agenda',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AgendaPrestadorScreen()),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 7),
        const Text(
          'Atalhos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: atalhos,
        ),
      ],
    );
  }

  // ===================== SERVIÇOS =====================

  double? extrairNotaGenerica(Map<String, dynamic> data) {
    final ordem = ['nota', 'rating', 'estrelas', 'notaGeral'];
    for (final c in ordem) {
      final v = data[c];
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    final aval = data['avaliacao'];
    if (aval is Map<String, dynamic>) {
      for (final c in ordem) {
        final v = aval[c];
        if (v is num) return v.toDouble();
        if (v is String) {
          final d = double.tryParse(v);
          if (d != null) return d;
        }
      }
    }
    return null;
  }

  Future<Map<String, num>> mediaQtdDoServicoPorAvaliacoes(
    String servicoId, {
    String? prestadorId,
    String? servicoTitulo,
  }) async {
    try {
      if (servicoId.isEmpty) return {'media': 0, 'qtd': 0};
      double soma = 0;
      int qtd = 0;

      final solicQuery = await db
          .collection('solicitacoesOrcamento')
          .where('servicoId', isEqualTo: servicoId)
          .get();

      if (solicQuery.docs.isNotEmpty) {
        final ids = solicQuery.docs.map((d) => d.id).toList();
        for (var i = 0; i < ids.length; i += 10) {
          final chunk = ids.sublist(
            i,
            (i + 10 > ids.length) ? ids.length : i + 10,
          );
          final avSnap = await db
              .collection('avaliacoes')
              .where('solicitacaoId', whereIn: chunk)
              .get();

          for (final a in avSnap.docs) {
            final nota = extrairNotaGenerica(a.data());
            if (nota != null) {
              soma += nota;
              qtd += 1;
            }
          }
        }
      }

      if (qtd == 0) {
        final possiveisCampos = [
          ['servicoId', servicoId],
          ['servico.id', servicoId],
          ['servicoIdRef', servicoId],
        ];
        for (final par in possiveisCampos) {
          final snap = await db
              .collection('avaliacoes')
              .where(par[0], isEqualTo: par[1])
              .get();
          if (snap.docs.isNotEmpty) {
            for (final a in snap.docs) {
              final nota = extrairNotaGenerica(a.data());
              if (nota != null) {
                soma += nota;
                qtd++;
              }
            }
            break;
          }
        }
      }

      if (qtd == 0 &&
          (prestadorId ?? '').isNotEmpty &&
          (servicoTitulo ?? '').isNotEmpty) {
        final snap = await db
            .collection('avaliacoes')
            .where('prestadorId', isEqualTo: prestadorId)
            .where('servicoTitulo', isEqualTo: servicoTitulo)
            .get();

        for (final a in snap.docs) {
          final nota = extrairNotaGenerica(a.data());
          if (nota != null) {
            soma += nota;
            qtd++;
          }
        }
      }

      final media = (qtd == 0) ? 0 : (soma / qtd);
      return {'media': media, 'qtd': qtd};
    } catch (_) {
      return {'media': 0, 'qtd': 0};
    }
  }

  void abrirAvaliacoesDoServico({
    required String servicoId,
    required String servicoTitulo,
  }) {
    final prestadorId = user?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarAvaliacoesScreen(
          prestadorId: prestadorId,
          servicoId: servicoId,
          servicoTitulo: servicoTitulo,
        ),
      ),
    );
  }

  Future<String?> getNomeCategoriaServById(String id) async {
    if (id.isEmpty) return null;
    final snap = await db.collection('categoriasServicos').doc(id).get();
    return snap.data()?['nome'] as String?;
  }

  Future<String?> getNomeUnidadeById(String id) async {
    if (id.isEmpty) return null;
    final snap = await db.collection('unidades').doc(id).get();
    return snap.data()?['abreviacao'] as String?;
  }

  Widget _ratingLinha({
    required String servicoId,
    required String servicoTitulo,
    required double docMedia,
    required int docQtd,
  }) {
    final prestadorId = user?.uid ?? '';
    final Future<Map<String, num>> fut = (docQtd > 0 || docMedia > 0)
        ? Future.value({'media': docMedia, 'qtd': docQtd})
        : mediaQtdDoServicoPorAvaliacoes(
            servicoId,
            prestadorId: prestadorId,
            servicoTitulo: servicoTitulo,
          );

    return FutureBuilder<Map<String, num>>(
      future: fut,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 18);
        }
        final media = (snap.data?['media'] ?? 0).toDouble();
        final qtd = (snap.data?['qtd'] ?? 0).toInt();

        return InkWell(
          onTap: () => abrirAvaliacoesDoServico(
            servicoId: servicoId,
            servicoTitulo: servicoTitulo,
          ),
          child: Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${media.toStringAsFixed(1)} ($qtd avaliações)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicosPrestadorSection() {
    final uid = user?.uid ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Serviços Prestados',
          actionLabel: 'Novo Serviço',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CadastroServicos()),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('servicos')
              .where('prestadorId', isEqualTo: uid)
              .orderBy('nome')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Text('Nenhum serviço cadastrado ainda.');
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final s = docs[i];
                final data = s.data();
                final ativo = data['ativo'] == true;
                final nomeServ = (data['nome'] ?? '') as String;
                final descricaoServ = (data['descricao'] ?? '') as String;
                final catId = (data['categoriaId'] ?? '') as String;
                final unidadeId = (data['unidadeId'] ?? '') as String;
                final num? vMed = data['valorMedio'] as num?;
                final num? vMin = data['valorMinimo'] as num?;
                final price = vMed ?? vMin ?? 0;

                double avServ = 0.0;
                final avVal = data['avaliacao'];
                if (avVal is num) {
                  avServ = avVal.toDouble();
                } else if (avVal is String) {
                  avServ = double.tryParse(avVal) ?? 0.0;
                }
                final int qtdAvServ = (data['qtdAvaliacoes'] is num)
                    ? (data['qtdAvaliacoes'] as num).toInt()
                    : 0;

                return _ServiceCard(
                  id: s.id,
                  nome: nomeServ,
                  descricao: descricaoServ,
                  categoriaId: catId,
                  unidadeId: unidadeId,
                  preco: price,
                  ativo: ativo,
                  docMedia: avServ,
                  docQtd: qtdAvServ,
                  data: data,
                  onEditar: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarServico(serviceId: s.id),
                    ),
                  ),
                  onToggleAtivo: (val) async =>
                      await s.reference.update({'ativo': val}),
                  getNomeCategoria: getNomeCategoriaServById,
                  getNomeUnidade: getNomeUnidadeById,
                  ratingBuilder: () => _ratingLinha(
                    servicoId: s.id,
                    servicoTitulo: nomeServ,
                    docMedia: avServ,
                    docQtd: qtdAvServ,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ===================== CONTEÚDO PRINCIPAL =====================
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Indica Aí',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const Text(
            'Gerencie seus serviços e oportunidades',
            style: TextStyle(color: Colors.deepPurple),
          ),
          const SizedBox(height: 20),
          _buildAtalhosIcones(),
          const SizedBox(height: 27),
          _buildServicosPrestadorSection(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final uid = u?.uid;

    return Scaffold(
      drawer: Drawer(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (u == null)
              ? const Stream.empty()
              : db.collection('usuarios').doc(u.uid).snapshots(),
          builder: (context, snap) {
            final dados = snap.data?.data();
            final nome = (dados?['nome'] ?? 'Prestador') as String;
            final endereco =
                (dados?['endereco'] as Map<String, dynamic>?) ?? {};
            final whatsapp = (endereco['whatsapp'] ?? '') as String;
            final cidade = (endereco['cidade'] ?? '') as String;
            final fotoUrl = (dados?['fotoUrl'] ?? '') as String?;
            final catProfId =
                (dados?['categoriaProfissionalId'] ?? '') as String?;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Colors.deepPurple),
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: (fotoUrl == null || fotoUrl.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.deepPurple,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Categoria + Cidade
                            FutureBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              future:
                                  (catProfId != null && catProfId.isNotEmpty)
                                  ? db
                                        .collection('categoriasProfissionais')
                                        .doc(catProfId)
                                        .get()
                                  : null,
                              builder: (context, catSnap) {
                                final catNome =
                                    (catSnap.data?.data()?['nome']
                                        as String?) ??
                                    'Profissional';
                                return Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        catNome,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (cidade.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      const Text(
                                        '|',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          cidade,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 6),

                            // WhatsApp
                            Row(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    whatsapp.isNotEmpty
                                        ? whatsapp
                                        : (u?.email ?? ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Ver perfil
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  context.goPerfil(replace: false);
                                },
                                child: const Text(
                                  'Ver perfil',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ======= MENU =======
                ListTile(
                  leading: const Icon(Icons.assignment),
                  title: const Text('Solicitações'),
                  trailing: (uid == null)
                      ? null
                      : StreamBuilder<int>(
                          stream: pendentesCountStream(uid),
                          builder: (context, snap) {
                            final c = snap.data ?? 0;
                            if (c <= 0) return const SizedBox.shrink();
                            return _Badge(count: c, small: true);
                          },
                        ),
                  onTap: () => context.goSolicitacoes(replace: false),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Agenda'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AgendaPrestadorScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Serviços Finalizados'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ServicosFinalizadosPrestadorScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () async {
                    Navigator.pop(context);
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _buildBody(),
      bottomNavigationBar: const PrestadorBottomNav(selectedIndex: 0),
    );
  }
}

// =================== Widgets auxiliares ===================

class _Badge extends StatelessWidget {
  final int count;
  final bool small;
  const _Badge({required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    final txt = (count > 99) ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 7,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: small ? 1 : 1.5),
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _IconOnlyAtalho extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;

  const _IconOnlyAtalho({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  }) : badgeStream = null;

  const _IconOnlyAtalho.withBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    required this.badgeStream,
  });

  @override
  Widget build(BuildContext context) {
    final iconText = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 36),
          tooltip: label,
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );

    if (badgeStream == null) return Center(child: iconText);

    return StreamBuilder<int>(
      stream: badgeStream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return Center(child: iconText);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: iconText),
            Positioned(right: 28, top: 2, child: _Badge(count: count)),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add, size: 18, color: Colors.deepPurple),
          label: Text(
            actionLabel,
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String id;
  final String nome;
  final String descricao;
  final String categoriaId;
  final String unidadeId;
  final num preco;
  final bool ativo;
  final double docMedia;
  final int docQtd;
  final Map<String, dynamic> data;
  final VoidCallback onEditar;
  final Future<void> Function(bool) onToggleAtivo;
  final Future<String?> Function(String) getNomeCategoria;
  final Future<String?> Function(String) getNomeUnidade;
  final Widget Function() ratingBuilder;

  const _ServiceCard({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.categoriaId,
    required this.unidadeId,
    required this.preco,
    required this.ativo,
    required this.docMedia,
    required this.docQtd,
    required this.data,
    required this.onEditar,
    required this.onToggleAtivo,
    required this.getNomeCategoria,
    required this.getNomeUnidade,
    required this.ratingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======= Cabeçalho (imagem + textos + avaliações)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📷 Miniatura
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _CategoriaThumb(
                  categoriaId: categoriaId,
                  db: FirebaseFirestore.instance,
                ),
              ),
              const SizedBox(width: 12),

              // 🧾 Texto e avaliações
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 70, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            nome,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          if (descricao.isNotEmpty)
                            Text(
                              descricao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                          FutureBuilder<String?>(
                            future: getNomeCategoria(categoriaId),
                            builder: (context, catSnap) {
                              final catNome = catSnap.data;
                              return Text(
                                (catNome != null && catNome.isNotEmpty)
                                    ? catNome
                                    : 'Categoria',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ⭐ Avaliações no canto superior direito
                    Positioned(
                      top: 0,
                      right: 0,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        child: ratingBuilder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10), // 🔹 espaçamento mais equilibrado
          // 💰 Valores
          FutureBuilder<String?>(
            future: getNomeUnidade(unidadeId),
            builder: (context, uniSnap) {
              final abrev = (uniSnap.data ?? '').trim();
              final unidadeAbrev = abrev.isNotEmpty ? abrev : 'un';
              final vMin = (data['valorMinimo'] ?? 0) as num;
              final vMed = (data['valorMedio'] ?? 0) as num;
              final vMax = (data['valorMaximo'] ?? 0) as num;
              String format(num n) =>
                  n.toDouble().toStringAsFixed(2).replaceAll('.', ',');

              return Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(
                  'Min: R\$${format(vMin)}   Méd: R\$${format(vMed)}   Máx: R\$${format(vMax)}/$unidadeAbrev',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                    fontSize: 12.5,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          // ====== Rodapé: Editar à esquerda | Ativo à direita
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onEditar,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.deepPurple, // 🔹 Cor mais viva
                  foregroundColor: Colors.white, // 🔹 Texto branco
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Editar'),
              ),
              const Spacer(),
              const Text(
                'Ativo',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: ativo,
                activeColor: Colors.deepPurple,
                onChanged: (val) => onToggleAtivo(val),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoriaThumb extends StatelessWidget {
  final String categoriaId;
  final FirebaseFirestore db;

  const _CategoriaThumb({required this.categoriaId, required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: db.collection('categoriasServicos').doc(categoriaId).get(),
      builder: (context, snapCat) {
        final radius = BorderRadius.circular(10);
        if (snapCat.connectionState == ConnectionState.waiting) {
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.06),
              borderRadius: radius,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final dataCat = snapCat.data?.data();
        final imagemUrl = (dataCat?['imagemUrl'] ?? '') as String?;
        return ClipRRect(
          borderRadius: radius,
          child: Container(
            width: 64,
            height: 64,
            color: Colors.deepPurple.withOpacity(0.06),
            child: (imagemUrl != null && imagemUrl.isNotEmpty)
                ? Image.network(imagemUrl, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        );
      },
    );
  }
}
