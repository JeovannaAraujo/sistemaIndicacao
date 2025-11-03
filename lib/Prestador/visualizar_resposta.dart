import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VisualizarRespostaPrestadorScreen extends StatefulWidget {
  final String docId;
  final FirebaseFirestore? firestore; // ✅ injeção para testes

  const VisualizarRespostaPrestadorScreen({
    super.key,
    required this.docId,
    this.firestore,
  });

  @override
  State<VisualizarRespostaPrestadorScreen> createState() =>
      VisualizarRespostaPrestadorScreenState();
}

class VisualizarRespostaPrestadorScreenState
    extends State<VisualizarRespostaPrestadorScreen> {
  static const String colSolicitacoes = 'solicitacoesOrcamento';
  final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late FirebaseFirestore db; // ✅ público e não-final

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Resposta Enviada'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      // 🔹 CORRIGIDO: tipo genérico removido do StreamBuilder
      body: StreamBuilder(
        stream: db.collection(colSolicitacoes).doc(widget.docId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data;
          if (doc == null || !(doc as dynamic).exists) {
            return const Center(child: Text('Solicitação não encontrada.'));
          }

          // 🔹 Cast totalmente seguro e independente de tipo genérico
          final Object? rawData = (doc as dynamic).data();
          final Map<String, dynamic> d = {};
          if (rawData is Map) {
            rawData.forEach((key, value) {
              d[key.toString()] = value;
            });
          }

          // 🔹 Agora é impossível dar cast error
          final servicoTitulo = (d['servicoTitulo'] ?? '').toString();
          final quantidade = (d['quantidade'] ?? '').toString();
          final valorProposto = (d['valorProposto'] as num?)?.toDouble();
          final dataInicio = fmtData(d['dataInicioSugerida']);
          final dataFim = fmtData(d['dataFinalPrevista']);
          final tempoValor = (d['tempoEstimadoValor'] ?? '').toString();
          final tempoUnidade = (d['tempoEstimadoUnidade'] ?? '').toString();
          final servicoId = (d['servicoId'] ?? '').toString();
          final clienteNome = (d['clienteNome'] ?? '').toString();
          final clienteWhats = (d['clienteWhatsapp'] ?? '').toString();

          // 🔹 Unidade (id e abreviação)
          final unidadeSelecionadaId = (d['unidadeSelecionadaId'] ?? '')
              .toString();
          final servicoUnidadeId = (d['servicoUnidadeId'] ?? '')
              .toString(); // fallback
          final unidadeIdUsar = unidadeSelecionadaId.isNotEmpty
              ? unidadeSelecionadaId
              : servicoUnidadeId;

          // ✅ Converte mapa aninhado de forma segura (sem casts diretos)
          final Map<String, dynamic> clienteEndereco = {};
          final ce = d['clienteEndereco'];
          if (ce is Map) {
            ce.forEach((k, v) => clienteEndereco[k.toString()] = v);
          }

          final rua = (clienteEndereco['rua'] ?? '').toString();
          final numero = (clienteEndereco['numero'] ?? '').toString();
          final bairro = (clienteEndereco['bairro'] ?? '').toString();
          final cidade = (clienteEndereco['cidade'] ?? '').toString();
          final complemento = (clienteEndereco['complemento'] ?? '').toString();

          final enderecoCompleto = [
            if (rua.isNotEmpty) rua,
            if (numero.isNotEmpty) 'Nº $numero',
            if (bairro.isNotEmpty) bairro,
            if (cidade.isNotEmpty) cidade,
            if (complemento.isNotEmpty) complemento,
          ].join(', ');

          return FutureBuilder<Map<String, dynamic>>(
            future: getInfo(servicoId, unidadeIdUsar),
            builder: (context, snapInfo) {
              if (!snapInfo.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final info = snapInfo.data!;
              final imagemUrl = info['imagemUrl'] ?? '';
              final valorMin = info['valorMin'];
              final valorMed = info['valorMed'];
              final valorMax = info['valorMax'];
              final unidadeAbrev = info['unidadeAbrev'] ?? '';
              final categoriaNome = info['categoriaNome'] ?? '';
              final descricaoServ = info['descricaoServ'] ?? '';

              final whatsapp = clienteWhats;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ServicoResumoCard(
                      titulo: servicoTitulo,
                      descricao: descricaoServ,
                      imagemUrl: imagemUrl,
                      categoriaNome: categoriaNome,
                      cidade: cidade,
                      valorMin: valorMin,
                      valorMed: valorMed,
                      valorMax: valorMax,
                      unidadeAbrev: unidadeAbrev,
                    ),

                    const SizedBox(height: 20),
                    const _SectionTitle('Quantidade ou dimensão'),
                    _ReadonlyBox(
                      '${quantidade.replaceAll('.0', '')} ${unidadeAbrev.isNotEmpty ? unidadeAbrev : ''}'
                          .trim(),
                    ),

                    const SizedBox(height: 16),
                    const _SectionTitle('Data de início sugerida'),
                    _ReadonlyBox(dataInicio),

                    const SizedBox(height: 16),
                    const _SectionTitle('Data final prevista'),
                    _ReadonlyBox(dataFim),

                    const SizedBox(height: 16),
                    const _SectionTitle('Estimativa de valor'),
                    _ReadonlyBox(moeda.format(valorProposto ?? 0)),

                    const SizedBox(height: 16),
                    const _SectionTitle('Tempo estimado de execução'),
                    _ReadonlyBox(formatTempo(tempoValor, tempoUnidade)),

                    const SizedBox(height: 20),
                    const _SectionTitle('Informações do Cliente'),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nome: $clienteNome',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Endereço: $enderecoCompleto',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.whatsapp,
                                size: 16,
                                color: whatsapp.isEmpty
                                    ? Colors.grey
                                    : Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  whatsapp.isEmpty ? 'Sem WhatsApp' : whatsapp,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: whatsapp.isEmpty
                                        ? Colors.grey
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
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
              );
            },
          );
        },
      ),
    );
  }

  // ==============================================================
  // 🔹 Funções auxiliares públicas para testes
  // ==============================================================

  static String fmtData(dynamic ts) {
    if (ts is! Timestamp) return '—';
    return DateFormat('dd/MM/yyyy').format(ts.toDate());
  }

  String formatTempo(dynamic tempo, String unidade) {
    if (tempo == null || tempo.toString().isEmpty) return '—';
    String valor = tempo.toString().replaceAll('.0', '');
    String unidadeFmt = unidade;
    if (unidadeFmt.isNotEmpty && valor != '1') {
      if (!unidadeFmt.endsWith('s')) unidadeFmt += 's';
    }
    return '$valor $unidadeFmt'.trim();
  }

  Future<Map<String, dynamic>> getInfo(
    String servicoId,
    String unidadeIdUsar,
  ) async {
    String imagemUrl = '';
    String categoriaNome = '';
    double? valorMin, valorMed, valorMax;
    String unidadeAbrev = '';
    String descricaoServ = '';

    try {
      // 🔹 Busca dados do serviço
      if (servicoId.isNotEmpty) {
        final servico = await db.collection('servicos').doc(servicoId).get();
        if (servico.exists) {
          final s = servico.data()!;
          descricaoServ = (s['descricao'] ?? '').toString();
          valorMin = (s['valorMinimo'] as num?)?.toDouble();
          valorMed = (s['valorMedio'] as num?)?.toDouble();
          valorMax = (s['valorMaximo'] as num?)?.toDouble();

          final categoriaId = (s['categoriaId'] ?? '').toString();
          if (categoriaId.isNotEmpty) {
            final cat = await db
                .collection('categoriasServicos')
                .doc(categoriaId)
                .get();
            final catData = cat.data();
            imagemUrl = (catData?['imagemUrl'] ?? '').toString();
            categoriaNome = (catData?['nome'] ?? '').toString();
          }
        }
      }

      // 🔹 Busca unidade de medida
      if (unidadeIdUsar.isNotEmpty) {
        final unidadeDoc = await db
            .collection('unidades')
            .doc(unidadeIdUsar)
            .get();
        if (unidadeDoc.exists) {
          unidadeAbrev = (unidadeDoc.data()?['abreviacao'] ?? '').toString();
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar info: $e');
    }

    return {
      'imagemUrl': imagemUrl,
      'descricaoServ': descricaoServ,
      'valorMin': valorMin,
      'valorMed': valorMed,
      'valorMax': valorMax,
      'unidadeAbrev': unidadeAbrev,
      'categoriaNome': categoriaNome,
    };
  }
}

/* =======================================================
   COMPONENTES (inalterados)
   ======================================================= */

class _ServicoResumoCard extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String imagemUrl;
  final String categoriaNome;
  final String cidade;
  final double? valorMin;
  final double? valorMed;
  final double? valorMax;
  final String unidadeAbrev;

  const _ServicoResumoCard({
    required this.titulo,
    required this.descricao,
    required this.imagemUrl,
    required this.categoriaNome,
    required this.cidade,
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
                  descricao.isEmpty ? '—' : descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cidade.isEmpty ? '—' : cidade,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${moeda.format(valorMin ?? 0)} – ${moeda.format(valorMed ?? 0)} – ${moeda.format(valorMax ?? 0)}'
                  '${unidadeAbrev.isNotEmpty ? '/$unidadeAbrev' : ''}',
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
  const _ReadonlyBox(this.text);

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
