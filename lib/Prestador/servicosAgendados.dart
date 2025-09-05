import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ServicosAgendadosScreen extends StatefulWidget {
  /// Quando `embedded` for true, renderiza apenas o conteúdo (sem Scaffold/AppBar),
  /// ideal para uso dentro da aba da Agenda.
  final bool embedded;
  const ServicosAgendadosScreen({super.key, this.embedded = false});

  @override
  State<ServicosAgendadosScreen> createState() =>
      _ServicosAgendadosScreenState();
}

class _ServicosAgendadosScreenState extends State<ServicosAgendadosScreen> {
  static const _colSolicitacoes = 'solicitacoesOrcamento';

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String _fmtData(DateTime d) => DateFormat('dd/MM/yyyy', 'pt_BR').format(d);
  DateTime _toDate(dynamic ts) {
    final d = (ts as Timestamp).toDate();
    return DateTime(d.year, d.month, d.day);
  }

  String _fmtEndereco(Map<String, dynamic>? e) {
    if (e == null) return '—';
    String rua = (e['rua'] ?? e['logradouro'] ?? '').toString();
    String numero = (e['numero'] ?? '').toString();
    String bairro = (e['bairro'] ?? '').toString();
    String compl = (e['complemento'] ?? '').toString();
    String cidade = (e['cidade'] ?? '').toString();
    String estado = (e['estado'] ?? e['uf'] ?? '').toString();
    String cep = (e['cep'] ?? '').toString();

    final partes = <String>[];
    if (rua.isNotEmpty && numero.isNotEmpty) {
      partes.add('$rua, nº $numero');
    } else if (rua.isNotEmpty) {
      partes.add(rua);
    }
    if (bairro.isNotEmpty) partes.add(bairro);
    if (compl.isNotEmpty) partes.add(compl);
    if (cidade.isNotEmpty && estado.isNotEmpty) {
      partes.add('$cidade - $estado');
    } else if (cidade.isNotEmpty) {
      partes.add(cidade);
    }
    final end = partes.join(', ');
    return cep.isNotEmpty ? '$end, CEP $cep' : (end.isEmpty ? '—' : end);
  }

