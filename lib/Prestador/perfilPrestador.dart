import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'cadastroServicos.dart';
import 'editarServico.dart';
import 'editarPerfilPrestador.dart';
import 'homePrestador.dart';

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
                        // Com StreamBuilder não é necessário, mas se voltar para FutureBuilder algum dia,
                        // esse setState força o rebuild.
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
                              // Thumb placeholder
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
                                    if (qtdAvServ > 0 || avServ > 0)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${avServ.toStringAsFixed(1)} ($qtdAvServ avaliações)',
                                          ),
                                        ],
                                      ),

                                    Text(
                                      nomeServ,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                            catNome != null &&
                                                    catNome.isNotEmpty
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
