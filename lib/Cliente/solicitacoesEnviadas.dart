// lib/Cliente/solicitacoesEnviadas.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/Cliente/visualizarSolicitacao.dart';
import 'rotasNavegacao.dart';

class SolicitacoesEnviadasScreen extends StatelessWidget {
  const SolicitacoesEnviadasScreen({super.key});

  static const _colSolic = 'solicitacoesOrcamento';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection(_colSolic)
        .where('clienteId', isEqualTo: uid)
        .orderBy('criadoEm', descending: true) // criar índice se pedir
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Solicitações'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: Column(
        children: [
          Tabs(
            active: TabKind.enviadas,
            onTapEnviadas: () {},
            onTapRespondidas: () => context.goRespondidas(),
            onTapAceitas: () => context.goAceitas(),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final now = DateTime.now();
                final docs = snap.data!.docs.where((doc) {
                  final d = doc.data();
                  final status = (d['status'] ?? 'pendente')
                      .toString()
                      .toLowerCase();

                  // 🔹 Se for ACEITA -> não mostra mais
                  if (status == 'aceita') return false;

                  // 🔹 Se for RECUSADA -> mostra por 1 dia (24h)
                  if (status.contains('recusad')) {
                    final criadoEm = (d['criadoEm'] as Timestamp?)?.toDate();
                    if (criadoEm != null) {
                      final diff = now.difference(criadoEm).inHours;
                      return diff < 24;
                    }
                    return false;
                  }

                  // 🔹 Se for PENDENTE ou outro -> mantém
                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Você ainda não fez nenhuma solicitação.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    return CardEnviada(dados: d, docId: docs[i].id);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 2),
    );
  }
}

/* ========================= Abas ========================= */

enum TabKind { enviadas, respondidas, aceitas }

class Tabs extends StatelessWidget {
  final TabKind active;
  final VoidCallback onTapEnviadas;
  final VoidCallback onTapRespondidas;
  final VoidCallback onTapAceitas;

  const Tabs({
    required this.active,
    required this.onTapEnviadas,
    required this.onTapRespondidas,
    required this.onTapAceitas,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(String text, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: selected ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.deepPurple : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  width: 56,
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Enviadas', active == TabKind.enviadas, onTapEnviadas),
        tab('Respondidas', active == TabKind.respondidas, onTapRespondidas),
        tab('Aceitas', active == TabKind.aceitas, onTapAceitas),
      ],
    );
  }
}

/* ========================= Repo simples de Categoria (cache) ========================= */

class CategoriaRepo {
  static final Map<String, String> _cache = {};
  static FirebaseFirestore firestore = FirebaseFirestore.instance; // 🔹 injetável

  static Future<String> nome(String id) async {
    if (id.isEmpty) return '';
    if (_cache.containsKey(id)) return _cache[id]!;

    final snap = await firestore
        .collection('categoriasProfissionais')
        .doc(id)
        .get();

    final n = (snap.data()?['nome'] ?? '').toString();
    _cache[id] = n;
    return n;
  }

  static void limparCache() => _cache.clear();
}

/* ========================= Card (dados do CLIENTE) ========================= */

class CardEnviada extends StatelessWidget {
  final Map<String, dynamic> dados;
  final String docId;
  final FirebaseFirestore? firestore; 
  const CardEnviada({required this.dados, required this.docId, this.firestore,});

  String _fmtDataHora(DateTime? dt) {
    if (dt == null) return '—';
    final df = DateFormat('dd/MM/yyyy \'às\' HH:mm');
    return df.format(dt);
  }

