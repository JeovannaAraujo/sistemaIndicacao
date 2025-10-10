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

  int _countWorkdays(DateTime start, DateTime end) {
    int count = 0;
    DateTime d = _ymd(start);
    while (!d.isAfter(_ymd(end))) {
      if (_isWorkday(d)) {
        count++;
      }
      d = d.add(const Duration(days: 1));
    }
    return count;
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

  Future<void> _loadWorkdays() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      final jornada = (doc.data()?['jornada'] ?? []) as List<dynamic>;

      // Mapeia nomes da jornada para weekdays numéricos
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

        // se não tiver jornada salva, padrão: segunda a sexta
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
      debugPrint('Erro ao carregar jornada: $e');
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

  @override
  void initState() {
    super.initState();
    _loadWorkdays(); // carrega jornada do prestador
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
    // CORREÇÃO: Adicionado 'em andamento' (com espaço) ao whereIn para capturar o status correto no banco
    final stream = FirebaseFirestore.instance
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: uid)
        .where(
          'status',
          whereIn: ['aceita', 'em andamento', 'em_andamento', 'finalizada'],
        )
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
              final prevEnd = data['dataFinalPrevista'] is Timestamp
                  ? _toYMD(data['dataFinalPrevista'])
                  : null;

              if (_isFinalStatus(status) && realEnd != null) {
                // 🔹 Serviço finalizado → usa o período real
                var d = start;
                while (!d.isAfter(realEnd)) {
                  if (_isWorkday(d)) _finalizedDays.add(d);
                  d = d.add(const Duration(days: 1));
                }
              } else if (status == 'em andamento' || status == 'em_andamento') {
                // 🔹 Em andamento → usa previsão como indisponível
                if (prevEnd != null) {
                  var d = start;
                  while (!d.isAfter(prevEnd)) {
                    if (_isWorkday(d)) _busyDays.add(d);
                    d = d.add(const Duration(days: 1));
                  }
                } else {
                  _markBusyFromDoc(data);
                }
              } else if (status == 'aceita') {
                // 🔹 Aceita → usa previsão padrão
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
    final today = _today;

    DateTime ymdLocal(DateTime d) => DateTime(d.year, d.month, d.day);

    Color bgFor(DateTime day) {
      final ymd = ymdLocal(day);

      // 1️⃣ Fora da jornada: cinza claro
      if (!_isWorkday(day)) {
        return const Color.fromARGB(255, 199, 190, 190);
      }

      // 2️⃣ Finalizados: roxo claro (sempre, mesmo se antes de hoje)
      if (_finalizedDays.contains(ymd)) {
        return const Color.fromARGB(255, 171, 120, 247);
      }

      // 3️⃣ Dias anteriores a hoje (mas que não foram finalizados): cinza claro
      if (ymd.isBefore(today)) {
        return const Color.fromARGB(255, 199, 190, 190);
      }

      // 4️⃣ Ocupados (em andamento/aceitos): azul claro (ajustado para cinza se preferir)
      // CORREÇÃO OPCIONAL: Mudei para cinza claro aqui para atender à sua descrição ("cinza")
      if (_busyDays.contains(ymd)) {
        return const Color.fromARGB(
          255,
          199,
          190,
          190,
        ); // Cinza para "em andamento"
      }

      // 5️⃣ Disponíveis (futuro dentro da jornada): verde
      return const Color.fromARGB(255, 109, 221, 140);
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
            _focusedDay = (selected.month != _focusedDay.month)
                ? selected
                : focused;
          });
        },

        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(),
          selectedDecoration: BoxDecoration(),
        ),

        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
        ),

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
              BorderSide(color: clrSel, width: 2),
            ),
          ),
          todayBuilder: (context, day, _) {
            final isSelected = isSameDay(day, _selectedDay);
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7),
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.black, width: 1)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: const TextStyle(
                  color: Colors.white,
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
      mainAxisSize: MainAxisSize.min,
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
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              chip(const Color.fromARGB(255, 199, 190, 190), 'Indisponível'),
              const SizedBox(width: 20),
              chip(const Color.fromARGB(255, 93, 248, 137), 'Disponível'),
              const SizedBox(width: 20),
              chip(const Color.fromARGB(255, 171, 120, 247), 'Finalizado'),
            ],
          ),
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
          final status = (d['status'] ?? '').toString().toLowerCase();

          // Define texto e cor do status (sem ícones)
          Color statusColor;
          String statusTexto;

          if (status.startsWith('finaliz')) {
            statusColor = const Color(0xFF5E35B1);
            statusTexto = 'Finalizado';
          } else if (status.contains('andamento')) {
            statusColor = Colors.blue;
            statusTexto = 'Em andamento';
          } else if (status == 'aceita') {
            statusColor = Colors.orange;
            statusTexto = 'Aceito';
          } else {
            statusColor = Colors.grey;
            statusTexto = 'Desconhecido';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8), // espaço pro badge
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

                      // 🔹 Data de início formatada
                      Text(
                        'Início: ${DateFormat('dd/MM/yyyy').format(inicio)}',
                      ),

                      // 🔹 Data de finalização (real, se existir)
                      () {
                        final fim =
                            d['dataFinalizacaoReal'] ?? d['dataFinalPrevista'];
                        final dataFmt = fim is Timestamp
                            ? DateFormat('dd/MM/yyyy').format(fim.toDate())
                            : '—';
                        return Text('Finalização: $dataFmt');
                      }(),

                      // 🔹 Cálculo da duração real
                      () {
                        final fim =
                            d['dataFinalizacaoReal'] ?? d['dataFinalPrevista'];
                        int dias = 0;
                        if (fim is Timestamp) {
                          final diff =
                              fim.toDate().difference(inicio).inDays +
                              1; // +1 para incluir o dia inicial
                          dias = diff > 0 ? diff : 1;
                        }
                        return Text(
                          'Duração: ${dias > 0 ? '$dias dia${dias > 1 ? 's' : ''}' : '—'}',
                        );
                      }(),

                      // 🔹 Mostra estimativa somente se não for finalizado
                      if (!status.startsWith('finaliz'))
                        Text(
                          'Estimativa: ${valor > 0 ? '$valor $unidade(s)' : '—'}',
                        ),

                      Text('Endereço: $endereco', softWrap: true),
                      const SizedBox(height: 8),

                      // 🔹 Botão WhatsApp só se não for finalizado
                      // 🔹 Exibe número do WhatsApp apenas se NÃO estiver finalizado
                      if (!status.startsWith('finaliz') && whatsapp != '—')
                        InkWell(
                          onTap: () => _openWhatsApp(whatsapp),
                          child: Row(
                            children: [
                              const Icon(
                                FontAwesomeIcons.whatsapp,
                                color: Color(
                                  0xFF25D366,
                                ), // cor oficial do WhatsApp
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                whatsapp,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 🔹 Badge de STATUS no canto superior direito (sem ícones)
                Positioned(
                  top: 8,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      statusTexto,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
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
