// lib/Prestador/notificacoes.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ===== ESTRUTURA ESPERADA NO FIRESTORE (coleção 'notificacoes') =====
/// Doc exemplo:
/// {
///   "destinatarioId": "<uid-prestador>",
///   "destinatarioTipo": "prestador",              // opcional (útil p/ filtros futuros)
///   "tipo": "nova_solicitacao",                   // ver _TipoNotificacao
///   "titulo": "Novo orçamento recebido",
///   "mensagem": "João solicitou orçamento para Pintura.",
///   "solicitacaoId": "<idSolic>",
///   "servicoTitulo": "Pintura residencial",       // opcional
///   "agendadoPara": Timestamp(...)                // usado nos lembretes "próximo"/"hoje"
///   "lido": false,
///   "criadoEm": Timestamp.now(),
/// }
///
/// Crie essas notificações quando:
/// - cliente cria solicitação (nova_solicitacao)
/// - cliente aceita (cliente_aceitou)                                                                                                                                                            
/// - cliente recusa (cliente_recusou)
/// - serviço agendado está próximo (servico_agendado_proximo)
/// - dia do serviço (servico_hoje)
///
/// Observação: você pode disparar isso por Cloud Functions (recomendado),
/// ou do app (ex.: após atualizar status).
///                                                                       
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final _auth = FirebaseAuth.instance;
  String? get _uid => _auth.currentUser?.uid;

  Query<Map<String, dynamic>> _query(String uid) {
    return FirebaseFirestore.instance
        .collection('notificacoes')
        .where('destinatarioId', isEqualTo: uid)
        .orderBy('criadoEm', descending: true)
        .limit(100);
  }

  Future<void> _marcarTudoComoLido(List<DocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      if (data['lido'] == true) continue;
      batch.update(d.reference, {'lido': true});
    }
    await batch.commit();
  }

  Future<void> _alternarLido(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final atual = data['lido'] == true;
    await doc.reference.update({'lido': !atual});
  }

  Future<void> _apagar(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        automaticallyImplyLeading: false, // sem seta de voltar (padrão Prestador)
        actions: [
          IconButton(
            tooltip: 'Marcar tudo como lido',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              if (uid == null) return;
              final snap = await _query(uid).get();
              await _marcarTudoComoLido(snap.docs);
            },
          ),
        ],
      ),
      body: (uid == null)
          ? const Center(child: Text('Usuário não autenticado.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query(uid).snapshots(),
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
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Você ainda não tem notificações.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();

                    final tipo = (data['tipo'] ?? '').toString();
                    final titulo = (data['titulo'] ?? '').toString();
                    final msg = (data['mensagem'] ?? '').toString();
                    final lido = data['lido'] == true;
                    final criadoEm = data['criadoEm'];
                    final agendadoPara = data['agendadoPara'];

                    final dtCriado = (criadoEm is Timestamp)
                        ? criadoAmigavel(criadoEm.toDate())
                        : '';
                    final dtAgendado = (agendadoPara is Timestamp)
                        ? ' • ${DateFormat('dd/MM, HH:mm').format(agendadoPara.toDate())}'
                        : '';

                    final deco = lido ? null : BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    );

                    return Dismissible(
                      key: ValueKey(d.id),
                      background: _swipeBg(
                        Icons.mark_email_read,
                        'Marcar como lida',
                        Colors.green,
                      ),
                      secondaryBackground: _swipeBg(
                        Icons.delete_outline,
                        'Apagar',
                        Colors.red,
                        alignEnd: true,
                      ),
                      confirmDismiss: (dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          await _alternarLido(d);
                          return false; // não remove da lista
                        } else {
                          await _apagar(d);
                          return true; // remove
                        }
                      },
                      child: Container(
                        decoration: deco,
                        child: ListTile(
                          leading: _iconePorTipo(tipo),
                          title: Text(
                            titulo.isNotEmpty ? titulo : _tituloPorTipo(tipo),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${msg.isNotEmpty ? msg : _mensagemPorTipo(tipo)}$dtAgendado',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dtCriado,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (!lido)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _alternarLido(d),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _swipeBg(IconData icon, String text, Color color,
      {bool alignEnd = false}) {
    final child = Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white)),
        const SizedBox(width: 16),
      ],
    );
    return Container(color: color, child: child);
  }

  String criadoAmigavel(DateTime dt) {
    final agora = DateTime.now();
    final diff = agora.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return DateFormat('dd/MM').format(dt);
  }

  Icon _iconePorTipo(String tipo) {
    switch (tipo) {
      case _TipoNotificacao.novaSolicitacao:
        return const Icon(Icons.markunread_mailbox, color: Colors.deepPurple);
      case _TipoNotificacao.clienteAceitou:
        return const Icon(Icons.task_alt, color: Colors.green);
      case _TipoNotificacao.clienteRecusou:
        return const Icon(Icons.highlight_off, color: Colors.red);
      case _TipoNotificacao.servicoProximo:
        return const Icon(Icons.event_available, color: Colors.orange);
      case _TipoNotificacao.servicoHoje:
        return const Icon(Icons.today, color: Colors.blue);
      default:
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  String _tituloPorTipo(String tipo) {
    switch (tipo) {
      case _TipoNotificacao.novaSolicitacao:
        return 'Novo orçamento recebido';
      case _TipoNotificacao.clienteAceitou:
        return 'Cliente aceitou a proposta';
      case _TipoNotificacao.clienteRecusou:
        return 'Cliente recusou a proposta';
      case _TipoNotificacao.servicoProximo:
        return 'Serviço agendado está próximo';
      case _TipoNotificacao.servicoHoje:
        return 'Você tem serviço hoje';
      default:
        return 'Notificação';
    }
  }

  String _mensagemPorTipo(String tipo) {
    switch (tipo) {
      case _TipoNotificacao.novaSolicitacao:
        return 'Você recebeu uma nova solicitação de orçamento.';
      case _TipoNotificacao.clienteAceitou:
        return 'O cliente aceitou sua proposta.';
      case _TipoNotificacao.clienteRecusou:
        return 'O cliente recusou sua proposta.';
      case _TipoNotificacao.servicoProximo:
        return 'Fique atento: o serviço está chegando.';
      case _TipoNotificacao.servicoHoje:
        return 'Hoje você tem um serviço agendado.';
      default:
        return '';
    }
  }
}

class _TipoNotificacao {
  static const novaSolicitacao = 'nova_solicitacao';
  static const clienteAceitou = 'cliente_aceitou';
  static const clienteRecusou = 'cliente_recusou';
  static const servicoProximo = 'servico_agendado_proximo';
  static const servicoHoje = 'servico_hoje';
}

/// =================== HELPERS OPCIONAIS PARA DISPARAR NOTIFICAÇÕES ===================
/// Você pode chamar estes helpers quando mudar o status da solicitação
/// ou quando criar/atualizar um agendamento.
/// Em produção, prefira Cloud Functions (onCreate/onUpdate) para garantir que
/// a notificação é criada mesmo se o app do prestador não estiver aberto.

Future<void> criarNotifNovaSolicitacao({
  required String prestadorId,
  required String solicitacaoId,
  String? servicoTitulo,
  String? clienteNome,
}) async {
  await FirebaseFirestore.instance.collection('notificacoes').add({
    'destinatarioId': prestadorId,
    'destinatarioTipo': 'prestador',
    'tipo': _TipoNotificacao.novaSolicitacao,
    'titulo': 'Novo orçamento recebido',
    'mensagem': clienteNome == null
        ? 'Você recebeu uma nova solicitação.'
        : '$clienteNome solicitou orçamento${servicoTitulo != null ? ' para $servicoTitulo' : ''}.',
    'solicitacaoId': solicitacaoId,
    'servicoTitulo': servicoTitulo,
    'lido': false,
    'criadoEm': FieldValue.serverTimestamp(),
  });
}

Future<void> criarNotifStatus({
  required String prestadorId,
  required String solicitacaoId,
  required bool aceito, // true = aceitou, false = recusou
  String? servicoTitulo,
}) async {
  final tipo = aceito
      ? _TipoNotificacao.clienteAceitou
      : _TipoNotificacao.clienteRecusou;
  final titulo = aceito
      ? 'Cliente aceitou a proposta'
      : 'Cliente recusou a proposta';
  final msg = aceito
      ? 'Parabéns! Proposta aceita${servicoTitulo != null ? ' para $servicoTitulo' : ''}.'
      : 'Proposta recusada${servicoTitulo != null ? ' para $servicoTitulo' : ''}.';

  await FirebaseFirestore.instance.collection('notificacoes').add({
    'destinatarioId': prestadorId,
    'destinatarioTipo': 'prestador',
    'tipo': tipo,
    'titulo': titulo,
    'mensagem': msg,
    'solicitacaoId': solicitacaoId,
    'servicoTitulo': servicoTitulo,
    'lido': false,
    'criadoEm': FieldValue.serverTimestamp(),
  });
}

Future<void> criarNotifAgendamento({
  required String prestadorId,
  required String solicitacaoId,
  required DateTime dataHora, // data do serviço
  bool proximo = false, // true => "próximo", false => "hoje"
  String? servicoTitulo,
}) async {
  await FirebaseFirestore.instance.collection('notificacoes').add({
    'destinatarioId': prestadorId,
    'destinatarioTipo': 'prestador',
    'tipo': proximo
        ? _TipoNotificacao.servicoProximo
        : _TipoNotificacao.servicoHoje,
    'titulo': proximo
        ? 'Serviço agendado está próximo'
        : 'Você tem serviço hoje',
    'mensagem': servicoTitulo == null
        ? (proximo ? 'O serviço está chegando.' : 'Não se esqueça do serviço.')
        : (proximo
            ? 'O serviço "$servicoTitulo" está chegando.'
            : 'Hoje tem "$servicoTitulo".'),
    'solicitacaoId': solicitacaoId,
    'servicoTitulo': servicoTitulo,
    'agendadoPara': Timestamp.fromDate(dataHora),
    'lido': false,
    'criadoEm': FieldValue.serverTimestamp(),
  });
}