  Future<String> _buscarAbrevUnidade(String unidadeId) async {
    if (unidadeId.isEmpty) return '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('unidades')
          .doc(unidadeId)
          .get();
      final data = doc.data();
      if (data == null) return '';
      return (data['abreviacao'] ?? data['sigla'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = firestore ?? FirebaseFirestore.instance;

    final prestadorId = (dados['prestadorId'] ?? '').toString();
    final servico = (dados['servicoTitulo'] ?? '').toString();
    final descricao = (dados['descricaoDetalhada'] ?? '').toString();
    final quantidade = (dados['quantidade'] is num)
        ? (dados['quantidade'] as num).toString().replaceAll('.0', '')
        : (dados['quantidade'] ?? '').toString();

    final unidadeId =
        (dados['unidadeSelecionadaId'] ?? '').toString().isNotEmpty
        ? dados['unidadeSelecionadaId'].toString()
        : (dados['servicoUnidadeId'] ?? '').toString();

    final criadoEm = (dados['criadoEm'] as Timestamp?)?.toDate();

    // ===== STATUS =====
    final status = (dados['status'] ?? 'pendente').toString().toLowerCase();
    String statusTexto = 'Pendente';
    Color statusCor = Colors.grey;

    switch (status) {
      case 'respondida':
        statusTexto = 'Respondida';
        statusCor = const Color(0xFF7E57C2);
        break;
      case 'aceita':
        statusTexto = 'Aceita';
        statusCor = const Color(0xFF4CAF50);
        break;
      case 'recusada':
      case 'recusadacliente':
        statusTexto = 'Recusada';
        statusCor = const Color(0xFFE53935);
        break;
      default:
        statusTexto = 'Pendente';
        statusCor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====== Cabeçalho: Imagem, nome do prestador, categoria e cidade ======
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? dados['prestadorNome'] ?? 'Prestador')
                  .toString();
              final fotoUrl = (u['fotoUrl'] ?? '').toString();

              final end = (u['endereco'] is Map)
                  ? (u['endereco'] as Map).cast<String, dynamic>()
                  : <String, dynamic>{};
              String cidade = (end['cidade'] ?? u['cidade'] ?? '').toString();
              String uf = (end['uf'] ?? u['uf'] ?? '').toString();
              String local = cidade.trim();
              if (uf.isNotEmpty &&
                  !RegExp('\\b$uf\\b', caseSensitive: false).hasMatch(local)) {
                local = local.isEmpty ? uf : '$local, $uf';
              }

              final catId =
                  (u['categoriaProfissionalId'] ??
                          dados['categoriaProfissionalId'] ??
                          '')
                      .toString();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade300,
                      child: (fotoUrl.isNotEmpty)
                          ? Image.network(fotoUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.person,
                              size: 28,
                              color: Colors.white70,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nome, categoria e cidade
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusCor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusCor.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                statusTexto,
                                style: TextStyle(
                                  color: statusCor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<String>(
                          future: CategoriaRepo.nome(catId),
                          builder: (context, s2) {
                            final profissao = (s2.data?.isNotEmpty == true)
                                ? s2.data!
                                : '';
                            return Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    profissao,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    local.isEmpty ? '—' : local,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // ====== Nome do serviço ======
          if (servico.isNotEmpty)
            Text(
              servico,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple,
                fontSize: 15,
              ),
            ),

          const SizedBox(height: 3),

          // ====== Descrição, Quantidade, Data ======
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              children: [
                const TextSpan(
                  text: 'Descrição: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ), // só isso em negrito
                ),
                TextSpan(
                  text: descricao, // texto normal
                ),
              ],
            ),
          ),

          const SizedBox(height: 3),

          FutureBuilder<String>(
            future: _buscarAbrevUnidade(unidadeId),
            builder: (context, snap) {
              final abrev = (snap.hasData && snap.data!.isNotEmpty)
                  ? snap.data!
                  : '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black87,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Quantidade: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ), // 💪 só o rótulo em negrito
                        ),
                        TextSpan(
                          text:
                              '$quantidade${abrev.isNotEmpty ? ' $abrev' : ''}', // valor normal
                        ),
                      ],
                    ),
                  ),

                  if (criadoEm != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Enviada em: ${_fmtDataHora(criadoEm)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // ====== Botão Ver Solicitação ======
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisualizarSolicitacaoScreen(docId: docId),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Ver solicitação',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ========================= Visualização somente leitura ========================= */

class VisualizarSolicitacaoEnviadaPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> dados;
  const VisualizarSolicitacaoEnviadaPage({
    super.key,
    required this.docId,
    required this.dados,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    final prestadorId = (dados['prestadorId'] ?? '').toString();
    final servico = (dados['servicoTitulo'] ?? '').toString();
    final descricaoSolic = (dados['descricaoDetalhada'] ?? '').toString();
    final quantidade = (dados['quantidade'] is num)
        ? (dados['quantidade'] as num).toString().replaceAll('.0', '')
        : (dados['quantidade'] ?? '').toString();
    final unidadeAbrev =
        (dados['unidadeSelecionadaAbrev'] ?? dados['servicoUnidadeAbrev'] ?? '')
            .toString();

    // ====== STATUS ======
    final status = (dados['status'] ?? 'pendente').toString().toLowerCase();
    Color statusCor;
    String statusTexto;
    switch (status) {
      case 'respondida':
        statusTexto = 'Respondida';
        statusCor = const Color(0xFF7E57C2);
        break;
      case 'aceita':
        statusTexto = 'Aceita';
        statusCor = const Color(0xFF4CAF50);
        break;
      case 'recusada':
      case 'recusadacliente':
        statusTexto = 'Recusada';
        statusCor = const Color(0xFFE53935);
        break;
      default:
        statusTexto = 'Pendente';
        statusCor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---------- Cabeçalho: Foto e nome do prestador + STATUS ----------
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? dados['prestadorNome'] ?? 'Prestador')
                  .toString();
              final fotoUrl = (u['fotoUrl'] ?? '').toString();

              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade300,
                      child: (fotoUrl.isNotEmpty)
                          ? Image.network(fotoUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.person,
                              size: 28,
                              color: Colors.white70,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.0,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusCor.withOpacity(0.15),
                      border: Border.all(color: statusCor.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusTexto,
                      style: TextStyle(
                        color: statusCor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // ---------- Corpo: informações da solicitação ----------
          Text(
            servico.isEmpty ? 'Serviço sem título' : servico,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.deepPurple,
            ),
          ),
          if (descricaoSolic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              descricaoSolic,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Quantidade: $quantidade${unidadeAbrev.isNotEmpty ? ' $unidadeAbrev' : ''}',
            style: const TextStyle(fontSize: 13.5, color: Colors.black54),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEDE7F6),
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisualizarSolicitacaoScreen(docId: docId),
                  ),
                );
              },
              child: const Text('Ver solicitação'),
            ),
          ),
        ],
      ),
    );
  }
}
