// lib/Cliente/solicitacoesEnviadas.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
          _Tabs(
            active: _TabKind.enviadas,
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
                final docs = snap.data!.docs;
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
                    return _CardEnviada(dados: d, docId: docs[i].id);
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

enum _TabKind { enviadas, respondidas, aceitas }

class _Tabs extends StatelessWidget {
  final _TabKind active;
  final VoidCallback onTapEnviadas;
  final VoidCallback onTapRespondidas;
  final VoidCallback onTapAceitas;

  const _Tabs({
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
        tab('Enviadas', active == _TabKind.enviadas, onTapEnviadas),
        tab('Respondidas', active == _TabKind.respondidas, onTapRespondidas),
        tab('Aceitas', active == _TabKind.aceitas, onTapAceitas),
      ],
    );
  }
}

/* ========================= Repo simples de Categoria (cache) ========================= */

class _CategoriaRepo {
  static final Map<String, String> _cache = {};
  static Future<String> nome(String id) async {
    if (id.isEmpty) return '';
    if (_cache.containsKey(id)) return _cache[id]!;
    final snap = await FirebaseFirestore.instance
        .collection('categoriasProfissionais')
        .doc(id)
        .get();
    final n = (snap.data()?['nome'] ?? '').toString();
    _cache[id] = n;
    return n;
  }
}

/* ========================= Card (dados do CLIENTE) ========================= */

class _CardEnviada extends StatelessWidget {
  final Map<String, dynamic> dados;
  final String docId;
  const _CardEnviada({required this.dados, required this.docId});

  String _fmtMoeda(num? v) =>
      v == null ? '—' : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
  String _fmtTs(Timestamp? ts) =>
      ts == null ? '—' : DateFormat('dd/MM/yyyy').format(ts.toDate());

