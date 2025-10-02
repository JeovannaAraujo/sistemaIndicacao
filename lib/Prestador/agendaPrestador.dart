import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'servicosAgendados.dart';

class AgendaPrestadorScreen extends StatefulWidget {
  const AgendaPrestadorScreen({super.key});
  @override
  State<AgendaPrestadorScreen> createState() => _AgendaPrestadorScreenState();
}

class _AgendaPrestadorScreenState extends State<AgendaPrestadorScreen> {
  // =================== Estado/Config ===================
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  late DateTime _selectedDay = _today;
  late DateTime _focusedDay = _today;
  CalendarFormat _format = CalendarFormat.month;

  final Set<int> _workWeekdays = {1, 2, 3, 4, 5};
  final Set<DateTime> _busyDays = {}; // indisponível (em andamento)
  final Set<DateTime> _finalizedDays =
      {}; // finalizado (dias realmente trabalhados)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _acceptedDocs = [];

  // =================== Utils ===================
  String _fmtData(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(d);

  bool _isWorkday(DateTime d) => _workWeekdays.contains(d.weekday);
  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _toYMD(dynamic ts) {
    final dt = (ts as Timestamp).toDate();
    return DateTime(dt.year, dt.month, dt.day);
  }

  Iterable<DateTime> _nextBusinessDays(DateTime start, int count) sync* {
    var d = _ymd(start);
    int added = 0;
    while (added < count) {
      if (_isWorkday(d)) {
        yield d;
        added++;
      }
      d = d.add(const Duration(days: 1));
    }
  }

  bool _isFinalStatus(String? s) =>
      (s ?? '').toLowerCase().startsWith('finaliz');

  /// tenta achar a data real de finalização no doc
  DateTime? _getFinalizacaoReal(Map<String, dynamic> d) {
    for (final k in [
      'dataFinalizacaoReal',
      'dataFinalizada',
      'dataConclusao',
      'dataFinalReal',
      'dataFinalizacao',
    ]) {
      final v = d[k];
      if (v is Timestamp) return _toYMD(v);
    }
    return null;
  }

  // marca como indisponíveis os dias previstos (status "aceita")
  void _markBusyFromDoc(Map<String, dynamic> data) {
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return;
    final start = _toYMD(tsInicio);

    final tsFinal = data['dataFinalPrevista'];
    if (tsFinal is Timestamp) {
      final end = _toYMD(tsFinal);
      var d = start;
      while (!d.isAfter(end)) {
        if (_isWorkday(d)) _busyDays.add(d);
        d = d.add(const Duration(days: 1));
      }
      return;
    }

    final unidade = (data['tempoEstimadoUnidade'] ?? '')
        .toString()
        .toLowerCase();
    final valor = (data['tempoEstimadoValor'] as num?)?.ceil() ?? 0;

    if (valor <= 0) {
      if (_isWorkday(start)) _busyDays.add(start);
      return;
    }

    if (unidade.startsWith('dia')) {
      for (final d in _nextBusinessDays(start, valor)) {
        _busyDays.add(d);
      }
    } else if (unidade.startsWith('hora')) {
      if (_isWorkday(start)) _busyDays.add(start);
    } else {
      if (_isWorkday(start)) _busyDays.add(start);
    }
  }

  bool _isBusy(DateTime day) => _busyDays.contains(_ymd(day));

  bool _docHitsDay(Map<String, dynamic> data, DateTime day) {
    final ymd = _ymd(day);
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return false;
    final start = _toYMD(tsInicio);

    final tsFinalReal = _getFinalizacaoReal(data);
    if (tsFinalReal != null) {
      if (ymd.isBefore(start) || ymd.isAfter(tsFinalReal)) return false;
      return _isWorkday(ymd);
    }

    final tsPrev = data['dataFinalPrevista'];
    if (tsPrev is Timestamp) {
      final end = _toYMD(tsPrev);
      if (ymd.isBefore(start) || ymd.isAfter(end)) return false;
      return _isWorkday(ymd);
    }

    final unidade = (data['tempoEstimadoUnidade'] ?? '')
        .toString()
        .toLowerCase();
    final valor = (data['tempoEstimadoValor'] as num?)?.ceil() ?? 0;

    if (unidade.startsWith('dia') && valor > 0) {
      for (final d in _nextBusinessDays(start, valor)) {
        if (d == ymd) return true;
      }
      return false;
    }

    return ymd == start && _isWorkday(ymd);
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

  // =================== Build ===================
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não logado.')),
        backgroundColor: Color(0xFFF9F6FF),
      );
    }

