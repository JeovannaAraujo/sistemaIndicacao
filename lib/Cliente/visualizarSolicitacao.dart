import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VisualizarSolicitacaoScreen extends StatelessWidget {
  final String docId;
  final FirebaseFirestore? firestore;
  const VisualizarSolicitacaoScreen({
    super.key,
    required this.docId,
    this.firestore,
  });

  static const String _colSolicitacoes = 'solicitacoesOrcamento';

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
        stream: (firestore ?? FirebaseFirestore.instance)
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
                ServicoResumoCard(
                  titulo: titulo,
                  descricao: servicoDesc,
                  servicoId: (d['servicoId'] ?? '').toString(),
                  prestadorNome: prestadorNome,
                  cidade: cidade,
                  unidadeAbrev: unAbrev,
                  firestore: firestore,
                ),

                const SizedBox(height: 16),

                // ===== RESTANTE DO DETALHE =====
                const SectionTitle('Descrição detalhada da Solicitação'),
                const SizedBox(height: 6),
                ReadonlyField.multiline(
                  controller: TextEditingController(text: descricao),
                ),

                const SizedBox(height: 16),
                const SectionTitle('Quantidade ou dimensão'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ReadonlyField(
                        controller: TextEditingController(
                          text: quantidade.isEmpty ? '—' : quantidade,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: ReadonlyField(
                        controller: TextEditingController(
                          text: unAbrev.isEmpty ? 'un.' : unAbrev,
                        ),
                        centered: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const SectionTitle('Data desejada para início'),
                const SizedBox(height: 6),
                ReadonlyField(
                  controller: TextEditingController(
                    text: dataDesejada.isEmpty ? 'Não informado' : dataDesejada,
                  ),
                  trailingIcon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 12),
                const SectionTitle('Horário desejado para execução'),
                const SizedBox(height: 6),
                ReadonlyField(
                  controller: TextEditingController(
                    text: horaDesejada.isEmpty ? 'Não informado' : horaDesejada,
                  ),
                  trailingIcon: Icons.access_time_outlined,
                ),

                const SizedBox(height: 16),
                const SectionTitle('Estimativa de Valor'),
                const SizedBox(height: 6),
                ReadonlyField(
                  controller: TextEditingController(text: estimativa),
                ),

                const SizedBox(height: 16),
                const SectionTitle('Endereço do serviço'),
                const SizedBox(height: 6),
                LabelValue(label: 'Local', value: enderecoLinha),

                const SizedBox(height: 16),
                const SectionTitle('Contato'),
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
                const SectionTitle('Imagens (opcional)'),
                const SizedBox(height: 6),
                ImagesGrid(urls: imagens),
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

class ServicoResumoCard extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String servicoId;
  final String prestadorNome;
  final String cidade;
  final String? unidadeAbrev;
  final FirebaseFirestore? firestore;

  const ServicoResumoCard({
    required this.titulo,
    required this.descricao,
    required this.servicoId,
    required this.prestadorNome,
    required this.cidade,
    this.unidadeAbrev,
    this.firestore,
  });

  // 🔹 Busca imagem + valores direto do serviço e categoria
  Future<Map<String, dynamic>> getServicoInfo() async {
    if (servicoId.isEmpty) return {};

    try {
      final servicoDoc = await (firestore ?? FirebaseFirestore.instance)
          .collection('servicos')
          .doc(servicoId)
          .get();

      if (!servicoDoc.exists) return {};

      final servicoData = servicoDoc.data() ?? {};
      final categoriaId = (servicoData['categoriaId'] ?? '').toString();

      String imagemUrl = '';
      if (categoriaId.isNotEmpty) {
        final catDoc = await (firestore ?? FirebaseFirestore.instance)
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
      future: getServicoInfo(),
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

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text);

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

class ReadonlyField extends StatelessWidget {
  final TextEditingController controller;
  final bool multiline;
  final bool centered;
  final IconData? trailingIcon;

  const ReadonlyField({
    required this.controller,
    this.centered = false,
    this.trailingIcon,
  }) : multiline = false;

  const ReadonlyField.multiline({required this.controller})
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

class LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const LabelValue({required this.label, required this.value});

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

class ImagesGrid extends StatelessWidget {
  final List<String> urls;

  const ImagesGrid({super.key, required this.urls});

  // ✅ Novo método para compatibilidade com testes
  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('mock:')) {
      // Usa imagem local (placeholder) durante os testes
      return const AssetImage('assets/placeholder.png');
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const Center(
        child: Text(
          'Sem imagens disponíveis',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: urls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, i) {
        final image = _getImageProvider(urls[i]);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image(
            image: image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        );
      },
    );
  }
}