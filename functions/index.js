/* eslint-disable no-console */
'use strict';

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { CloudTasksClient } = require('@google-cloud/tasks');

admin.initializeApp();
const db = admin.firestore();
const fcm = admin.messaging();
const tasksClient = new CloudTasksClient();

// ======= CONFIG =======
const REGION = 'southamerica-east1';
const QUEUE = 'lembretes-queue';
const CHANNEL_ID_ANDROID = 'default_channel_id'; // bate com o canal criado no app

// ======= ENVIO + INBOX =======
/**
 * Envia push e grava inbox em /notificacoes/{uid}/itens
 * Campos batem com a tela: titulo, mensagem, lido, criadoEm (+ tipo, entidadeId)
 */
async function sendToUser(userId, opts) {
  const { title, body, data = {}, tipo, entidadeId = null, agendadoPara = null } = opts;

  // 1) grava inbox (subcoleção "itens" do uid)
  await db
    .collection('notificacoes')
    .doc(userId)
    .collection('itens')
    .add({
      destinatarioId: userId,
      titulo: title,
      mensagem: body,               // 👈 nome que a tela usa
      tipo,                         // ex.: nova_solicitacao, cliente_aceitou…
      entidadeId,
      agendadoPara,                 // Timestamp (opcional, usado nos lembretes)
      lido: false,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(), // 👈 nome que a tela usa
    });

  // 2) envia FCM para todos os tokens do usuário
  const userSnap = await db.collection('usuarios').doc(userId).get();
  if (!userSnap.exists) return;

  const tokens = (userSnap.get('pushTokens') || []).filter(Boolean);
  if (!tokens.length) return;

  try {
    const resp = await fcm.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { channelId: CHANNEL_ID_ANDROID },
      },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });

    // remove tokens inválidos
    const toRemove = [];
    resp.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error && r.error.code ? r.error.code : '';
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          toRemove.push(tokens[i]);
        }
      }
    });
    if (toRemove.length) {
      await db
        .collection('usuarios')
        .doc(userId)
        .set(
          {
            pushTokens: admin.firestore.FieldValue.arrayRemove(...toRemove), // 👈 spread
          },
          { merge: true }
        );
    }
  } catch (e) {
    console.error('Erro FCM:', e);
  }
}

// ============ 1) Nova solicitação -> notifica Prestador ============
exports.onSolicitacaoCriada = onDocumentCreated(
  { document: 'solicitacoesOrcamento/{solId}', region: REGION },
  async (event) => {
    const s = event.data.data();
    if (!s) return;

    const destino = s.prestadorId || s.profissionalId;
    if (!destino) return;

    const servico =
      s.servicoNome || s.servicoTitulo || (s.servico && s.servico.titulo) || 'um serviço';

    await sendToUser(destino, {
      title: 'Novo orçamento recebido',
      body: `Você recebeu uma solicitação para: ${servico}`,
      data: {
        tipo: 'nova_solicitacao',
        entidadeId: event.params.solId,
        deepLink: `app://solicitacoes/${event.params.solId}`,
      },
      tipo: 'nova_solicitacao',        // 👈 mapeia ícone/texto na sua tela
      entidadeId: event.params.solId,
    });
  }
);

// ============ 2) Mudança de status na própria solicitação ============
exports.onSolicStatusMudou = onDocumentUpdated(
  { document: 'solicitacoesOrcamento/{solId}', region: REGION },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    if ((before.status || '') === (after.status || '')) return;

    const destino = after.prestadorId || after.profissionalId;
    if (!destino) return;

    const servico =
      after.servicoNome ||
      after.servicoTitulo ||
      (after.servico && after.servico.titulo) ||
      null;

    if (after.status === 'aceita') {
      await sendToUser(destino, {
        title: 'Cliente aceitou a proposta',
        body: servico ? `Proposta aceita para ${servico}.` : 'Proposta aceita.',
        data: {
          tipo: 'cliente_aceitou',
          entidadeId: event.params.solId,
          deepLink: `app://solicitacoes/${event.params.solId}`,
        },
        tipo: 'cliente_aceitou',
        entidadeId: event.params.solId,
      });
    } else if (after.status === 'recusada' || after.status === 'recusada_cliente') {
      await sendToUser(destino, {
        title: 'Cliente recusou a proposta',
        body: servico ? `Proposta recusada para ${servico}.` : 'Proposta recusada.',
        data: {
          tipo: 'cliente_recusou',
          entidadeId: event.params.solId,
          deepLink: `app://solicitacoes/${event.params.solId}`,
        },
        tipo: 'cliente_recusou',
        entidadeId: event.params.solId,
      });
    }
  }
);

// ============ 3) Agendamento criado -> agenda lembretes ============
exports.onAgendamentoCriado = onDocumentCreated(
  { document: 'agendamentos/{agId}', region: REGION },
  async (event) => {
    const a = event.data.data();
    if (!a || !a.dataInicio) return;
    await scheduleReminderTask(a, event.params.agId, 'vespera');
    await scheduleReminderTask(a, event.params.agId, 'dia');
  }
);

// ============ Alvo HTTP das tarefas ============
exports.reminderHttp = onRequest({ region: REGION }, async (req, res) => {
  try {
    const { agId, tipo } = req.body || {};
    if (!agId || !tipo) return res.status(400).send('agId/tipo faltando');

    const agSnap = await db.collection('agendamentos').doc(agId).get();
    if (!agSnap.exists) return res.status(404).send('Agendamento não encontrado');

    const a = agSnap.data();
    const when = a.dataInicio.toDate();
    const title = tipo === 'vespera' ? 'Lembrete: serviço amanhã' : 'Lembrete: serviço hoje';
    const body =
      'Serviço: ' +
      (a.servicoNome || a.servicoTitulo || '') +
      ' - Início: ' +
      when.toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

    const payload = {
      title,
      body,
      data: {
        tipo: tipo === 'vespera' ? 'servico_agendado_proximo' : 'servico_hoje',
        entidadeId: agId,
        deepLink: `app://agendamentos/${agId}`,
      },
      tipo: tipo === 'vespera' ? 'servico_agendado_proximo' : 'servico_hoje',
      entidadeId: agId,
      agendadoPara: a.dataInicio, // salva pro app exibir horário
    };

    // Prestador
    if (a.prestadorId) await sendToUser(a.prestadorId, payload);
    // Cliente (opcional)
    if (a.clienteId) await sendToUser(a.clienteId, payload);

    return res.status(200).send('ok');
  } catch (e) {
    console.error(e);
    return res.status(500).send('erro');
  }
});

/**
 * Agenda uma tarefa no Cloud Tasks para lembretes
 */
async function scheduleReminderTask(ag, agId, tipo) {
  const start = ag.dataInicio.toDate();
  const fireAt = new Date(start);
  if (tipo === 'vespera') {
    fireAt.setDate(fireAt.getDate() - 1);
    fireAt.setHours(9, 0, 0, 0);
  } else {
    fireAt.setHours(8, 0, 0, 0);
  }

  const project = process.env.GCLOUD_PROJECT;
  const parent = tasksClient.queuePath(project, REGION, QUEUE);
  const url = `https://${REGION}-${project}.cloudfunctions.net/reminderHttp`;

  const task = {
    httpRequest: {
      httpMethod: 'POST',
      url,
      headers: { 'Content-Type': 'application/json' },
      body: Buffer.from(JSON.stringify({ agId, tipo })).toString('base64'),
    },
    scheduleTime: { seconds: Math.floor(fireAt.getTime() / 1000) },
  };

  await tasksClient.createTask({ parent, task });
}
