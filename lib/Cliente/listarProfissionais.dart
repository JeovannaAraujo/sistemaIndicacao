import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'visualizarPerfilPrestador.dart';

class ProfissionaisPorCategoriaScreen extends StatelessWidget {
  final String categoriaId;
  final String categoriaNome;

  const ProfissionaisPorCategoriaScreen({
    super.key,
    required this.categoriaId,
    required this.categoriaNome,
  });

  @override
  Widget build(BuildContext context) {
    // Consulta SEM orderBy (evita índice composto obrigatório).
    final query = FirebaseFirestore.instance
        .collection('usuarios')
        .where('tipoPerfil', isEqualTo: 'Prestador')
        .where('ativo', isEqualTo: true)
        .where('categoriaProfissionalId', isEqualTo: categoriaId);
        // .orderBy('criadoEm', descending: true); // <- se quiser usar, crie índice composto

    return Scaffold(
      appBar: AppBar(title: Text(categoriaNome)),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            // Mostra o erro real para facilitar a vida (ex.: link de índice do Firestore)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Ordena em memória por criadoEm desc (fallback para atualizadoEm, depois DateTime(0))
          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              DateTime _getDate(QueryDocumentSnapshot d) {
                final m = d.data() as Map<String, dynamic>;
                final ce = m['criadoEm'];
                final ae = m['atualizadoEm'];
                if (ce is Timestamp) return ce.toDate();
                if (ae is Timestamp) return ae.toDate();
                return DateTime.fromMillisecondsSinceEpoch(0);
              }

              final tb = _getDate(b);
              final ta = _getDate(a);
              return tb.compareTo(ta); // desc
            });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ainda não há profissionais de $categoriaNome.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final endereco =
                  (data['endereco'] as Map?)?.cast<String, dynamic>() ?? {};

              final nome = (data['nome'] ?? '').toString();
              final areaAtendimento = (data['areaAtendimento'] ?? '').toString();
              final cidade =
                  (endereco['cidade'] ?? data['cidade'] ?? '').toString();

              final fotoUrl = (data['fotoUrl'] ?? '').toString();
              final tempoExperiencia =
                  (data['tempoExperiencia'] ?? '').toString(); // "5-10 anos"

              // Campo de nota pode variar no seu app; aqui mantenho suporte ao que você usou.
              final double? nota = (data['nota'] is num)
                  ? (data['nota'] as num).toDouble()
                  : (data['avaliacao'] is num)
                      ? (data['avaliacao'] as num).toDouble()
                      : (data['rating'] is num)
                          ? (data['rating'] as num).toDouble()
                          : null;

              final int? avaliacoes = (data['avaliacoes'] is num)
                  ? (data['avaliacoes'] as num).toInt()
                  : (data['qtdAvaliacoes'] is num)
                      ? (data['qtdAvaliacoes'] as num).toInt()
                      : null;

              return _ProfessionalCard(
                id: docs[i].id,
                nome: nome,
                cidade: cidade,
                areaAtendimento: areaAtendimento,
                fotoUrl: fotoUrl,
                tempoExperiencia: tempoExperiencia,
                nota: nota,
                avaliacoes: avaliacoes,
                categoriaNome: categoriaNome,
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final String id;
  final String nome;
  final String cidade;
  final String areaAtendimento;
  final String fotoUrl;
  final String tempoExperiencia;
  final double? nota;
  final int? avaliacoes;
  final String categoriaNome;

  const _ProfessionalCard({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.areaAtendimento,
    required this.fotoUrl,
    required this.tempoExperiencia,
    required this.categoriaNome,
    this.nota,
    this.avaliacoes,
  });

  @override
  Widget build(BuildContext context) {
    // Prioriza "área de atendimento"; se vazio, mostra cidade
    final localText = areaAtendimento.isNotEmpty ? areaAtendimento : cidade;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar/foto
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
              child: (fotoUrl.isEmpty) ? const Icon(Icons.person, size: 32) : null,
            ),
            const SizedBox(width: 12),

            // Conteúdo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome + avaliação à direita
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (nota != null) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 18),
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
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.black45,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Categoria | 📍 Local (somente cidade/área)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          categoriaNome,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text('  |  ', style: TextStyle(color: Colors.black45)),
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          localText,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Experiência
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.work_outline,
                          size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      Text(
                        tempoExperiencia.isEmpty
                            ? 'Experiência não informada'
                            : tempoExperiencia,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Ações
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VisualizarPerfilPrestador(prestadorId: id),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            side: const BorderSide(color: Colors.deepPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Perfil Prestador'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Navegar para Agenda do prestador
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Abrir Agenda (implementar rota)'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Agenda',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
