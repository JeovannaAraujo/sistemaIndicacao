import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class EnviarOrcamentoScreen extends StatefulWidget {
  final String solicitacaoId;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const EnviarOrcamentoScreen({
    super.key,
    required this.solicitacaoId,
    this.firestore,
    this.auth,
  });

  @override
  State<EnviarOrcamentoScreen> createState() => _EnviarOrcamentoScreenState();
}

class _EnviarOrcamentoScreenState extends State<EnviarOrcamentoScreen> {
  static const colSolicitacoes = 'solicitacoesOrcamento';
  final _formKey = GlobalKey<FormState>();

  // Controles de formulário
  final _valorPropostoCtl = TextEditingController();
  final _tempoValorCtl = TextEditingController();
  final _observacoesCtl = TextEditingController();

  late final FirebaseFirestore db;
  late final FirebaseAuth auth;

  String _tempoUnidade = 'dia';
  DateTime? _dataInicio;
  TimeOfDay? _horaInicio;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  DocumentSnapshot<Map<String, dynamic>>? _docSolic;
  bool _enviando = false;

  // 🔥 NOVO: Para buscar dados do prestador
  String? _prestadorId;

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;
    _loadSolicitacao();
  }

  @override
  void dispose() {
    _valorPropostoCtl.dispose();
    _tempoValorCtl.dispose();
    _observacoesCtl.dispose();
    super.dispose();
  }

  Future<void> _loadSolicitacao() async {
    final doc = await db
        .collection(colSolicitacoes)
        .doc(widget.solicitacaoId)
        .get();

    if (mounted) {
      setState(() {
        _docSolic = doc;
        _prestadorId = doc.data()?['prestadorId']?.toString();
      });
    }
  }

  // ---------- CALENDÁRIO COM VALIDAÇÃO ----------

  Future<void> _selecionarDataDisponivel() async {
    if (_prestadorId == null) return;

    final dataSelecionada = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarioSelecaoData(
        prestadorId: _prestadorId!,
        prestadorNome: _docSolic?.data()?['prestadorNome'] ?? '',
      ),
    );

    if (dataSelecionada != null && mounted) {
      setState(() {
        _dataInicio = dataSelecionada;
        // Se selecionou hoje, reseta a hora para evitar conflito
        final hoje = DateTime.now();
        if (_dataInicio!.day == hoje.day &&
            _dataInicio!.month == hoje.month &&
            _dataInicio!.year == hoje.year) {
          _horaInicio = null;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initialTime =
        _dataInicio != null &&
            _dataInicio!.day == now.day &&
            _dataInicio!.month == now.month &&
            _dataInicio!.year == now.year
        ? TimeOfDay.fromDateTime(now) // Se for hoje, começa da hora atual
        : const TimeOfDay(hour: 8, minute: 0);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null && mounted) {
      // 🔥 VALIDAÇÃO: Se for hoje, não permite hora passada
      if (_dataInicio != null) {
        final hoje = DateTime.now();
        final isHoje =
            _dataInicio!.day == hoje.day &&
            _dataInicio!.month == hoje.month &&
            _dataInicio!.year == hoje.year;

        if (isHoje) {
          final horaAtual = TimeOfDay.fromDateTime(hoje);
          if (picked.hour < horaAtual.hour ||
              (picked.hour == horaAtual.hour &&
                  picked.minute < horaAtual.minute)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Não é possível selecionar um horário que já passou para hoje.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      setState(() {
        _horaInicio = picked;
      });
    }
  }

  // ---------- HELPERS ----------
  double? _parseMoeda(String v) {
    final s = v
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(s);
  }

  String _fmtData(dynamic ts) {
    if (ts is Timestamp) return DateFormat('dd/MM/yyyy').format(ts.toDate());
    return 'Não informado';
  }

  String _fmtHora(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'Não informado';
  }

  InputDecoration _inputDecoration({
    String? hint,
    Widget? suffixIcon,
    String? label,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  // ---------- AÇÕES ----------
  Future<void> _enviarOrcamento() async {
    if (_docSolic == null) return;
    if (!_formKey.currentState!.validate()) return;

    final valor = _parseMoeda(_valorPropostoCtl.text) ?? 0;
    final tempo =
        double.tryParse(_tempoValorCtl.text.replaceAll(',', '.')) ?? 0;
    DateTime? inicioSugerido;

    // pega data/hora do cliente, caso prestador não altere
    final dataCliTs = _docSolic!.data()?['dataDesejada'] as Timestamp?;
    final dataCli = dataCliTs?.toDate();

    if (_dataInicio != null || _horaInicio != null) {
      // prestador escolheu data/hora alternativa
      final base = _dataInicio ?? dataCli ?? DateTime.now();
      final h = _horaInicio?.hour ?? dataCli?.hour ?? 8;
      final m = _horaInicio?.minute ?? dataCli?.minute ?? 0;
      inicioSugerido = DateTime(base.year, base.month, base.day, h, m);
    } else {
      // usa data e hora do cliente
      inicioSugerido = dataCli ?? DateTime.now();
    }

    setState(() => _enviando = true);
    try {
      final fs = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prestadorUid = uid!;

      // 1) Define início (usa a sugerida; se nula, usa agora alinhado)
      final inicio = inicioSugerido;

      // 2) Carrega jornada do prestador
      final jornada = await fetchJornadaPrestador(prestadorUid);

      // 3) Calcula data final
      late DateTime fimPrevisto;
      if (_tempoUnidade == 'hora') {
        fimPrevisto = addWorkingHours(inicio, tempo, jornada);
      } else {
        // 'dia'
        fimPrevisto = addWorkingDays(inicio, tempo, jornada);
      }

      await fs.collection(colSolicitacoes).doc(widget.solicitacaoId).update({
        'status': 'respondida',
        'respondidaEm': FieldValue.serverTimestamp(),
        'respondidaPor': uid,
        'valorProposto': valor,
        'tempoEstimadoValor': tempo,
        'tempoEstimadoUnidade': _tempoUnidade,
        'dataInicioSugerida': Timestamp.fromDate(inicioSugerido),

        // ✅ grava a data final prevista
        'dataFinalPrevista': Timestamp.fromDate(fimPrevisto),

        'observacoesPrestador': _observacoesCtl.text.trim(),
      });

      // Historiza em subcoleção (sem serverTimestamp dentro de arrayUnion)
      await fs
          .collection(colSolicitacoes)
          .doc(widget.solicitacaoId)
          .collection('historico')
          .add({
            'tipo': 'proposta_enviada',
            'quando': FieldValue.serverTimestamp(),
            'por': uid,
            'valorProposto': valor,
            'tempoValor': tempo,
            'tempoUnidade': _tempoUnidade,
            'inicio': Timestamp.fromDate(inicio),
            'fimPrevisto': Timestamp.fromDate(fimPrevisto),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Orçamento enviado!')));

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao enviar: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final carregando = _docSolic == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Enviar Orçamento'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  // 🔥 MÉTODO PARA BUSCAR A UNIDADE CORRETA
  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUnidadeStream(
    Map<String, dynamic> d,
  ) {
    // Busca a unidade correta: Primeiro tenta usar a unidadeSelecionadaId, se não tiver, usa a servicoUnidadeId
    final unidadeSelecionadaId = (d['unidadeSelecionadaId'] ?? '').toString();
    final servicoUnidadeId = (d['servicoUnidadeId'] ?? '').toString();

    // Primeiro tenta a unidade selecionada, depois a do serviço
    final unidadeId = unidadeSelecionadaId.isNotEmpty
        ? unidadeSelecionadaId
        : servicoUnidadeId;

    if (unidadeId.isEmpty) {
      // Retorna um stream vazio se não tiver ID
      return const Stream.empty();
    }

    return db.collection('unidades').doc(unidadeId).snapshots();
  }

  Widget _buildForm() {
    final d = _docSolic!.data()!;
    final titulo = (d['servicoTitulo'] ?? '').toString();
    final quantidade = (d['quantidade'] is num)
        ? (d['quantidade'] as num).toStringAsFixed(0)
        : (d['quantidade']?.toString() ?? '');

    (d['unidadeSelecionadaAbrev'] ?? d['servicoUnidadeAbrev'] ?? '').toString();
    final estimativaValor = (d['estimativaValor'] is num)
        ? _moeda.format((d['estimativaValor'] as num).toDouble())
        : 'R\$0,00';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // 🔥 BLOCO: ESTIMATIVA COM BUSCA DA UNIDADE CORRETA
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _getUnidadeStream(d),
              builder: (context, unidadeSnap) {
                String unidadeAbrev = 'unidade';

                if (unidadeSnap.hasData && unidadeSnap.data!.exists) {
                  final unidadeData = unidadeSnap.data!.data()!;
                  unidadeAbrev = (unidadeData['abreviacao'] ?? 'unidade')
                      .toString();
                } else {
                  // 🔥 FALLBACK: usa abreviações salvas diretamente
                  final unidadeSelecionadaAbrev =
                      (d['unidadeSelecionadaAbrev'] ?? '').toString();
                  final servicoUnidadeAbrev = (d['servicoUnidadeAbrev'] ?? '')
                      .toString();

                  if (unidadeSelecionadaAbrev.isNotEmpty) {
                    unidadeAbrev = unidadeSelecionadaAbrev;
                  } else if (servicoUnidadeAbrev.isNotEmpty) {
                    unidadeAbrev = servicoUnidadeAbrev;
                  }
                }

                return _EstimativaCard(
                  valor: estimativaValor,
                  unidade: unidadeAbrev,
                );
              },
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Dados da solicitação do cliente'),
            const SizedBox(height: 15),
            _ReadOnlyField(
              label: 'Serviço desejado',
              value: titulo.isEmpty ? 'Não informado' : titulo,
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              label: 'Data desejada para início',
              value: _fmtData(d['dataDesejada']),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            const SizedBox(height: 16),
            _ReadOnlyField(
              label: 'Horário desejado para execução',
              value: _fmtHora(d['dataDesejada']),
            ),
            const SizedBox(height: 15),

            // 🔥 STREAM BUILDER PARA BUSCAR A UNIDADE CORRETA
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _getUnidadeStream(d),
              builder: (context, unidadeSnap) {
                String unidadeAbrev = 'un.';

                if (unidadeSnap.hasData && unidadeSnap.data!.exists) {
                  final unidadeData = unidadeSnap.data!.data()!;
                  unidadeAbrev = (unidadeData['abreviacao'] ?? 'un.')
                      .toString();
                } else {
                  // 🔥 FALLBACK: usa abreviações salvas diretamente
                  final unidadeSelecionadaAbrev =
                      (d['unidadeSelecionadaAbrev'] ?? '').toString();
                  final servicoUnidadeAbrev = (d['servicoUnidadeAbrev'] ?? '')
                      .toString();

                  if (unidadeSelecionadaAbrev.isNotEmpty) {
                    unidadeAbrev = unidadeSelecionadaAbrev;
                  } else if (servicoUnidadeAbrev.isNotEmpty) {
                    unidadeAbrev = servicoUnidadeAbrev;
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: _ReadOnlyField(
                        label: 'Quantidade ou dimensão',
                        value: quantidade,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _UnitChip(text: unidadeAbrev),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Valor Proposto'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _valorPropostoCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.start,
              decoration: _inputDecoration(hint: 'R\$ 0,00'),
              onChanged: (v) {
                String digits = v.replaceAll(RegExp(r'[^0-9]'), '');

                if (digits.isEmpty) {
                  _valorPropostoCtl.text = '';
                  return;
                }

                // Converte os centavos
                double value = double.parse(digits) / 100.0;

                final textoFormatado = _moeda.format(value);

                if (textoFormatado != v) {
                  _valorPropostoCtl.value = TextEditingValue(
                    text: textoFormatado,
                    selection: TextSelection.collapsed(
                      offset: textoFormatado.length,
                    ),
                  );
                }
              },
              validator: (v) {
                final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9,]'), '');
                final valor = double.tryParse(cleaned.replaceAll(',', '.'));
                if (valor == null || valor <= 0) {
                  return 'Informe um valor válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Tempo estimado para execução'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tempoValorCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(hint: '0'),
                    validator: (v) {
                      final x = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (x == null || x <= 0) return 'Informe o tempo';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _tempoUnidade,
                    items: const [
                      DropdownMenuItem(value: 'dia', child: Text('dia')),
                      DropdownMenuItem(value: 'hora', child: Text('hora')),
                    ],
                    onChanged: (v) =>
                        setState(() => _tempoUnidade = v ?? 'dia'),
                    decoration: _inputDecoration(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Data alternativa para iniciar execução'),
            const SizedBox(height: 6),
            TextFormField(
              readOnly: true,
              onTap: _selecionarDataDisponivel, // 🔥 AGORA USA O CALENDÁRIO
              controller: TextEditingController(
                text: _dataInicio == null
                    ? ''
                    : DateFormat('dd/MM/yyyy').format(_dataInicio!),
              ),
              decoration: _inputDecoration(
                hint: 'Clique para ver agenda disponível',
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Horário alternativo para iniciar execução'),
            const SizedBox(height: 6),
            TextFormField(
              readOnly: true,
              onTap: _pickTime,
              controller: TextEditingController(
                text: _horaInicio == null
                    ? ''
                    : '${_horaInicio!.hour.toString().padLeft(2, '0')}:${_horaInicio!.minute.toString().padLeft(2, '0')}',
              ),
              decoration: _inputDecoration(
                hint: '00:00',
                suffixIcon: const Icon(Icons.access_time_outlined),
              ),
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clique em "Selecionar Data" para ver sua agenda e escolher uma data disponível. '
                      'Horários do passado não podem ser selecionados.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Observações'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _observacoesCtl,
              minLines: 3,
              maxLines: 5,
              decoration: _inputDecoration(
                hint: 'Ex.: condições, materiais, forma de pagamento...',
              ),
            ),

            const SizedBox(height: 20),
            // Botões (gradiente + ação secundária)
            _PrimaryGradientButton(
              text: 'Enviar Orçamento',
              onPressed: _enviando ? null : _enviarOrcamento,
              loading: _enviando,
            ),
            const SizedBox(height: 10),

            _GlossyRedButton(
              text: 'Cancelar',
              onPressed: _enviando ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== CALENDÁRIO DE SELEÇÃO DE DATA ==================

class _CalendarioSelecaoData extends StatefulWidget {
  final String prestadorId;
  final String prestadorNome;
  const _CalendarioSelecaoData({
    required this.prestadorId,
    required this.prestadorNome,
  });

  @override
  State<_CalendarioSelecaoData> createState() => _CalendarioSelecaoDataState();
}

class _CalendarioSelecaoDataState extends State<_CalendarioSelecaoData> {
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  late DateTime _selectedDay = _today;
  late DateTime _focusedDay = _today;
  CalendarFormat _format = CalendarFormat.month;

  // 🔹 Jornada real do prestador
  final Set<int> _workWeekdays = {};
  final Set<DateTime> busyDays = {};

  @override
  void initState() {
    super.initState();
    _loadJornadaPrestador();
  }

  /// 🔹 Busca jornada de trabalho do prestador
  Future<void> _loadJornadaPrestador() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.prestadorId)
          .get();

      final jornada = (doc.data()?['jornada'] ?? []) as List<dynamic>;
      final Map<String, int> diasSemana = {
        'Segunda-feira': DateTime.monday,
        'Terça-feira': DateTime.tuesday,
        'Quarta-feira': DateTime.wednesday,
        'Quinta-feira': DateTime.thursday,
        'Sexta-feira': DateTime.friday,
        'Sábado': DateTime.saturday,
        'Domingo': DateTime.sunday,
      };

      setState(() {
        _workWeekdays
          ..clear()
          ..addAll(
            jornada
                .map((d) => diasSemana[d.toString()])
                .whereType<int>()
                .toSet(),
          );

        // fallback: se não tiver jornada, assume segunda a sexta
        if (_workWeekdays.isEmpty) {
          _workWeekdays.addAll([
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ]);
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar jornada do prestador: $e');
    }
  }

  String fmtData(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(d);
  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime toYMD(dynamic ts) {
    final dt = (ts as Timestamp).toDate();
    return DateTime(dt.year, dt.month, dt.day);
  }

  bool isWorkday(DateTime d) => _workWeekdays.contains(d.weekday);

  Iterable<DateTime> nextBusinessDays(DateTime start, int count) sync* {
    var d = _ymd(start);
    int added = 0;
    while (added < count) {
      if (isWorkday(d)) {
        yield d;
        added++;
      }
      d = d.add(const Duration(days: 1));
    }
  }

  // marca como indisponíveis os dias previstos
  void markBusyFromDoc(Map<String, dynamic> data) {
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return;
    final start = toYMD(tsInicio);

    final tsFinal = data['dataFinalPrevista'];
    if (tsFinal is Timestamp) {
      final end = toYMD(tsFinal);
      var d = start;
      while (!d.isAfter(end)) {
        if (isWorkday(d)) busyDays.add(d);
        d = d.add(const Duration(days: 1));
      }
      return;
    }

    final unidade = (data['tempoEstimadoUnidade'] ?? '')
        .toString()
        .toLowerCase();
    final valor = (data['tempoEstimadoValor'] as num?)?.ceil() ?? 0;

    if (valor <= 0) {
      if (isWorkday(start)) busyDays.add(start);
      return;
    }

    if (unidade.startsWith('dia')) {
      for (final d in nextBusinessDays(start, valor)) {
        busyDays.add(d);
      }
    } else if (unidade.startsWith('hora')) {
      if (isWorkday(start)) busyDays.add(start);
    } else {
      if (isWorkday(start)) busyDays.add(start);
    }
  }

  bool _isBusy(DateTime day) => busyDays.contains(_ymd(day));

  // 🔥 VERIFICA SE O DIA SELECIONADO É VÁLIDO
  bool _isValidDay(DateTime day) {
    final ymd = _ymd(day);

    // 🔹 Não pode ser antes de hoje
    if (ymd.isBefore(_today)) return false;

    // 🔹 Não pode ser fora da jornada do prestador
    if (!isWorkday(day)) return false;

    // 🔹 Não pode ser dia ocupado
    if (_isBusy(day)) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Busca TODOS os status relevantes (incluindo finalizados/avaliados)
    final stream = FirebaseFirestore.instance
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .where(
          'status',
          whereIn: [
            'aceita',
            'em andamento',
            'em_andamento',
            'finalizada',
            'finalizado',
            'avaliada',
            'avaliado',
          ],
        )
        .orderBy('dataInicioSugerida', descending: false)
        .snapshots();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== Título com nome do prestador =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Sua Agenda - ${widget.prestadorNome}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3E1F93),
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),

            // ===== Header custom com mês, setas e fechar =====
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(
                          _focusedDay.year,
                          _focusedDay.month - 1,
                          1,
                        );
                      });
                    },
                    icon: const Icon(Icons.arrow_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('LLLL yyyy', 'pt_BR').format(_focusedDay),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(
                          _focusedDay.year,
                          _focusedDay.month + 1,
                          1,
                        );
                      });
                    },
                    icon: const Icon(Icons.arrow_right),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),

            // ===== Calendário =====
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                busyDays.clear();

                if (snap.hasData) {
                  // 🔥 Processa TODOS os documentos como indisponíveis
                  for (final doc in snap.data!.docs) {
                    final data = doc.data();
                    final tsInicio = data['dataInicioSugerida'];
                    if (tsInicio is! Timestamp) continue;
                    final start = toYMD(tsInicio);

                    // 🔹 Para serviços finalizados/avaliados, usa período real se existir
                    final status = (data['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    final isFinalizado =
                        status.startsWith('finaliz') ||
                        status.startsWith('avalia');

                    DateTime? endDate;

                    if (isFinalizado) {
                      // 🔹 Tenta pegar data final real para finalizados
                      for (final k in [
                        'dataFinalizacaoReal',
                        'dataFinalizada',
                        'dataConclusao',
                        'dataFinalReal',
                        'dataFinalizacao',
                      ]) {
                        final v = data[k];
                        if (v is Timestamp) {
                          endDate = toYMD(v);
                          break;
                        }
                      }
                    }

                    // 🔹 Se não encontrou data final real, usa a prevista
                    if (endDate == null &&
                        data['dataFinalPrevista'] is Timestamp) {
                      endDate = toYMD(data['dataFinalPrevista']);
                    }

                    // 🔹 Se ainda não tem data final, marca apenas o dia inicial
                    if (endDate == null) {
                      if (isWorkday(start)) busyDays.add(start);
                    } else {
                      // 🔹 Marca todo o período como indisponível
                      var d = start;
                      while (!d.isAfter(endDate)) {
                        if (isWorkday(d)) busyDays.add(d);
                        d = d.add(const Duration(days: 1));
                      }
                    }
                  }
                }

                return _calendarCard();
              },
            ),

            // ===== Legenda SIMPLIFICADA =====
            _legenda(),

            // ===== Botões =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isValidDay(_selectedDay)
                          ? () {
                              Navigator.pop(context, _selectedDay);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isValidDay(_selectedDay)
                            ? Colors.deepPurple
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarCard() {
    const clrSelBorder = Color(0xFF673AB7);
    const clrBusy = Color.fromARGB(255, 199, 190, 190); // indisponível
    const clrAvail = Color.fromARGB(255, 109, 221, 140); // disponível

    Color bgFor(DateTime day) {
      final today = _today;
      final ymd = _ymd(day);

      // 1️⃣ Fora da jornada: cinza claro
      if (!isWorkday(day)) {
        return clrBusy;
      }

      // 2️⃣ Dias anteriores a hoje: cinza claro
      if (ymd.isBefore(today)) {
        return clrBusy;
      }

      // 3️⃣ Ocupados (aceitos, em andamento, finalizados, avaliados): cinza
      if (_isBusy(day)) {
        return clrBusy;
      }

      // 4️⃣ Disponíveis (futuro dentro da jornada): verde
      return clrAvail;
    }

    Widget cell(DateTime day, Color bg, {Border? border, Color? text}) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: text ?? Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TableCalendar(
        locale: 'pt_BR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _format,
        onFormatChanged: (f) => setState(() => _format = f),
        headerVisible: false,
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(),
          selectedDecoration: BoxDecoration(),
        ),
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = _ymd(selected);
            _focusedDay = (selected.month != _focusedDay.month)
                ? selected
                : focused;
          });
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, _) => cell(day, bgFor(day)),
          outsideBuilder: (context, day, _) =>
              Opacity(opacity: 0.5, child: cell(day, bgFor(day))),
          disabledBuilder: (context, day, _) =>
              Opacity(opacity: 0.5, child: cell(day, bgFor(day))),
          selectedBuilder: (context, day, _) => cell(
            day,
            bgFor(day),
            border: const Border.fromBorderSide(
              BorderSide(color: clrSelBorder, width: 2),
            ),
          ),
          todayBuilder: (context, day, _) => cell(
            day,
            bgFor(day),
            border: Border.all(color: Colors.black, width: 1),
            text: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _legenda() {
    Widget chip(Color c, String t) => Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chip(const Color.fromARGB(255, 199, 190, 190), 'Indisponível'),
          const SizedBox(width: 14),
          chip(const Color.fromARGB(255, 109, 221, 140), 'Disponível'),
        ],
      ),
    );
  }
}

/// Representa a jornada de trabalho do prestador.
class Jornada {
  final Set<int> dias; // DateTime.monday..DateTime.sunday
  final int inicioMin; // minutos a partir de 00:00 (ex.: 8*60=480)
  final int fimMin; // idem
  int get cargaMinDia => (fimMin - inicioMin).clamp(0, 24 * 60);

  const Jornada({
    required this.dias,
    required this.inicioMin,
    required this.fimMin,
  });

  factory Jornada.padrao() => const Jornada(
    dias: {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
    inicioMin: 8 * 60, // 08:00
    fimMin: 17 * 60, // 17:00
  );
}

int _hhmmToMin(String s) {
  final p = s.split(':');
  if (p.length != 2) return 8 * 60;
  final h = int.tryParse(p[0]) ?? 8;
  final m = int.tryParse(p[1]) ?? 0;
  return (h * 60 + m).clamp(0, 24 * 60);
}

DateTime _withMinutesOfDay(DateTime d, int minutes) =>
    DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);

int _minutesOfDay(DateTime d) => d.hour * 60 + d.minute;

/// Busca a jornada no Firestore em /usuarios/{uid}.
/// Campos aceitos (qualquer um deles; se não existir, usa padrão):
/// - jornada: { inicio: '08:00', fim: '17:00', diasAtivos: [1,2,3,4,5] }
/// - ou jornadaInicio: '08:00', jornadaFim: '17:00'
/// - diasTrabalho: [1..7]  (1=segunda ... 7=domingo)
/// - diasMapa: {seg:true, ter:true, qua:true, qui:true, sex:true, sab:false, dom:false}
Future<Jornada> fetchJornadaPrestador(String prestadorUid) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(prestadorUid)
        .get();
    if (!snap.exists) return Jornada.padrao();
    final d = (snap.data() ?? {});

    String? iniStr;
    String? fimStr;
    Set<int> dias = {};

    if (d['jornada'] is Map) {
      final j = d['jornada'] as Map;
      iniStr = (j['inicio'] ?? j['jornadaInicio'])?.toString();
      fimStr = (j['fim'] ?? j['jornadaFim'])?.toString();

      if (j['diasAtivos'] is List) {
        dias = Set<int>.from(
          (j['diasAtivos'] as List).map((e) => int.tryParse(e.toString()) ?? 0),
        ).where((e) => e >= 1 && e <= 7).toSet();
      }
    }

    iniStr ??= d['jornadaInicio']?.toString();
    fimStr ??= d['jornadaFim']?.toString();

    if (dias.isEmpty && d['diasTrabalho'] is List) {
      dias = Set<int>.from(
        (d['diasTrabalho'] as List).map((e) => int.tryParse(e.toString()) ?? 0),
      ).where((e) => e >= 1 && e <= 7).toSet();
    }

    if (dias.isEmpty && d['diasMapa'] is Map) {
      final m = d['diasMapa'] as Map;
      final map = {
        'seg': DateTime.monday,
        'ter': DateTime.tuesday,
        'qua': DateTime.wednesday,
        'qui': DateTime.thursday,
        'sex': DateTime.friday,
        'sab': DateTime.saturday,
        'dom': DateTime.sunday,
      };
      for (final k in map.keys) {
        if ((m[k] ?? false) == true) dias.add(map[k]!);
      }
    }

    if (dias.isEmpty) dias = Jornada.padrao().dias;

    final inicioMin = iniStr != null
        ? _hhmmToMin(iniStr)
        : Jornada.padrao().inicioMin;
    final fimMin = fimStr != null
        ? _hhmmToMin(fimStr)
        : Jornada.padrao().fimMin;
    return Jornada(dias: dias, inicioMin: inicioMin, fimMin: fimMin);
  } catch (_) {
    return Jornada.padrao();
  }
}

bool isWorkingDay(DateTime d, Jornada j) => j.dias.contains(d.weekday);

DateTime _nextWorkingDayStart(DateTime date, Jornada j) {
  var d = DateTime(date.year, date.month, date.day);
  while (!isWorkingDay(d, j)) {
    d = d.add(const Duration(days: 1));
  }
  return _withMinutesOfDay(d, j.inicioMin);
}

/// Alinha para um instante válido dentro da jornada.
/// - Se for fim de semana / dia não trabalhado → próximo dia útil no horário de início
/// - Se antes do início → início do mesmo dia
/// - Se depois do fim → início do próximo dia útil
DateTime alignToJornadaStart(DateTime dt, Jornada j) {
  if (!isWorkingDay(dt, j)) return _nextWorkingDayStart(dt, j);
  final mod = _minutesOfDay(dt);
  if (mod < j.inicioMin) return _withMinutesOfDay(dt, j.inicioMin);
  if (mod >= j.fimMin) {
    return _nextWorkingDayStart(dt.add(const Duration(days: 1)), j);
  }
  return dt;
}

/// Soma horas úteis respeitando a jornada (pula dias não trabalhados)
DateTime addWorkingHours(DateTime start, double hours, Jornada j) {
  var cur = alignToJornadaStart(start, j);
  var remaining = (hours * 60).round();

  while (remaining > 0) {
    final mod = _minutesOfDay(cur);
    final minutesLeftToday = (j.fimMin - mod).clamp(0, j.cargaMinDia);
    if (minutesLeftToday == 0) {
      cur = _nextWorkingDayStart(cur.add(const Duration(days: 1)), j);
      continue;
    }
    final step = remaining < minutesLeftToday ? remaining : minutesLeftToday;
    cur = cur.add(Duration(minutes: step));
    remaining -= step;
    if (remaining > 0) {
      cur = _nextWorkingDayStart(cur.add(const Duration(minutes: 1)), j);
    }
  }
  return cur;
}

/// Soma dias úteis.
/// Regra: se o prestador informou "5 dias", o término é no **quinto dia útil** após a data de início,
/// conforme seu exemplo (começa dia 28 → termina 5 dias depois, pulando fins de semana).
DateTime addWorkingDays(DateTime start, double dias, Jornada j) {
  // Se for inteiro, contamos "N dias" como mover N dias úteis e terminar no fim do expediente
  final inteiro = dias.floor();
  final resto = dias - inteiro;

  var d = alignToJornadaStart(start, j);

  // avança N dias úteis
  for (var i = 0; i < inteiro; i++) {
    // vai para o próximo dia útil (contagem no seu modelo inclui o dia de início como dia 0)
    d = _nextWorkingDayStart(d.add(const Duration(days: 1)), j);
  }
  // se não tinha parte decimal, terminar no fim da jornada do dia final
  if (resto == 0) {
    return _withMinutesOfDay(d, j.fimMin);
  }

  // parte fracionária do dia → converte para horas de trabalho
  final horasFracao = resto * (j.cargaMinDia / 60.0);
  return addWorkingHours(d, horasFracao, j);
}

class _EstimativaCard extends StatelessWidget {
  final String valor;
  final String unidade;
  const _EstimativaCard({required this.valor, required this.unidade});

  @override
  Widget build(BuildContext context) {
    final semEstimativa = valor == 'R\$0,00' || valor.trim().isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E7FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: semEstimativa
          ? const Text(
              'Não há estimativa de valor para esta solicitação, pois o cliente selecionou uma unidade de medida diferente da cadastrada para o serviço.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w500,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimativa de Valor',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este valor é calculado automaticamente com base na quantidade informada e na média de preços do serviço.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fórmula: Quantidade × Valor Médio por $unidade.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Este campo é apenas informativo e não pode ser editado manualmente.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
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

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final Widget? suffixIcon;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String text;
  const _UnitChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 48,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.7,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
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
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text, // ← usa o parâmetro
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlossyRedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GlossyRedButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.7,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF5252),
                Color(0xFFD32F2F),
              ], // vermelho degradê
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
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