    // busca solicitações aceitas e finalizadas
    final stream = FirebaseFirestore.instance
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: uid)
        .where('status', whereIn: ['aceita', 'em_andamento', 'finalizada'])
        .orderBy('dataInicioSugerida', descending: false)
        .snapshots();

    return DefaultTabController(
      length: 2,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          _busyDays.clear();
          _finalizedDays.clear();
          _acceptedDocs = [];

          if (snap.hasData) {
            _acceptedDocs = snap.data!.docs;

            for (final doc in _acceptedDocs) {
              final data = doc.data();
              final status = (data['status'] ?? '').toString().toLowerCase();
              final tsInicio = data['dataInicioSugerida'];
              if (tsInicio is! Timestamp) continue;
              final start = _toYMD(tsInicio);

              final realEnd = _getFinalizacaoReal(data);

              if (_isFinalStatus(status) && realEnd != null) {
                // FINALIZADO: pinta do início até a data real (somente dias úteis)
                var d = start;
                while (!d.isAfter(realEnd)) {
                  if (_isWorkday(d)) _finalizedDays.add(d);
                  d = d.add(const Duration(days: 1));
                }
              } else {
                // EM ANDAMENTO/ACEITA: INDISPONÍVEL pelo previsto/estimado
                _markBusyFromDoc(data);
              }
            }
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF9F6FF),
            body: NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF5E35B1),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  leadingWidth: 56,
                  pinned: true,
                  expandedHeight: 130,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5F0FF), Color(0xFFD8C8F5)],
                      ),
                    ),
                    child: const SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(64, 8, 16, 50),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 6),
                            Text(
                              'Agenda do Prestador',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3E1F93),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(46),
                    child: Container(
                      color: Colors.white,
                      child: const TabBar(
                        labelPadding: EdgeInsets.symmetric(horizontal: 16),
                        indicatorWeight: 3,
                        indicatorColor: Color(0xFF5E35B1),
                        labelColor: Color(0xFF5E35B1),
                        unselectedLabelColor: Colors.black87,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        tabs: [
                          Tab(text: 'Calendário'),
                          Tab(text: 'Serviços Agendados'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  // ===== Aba 1: Calendário =====
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        _calendarCard(),
                        _legenda(),
                        _tituloServicosDoDia(),
                        _listaServicosDoDia(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  // ===== Aba 2: Serviços Agendados (embutido) =====
                  const ServicosAgendadosScreen(embedded: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =================== Widgets da Aba 1 ===================
  Widget _calendarCard() {
    const clrSel = Color(0xFF673AB7); // roxo da borda

    DateTime ymdLocal(DateTime d) => DateTime(d.year, d.month, d.day);

    Color bgFor(DateTime day) {
      final ymd = ymdLocal(day);
      if (_busyDays.contains(ymd)) {
        return const Color.fromARGB(255, 255, 64, 77); // ocupado (vermelho)
      }
      if (_finalizedDays.contains(ymd)) {
        return const Color.fromARGB(
          255,
          171,
          120,
          247,
        ); // finalizado (roxo claro)
      }
      if (!_isWorkday(day)) {
        return const Color.fromARGB(255, 199, 190, 190); // fds (cinza)
      }
      return const Color.fromARGB(255, 109, 221, 140); // disponível (verde)
    }

    Widget cell(DateTime day, Color bg, {Border? border}) {
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
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: TableCalendar(
        locale: 'pt_BR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _format,
        onFormatChanged: (f) => setState(() => _format = f),

        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = _ymd(selected);
            // virar automaticamente para o mês do dia clicado (se for fora do mês atual)
            _focusedDay = (selected.month != _focusedDay.month) ? selected : focused;
          });
        },

        // MUITO IMPORTANTE: zera as decorações padrão
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(), // sem círculo de "hoje"
          selectedDecoration:
              BoxDecoration(), // sem preenchimento do "selecionado"
        ),

        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
        ),

        calendarBuilders: CalendarBuilders(
          // célula “normal”
          defaultBuilder: (context, day, _) => cell(day, bgFor(day)),

          // fora do mês / desabilitado (opacidade menor)
          outsideBuilder: (context, day, _) =>
              Opacity(opacity: 0.5, child: cell(day, bgFor(day))),
          disabledBuilder: (context, day, _) =>
              Opacity(opacity: 0.5, child: cell(day, bgFor(day))),

          // selecionado → SÓ borda roxa
          selectedBuilder: (context, day, _) => cell(
            day,
            bgFor(day),
            border: const Border.fromBorderSide(
              BorderSide(color: clrSel, width: 2),
            ),
          ),

          // hoje (quando NÃO é o selecionado) → preenchido roxo
          todayBuilder: (context, day, _) {
            final isSelected = isSameDay(day, _selectedDay);
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7), // roxo preenchido
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(
                        color: Colors.black,
                        width: 1,
                      ) // opcional: destaque se também for selecionado
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: const TextStyle(
                  color: Colors.white, // número branco para contraste
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
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
        children: [
          chip(const Color.fromARGB(255, 243, 46, 62), 'Indisponível'),
          const SizedBox(width: 14),
          chip(const Color.fromARGB(255, 93, 248, 137), 'Disponível'),
          const SizedBox(width: 14),
          chip(const Color.fromARGB(255, 132, 65, 233), 'Finalizado'),
        ],
      ),
    );
  }

  Widget _tituloServicosDoDia() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Serviços em ${_fmtData(_selectedDay)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  Widget _listaServicosDoDia() {
    final dia = _ymd(_selectedDay);
    final docsDoDia = _acceptedDocs
        .where((doc) => _docHitsDay(doc.data(), dia))
        .toList();

    if (docsDoDia.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(
          height: 80,
          child: Center(child: Text('Sem serviços agendados para esta data.')),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: docsDoDia.map((doc) {
          final d = doc.data();
          final inicio = _toYMD(d['dataInicioSugerida']);
          final unidade = (d['tempoEstimadoUnidade'] ?? '').toString();
          final valor = (d['tempoEstimadoValor'] as num?)?.ceil() ?? 0;
          final cliente = (d['clienteNome'] ?? '') as String?;
          final endereco = _fmtEndereco(
            (d['clienteEndereco'] ?? d['endereco']) as Map<String, dynamic>?,
          );
          final whatsapp = _pickWhatsApp(d);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (d['servicoTitulo'] ?? 'Serviço agendado') as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cliente: ${cliente?.isNotEmpty == true ? cliente : '—'}',
                  ),
                  Text('Início: ${DateFormat('dd/MM/yyyy').format(inicio)}'),
                  Text('Estimativa: ${valor > 0 ? '$valor $unidade(s)' : '—'}'),
                  Text('Endereço: $endereco', softWrap: true),
                  const SizedBox(height: 10),
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
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LegendaDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendaDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
