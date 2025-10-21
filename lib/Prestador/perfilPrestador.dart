import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:myapp/Prestador/avaliacoesPrestador.dart';
import 'editarPerfilPrestador.dart';
import 'rotasNavegacao.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Cliente/homeCliente.dart';

class PerfilPrestador extends StatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const PerfilPrestador({
    super.key,
    required this.userId,
    this.firestore,
    this.auth,
  });

  @override
  State<PerfilPrestador> createState() => PerfilPrestadorState();
}

class PerfilPrestadorState extends State<PerfilPrestador> {
  late FirebaseFirestore db;
  late FirebaseAuth auth;
  User? user;

  final Map<String, String> _categoriaProfCache = {};
  Map<String, String> get categoriaProfCache => _categoriaProfCache;

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;
    user = auth.currentUser;
  }

  // ====== Extrai nota genérica de vários formatos ======
  double? extrairNotaGenerica(Map<String, dynamic> data) {
    for (final k in const ['nota', 'rating', 'estrelas', 'notaGeral']) {
      final v = data[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }

    final aval = data['avaliacao'];
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

  // ====== Retorna nome da categoria profissional com cache ======
  Future<String?> getNomeCategoriaProfById(String id) async {
    if (id.isEmpty) return null;
    if (_categoriaProfCache.containsKey(id)) return _categoriaProfCache[id];

    final snap = await db.collection('categoriasProfissionais').doc(id).get();
    final nome = snap.data()?['nome'] as String?;
    if (nome != null && nome.isNotEmpty) _categoriaProfCache[id] = nome;
    return nome;
  }

  // ====== Stream de avaliações do prestador ======
  Stream<Map<String, num>> streamMediaETotalDoPrestador(String prestadorId) {
    return db
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: prestadorId)
        .snapshots()
        .map((snap) {
          double soma = 0;
          int qtd = 0;
          for (final d in snap.docs) {
            final nota = extrairNotaGenerica(d.data());
            if (nota != null) {
              soma += nota;
              qtd += 1;
            }
          }
          final media = qtd == 0 ? 0.0 : soma / qtd;
          return {'media': media, 'qtd': qtd};
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Prestador'),
        automaticallyImplyLeading: false, // 🔥 remove seta de voltar
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('usuarios').doc(widget.userId).snapshots(),

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

          // (mantém os campos antigos apenas como fallback visual inicial)
          double avaliacaoDoc = 0.0;
          final av = dados['avaliacao'];
          if (av is num) {
            avaliacaoDoc = av.toDouble();
          } else if (av is String) {
            avaliacaoDoc = double.tryParse(av) ?? 0.0;
          }
          final int qtdAvaliacoesDoc = (dados['qtdAvaliacoes'] is num)
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
                // ---------- Cabeçalho ----------
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.deepPurple.shade50,
                      backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: (fotoUrl == null || fotoUrl.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 34,
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
                          const SizedBox(height: 4),

                          // Categoria | 📍 Cidade
                          Builder(
                            builder: (context) {
                              if (catProfId == null || catProfId.isEmpty) {
                                return Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Sem categoria',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('|'),
                                    const SizedBox(width: 6),
                                    const FaIcon(
                                      FontAwesomeIcons.locationDot,
                                      size: 14,
                                      color: Colors.deepPurple,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        cidade,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return FutureBuilder<String?>(
                                future: getNomeCategoriaProfById(catProfId),
                                builder: (context, s) {
                                  final nomeCat = s.data ?? 'Categoria';
                                  return Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          nomeCat,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('|'),
                                      const SizedBox(width: 6),
                                      const FaIcon(
                                        FontAwesomeIcons.locationDot,
                                        size: 14,
                                        color: Colors.deepPurple,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          cidade,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 6),

                          // Avaliação (AGORA LENDO TODAS AS AVALIAÇÕES DO PRESTADOR)
                          StreamBuilder<Map<String, num>>(
                            stream: streamMediaETotalDoPrestador(widget.userId),
                            builder: (context, s) {
                              if (!s.hasData) {
                                return const SizedBox.shrink(); // retorna algo vazio enquanto carrega
                              }

                              final media = (s.data?['media'] ?? avaliacaoDoc)
                                  .toDouble();
                              final qtd = (s.data?['qtd'] ?? qtdAvaliacoesDoc)
                                  .toInt();

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VisualizarAvaliacoesPrestador(
                                            prestadorId: widget.userId,
                                          ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${media.toStringAsFixed(1)} ($qtd avaliações)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87, // 🔹 cor preta
                                        decoration: TextDecoration
                                            .none, // 🔹 remove sublinhado
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 6),

                          // WhatsApp
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
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

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
                const SizedBox(height: 12),

                // ---------- Formas de Pagamento ----------
                const Text(
                  'Formas de Pagamento:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (meiosDyn.isEmpty)
                  const Text('-')
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: meiosDyn.map((p) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 6,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                p.toString(),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 12),

                // ---------- Jornada ----------
                const SizedBox(height: 16),
                const Text(
                  'Jornada de Trabalho:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (jornadaDyn.isEmpty)
                  const Text('-')
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: jornadaDyn.map((dia) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dia.toString(),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 20),

                // Botão trocar perfil (para quem é ambos)
                if ((dados['tipoPerfil'] ?? '') == 'Ambos') ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('perfilAtivo', 'Cliente');
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Trocar para Cliente'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.deepPurple),
                        foregroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ---------- Botão Editar Perfil ----------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // usa a mesma barra centralizada
      bottomNavigationBar: const PrestadorBottomNav(selectedIndex: 2),
    );
  }
}
