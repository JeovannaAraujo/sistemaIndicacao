// lib/Prestador/perfilPrestador.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'editarPerfilPrestador.dart';
import 'rotasNavegacao.dart';

class PerfilPrestador extends StatefulWidget {
  final String userId;

  const PerfilPrestador({super.key, required this.userId});

  @override
  State<PerfilPrestador> createState() => _PerfilPrestadorState();
}

class _PerfilPrestadorState extends State<PerfilPrestador> {
  final user = FirebaseAuth.instance.currentUser;

  // ====== Cache simples para nome da categoria profissional ======
  final Map<String, String> _categoriaProfCache = {};
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

  // ====== Helper para extrair nota de formas diferentes ======
  double? _extrairNotaGenerica(Map<String, dynamic> data) {
    // tenta nos campos diretos
    for (final k in const ['nota', 'rating', 'estrelas', 'notaGeral']) {
      final v = data[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    // tenta em um mapa "avaliacao"
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

  /// Stream com todas as avaliações deste prestador
  Stream<Map<String, num>> _streamMediaETotalDoPrestador(String prestadorId) {
    return FirebaseFirestore.instance
        .collection('avaliacoes')
        .where('prestadorId', isEqualTo: prestadorId)
        .snapshots()
        .map((snap) {
          double soma = 0;
          int qtd = 0;
          for (final d in snap.docs) {
            final nota = _extrairNotaGenerica(d.data());
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
                                future: _getNomeCategoriaProfById(catProfId),
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
                            stream: _streamMediaETotalDoPrestador(
                              widget.userId,
                            ),
                            builder: (context, s) {
                              final media =
                                  (s.data?['media'] ??
                                          avaliacaoDoc) // fallback enquanto carrega
                                      .toDouble();
                              final qtd =
                                  (s.data?['qtd'] ??
                                          qtdAvaliacoesDoc) // fallback
                                      .toInt();

                              return Row(
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
                                    ),
                                  ),
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
                if (meiosDyn.isEmpty)
                  const Text('-')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: -8,
                    children: meiosDyn
                        .map((p) => Chip(label: Text('$p')))
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
                        .map((d) => Chip(label: Text('$d')))
                        .toList(),
                  ),

                const SizedBox(height: 20),

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
