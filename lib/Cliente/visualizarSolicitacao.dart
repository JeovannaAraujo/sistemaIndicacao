import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VisualizarSolicitacaoScreen extends StatelessWidget {
  final String docId;
  const VisualizarSolicitacaoScreen({super.key, required this.docId});

  static const String _colSolicitacoes = 'solicitacoesOrcamento';
  static const String _colCategoriasServ = 'categoriasServicos';

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Detalhes da Solicitação'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(_colSolicitacoes)
            .doc(docId)
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

          final d = snap.data!.data()!;
          final estimativa = (d['estimativaValor'] is num)
              ? moeda.format((d['estimativaValor'] as num).toDouble())
              : 'R\$0,00';

          final titulo = (d['servicoTitulo'] ?? '').toString();
          final descricao = (d['descricaoDetalhada'] ?? '').toString();
          final quantidade = (d['quantidade']?.toString() ?? '').replaceAll(
            '.0',
            '',
          );
          final unAbrev = (d['unidadeSelecionadaAbrev'] ?? '').toString();
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

          final prestadorNome = (d['prestadorNome'] ?? '').toString();
          final servicoDesc = (d['servicoDescricao'] ?? '').toString();
          final servicoCategoriaId = (d['categoriaServicoId'] ?? '').toString();

          final valorMin = (d['servicoValorMinimo'] is num)
              ? (d['servicoValorMinimo'] as num).toDouble()
              : null;
          final valorMed = (d['servicoValorMedio'] is num)
              ? (d['servicoValorMedio'] as num).toDouble()
              : null;
          final valorMax = (d['servicoValorMaximo'] is num)
              ? (d['servicoValorMaximo'] as num).toDouble()
              : null;

          final end = (d['clienteEndereco'] is Map<String, dynamic>)
              ? (d['clienteEndereco'] as Map<String, dynamic>)
              : <String, dynamic>{};

          final cidade = (end['cidade'] ?? '').toString();
          final enderecoLinha = [
            end['rua'],
            if (end['numero'] != null) 'Nº ${end['numero']}',
            end['bairro'],
            end['cidade'],
            end['uf'] ?? end['estado'],
          ].where((e) => e != null && e.toString().isNotEmpty).join(', ');

          final clienteWhatsapp = (d['clienteWhatsapp'] ?? '').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== CARD DE RESUMO DO SERVIÇO =====
                _ServicoResumoCard(
                  titulo: titulo,
                  descricao: servicoDesc,
                  servicoId: (d['servicoId'] ?? '').toString(),
                  prestadorNome: prestadorNome,
                  cidade: cidade,
                  unidadeAbrev: unAbrev,
                ),

                const SizedBox(height: 16),

                // ===== RESTANTE DO DETALHE =====
                const _SectionTitle('Descrição detalhada da Solicitação'),
                const SizedBox(height: 6),
                _ReadonlyField.multiline(
                  controller: TextEditingController(text: descricao),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Quantidade ou dimensão'),
                const SizedBox(height: 6),
                Row(
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
                          text: unAbrev.isEmpty ? 'un.' : unAbrev,
                        ),
                        centered: true,
                      ),
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
                const _SectionTitle('Estimativa de Valor'),
                const SizedBox(height: 6),
                _ReadonlyField(
                  controller: TextEditingController(text: estimativa),
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Endereço do serviço'),
                const SizedBox(height: 6),
                _LabelValue(label: 'Local', value: enderecoLinha),

                const SizedBox(height: 16),
                const _SectionTitle('Contato'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 18,
                      color: Color(0xFF25D366),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      clienteWhatsapp.isEmpty
                          ? 'Sem WhatsApp'
                          : clienteWhatsapp,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const _SectionTitle('Imagens (opcional)'),
                const SizedBox(height: 6),
                _ImagesGrid(urls: imagens),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =======================================================
// ======== CARD IGUAL AO DA TELA DE SOLICITAR ===========
// =======================================================

class _ServicoResumoCard extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String servicoId;
  final String prestadorNome;
  final String cidade;
  final String? unidadeAbrev;

  const _ServicoResumoCard({
    required this.titulo,
    required this.descricao,
    required this.servicoId,
    required this.prestadorNome,
    required this.cidade,
    this.unidadeAbrev,
  });

  // 🔹 Busca imagem + valores direto do serviço e categoria
  Future<Map<String, dynamic>> _getServicoInfo() async {
    if (servicoId.isEmpty) return {};

    try {
      final servicoDoc = await FirebaseFirestore.instance
          .collection('servicos')
          .doc(servicoId)
          .get();

      if (!servicoDoc.exists) return {};

      final servicoData = servicoDoc.data() ?? {};
      final categoriaId = (servicoData['categoriaId'] ?? '').toString();

      String imagemUrl = '';
      if (categoriaId.isNotEmpty) {
        final catDoc = await FirebaseFirestore.instance
            .collection('categoriasServicos')
            .doc(categoriaId)
            .get();

        if (catDoc.exists) {
          imagemUrl = (catDoc.data()?['imagemUrl'] ?? '').toString();
        }
      }

      return {
        'imagemUrl': imagemUrl,
        'valorMinimo': servicoData['valorMinimo'],
        'valorMedio': servicoData['valorMedio'],
        'valorMaximo': servicoData['valorMaximo'],
      };
    } catch (e) {
      debugPrint('Erro ao buscar info do serviço: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return FutureBuilder<Map<String, dynamic>>(
      future: _getServicoInfo(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data ?? {};
        final imagemUrl = (data['imagemUrl'] ?? '').toString();
        final valorMinimo = (data['valorMinimo'] is num)
            ? (data['valorMinimo'] as num).toDouble()
            : null;
        final valorMedio = (data['valorMedio'] is num)
            ? (data['valorMedio'] as num).toDouble()
            : null;
        final valorMaximo = (data['valorMaximo'] is num)
            ? (data['valorMaximo'] as num).toDouble()
            : null;

        // 🔹 Monta a string dos valores
        String precosFmt() {
          final partes = <String>[];
          if (valorMinimo != null && valorMinimo > 0) {
            partes.add('Min: ${moeda.format(valorMinimo)}');
          }
          if (valorMedio != null && valorMedio > 0) {
            partes.add('Méd: ${moeda.format(valorMedio)}');
          }
          if (valorMaximo != null && valorMaximo > 0) {
            partes.add('Máx: ${moeda.format(valorMaximo)}');
          }

          if (partes.isEmpty) return '—';
          final unidadeTxt = (unidadeAbrev?.isNotEmpty ?? false)
              ? ' / ${unidadeAbrev!}'
              : '';
          return '${partes.join('   ')}$unidadeTxt';
        }

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEDE7F6), Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Imagem
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: imagemUrl.isEmpty
                      ? const Color(0xFFD1C4E9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  image: imagemUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imagemUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imagemUrl.isEmpty
                    ? const Icon(
                        Icons.image_outlined,
                        color: Colors.deepPurple,
                        size: 26,
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // ✅ Texto e valores
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (descricao.isNotEmpty)
                      Text(
                        descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Prestador: $prestadorNome',
                      style: const TextStyle(fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            cidade,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${moeda.format(valorMinimo ?? 0)} – '
                        '${moeda.format(valorMedio ?? 0)} – '
                        '${moeda.format(valorMaximo ?? 0)}'
                        '${(unidadeAbrev?.isNotEmpty ?? false) ? '/$unidadeAbrev' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.deepPurple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =======================================================
// ======== COMPONENTES REUTILIZADOS DE DETALHES =========
// =======================================================

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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
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
          child: Text(value.isEmpty ? '—' : value),
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
            child: Image.network(
              u,
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.dst,
            ),
          ),
        );
      },
    );
  }

  static void _showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
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
