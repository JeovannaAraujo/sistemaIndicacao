import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VisualizarRespostaScreen extends StatefulWidget {
  final String docId;
  const VisualizarRespostaScreen({super.key, required this.docId});

  @override
  State<VisualizarRespostaScreen> createState() =>
      VisualizarRespostaScreenState();
}

class VisualizarRespostaScreenState extends State<VisualizarRespostaScreen> {
  static const colSolicitacoes = 'solicitacoesOrcamento';
  final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Resposta do Prestador'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(colSolicitacoes)
            .doc(widget.docId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Erro: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.data!.exists) {
            return const Center(child: Text('Solicitação não encontrada.'));
          }

          final d = snap.data!.data() ?? {};
          final servicoId = (d['servicoId'] ?? '').toString();
          final prestadorId = (d['prestadorId'] ?? '').toString();
          final cidade = (d['clienteEndereco']?['cidade'] ?? '').toString();
          final descricao = (d['descricaoDetalhada'] ?? '').toString();
          final quantidade = (d['quantidade'] ?? '').toString();
          final valorProposto = (d['valorProposto'] as num?)?.toDouble();
          final tempo = (d['tempoEstimadoValor'] ?? '').toString();
          final tempoUn = (d['tempoEstimadoUnidade'] ?? '').toString();
          final dataInicio = fmtData(d['dataInicioSugerida']);
          final dataFim = fmtData(d['dataFinalPrevista']);
          final obs = (d['observacoesPrestador'] ?? '').toString();
          final unidadeSelecionadaId = (d['unidadeSelecionadaId'] ?? '')
              .toString();
          final servicoUnidadeId = (d['servicoUnidadeId'] ?? '').toString();
          final unidadeId = unidadeSelecionadaId.isNotEmpty
              ? unidadeSelecionadaId
              : servicoUnidadeId;