  String _pickWhatsApp(Map<String, dynamic> d) {
    for (final k in [
      'clienteWhatsapp',
      'clienteWhatsApp',
      'whatsapp',
      'clienteTelefone',
      'telefone',
    ]) {
      final v = d[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '—';
  }

  String _onlyDigits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _openWhatsApp(String rawPhone) async {
    if (rawPhone == '—' || rawPhone.trim().isEmpty) return;
    final digits = _onlyDigits(rawPhone);
    final uri = Uri.parse('https://wa.me/55$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps(String endereco) async {
    if (endereco.trim().isEmpty || endereco == '—') return;
    final encoded = Uri.encodeComponent(endereco);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ================== Auto-start helpers ==================

  DateTime _nowFloorToMinute() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
    // (evita diferenças de milissegundos)
  }

  DateTime? _toFullDateTime(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  /// Deve auto-iniciar? (agora >= início e ainda não está em andamento/finalizada/cancelada)
  bool _shouldAutoStart(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString().toLowerCase();
    if (status == 'em andamento' ||
        status == 'em_andamento' ||
        status.startsWith('finaliz') ||
        status.startsWith('cancel')) {
      return false;
    }
    final start = _toFullDateTime(d['dataInicioSugerida']);
    if (start == null) return false;
    final now = _nowFloorToMinute();
    return now.isAfter(start) || now.isAtSameMomentAs(start);
  }

  /// Atualiza para "em andamento" na virada do horário (uma única vez)
  Future<void> _autoStartIfNeeded(String docId, Map<String, dynamic> d) async {
    if (!_shouldAutoStart(d)) return;
    if (d['iniciadaEm'] != null) return; // já marcou início antes
    await FirebaseFirestore.instance
        .collection(_colSolicitacoes)
        .doc(docId)
        .update({
          'status': 'em andamento',
          'iniciadaEm': FieldValue.serverTimestamp(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        });
  }

  // ================== UI helpers ==================

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    String label;

    if (s.startsWith('finaliz')) {
      bg = const Color(0xFFEDE7F6);
      fg = const Color(0xFF5E35B1);
      label = 'Finalizado';
    } else if (s == 'em andamento' || s == 'em_andamento') {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
      label = 'Em andamento';
    } else if (s.startsWith('cancel')) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      label = 'Cancelado';
    } else if (s == 'aguardando_inicio') {
      bg = const Color(0xFFFFF8E1);
      fg = const Color(0xFF8D6E63);
      label = 'Aguardando início';
    } else {
      bg = const Color(0xFFF5F5F5);
      fg = const Color(0xFF616161);
      label = 'Não iniciado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            s.startsWith('finaliz')
                ? Icons.check_circle
                : (s == 'em andamento' || s == 'em_andamento')
                ? Icons.autorenew
                : s.startsWith('cancel')
                ? Icons.cancel
                : Icons.schedule,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title efetuado com sucesso!')));
      }
    }
  }

  Future<void> _finalizarServico(String docId) async {
    await FirebaseFirestore.instance
        .collection(_colSolicitacoes)
        .doc(docId)
        .update({
          'status': 'finalizada',
          'dataFinalizacaoReal': FieldValue.serverTimestamp(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        });
  }

  // ========= CANCELAMENTO =========

  Future<String?> _askMotivoCancelamento(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motivo do cancelamento'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex.: cliente indisponível, endereço incorreto...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarServico(String docId, {String? motivo}) async {
    await FirebaseFirestore.instance
        .collection(_colSolicitacoes)
        .doc(docId)
        .update({
          'status': 'cancelada',
          'canceladaEm': FieldValue.serverTimestamp(),
          'motivoCancelamento': (motivo ?? '').trim(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final body = _buildBody(uid); // corpo reutilizável para embedded e tela

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Serviços Agendados'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: body,
    );
  }

  Widget _buildBody(String? uid) {
    if (uid == null) {
      return const Center(child: Text('Usuário não logado.'));
    }

    final stream = FirebaseFirestore.instance
        .collection(_colSolicitacoes)
        .where('prestadorId', isEqualTo: uid)
        .where(
          'status',
          whereIn: [
            'aceita',
            'em andamento',
            'em_andamento',
            'finalizada',
            'cancelada',
            'não iniciado',
            'nao iniciado',
          ],
        )
        .orderBy('dataInicioSugerida', descending: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erro: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Nenhum serviço encontrado.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final id = docs[i].id;

            // Auto-start se já passou da hora
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _autoStartIfNeeded(id, d);
            });

            final rawStatus = (d['status'] ?? '').toString().toLowerCase();

            final inicioTs = d['dataInicioSugerida'];
            final inicioFull = _toFullDateTime(inicioTs);
            final passouDaHora =
                inicioFull != null &&
                (_nowFloorToMinute().isAfter(inicioFull) ||
                    _nowFloorToMinute().isAtSameMomentAs(inicioFull));

            // Status "efetivo" para a UI
            final effectiveStatus =
                (rawStatus == 'aceita' ||
                    rawStatus == 'não iniciado' ||
                    rawStatus == 'nao iniciado')
                ? (passouDaHora ? 'em_andamento' : 'aguardando_inicio')
                : rawStatus;

            final titulo = (d['servicoTitulo'] ?? 'Serviço') as String;
            final cliente = (d['clienteNome'] ?? '—') as String;

            final dataInicio = (inicioTs is Timestamp)
                ? _fmtData(_toDate(inicioTs))
                : '—';

            final unidade = (d['tempoEstimadoUnidade'] ?? '').toString();
            final valor = (d['tempoEstimadoValor'] as num?)?.ceil() ?? 0;
            final estimativa = valor > 0
                ? '$valor ${unidade.isEmpty ? "dia(s)" : unidade}(s)'
                : '—';

            final endereco = _fmtEndereco(
              (d['clienteEndereco'] ?? d['endereco']) as Map<String, dynamic>?,
            );
            final whatsapp = _pickWhatsApp(d);

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título + Chip de status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        _statusChip(effectiveStatus),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text('Cliente: $cliente'),
                    Text('Data de início: $dataInicio'),
                    Row(
                      children: [
                        const Text('Duração estimada: '),
                        if (valor > 0)
                          InkWell(
                            onTap: () {}, // apenas visual
                            child: Text(
                              estimativa,
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const Text('—'),
                      ],
                    ),
                    Text('Endereço: $endereco'),
                    const SizedBox(height: 8),

                    // Ações rápidas (WhatsApp)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: (whatsapp == '—')
                              ? null
                              : () => _openWhatsApp(whatsapp),
                          icon: const Icon(FontAwesomeIcons.whatsapp, size: 16),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Botões (sem "Iniciar")
                    _acoesFluxo(
                      status: effectiveStatus,
                      onFinalizar: () {
                        _confirmAndRun(
                          context: context,
                          title: 'Finalizar serviço',
                          message: 'Confirmar a finalização deste serviço?',
                          action: () => _finalizarServico(id),
                        );
                      },
                      onCancelar: () async {
                        final motivo = await _askMotivoCancelamento(context);
                        await _confirmAndRun(
                          context: context,
                          title: 'Cancelar serviço',
                          message:
                              'Tem certeza que deseja cancelar este serviço?',
                          action: () => _cancelarServico(id, motivo: motivo),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Sem botão de iniciar: apenas "Finalizar" e/ou "Cancelar"
  Widget _acoesFluxo({
    required String status,
    required VoidCallback onFinalizar,
    required VoidCallback onCancelar,
  }) {
    final s = status.toLowerCase();

    // Já em andamento (ou considerado em andamento porque chegou a hora)
    if (s == 'em andamento' || s == 'em_andamento') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinalizar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Finalizar Serviço'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCancelar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      );
    }

    // Antes do horário (aguardando início) → só Cancelar
    if (s == 'aguardando_inicio' ||
        s == 'aceita' ||
        s == 'não iniciado' ||
        s == 'nao iniciado') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onCancelar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancelar'),
        ),
      );
    }

    // Finalizada/Cancelada → sem ações
    return const SizedBox.shrink();
  }
}
