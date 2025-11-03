import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'enviar_orcamento.dart';

class DetalhesSolicitacaoScreen extends StatelessWidget {
  final String docId;
  final FirebaseFirestore? firestore;

  const DetalhesSolicitacaoScreen({
    super.key,
    required this.docId,
    this.firestore,
  });

  static const String _colSolicitacoes = 'solicitacoesOrcamento';
  static const String _colUnidades = 'unidades';

  @override
  Widget build(BuildContext context) {
    final db = firestore ?? FirebaseFirestore.instance;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Detalhes Serviço'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection(_colSolicitacoes).doc(docId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Erro ao carregar a solicitação:\n${snap.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Solicitação não encontrada.'));
          }

          final d = snap.data!.data()!;
          final status = (d['status'] ?? '').toString().toLowerCase();
          final estimativa = (d['estimativaValor'] is num)
              ? moeda.format((d['estimativaValor'] as num).toDouble())
              : 'R\$0,00';
          final titulo = (d['servicoTitulo'] ?? '').toString();
          final descricao = (d['descricaoDetalhada'] ?? '').toString();

          final quantidade = (d['quantidade'] is num)
              ? ((d['quantidade'] as num) % 1 == 0
                    ? (d['quantidade'] as num).toInt().toString()
                    : NumberFormat("#.##", "pt_BR").format(d['quantidade']))
              : (d['quantidade']?.toString() ?? '');

          // 🔥 BUSCA A UNIDADE CORRETA: Primeiro tenta a unidade selecionada, depois a do serviço
          final unidadeSelecionadaAbrev = (d['unidadeSelecionadaAbrev'] ?? '')
              .toString();
          final servicoUnidadeId = (d['servicoUnidadeId'] ?? '').toString();
          final unidadeSelecionadaId = (d['unidadeSelecionadaId'] ?? '')
              .toString();

          final ts = d['dataDesejada'] as Timestamp?;
          final dataDesejada = ts == null
              ? ''
              : DateFormat('dd/MM/yyyy').format(ts.toDate());
          final horaDesejada = ts == null
              ? ''
              : DateFormat('HH:mm').format(ts.toDate());

          final imagens = (d['imagens'] is List)
              ? List<String>.from(d['imagens'] as List)
              : const <String>[];

          final clienteNome = (d['clienteNome'] ?? '').toString();
          final clienteWhatsapp = (d['clienteWhatsapp'] ?? '').toString();
          final end = (d['clienteEndereco'] is Map<String, dynamic>)
              ? (d['clienteEndereco'] as Map<String, dynamic>)
              : <String, dynamic>{};

          String enderecoLinha() {
            String ln = '';
            if ((end['rua'] ?? '').toString().isNotEmpty) {
              ln = '${end['rua']}';
              if ((end['numero'] ?? '').toString().isNotEmpty) {
                ln += ', Nº ${end['numero']}';
              }
              if ((end['complemento'] ?? '').toString().isNotEmpty) {
                ln += ', ${end['complemento']}';
              }
            }
            final bairro = (end['bairro'] ?? '').toString();
            final cep = (end['cep'] ?? '').toString();
            final cidade = (end['cidade'] ?? '').toString();
            final partes = <String>[
              if (ln.isNotEmpty) ln,
              if (bairro.isNotEmpty) bairro,
              if (cep.isNotEmpty) 'CEP $cep',
              if (cidade.isNotEmpty) cidade,
            ];
            return partes.join('. ');
          }

          final bool isProcessada = [
            'respondida',
            'aceita',
            'recusada',
            'cancelada',
            'finalizada',
          ].contains(status);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Estimativa de Valor'),
                const SizedBox(height: 6),

                if (d['estimativaValor'] != null &&
                    d['estimativaValor'] != 0) ...[
                  _ReadonlyField(
                    controller: TextEditingController(text: estimativa),
                  ),
                  const SizedBox(height: 6),
                  const _HintBox(
                    children: [
                      Text(
                        'Este valor é calculado automaticamente com base na quantidade informada e na média de preços do serviço.',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fórmula: Quantidade × Valor Médio por unidade.',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Este campo é apenas informativo e não pode ser editado manualmente.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ] else ...[
                  const _HintBox(
                    children: [
                      Text(
                        'Não há estimativa de valor para esta solicitação, pois o cliente selecionou uma unidade de medida diferente da cadastrada para o serviço.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                const _SectionTitle('Serviço desejado'),
                const SizedBox(height: 6),
                _ReadonlyField(controller: TextEditingController(text: titulo)),
                const SizedBox(height: 16),

                const _SectionTitle('Descrição detalhada da Solicitação'),
                const SizedBox(height: 6),
                _ReadonlyField.multiline(
                  controller: TextEditingController(text: descricao),
                ),
                const SizedBox(height: 16),

                const _SectionTitle('Quantidade ou dimensão'),
                const SizedBox(height: 6),

                // 🔥 STREAM BUILDER PARA BUSCAR A UNIDADE CORRETA
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _getUnidadeStream(
                    db,
                    unidadeSelecionadaId,
                    servicoUnidadeId,
                  ),
                  builder: (context, unidadeSnap) {
                    String unidadeAbrev = 'un.';

                    if (unidadeSnap.hasData && unidadeSnap.data!.exists) {
                      final unidadeData = unidadeSnap.data!.data()!;
                      unidadeAbrev = (unidadeData['abreviacao'] ?? 'un.')
                          .toString();
                    } else if (unidadeSelecionadaAbrev.isNotEmpty) {
                      unidadeAbrev = unidadeSelecionadaAbrev;
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _ReadonlyField(
                            controller: TextEditingController(
                              text: quantidade.isEmpty ? '—' : quantidade,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: _ReadonlyField(
                            controller: TextEditingController(
                              text: unidadeAbrev,
                            ),
                            centered: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                const _HintBox(
                  children: [
                    Text(
                      'Utilize essa informação para calcular o valor do orçamento com base no preço por unidade.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const _SectionTitle('Data desejada para início'),
                const SizedBox(height: 6),
                _ReadonlyField(
                  controller: TextEditingController(
                    text: dataDesejada.isEmpty ? 'Não informado' : dataDesejada,
                  ),
                  trailingIcon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 12),
                const _SectionTitle('Horário desejado para execução'),
                const SizedBox(height: 6),
                _ReadonlyField(
                  controller: TextEditingController(
                    text: horaDesejada.isEmpty ? 'Não informado' : horaDesejada,
                  ),
                  trailingIcon: Icons.access_time_outlined,
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Imagens (opcional)'),
                const SizedBox(height: 6),
                _ImagesGrid(urls: imagens),

                const SizedBox(height: 20),
                const _SectionTitle('Informações do cliente'),
                const SizedBox(height: 10),
                _LabelValue(label: 'Cliente', value: clienteNome),
                const SizedBox(height: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Endereço e Contato',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
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
                            enderecoLinha().isEmpty ? '—' : enderecoLinha(),
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 16,
                                color: Color(0xFF25D366),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                clienteWhatsapp.isEmpty
                                    ? 'Sem WhatsApp'
                                    : _aplicarMascaraWhatsApp(clienteWhatsapp),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (!isProcessada) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EnviarOrcamentoScreen(solicitacaoId: docId),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Enviar Orçamento'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _abrirDialogoRecusar(context, db),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE9D7FF),
                            foregroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Recusar Solicitação'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔥 MÉTODO PARA BUSCAR A UNIDADE CORRETA
  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUnidadeStream(
    FirebaseFirestore db,
    String unidadeSelecionadaId,
    String servicoUnidadeId,
  ) {
    // Primeiro tenta a unidade selecionada, depois a do serviço
    final unidadeId = unidadeSelecionadaId.isNotEmpty
        ? unidadeSelecionadaId
        : servicoUnidadeId;

    if (unidadeId.isEmpty) {
      // Retorna um stream vazio se não tiver ID
      return const Stream.empty();
    }

    return db.collection(_colUnidades).doc(unidadeId).snapshots();
  }

  // 🔥 FUNÇÃO DE MÁSCARA PARA WHATSAPP
  String _aplicarMascaraWhatsApp(String value) {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.length <= 2) {
      return value;
    } else if (value.length <= 7) {
      return '(${value.substring(0, 2)}) ${value.substring(2)}';
    } else {
      return '(${value.substring(0, 2)}) ${value.substring(2, 7)}-${value.substring(7)}';
    }
  }

  // ✅ recebe Firestore injetado
  void _abrirDialogoRecusar(BuildContext context, FirebaseFirestore db) {
    final motivoCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recusar Solicitação'),
        content: TextField(
          controller: motivoCtl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await db.collection(_colSolicitacoes).doc(docId).update({
                'status': 'recusada',
                'recusadaEm': FieldValue.serverTimestamp(),
                'recusaMotivo': motivoCtl.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
// ========================= Widgets auxiliares =========================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final TextEditingController controller;
  final bool multiline;
  final bool centered;
  final IconData? trailingIcon;

  const _ReadonlyField({
    required this.controller,
    this.centered = false,
    this.trailingIcon,
  }) : multiline = false;

  const _ReadonlyField.multiline({required this.controller})
    : multiline = true,
      centered = false,
      trailingIcon = null;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 5 : 1,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        suffixIcon: trailingIcon == null ? null : Icon(trailingIcon),
        filled: true,
        fillColor: Colors.white,
        hintText: '—',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  final List<Widget> children;
  const _HintBox({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E7FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 15, // 🔹 ajuste aqui o tamanho da fonte
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImagesGrid extends StatelessWidget {
  final List<String> urls;
  const _ImagesGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: const Text('Sem imagens anexadas'),
      );
    }

    return GridView.builder(
      itemCount: urls.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final u = urls[i];
        return InkWell(
          onTap: () => _showImage(context, u),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: Colors.grey.shade300,
              child: Image.network(u, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  static void _showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