          return FutureBuilder<Map<String, dynamic>>(
            future: getInfo(servicoId, prestadorId, unidadeId),
            builder: (context, snap2) {
              if (!snap2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final info = snap2.data!;
              final unidadeAbrev = info['unidadeAbrev'] ?? '';
              final imagemUrl = info['imagemUrl'] ?? '';
              final valorMin = info['valorMin'];
              final valorMed = info['valorMed'];
              final valorMax = info['valorMax'];
              final whatsapp = info['whatsapp'] ?? '';

              String qtdFmt = quantidade.replaceAll('.0', '');
              if (unidadeAbrev.isNotEmpty) qtdFmt += ' $unidadeAbrev';

              // ====== status ======
              final status = (d['status'] ?? '').toString().toLowerCase();
              final jaAceitaOuCancelada =
                  status == 'aceita' ||
                  status == 'cancelada' ||
                  status == 'recusada_cliente';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== Card do serviço =====
                    _ServicoResumoCard(
                      titulo: (d['servicoTitulo'] ?? '').toString(),
                      descricao: (d['servicoDescricao'] ?? '').toString(),
                      cidade: cidade,
                      imagemUrl: imagemUrl,
                      valorMin: valorMin,
                      valorMed: valorMed,
                      valorMax: valorMax,
                      unidadeAbrev: unidadeAbrev,
                    ),

                    const SizedBox(height: 20),
                    const _SectionTitle('Descrição detalhada da Solicitação'),
                    _ReadonlyBox(
                      descricao.isEmpty ? '—' : descricao,
                      multiline: true,
                    ),

                    const SizedBox(height: 16),
                    const _SectionTitle('Quantidade ou dimensão'),
                    _ReadonlyBox(qtdFmt),

                    const SizedBox(height: 16),
                    const _SectionTitle('Data de início sugerida'),
                    _ReadonlyBox(dataInicio),

                    const SizedBox(height: 16),
                    const _SectionTitle('Data final prevista'),
                    _ReadonlyBox(dataFim),

                    const SizedBox(height: 16),
                    const _SectionTitle('Estimativa de Valor'),
                    _ReadonlyBox(moeda.format(valorProposto ?? 0)),

                    const SizedBox(height: 16),
                    const _SectionTitle('Tempo estimado de execução'),
                    _ReadonlyBox(formatTempo(tempo, tempoUn)),

                    const SizedBox(height: 16),
                    const _SectionTitle('Contato do prestador'),
                    _ContatoBox(whatsapp),

                    const SizedBox(height: 16),
                    const _SectionTitle('Observações do prestador'),
                    _ReadonlyBox(
                      obs.isEmpty ? 'Nenhuma.' : obs,
                      multiline: true,
                    ),

                    const SizedBox(height: 30),

                    // ===== Botões =====
                    if (jaAceitaOuCancelada)
                      ...[
                    ] else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection(colSolicitacoes)
                                  .doc(widget.docId)
                                  .update({
                                    'status': 'aceita',
                                    'aceitaEm': FieldValue.serverTimestamp(),
                                  });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Orçamento aceito com sucesso!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Aceitar Orçamento',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection(colSolicitacoes)
                                  .doc(widget.docId)
                                  .update({
                                    'status': 'recusada_cliente',
                                    'recusadaEm': FieldValue.serverTimestamp(),
                                  });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Orçamento recusado.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Recusar Orçamento',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // =================== Funções auxiliares ===================

  String formatTempo(dynamic tempo, String unidade) {
    if (tempo == null || tempo.toString().isEmpty) return '—';
    String valor = tempo.toString().replaceAll('.0', '');
    String unidadeFmt = unidade;
    if (unidadeFmt.isNotEmpty && valor != '1') {
      if (!unidadeFmt.endsWith('s')) unidadeFmt += 's';
    }
    return '$valor $unidadeFmt'.trim();
  }

  static String fmtData(dynamic ts) {
    if (ts is! Timestamp) return '—';
    return DateFormat('dd/MM/yyyy').format(ts.toDate());
  }

  Future<Map<String, dynamic>> getInfo(
    String servicoId,
    String prestadorId,
    String unidadeId, {
    FirebaseFirestore? firestore, // ✅ injeção opcional
  }) async {
    final db =
        firestore ?? FirebaseFirestore.instance; // ✅ usa o fake ou o real

    String unidadeAbrev = '';
    String imagemUrl = '';
    double? valorMin, valorMed, valorMax;
    String whatsapp = '';

    try {
      String unidadeFinalId = unidadeId;
      if (unidadeFinalId.isEmpty && servicoId.isNotEmpty) {
        final servico = await db.collection('servicos').doc(servicoId).get();
        unidadeFinalId = (servico.data()?['unidadeId'] ?? '').toString();
      }

      if (unidadeFinalId.isNotEmpty) {
        final u = await db.collection('unidades').doc(unidadeFinalId).get();
        unidadeAbrev = (u.data()?['abreviacao'] ?? '').toString();
      }

      if (servicoId.isNotEmpty) {
        final servico = await db.collection('servicos').doc(servicoId).get();
        if (servico.exists) {
          final s = servico.data()!;
          valorMin = (s['valorMinimo'] as num?)?.toDouble();
          valorMed = (s['valorMedio'] as num?)?.toDouble();
          valorMax = (s['valorMaximo'] as num?)?.toDouble();

          final categoriaId = (s['categoriaId'] ?? '').toString();
          if (categoriaId.isNotEmpty) {
            final cat = await db
                .collection('categoriasServicos')
                .doc(categoriaId)
                .get();
            imagemUrl = (cat.data()?['imagemUrl'] ?? '').toString();
          }
        }
      }

      if (prestadorId.isNotEmpty) {
        final p = await db.collection('usuarios').doc(prestadorId).get();
        final end = (p.data()?['endereco'] ?? {}) as Map?;
        whatsapp = (end?['whatsapp'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('Erro ao buscar info: $e');
    }

    return {
      'unidadeAbrev': unidadeAbrev,
      'imagemUrl': imagemUrl,
      'valorMin': valorMin,
      'valorMed': valorMed,
      'valorMax': valorMax,
      'whatsapp': whatsapp,
    };
  }
}

// --- Mock da tela para teste sem Firebase real ---
class VisualizarRespostaScreenFake extends VisualizarRespostaScreen {
  final FakeFirebaseFirestore firestore;

  const VisualizarRespostaScreenFake({
    super.key,
    required super.docId,
    required this.firestore,
  });

  @override
  State<VisualizarRespostaScreen> createState() =>
      _VisualizarRespostaScreenFakeState();
}

class _VisualizarRespostaScreenFakeState extends VisualizarRespostaScreenState {
  @override
  Widget build(BuildContext context) {
    // substitui o stream pelo fakeDb
    return Scaffold(
      appBar: AppBar(title: const Text('Mock da Resposta')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: (widget as VisualizarRespostaScreenFake)
            .firestore
            .collection(VisualizarRespostaScreenState.colSolicitacoes)
            .doc(widget.docId)
            .get(),
        builder: (context, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();
          final d = snap.data!.data() ?? {};
          return Column(
            children: [
              Text('Status: ${d['status']}'),
              ElevatedButton(
                key: const Key('btnAceitar'),
                onPressed: () async {
                  await (widget as VisualizarRespostaScreenFake)
                      .firestore
                      .collection(VisualizarRespostaScreenState.colSolicitacoes)
                      .doc(widget.docId)
                      .update({'status': 'aceita'});
                },
                child: const Text('Aceitar'),
              ),
              ElevatedButton(
                key: const Key('btnRecusar'),
                onPressed: () async {
                  await (widget as VisualizarRespostaScreenFake)
                      .firestore
                      .collection(VisualizarRespostaScreenState.colSolicitacoes)
                      .doc(widget.docId)
                      .update({'status': 'recusada_cliente'});
                },
                child: const Text('Recusar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* =======================================================
   CARD RESUMO DO SERVIÇO
   ======================================================= */

class _ServicoResumoCard extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String cidade;
  final String imagemUrl;
  final double? valorMin;
  final double? valorMed;
  final double? valorMax;
  final String unidadeAbrev;

  const _ServicoResumoCard({
    required this.titulo,
    required this.descricao,
    required this.cidade,
    required this.imagemUrl,
    required this.valorMin,
    required this.valorMed,
    required this.valorMax,
    required this.unidadeAbrev,
  });
  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 54,
              height: 54,
              color: Colors.grey.shade200,
              child: imagemUrl.isEmpty
                  ? const Icon(
                      Icons.image_outlined,
                      color: Colors.deepPurple,
                      size: 28,
                    )
                  : Image.network(imagemUrl, fit: BoxFit.cover),
            ),
          ),
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
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cidade,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${moeda.format(valorMin ?? 0)} – ${moeda.format(valorMed ?? 0)} – ${moeda.format(valorMax ?? 0)}',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* =======================================================
   COMPONENTES REUTILIZADOS
   ======================================================= */

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }
}

class _ReadonlyBox extends StatelessWidget {
  final String text;
  final bool multiline;
  const _ReadonlyBox(this.text, {this.multiline = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _ContatoBox extends StatelessWidget {
  final String whatsapp;
  const _ContatoBox(this.whatsapp);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const FaIcon(
            FontAwesomeIcons.whatsapp,
            color: Color(0xFF25D366),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              whatsapp.isEmpty ? 'Sem WhatsApp' : whatsapp,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
