// lib/Prestador/homePrestador.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Login/login.dart';
import 'agendaPrestador.dart';
import 'solicitacoesRecebidas.dart';
import 'editarServico.dart';
import 'visualizarAvaliacoes.dart';
import 'perfilPrestador.dart'; // para abrir o perfil do prestador via BottomNavigation

class HomePrestadorScreen extends StatefulWidget {
  const HomePrestadorScreen({super.key});

  @override
  State<HomePrestadorScreen> createState() => _HomePrestadorScreenState();
}

class _HomePrestadorScreenState extends State<HomePrestadorScreen> {
  final user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  // ======== STREAM: contagem de pendentes para badge ========
  static const String _colSolicitacoes = 'solicitacoesOrcamento';
  Stream<int> _pendentesCountStream(String prestadorId) {
    return FirebaseFirestore.instance
        .collection(_colSolicitacoes)
        .where('prestadorId', isEqualTo: prestadorId)
        .where('status', isEqualTo: 'pendente')
        .snapshots()
        .map((s) => s.size);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    final uid = user?.uid ?? '';
    if (index == 1) {
      // Solicitações
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SolicitacoesRecebidasScreen()),
      );
    } else if (index == 2) {
      // Perfil do Prestador
      if (uid.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PerfilPrestador(userId: uid)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
      }
    }
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
          // TODO: navegue para sua tela de serviços finalizados
        },
      ),
      _IconOnlyAtalho.withBadge(
        icon: Icons.assignment,
        color: Colors.orange,
        label: 'Solicitações',
        badgeStream: (uid == null) ? null : _pendentesCountStream(uid),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SolicitacoesRecebidasScreen(),
            ),
          );
        },
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
        const SizedBox(height: 8),
        const Text(
          'Atalhos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 12),
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

  // ===================== SERVIÇOS (igual ao Perfil) ====================

  // Helpers de avaliação (mesmos comportamentos do Perfil)
  double? _extrairNotaGenerica(Map<String, dynamic> data) {
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

  Future<Map<String, num>> _mediaQtdDoServicoPorAvaliacoes(
    String servicoId, {
    String? prestadorId,
    String? servicoTitulo,
  }) async {
    try {
      if (servicoId.isEmpty) return {'media': 0, 'qtd': 0};
      final fs = FirebaseFirestore.instance;
      double soma = 0;
      int qtd = 0;

      // (A) via solicitacoesOrcamento -> avaliacoes (solicitacaoId)
      final solicQuery = await fs
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
          final avSnap = await fs
              .collection('avaliacoes')
              .where('solicitacaoId', whereIn: chunk)
              .get();

          for (final a in avSnap.docs) {
            final data = a.data();
            final nota = _extrairNotaGenerica(data);
            if (nota != null) {
              soma += nota;
              qtd += 1;
            }
          }
        }
      }

      // (B) fallback por servicoId em 'avaliacoes'
      if (qtd == 0) {
        final possiveisCampos = [
          ['servicoId', servicoId],
          ['servico.id', servicoId],
          ['servicoIdRef', servicoId],
        ];
        for (final par in possiveisCampos) {
          final snap = await fs
              .collection('avaliacoes')
              .where(par[0] as String, isEqualTo: par[1])
              .get();
          if (snap.docs.isNotEmpty) {
            for (final a in snap.docs) {
              final nota = _extrairNotaGenerica(a.data());
              if (nota != null) {
                soma += nota;
                qtd++;
              }
            }
            break;
          }
        }
      }

      // (C) fallback final prestadorId + servicoTitulo
      if (qtd == 0) {
        if ((prestadorId ?? '').isNotEmpty &&
            (servicoTitulo ?? '').isNotEmpty) {
          final snap = await fs
              .collection('avaliacoes')
              .where('prestadorId', isEqualTo: prestadorId)
              .where('servicoTitulo', isEqualTo: servicoTitulo)
              .get();

          for (final a in snap.docs) {
            final nota = _extrairNotaGenerica(a.data());
            if (nota != null) {
              soma += nota;
              qtd++;
            }
          }
        }
      }

      final media = (qtd == 0) ? 0 : (soma / qtd);
      return {'media': media, 'qtd': qtd};
    } catch (_) {
      return {'media': 0, 'qtd': 0};
    }
  }

  void _abrirAvaliacoesDoServico({
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

  String _formatMoney(num? v) {
    final d = (v ?? 0).toDouble();
    final s = d.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }

  final Map<String, String> _categoriaServCache = {};
  final Map<String, String> _unidadeCache = {};

  Future<String?> _getNomeCategoriaServById(String id) async {
    if (id.isEmpty) return null;
    if (_categoriaServCache.containsKey(id)) return _categoriaServCache[id];
    final snap = await FirebaseFirestore.instance
        .collection('categoriasServicos')
        .doc(id)
        .get();
    final nome = snap.data()?['nome'] as String?;
    if (nome != null && nome.isNotEmpty) _categoriaServCache[id] = nome;
    return nome;
  }

  Future<String?> _getNomeUnidadeById(String id) async {
    if (id.isEmpty) return null;
    if (_unidadeCache.containsKey(id)) return _unidadeCache[id];
    final snap = await FirebaseFirestore.instance
        .collection('unidades')
        .doc(id)
        .get();
    final nome = snap.data()?['nome'] as String?;
    if (nome != null && nome.isNotEmpty) _unidadeCache[id] = nome;
    return nome;
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
        : _mediaQtdDoServicoPorAvaliacoes(
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: InkWell(
            onTap: () => _abrirAvaliacoesDoServico(
              servicoId: servicoId,
              servicoTitulo: servicoTitulo,
            ),
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${media.toStringAsFixed(1)} ($qtd avaliações)',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
            ),
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
        const SizedBox(height: 20),
        const Text(
          'Serviços Prestados',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('servicos')
              .where('prestadorId', isEqualTo: uid)
              .orderBy('nome')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Text('Erro ao carregar serviços: ${snap.error}');
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

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumb da categoria do serviço
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('categoriasServicos')
                            .doc(catId)
                            .get(),
                        builder: (context, snapCat) {
                          if (snapCat.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          final dataCat = snapCat.data?.data();
                          final imagemUrl =
                              (dataCat?['imagemUrl'] ?? '') as String?;

                          return Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                              image: (imagemUrl != null && imagemUrl.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(imagemUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (imagemUrl == null || imagemUrl.isEmpty)
                                ? const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  )
                                : null,
                          );
                        },
                      ),

                      const SizedBox(width: 12),

                      // Infos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TÍTULO
                            Text(
                              nomeServ,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // ⭐ LINHA DE AVALIAÇÃO (igual Perfil)
                            _ratingLinha(
                              servicoId: s.id,
                              servicoTitulo: nomeServ,
                              docMedia: avServ,
                              docQtd: qtdAvServ,
                            ),

                            if (descricaoServ.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  descricaoServ,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: FutureBuilder<String?>(
                                future: _getNomeCategoriaServById(catId),
                                builder: (context, catSnap) {
                                  final catNome = catSnap.data;
                                  return Text(
                                    (catNome != null && catNome.isNotEmpty)
                                        ? catNome
                                        : 'Categoria',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: FutureBuilder<String?>(
                                future: _getNomeUnidadeById(unidadeId),
                                builder: (context, uniSnap) {
                                  final unNome = (uniSnap.data ?? '').trim();
                                  final sufixo = unNome.isNotEmpty
                                      ? unNome
                                      : 'un';
                                  return Text(
                                    '${_formatMoney(price)}/$sufixo',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Ações: Editar + Ativado
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditarServico(serviceId: s.id),
                                ),
                              );
                            },
                            child: const Text('Editar'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Ativado'),
                              Switch(
                                value: ativo,
                                onChanged: (val) async {
                                  await s.reference.update({'ativo': val});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ===================== CONTEÚDO ===========================
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

          // atalhos somente ícones
          _buildAtalhosIcones(),

          // lista de serviços igual ao perfil
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
              : FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(u.uid)
                    .snapshots(),
          builder: (context, snap) {
            final dados = snap.data?.data();
            final nome = (dados?['nome'] ?? 'Prestador') as String;
            final endereco =
                (dados?['endereco'] as Map<String, dynamic>?) ?? {};
            final whatsapp = (endereco['whatsapp'] ?? '') as String;
            final rua = (endereco['rua'] ?? '') as String;
            final numero = (endereco['numero'] ?? '') as String;
            final bairro = (endereco['bairro'] ?? '') as String;
            final cidade = (endereco['cidade'] ?? '') as String;
            final fotoUrl = (dados?['fotoUrl'] ?? '') as String?;

            final enderecoTxt = [
              if (rua.isNotEmpty) '$rua, $numero',
              if (bairro.isNotEmpty) bairro,
              if (cidade.isNotEmpty) cidade,
            ].where((e) => e.trim().isNotEmpty).join(' • ');

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(nome),
                  accountEmail: Text(
                    whatsapp.isNotEmpty ? whatsapp : (u?.email ?? ''),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                        ? NetworkImage(fotoUrl)
                        : null,
                    child: (fotoUrl == null || fotoUrl.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.deepPurple,
                          )
                        : null,
                  ),
                  decoration: const BoxDecoration(color: Colors.deepPurple),
                  otherAccountsPictures: [
                    if (enderecoTxt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          enderecoTxt,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notificações'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configurações'),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment),
                  title: const Text('Solicitações'),
                  trailing: (uid == null)
                      ? null
                      : StreamBuilder<int>(
                          stream: _pendentesCountStream(uid),
                          builder: (context, snap) {
                            final c = snap.data ?? 0;
                            if (c <= 0) return const SizedBox.shrink();
                            return _Badge(count: c, small: true);
                          },
                        ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SolicitacoesRecebidasScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Serviços Finalizados'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
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
        title: const Text('Indica Aí'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        elevation: 0,
      ),

      body: _buildBody(),

      // ============== Bottom Bar SOMENTE 3 itens ==============
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: (uid == null)
                ? const Icon(Icons.description)
                : StreamBuilder<int>(
                    stream: _pendentesCountStream(uid),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      if (count <= 0) return const Icon(Icons.description);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.description),
                          Positioned(
                            right: -6,
                            top: -2,
                            child: _Badge(count: count),
                          ),
                        ],
                      );
                    },
                  ),
            label: 'Solicitações',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// =================== Widget de Badge reutilizável ===================
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
      constraints: BoxConstraints(
        minWidth: small ? 18 : 20,
        minHeight: small ? 18 : 20,
      ),
      child: Text(
        txt,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}

// =================== Ícone-only Atalho ===================
class _IconOnlyAtalho extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;

  const _IconOnlyAtalho({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  }) : badgeStream = null;

  const _IconOnlyAtalho.withBadge({
    super.key,
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
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
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
