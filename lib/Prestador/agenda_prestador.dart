import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'servicos_agendados.dart';

class AgendaPrestadorScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const AgendaPrestadorScreen({super.key, this.firestore, this.auth});

  @override
  State<AgendaPrestadorScreen> createState() => AgendaPrestadorScreenState();
}

class AgendaPrestadorScreenState extends State<AgendaPrestadorScreen> {
  late FirebaseFirestore db;
  late FirebaseAuth auth;

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;
    loadWorkdays();
  }

  // =================== Estado/Config ===================
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  late DateTime _selectedDay = _today;
  late DateTime _focusedDay = _today;
  CalendarFormat _format = CalendarFormat.month;

  final Set<int> _workWeekdays = {1, 2, 3, 4, 5};
  final Set<DateTime> busyDays = {};
  final Set<DateTime> _finalizedDays = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _acceptedDocs = [];

  // =================== Utils ===================
  String fmtData(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(d);

  bool isWorkday(DateTime d) => _workWeekdays.contains(d.weekday);
  DateTime ymd(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime toYMD(dynamic ts) {
    final dt = (ts as Timestamp).toDate();
    return DateTime(dt.year, dt.month, dt.day);
  }

  // 🔥 Formata número de WhatsApp com máscara
  String formatWhatsApp(String phone) {
    final digits = onlyDigits(phone);
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  Iterable<DateTime> nextBusinessDays(DateTime start, int count) sync* {
    var d = ymd(start);
    int added = 0;
    while (added < count) {
      if (isWorkday(d)) {
        yield d;
        added++;
      }
      d = d.add(const Duration(days: 1));
    }
  }

  bool isFinalStatus(String? s) {
    final txt = (s ?? '').toLowerCase().trim();
    return txt.startsWith('finaliz') || txt.startsWith('avalia');
  }

  /// tenta achar a data real de finalização no doc
  DateTime? getFinalizacaoReal(Map<String, dynamic> d) {
    for (final k in [
      'dataFinalizacaoReal',
      'dataFinalizada',
      'dataConclusao',
      'dataFinalReal',
      'dataFinalizacao',
    ]) {
      final v = d[k];
      if (v is Timestamp) return toYMD(v);
    }
    return null;
  }

  // 🔥 CORRIGIDO: Verifica se um serviço foi finalizado ANTES do período previsto
  bool _wasFinalizedEarly(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();

    // Só aplica para serviços finalizados
    if (!status.startsWith('finaliz')) return false;

    final finalizacaoReal = getFinalizacaoReal(data);
    final dataInicio = data['dataInicioSugerida'];
    final tempoEstimado = data['tempoEstimadoValor'] as num?;
    final unidade = (data['tempoEstimadoUnidade'] ?? '')
        .toString()
        .toLowerCase();

    // Se não tem dados suficientes, não considera como finalizado antecipadamente
    if (finalizacaoReal == null ||
        dataInicio is! Timestamp ||
        tempoEstimado == null) {
      return false;
    }

    final inicio = dataInicio.toDate();

    // 🔥 LÓGICA PRINCIPAL: Serviços por HORA
    if (unidade.startsWith('hora')) {
      // Para serviços por hora: se foi finalizado no MESMO dia do início, libera o dia INTEIRO
      return finalizacaoReal.isAtSameMomentAs(ymd(inicio));
    }

    // 🔥 LÓGICA PARA SERVIÇOS POR DIA
    if (unidade.startsWith('dia')) {
      final dataFinalPrevista = data['dataFinalPrevista'];
      if (dataFinalPrevista is Timestamp) {
        final finalPrevista = toYMD(dataFinalPrevista);
        // Se finalizou antes da data prevista, libera os dias seguintes
        return finalizacaoReal.isBefore(finalPrevista);
      }
    }

    return false;
  }

  // 🔥 CORRIGIDO: Calcula dias que devem ser liberados (sem horas específicas)
  Map<String, dynamic> _calculateAvailableSlots(Map<String, dynamic> data) {
    final finalizacaoReal = getFinalizacaoReal(data);
    final dataInicio = data['dataInicioSugerida'];
    final tempoEstimado = data['tempoEstimadoValor'] as num?;
    final unidade = (data['tempoEstimadoUnidade'] ?? '')
        .toString()
        .toLowerCase();

    if (finalizacaoReal == null ||
        dataInicio is! Timestamp ||
        tempoEstimado == null) {
      return {'type': 'none'};
    }

    final inicio = dataInicio.toDate();

    // 🔥 CASO SERVIÇOS POR HORA - Libera o DIA INTEIRO
    if (unidade.startsWith('hora')) {
      if (finalizacaoReal.isAtSameMomentAs(ymd(inicio))) {
        return {
          'type': 'day',
          'date': finalizacaoReal,
          'availableFrom': finalizacaoReal,
        };
      }
    }

    // 🔥 CASO SERVIÇOS POR DIA
    if (unidade.startsWith('dia')) {
      final dataFinalPrevista = data['dataFinalPrevista'];
      if (dataFinalPrevista is Timestamp) {
        final finalPrevista = toYMD(dataFinalPrevista);
        if (finalizacaoReal.isBefore(finalPrevista)) {
          final diasRestantes = finalPrevista
              .difference(finalizacaoReal)
              .inDays;
          if (diasRestantes > 0) {
            return {
              'type': 'days',
              'availableFrom': finalizacaoReal.add(const Duration(days: 1)),
              'daysAvailable': diasRestantes,
            };
          }
        }
      }
    }

    return {'type': 'none'};
  }

  int countWorkdays(DateTime start, DateTime end) {
    int count = 0;
    DateTime d = ymd(start);
    while (!d.isAfter(ymd(end))) {
      if (isWorkday(d)) {
        count++;
      }
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  // 🔥 ATUALIZADO: Não marca como ocupado se foi finalizado antecipadamente
  void markBusyFromDoc(Map<String, dynamic> data) {
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return;
    final start = toYMD(tsInicio);

    // 🔥 CORRIGIDO: Não marca como ocupado se foi finalizado antecipadamente
    if (_wasFinalizedEarly(data)) {
      // Não marca os slots que foram liberados
      // Exemplo: Serviço de 24h finalizado às 15:40 → dia fica disponível
      return;
    }

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

  bool isBusy(DateTime day) => busyDays.contains(ymd(day));

  bool docHitsDay(Map<String, dynamic> data, DateTime day) {
    final dayYmd = ymd(day);
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return false;
    final start = ymd(toYMD(tsInicio));

    // 🔹 Finalização real — inclui todo o intervalo até o último dia
    final tsFinalReal = getFinalizacaoReal(data);
    if (tsFinalReal != null) {
      final end = ymd(tsFinalReal);
      if (!dayYmd.isBefore(start) && !dayYmd.isAfter(end)) {
        return true;
      }
      return false;
    }

    // 🔹 Finalização prevista
    final tsPrev = data['dataFinalPrevista'];
    if (tsPrev is Timestamp) {
      final end = ymd(toYMD(tsPrev));
      if (!dayYmd.isBefore(start) && !dayYmd.isAfter(end)) {
        return isWorkday(dayYmd);
      }
      return false;
    }

    // 🔹 Caso estimado por unidade/valor
    final unidade = (data['tempoEstimadoUnidade'] ?? '')
        .toString()
        .toLowerCase();
    final valor = (data['tempoEstimadoValor'] as num?)?.ceil() ?? 0;

    if (unidade.startsWith('dia') && valor > 0) {
      for (final d in nextBusinessDays(start, valor)) {
        if (d == dayYmd) return true;
      }
      return false;
    }

    return dayYmd == start && isWorkday(dayYmd);
  }

  String fmtEndereco(Map<String, dynamic>? e) {
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

  String pickWhatsApp(Map<String, dynamic> d) {
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

  String onlyDigits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _openWhatsApp(String rawPhone) async {
    if (rawPhone == '—' || rawPhone.trim().isEmpty) return;
    final digits = onlyDigits(rawPhone);
    final uri = Uri.parse('https://wa.me/55$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> loadWorkdays() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await db.collection('usuarios').doc(uid).get();
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

      if (mounted) {
        setState(() {
          _workWeekdays
            ..clear()
            ..addAll(
              jornada
                  .map((d) => diasSemana[d.toString()])
                  .whereType<int>()
                  .toSet(),
            );

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
      } else {
        _workWeekdays
          ..clear()
          ..addAll(
            jornada
                .map((d) => diasSemana[d.toString()])
                .whereType<int>()
                .toSet(),
          );

        if (_workWeekdays.isEmpty) {
          _workWeekdays.addAll([
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ]);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar jornada: $e');
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

    final stream = FirebaseFirestore.instance
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: uid)
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

    return DefaultTabController(
      length: 2,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          busyDays.clear();
          _finalizedDays.clear();
          _acceptedDocs = [];

          if (snap.hasData) {
            _acceptedDocs = snap.data!.docs;

            for (final doc in _acceptedDocs) {
              final data = doc.data();
              final status = (data['status'] ?? '').toString().toLowerCase();
              final tsInicio = data['dataInicioSugerida'];
              if (tsInicio is! Timestamp) continue;
              final start = toYMD(tsInicio);

              final realEnd = getFinalizacaoReal(data);
              final prevEnd = data['dataFinalPrevista'] is Timestamp
                  ? toYMD(data['dataFinalPrevista'])
                  : null;

              if (isFinalStatus(status) && realEnd != null) {
                var d = start;
                while (!d.isAfter(realEnd)) {
                  if (isWorkday(d)) _finalizedDays.add(d);
                  d = d.add(const Duration(days: 1));
                }

                // 🔥 NOVO: Verifica se foi finalizado antecipadamente e libera slots
                if (_wasFinalizedEarly(data)) {
                  _calculateAvailableSlots(data);
                  // Os slots liberados NÃO são marcados como busyDays
                }
              } else if (status == 'em andamento' || status == 'em_andamento') {
                if (prevEnd != null) {
                  var d = start;
                  while (!d.isAfter(prevEnd)) {
                    if (isWorkday(d)) busyDays.add(d);
                    d = d.add(const Duration(days: 1));
                  }
                } else {
                  markBusyFromDoc(data);
                }
              } else if (status == 'aceita') {
                markBusyFromDoc(data);
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
    const clrSel = Color(0xFF673AB7);
    final today = _today;

    DateTime ymdLocal(DateTime d) => DateTime(d.year, d.month, d.day);

    Color bgFor(DateTime day) {
      final ymd = ymdLocal(day);

      if (!isWorkday(day)) {
        return const Color.fromARGB(255, 199, 190, 190);
      }

      if (_finalizedDays.contains(ymd)) {
        return const Color.fromARGB(255, 171, 120, 247);
      }

      if (ymd.isBefore(today)) {
        return const Color.fromARGB(255, 199, 190, 190);
      }

      if (busyDays.contains(ymd)) {
        return const Color.fromARGB(255, 199, 190, 190);
      }

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
        availableCalendarFormats: const {
          CalendarFormat.month: 'Semana',
          CalendarFormat.twoWeeks: 'Mês',
          CalendarFormat.week: '2 semanas',
        },
        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = ymd(selected);
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
          'Serviços em ${fmtData(_selectedDay)}',
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
    final dia = ymd(_selectedDay);
    final docsDoDia = _acceptedDocs
        .where((doc) => docHitsDay(doc.data(), dia))
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
          final inicio = toYMD(d['dataInicioSugerida']);
          final unidade = (d['tempoEstimadoUnidade'] ?? '').toString();
          final valor = (d['tempoEstimadoValor'] as num?)?.ceil() ?? 0;
          final cliente = (d['clienteNome'] ?? '') as String?;
          final endereco = fmtEndereco(
            (d['clienteEndereco'] ?? d['endereco']) as Map<String, dynamic>?,
          );
          final whatsapp = pickWhatsApp(d);
          final status = (d['status'] ?? '').toString().toLowerCase();

          Color statusColor;
          String statusTexto;

          if (status.startsWith('finaliz') || status.startsWith('avalia')) {
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
                      const SizedBox(height: 8),
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
                      Text(
                        'Início: ${DateFormat('dd/MM/yyyy').format(inicio)}',
                      ),
                      () {
                        final fim =
                            d['dataFinalizacaoReal'] ?? d['dataFinalPrevista'];
                        final dataFmt = fim is Timestamp
                            ? DateFormat('dd/MM/yyyy').format(fim.toDate())
                            : '—';
                        return Text('Finalização: $dataFmt');
                      }(),
                      () {
                        final fim =
                            d['dataFinalizacaoReal'] ?? d['dataFinalPrevista'];
                        int dias = 0;
                        if (fim is Timestamp) {
                          final diff =
                              fim.toDate().difference(inicio).inDays + 1;
                          dias = diff > 0 ? diff : 1;
                        }
                        return Text(
                          'Duração: ${dias > 0 ? '$dias dia${dias > 1 ? 's' : ''}' : '—'}',
                        );
                      }(),
                      if (!status.startsWith('finaliz'))
                        Text(
                          'Estimativa: ${valor > 0 ? '$valor $unidade(s)' : '—'}',
                        ),
                      Text('Endereço: $endereco', softWrap: true),
                      const SizedBox(height: 8),
                      if (!status.startsWith('finaliz') &&
                          !status.startsWith('avalia') &&
                          whatsapp != '—')
                        InkWell(
                          onTap: () => _openWhatsApp(whatsapp),
                          child: Row(
                            children: [
                              const Icon(
                                FontAwesomeIcons.whatsapp,
                                color: Color(0xFF25D366),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatWhatsApp(whatsapp),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
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