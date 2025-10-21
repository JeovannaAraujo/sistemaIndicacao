import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// importa a aba "Minhas avaliações" separada
import 'avaliacoes.dart';

class ServicosFinalizadosScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const ServicosFinalizadosScreen({super.key, this.firestore, this.auth});

  @override
  State<ServicosFinalizadosScreen> createState() =>
      _ServicosFinalizadosScreenState();
}

class _ServicosFinalizadosScreenState extends State<ServicosFinalizadosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  FirebaseFirestore get firestore =>
      widget.firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => widget.auth ?? FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B2CF6),
        title: const Text('Serviços Finalizados'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Finalizados'),
            Tab(text: 'Minhas avaliações'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          TabFinalizados(firestore: firestore, auth: auth),
          MinhasAvaliacoesTab(firestore: firestore, auth: auth),
        ],
      ),
    );
  }
}

class TabFinalizados extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const TabFinalizados({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final userId = auth.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('Usuário não autenticado'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('servicos')
          .where('clienteId', isEqualTo: userId)
          .where('status', isEqualTo: 'finalizado')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhum serviço finalizado.'));
        }

        final servicos = snapshot.data!.docs;

        return ListView.builder(
          itemCount: servicos.length,
          itemBuilder: (context, index) {
            final servico = servicos[index].data() as Map<String, dynamic>;
            final data = servico['dataFim'] != null
                ? (servico['dataFim'] is Timestamp
                    ? (servico['dataFim'] as Timestamp).toDate()
                    : servico['dataFim'] as DateTime)
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(servico['descricao'] ?? 'Sem descrição'),
                subtitle: data != null
                    ? Text('Concluído em ${DateFormat('dd/MM/yyyy').format(data)}')
                    : const Text('Sem data definida'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B2CF6),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AvaliarServicoScreen(
                          servicoId: servicos[index].id,
                          prestadorId: servico['prestadorId'] ?? '',
                          firestore: firestore,
                          auth: auth,
                        ),
                      ),
                    );
                  },
                  child: const Text('Avaliar'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AvaliarServicoScreen extends StatefulWidget {
  final String servicoId;
  final String prestadorId;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const AvaliarServicoScreen({
    super.key,
    required this.servicoId,
    required this.prestadorId,
    required this.firestore,
    required this.auth,
  });

  @override
  State<AvaliarServicoScreen> createState() => _AvaliarServicoScreenState();
}

class _AvaliarServicoScreenState extends State<AvaliarServicoScreen> {
  double nota = 5;
  bool enviando = false;

 Future<void> enviarAvaliacao() async {
  setState(() => enviando = true);

  final clienteId = widget.auth.currentUser?.uid;

  // 🧱 Evita criar avaliação sem login
  if (clienteId == null || clienteId.isEmpty) {
    setState(() => enviando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuário não autenticado.')),
    );
    return;
  }

  try {
    // ✅ Cria avaliação
    await widget.firestore.collection('avaliacoes').add({
      'servicoId': widget.servicoId,
      'prestadorId': widget.prestadorId,
      'clienteId': clienteId,
      'nota': nota,
      'data': DateTime.now(),
    });

    // ✅ Atualiza status do serviço, se existir
    final servicoRef =
        widget.firestore.collection('servicos').doc(widget.servicoId);

    final servicoSnap = await servicoRef.get();
    if (servicoSnap.exists) {
      await servicoRef.update({'status': 'avaliada'});
    } else {
      debugPrint(
          '⚠️ Serviço ${widget.servicoId} não encontrado — ignorando update.');
    }

    // ✅ Mostra sucesso
    if (mounted) {
      setState(() => enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada com sucesso!')),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    // ⚠️ Captura erro geral (inclusive do fake firestore)
    debugPrint('❌ Erro ao enviar avaliação: $e');
    if (mounted) {
      setState(() => enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar avaliação.')),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliar Serviço'),
        backgroundColor: const Color(0xFF5B2CF6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Avalie o serviço realizado:'),
            Slider(
              value: nota,
              min: 0,
              max: 5,
              divisions: 5,
              label: nota.toString(),
              onChanged: enviando ? null : (v) => setState(() => nota = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: enviando ? null : enviarAvaliacao,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B2CF6),
              ),
              child: enviando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Enviar Avaliação'),
            ),
          ],
        ),
      ),
    );
  }
}