  (String, Color) _statusView(String s) {
    switch (s.toLowerCase()) {
      case 'respondida':
        return ('Respondida', const Color(0xFF7E57C2));
      case 'aceita':
        return ('Aceita', const Color(0xFF4CAF50));
      case 'recusada':
      case 'recusadacliente':
        return ('Recusada', const Color(0xFFE53935));
      case 'pendente':
      default:
        return ('Pendente', const Color(0xFF757575));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // IDs
    final prestadorId = (dados['prestadorId'] ?? '').toString();

    // Status + campos enviados pelo CLIENTE
    final status = (dados['status'] ?? 'pendente').toString();
    final servico = (dados['servicoTitulo'] ?? '').toString();
    final servicoDesc = (dados['servicoDescricao'] ?? '').toString();

    final estimativaValor =
        (dados['estimativaValor'] is num) ? dados['estimativaValor'] as num : null;

    final quantidade =
        (dados['quantidade'] is num) ? dados['quantidade'] as num : null;
    final unidadeAbrev = (dados['unidadeSelecionadaAbrev'] ??
            dados['servicoUnidadeAbrev'] ??
            '')
        .toString();

    final tsDesejada = dados['dataDesejada'] as Timestamp?;

    final (labelStatus, colorStatus) = _statusView(status);

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
          // ---------- Cabeçalho: foto, nome, categoria • local + chip status ----------
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: fs.collection('usuarios').doc(prestadorId).get(),
            builder: (context, snap) {
              final u = snap.data?.data() ?? const <String, dynamic>{};
              final nome = (u['nome'] ?? dados['prestadorNome'] ?? 'Prestador').toString();
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
                  (u['categoriaProfissionalId'] ?? dados['categoriaProfissionalId'] ?? '').toString();

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
                          : const Icon(Icons.person, size: 28, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<String>(
                          future: _CategoriaRepo.nome(catId),
                          builder: (context, s2) {
                            final profissao =
                                (s2.data?.isNotEmpty == true) ? s2.data! : '';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    profissao,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('•', style: TextStyle(color: Colors.black26)),
                                const SizedBox(width: 6),
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: Colors.black45),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    local.isEmpty ? '—' : local,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorStatus.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorStatus.withOpacity(0.4)),
                    ),
                    child: Text(
                      labelStatus,
                      style: TextStyle(
                        color: colorStatus,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // ---------- Corpo (somente dados do CLIENTE) ----------
          _kv('Serviço:', servico.isEmpty ? '—' : servico, boldValue: true),
          if (servicoDesc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(servicoDesc,
                  style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
            ),
          _kv('Valor Total Proposto:', _fmtMoeda(estimativaValor)),
          _kv(
            'Quantidade:',
            (quantidade == null)
                ? '—'
                : unidadeAbrev.isEmpty
                    ? quantidade.toString().replaceAll('.0', '')
                    : '${quantidade.toString().replaceAll('.0', '')} $unidadeAbrev',
          ),
          _kv('Data desejada:', _fmtTs(tsDesejada)),
          _kv('Data de início:', '—'), // definido na resposta do prestador
          _kv('Data final:', '—'),     // definido na resposta do prestador

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisualizarSolicitacaoEnviadaPage(
                      docId: docId,
                      dados: dados,
                    ),
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

  Widget _kv(String k, String v, {bool boldValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13.5),
          children: [
            TextSpan(text: '$k ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(
              text: v,
              style: TextStyle(fontWeight: boldValue ? FontWeight.w700 : FontWeight.w400),
            ),
          ],
        ),
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

  String _fmtTs(Timestamp? ts) =>
      ts == null ? '—' : DateFormat('dd/MM/yyyy').format(ts.toDate());
  String _fmtMoeda(num? v) =>
      v == null ? '—' : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

  @override
  Widget build(BuildContext context) {
    final endereco =
        (dados['clienteEndereco'] is Map) ? (dados['clienteEndereco'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    final linhaEnd = [
      endereco['rua'],
      (endereco['numero']?.toString().isNotEmpty == true) ? 'nº ${endereco['numero']}' : null,
      endereco['bairro'],
      endereco['cidade'],
      endereco['estado'] ?? endereco['uf'],
    ].where((e) => (e?.toString().isNotEmpty ?? false)).join(', ');

    final imagens = (dados['imagens'] is List) ? List<String>.from(dados['imagens']) : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitação enviada'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      backgroundColor: const Color(0xFFF9F6FF),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Serviço', (dados['servicoTitulo'] ?? '—').toString(), big: true),
            const SizedBox(height: 8),
            _kv('Descrição detalhada', (dados['descricaoDetalhada'] ?? '—').toString()),
            const SizedBox(height: 8),
            _kv('Quantidade', (() {
              final q = dados['quantidade'];
              final abrev = (dados['unidadeSelecionadaAbrev'] ?? dados['servicoUnidadeAbrev'] ?? '').toString();
              if (q is num) {
                final qq = q.toString().replaceAll('.0', '');
                return abrev.isEmpty ? qq : '$qq $abrev';
              }
              return '—';
            })()),
            const SizedBox(height: 8),
            _kv('Valor total proposto', _fmtMoeda(dados['estimativaValor'] as num?)),
            _kv('Data desejada', _fmtTs(dados['dataDesejada'] as Timestamp?)),
            const SizedBox(height: 8),
            _kv('Endereço do serviço', linhaEnd.isEmpty ? '—' : linhaEnd),
            if ((endereco['cep'] ?? '').toString().isNotEmpty)
              _kv('CEP', (endereco['cep'] ?? '').toString()),
            if ((dados['clienteWhatsapp'] ?? '').toString().isNotEmpty)
              _kv('Whatsapp', (dados['clienteWhatsapp'] ?? '').toString()),
            const SizedBox(height: 16),
            if (imagens.isNotEmpty) ...[
              const Text('Imagens anexadas', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: imagens.map((url) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool big = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.black87,
          fontSize: big ? 16 : 13.5,
          height: 1.25,
        ),
        children: [
          TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: v),
        ],
      ),
    );
  }
}
