import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServicosFinalizadosPrestadorScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const ServicosFinalizadosPrestadorScreen({
    super.key,
    this.firestore,
    this.auth,
  });

  @override
  State<ServicosFinalizadosPrestadorScreen> createState() =>
      ServicosFinalizadosPrestadorScreenState();
}

class ServicosFinalizadosPrestadorScreenState
    extends State<ServicosFinalizadosPrestadorScreen> {
  late FirebaseFirestore db;
  late FirebaseAuth auth;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _buscaCtl = TextEditingController();
  String _filtroCliente = '';

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;
  }

  @override
  void dispose() {
    _buscaCtl.dispose();
    super.dispose();
  }

  // === Métodos expostos publicamente para testes unitários ===
  String fmtData(dynamic val) => _fmtData(val);

  Future<String> calcDuracaoComJornada(
    String prestadorId,
    dynamic ini,
    dynamic fim, {
    dynamic realFim,
  }) =>
      _calcDuracaoComJornada(prestadorId, ini, fim, realFim: realFim);

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;

    final stream = db
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: uid)
        .where('status', isEqualTo: 'finalizada')
        .orderBy('respondidaEm', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text(
          'Serviços Finalizados',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        elevation: 0.3,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ===== Barra de busca =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _buscaCtl,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  setState(() => _filtroCliente = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 4),

          // ===== Lista =====
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  return const Center(
                    child: Text('Nenhum serviço finalizado ainda.'),
                  );
                }

                // aplica o filtro de busca
                final filtrados = docs.where((d) {
                  final cliente = (d['clienteNome'] ?? '')
                      .toString()
                      .toLowerCase();
                  return cliente.contains(_filtroCliente);
                }).toList();

                if (filtrados.isEmpty) {
                  return const Center(
                    child: Text('Nenhum resultado encontrado.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = filtrados[i].data();

                    final cliente = (d['clienteNome'] ?? '').toString();
                    final titulo = (d['servicoTitulo'] ?? '').toString();
                    final dataInicio = _fmtData(d['dataInicioSugerida']);
                    final dataFim = _fmtData(
                      d['dataFinalizacaoReal'] ?? d['dataFinalPrevista'],
                    );
                    final valor = _moeda.format((d['valorProposto'] ?? 0));

                    return FutureBuilder<String>(
                      future: _calcDuracaoComJornada(
                        d['prestadorId'] ?? '',
                        d['dataInicioSugerida'],
                        d['dataFinalPrevista'],
                        realFim: d['dataFinalizacaoReal'],
                      ),
                      builder: (context, snapshot) {
                        final duracao = snapshot.data ?? '—';
                        return _FinalizadoCard(
                          titulo: titulo,
                          cliente: cliente,
                          dataInicio: dataInicio,
                          dataFim: dataFim,
                          duracao: duracao,
                          valor: valor,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 🔹 FORMATAÇÃO DE DATAS (privado)
  // =====================================================
  String _fmtData(dynamic val) {
    if (val == null) return '—';
    try {
      if (val is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(val.toDate());
      }
      if (val is String && val.isNotEmpty) return val;
      return '—';
    } catch (_) {
      return '—';
    }
  }

  // =====================================================
  // 🔹 CÁLCULO DE DURAÇÃO CONSIDERANDO JORNADA DO PRESTADOR (privado)
  // =====================================================
  Future<String> _calcDuracaoComJornada(
    String prestadorId,
    dynamic ini,
    dynamic fim, {
    dynamic realFim,
  }) async {
    DateTime? inicio;
    DateTime? finalPrevista;

    if (ini is Timestamp) inicio = ini.toDate();
    if (fim is Timestamp) finalPrevista = fim.toDate();

    DateTime? finalUsada;
    if (realFim is Timestamp) {
      finalUsada = realFim.toDate();
    } else {
      finalUsada = finalPrevista;
    }

    if (inicio == null || finalUsada == null) return '—';

    List<dynamic> jornada = [];
    try {
      final doc = await db.collection('usuarios').doc(prestadorId).get();
      jornada = (doc.data()?['jornada'] ?? []) as List<dynamic>;
    } catch (_) {}

    final Map<String, int> diasSemana = {
      'Segunda-feira': DateTime.monday,
      'Terça-feira': DateTime.tuesday,
      'Quarta-feira': DateTime.wednesday,
      'Quinta-feira': DateTime.thursday,
      'Sexta-feira': DateTime.friday,
      'Sábado': DateTime.saturday,
      'Domingo': DateTime.sunday,
    };

    final Set<int> diasTrabalho = jornada
        .map((d) => diasSemana[d.toString()])
        .whereType<int>()
        .toSet();

    if (diasTrabalho.isEmpty) {
      diasTrabalho.addAll([
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ]);
    }

    int diasUteis = 0;
    DateTime dataAtual = inicio;

    while (!dataAtual.isAfter(finalUsada)) {
      if (diasTrabalho.contains(dataAtual.weekday)) {
        diasUteis++;
      }
      dataAtual = dataAtual.add(const Duration(days: 1));
    }

    return '$diasUteis dia${diasUteis == 1 ? '' : 's'}';
  }
}

// =====================================================
// 🟣 COMPONENTE DE CARD (inalterado)
// =====================================================
class _FinalizadoCard extends StatelessWidget {
  final String titulo;
  final String cliente;
  final String dataInicio;
  final String dataFim;
  final String duracao;
  final String valor;

  const _FinalizadoCard({
    required this.titulo,
    required this.cliente,
    required this.dataInicio,
    required this.dataFim,
    required this.duracao,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E9FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Finalizado',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _info('Cliente:', cliente),
          const SizedBox(height: 4),
          _info('Data de início:', dataInicio),
          const SizedBox(height: 4),
          _info('Data de finalização:', dataFim),
          const SizedBox(height: 4),
          _info('Duração:', duracao),
          const SizedBox(height: 4),
          Text(
            'Valor total: $valor',
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 13.5,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.black87, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
