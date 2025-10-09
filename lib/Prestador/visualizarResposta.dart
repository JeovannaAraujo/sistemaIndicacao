// lib/Prestador/visualizarResposta.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VisualizarRespostaPrestadorScreen extends StatefulWidget {
  final String docId;
  const VisualizarRespostaPrestadorScreen({super.key, required this.docId});

  @override
  State<VisualizarRespostaPrestadorScreen> createState() =>
      _VisualizarRespostaPrestadorScreenState();
}

class _VisualizarRespostaPrestadorScreenState
    extends State<VisualizarRespostaPrestadorScreen> {
  static const colSolicitacoes = 'solicitacoesOrcamento';
  final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Resposta Enviada'),
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

          final servicoTitulo = (d['servicoTitulo'] ?? '').toString();
          final descricao = (d['descricaoDetalhada'] ?? '').toString();
          final quantidade = (d['quantidade'] ?? '').toString();
          final valorProposto = (d['valorProposto'] as num?)?.toDouble();
          final dataInicio = _fmtData(d['dataInicioSugerida']);
          final dataFim = _fmtData(d['dataFinalPrevista']);
          final clienteNome = (d['clienteNome'] ?? '').toString();
          final clienteEndereco = (d['clienteEndereco']?['cidade'] ?? '').toString();
          final clienteWhats = (d['clienteEndereco']?['whatsapp'] ?? '').toString();
          final tempoValor = (d['tempoEstimadoValor'] ?? '').toString();
          final tempoUnidade = (d['tempoEstimadoUnidade'] ?? '').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Cabeçalho (Cliente) =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solicitação do Cliente',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clienteNome.isEmpty ? 'Cliente não identificado' : clienteNome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clienteEndereco.isEmpty ? '—' : clienteEndereco,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const _SectionTitle('Serviço solicitado'),
                _ReadonlyBox(servicoTitulo.isEmpty ? '—' : servicoTitulo),

                const SizedBox(height: 16),
                const _SectionTitle('Descrição detalhada da solicitação'),
                _ReadonlyBox(descricao.isEmpty ? '—' : descricao, multiline: true),

                const SizedBox(height: 16),
                const _SectionTitle('Quantidade ou dimensão'),
                _ReadonlyBox(quantidade.replaceAll('.0', '')),

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
                _ReadonlyBox(_formatTempo(tempoValor, tempoUnidade)),

                const SizedBox(height: 16),
                const _SectionTitle('Contato do cliente'),
                _ContatoBox(clienteWhats),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmtData(dynamic ts) {
    if (ts is! Timestamp) return '—';
    return DateFormat('dd/MM/yyyy').format(ts.toDate());
  }

  String _formatTempo(dynamic tempo, String unidade) {
    if (tempo == null || tempo.toString().isEmpty) return '—';
    String valor = tempo.toString().replaceAll('.0', '');
    String unidadeFmt = unidade;
    if (unidadeFmt.isNotEmpty && valor != '1') {
      if (!unidadeFmt.endsWith('s')) unidadeFmt += 's';
    }
    return '$valor $unidadeFmt'.trim();
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
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
