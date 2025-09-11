import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'cadastroServicos.dart';
import 'editarServico.dart';
import 'editarPerfilPrestador.dart';
import 'homePrestador.dart';
import 'visualizarAvaliacoes.dart';

class PerfilPrestador extends StatefulWidget {
  final String userId;

  const PerfilPrestador({super.key, required this.userId});

  @override
  State<PerfilPrestador> createState() => _PerfilPrestadorState();
}

class _PerfilPrestadorState extends State<PerfilPrestador> {
  int _selectedIndex = 3;

  // Caches em memória
  final Map<String, String> _categoriaProfCache = {};
  final Map<String, String> _categoriaServCache = {};
  final Map<String, String> _unidadeCache = {};

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePrestadorScreen()),
        );
        break;
      case 1:
        // tela de busca
        break;
      case 2:
        // tela de solicitações do prestador
        break;
      case 3:
        // já está na tela
        break;
    }
  }

  // 👇 helper para abrir a tela de avaliações do serviço
  void _abrirAvaliacoesDoServico({
    required String servicoId,
    required String servicoTitulo,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarAvaliacoesScreen(
          prestadorId: widget.userId,
          servicoId: servicoId,
          servicoTitulo: servicoTitulo,
        ),
      ),
    );
  }

  // ============================
  // AVALIAÇÕES (cálculo robusto)
  // ============================

  // Lê nota em nomes diferentes de campo, priorizando 'nota'
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
    // (se precisar suportar outro nome, basta incluir acima)
  }

  // Calcula média/quantidade para o serviço:
  // (A) solicitacoesOrcamento -> avaliacoes por solicitacaoId
  // (B) fallback por servicoId direto (se existir na sua base)
  // (C) fallback final pelo que está no seu banco: prestadorId + servicoTitulo
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

      // (A) via solicitacoesOrcamento -> avaliacoes (solicitacaoId in [...])
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

      // (B) fallback por servicoId (se sua coleção avaliacoes tiver esse campo)
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

      // (C) fallback final pelo padrão do seu banco (print): prestadorId + servicoTitulo
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

  // Linha de rating com fallback automático
  Widget _ratingLinha({
    required String servicoId,
    required String servicoTitulo,
    required double docMedia,
    required int docQtd,
  }) {
    final String prestadorId = widget.userId;

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
            child: // dentro de _ratingLinha, substitua o Row(...) por:
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: // dentro de _ratingLinha, substitua o Row(...) por:
              FittedBox(
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
          ),
        );
      },
    );
  }

  // Nome da categoria PROFISSIONAL por ID
  Future<String?> _getNomeCategoriaProfById(String id) async {
    if (id.isEmpty) return null;
    if (_categoriaProfCache.containsKey(id)) return _categoriaProfCache[id];
    final snap = await FirebaseFirestore.instance
        .collection('categoriasProfissionais')
        .doc(id)
        .get();
    final nome = snap.data()?['nome'] as String?;
    if (nome != null && nome.isNotEmpty) _categoriaProfCache[id] = nome;
    return nome;
  }

  // Nome da categoria de SERVIÇO por ID
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

  // Nome da UNIDADE por ID
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

  String _formatMoney(num? v) {
    final d = (v ?? 0).toDouble();
    final s = d.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Prestador')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Prestador não encontrado.'));
          }

          final dados = snapshot.data!.data()!;
          final nome = (dados['nome'] ?? '') as String;
          final email = (dados['email'] ?? '') as String;
          final endereco = (dados['endereco'] as Map<String, dynamic>?) ?? {};
          final cidade = (endereco['cidade'] ?? '') as String;
          final whatsapp = (endereco['whatsapp'] ?? '') as String;
          final String? catProfId = dados['categoriaProfissionalId'] as String?;
          final String? fotoUrl = (dados['fotoUrl'] ?? '') as String?;

          double avaliacao = 0.0;
          final av = dados['avaliacao'];
          if (av is num) {
            avaliacao = av.toDouble();
          } else if (av is String) {
            avaliacao = double.tryParse(av) ?? 0.0;
          }
          final int qtdAvaliacoes = (dados['qtdAvaliacoes'] is num)
              ? (dados['qtdAvaliacoes'] as num).toInt()
              : 0;

          final descricao = (dados['descricao'] ?? '') as String;
          final tempoExperiencia = (dados['tempoExperiencia'] ?? '-') as String;

          final List<dynamic> jornadaDyn =
              (dados['jornada'] as List?) ?? const [];
          final List<dynamic> meiosDyn =
              (dados['meiosPagamento'] as List?) ?? const [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- TOPO ----------
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple.shade50,
                      backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: (fotoUrl == null || fotoUrl.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.deepPurple,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(color: Colors.grey),
                          ),

                          // Categoria profissional | Cidade
                          Builder(
                            builder: (context) {
                              if (catProfId == null || catProfId.isEmpty) {
                                return Text('Sem categoria | $cidade');
                              }
                              return FutureBuilder<String?>(
                                future: _getNomeCategoriaProfById(catProfId),
                                builder: (context, s) {
                                  final nomeCat = s.data ?? 'Categoria';
                                  return Text('$nomeCat | $cidade');
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(whatsapp),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${avaliacao.toStringAsFixed(1)} ($qtdAvaliacoes avaliações)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ---------- Descrição ----------
                if (descricao.isNotEmpty) ...[
                  Text(descricao, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                ],

                // ---------- Experiência ----------
                Text(
                  'Experiência: $tempoExperiencia',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                // ---------- Formas de Pagamento ----------
                const Text(
                  'Formas de Pagamento:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (meiosDyn.isEmpty)
                  const Text('-')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: meiosDyn
                        .map((pag) => Chip(label: Text('$pag')))
                        .toList(),
                  ),

                const SizedBox(height: 12),

                // ---------- Jornada ----------
                const Text(
                  'Jornada:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (jornadaDyn.isEmpty)
                  const Text('-')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: jornadaDyn
                        .map((dia) => Chip(label: Text('$dia')))
                        .toList(),
                  ),

                const SizedBox(height: 20),

                // ---------- Botões ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CadastroServicos(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Novo Serviço'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditarPerfilPrestador(userId: widget.userId),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Perfil'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---------- Serviços Prestados ----------
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
                      .where('prestadorId', isEqualTo: widget.userId)
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
                        final descricaoServ =
                            (data['descricao'] ?? '') as String;
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
                              // Thumb placeholder (categoria do serviço)
                              FutureBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
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
                                      image:
                                          (imagemUrl != null &&
                                              imagemUrl.isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(imagemUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child:
                                        (imagemUrl == null || imagemUrl.isEmpty)
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

                                    // ⭐ LINHA DE AVALIAÇÃO (logo abaixo do título)
                                    _ratingLinha(
                                      servicoId: s.id,
                                      servicoTitulo: nomeServ,
                                      docMedia: avServ,
                                      docQtd: qtdAvServ,
                                    ),

                                    if (descricaoServ.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2.0,
                                        ),
                                        child: Text(
                                          descricaoServ,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),

                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: FutureBuilder<String?>(
                                        future: _getNomeCategoriaServById(
                                          catId,
                                        ),
                                        builder: (context, catSnap) {
                                          final catNome = catSnap.data;
                                          return Text(
                                            (catNome != null &&
                                                    catNome.isNotEmpty)
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
                                          final unNome = (uniSnap.data ?? '')
                                              .trim();
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
                                          await s.reference.update({
                                            'ativo': val,
                                          });
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
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Solicitações',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
