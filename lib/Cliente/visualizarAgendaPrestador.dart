// lib/Cliente/visualizarAgendaPrestador.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Abra como modal sobre a tela do perfil
Future<void> showAgendaPrestadorModal(
  BuildContext context, {
  required String prestadorId,
  String? prestadorNome,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withOpacity(0.25),
    pageBuilder: (_, __, ___) => Center(
      child: VisualizarAgendaPrestador(
        prestadorId: prestadorId,
        prestadorNome: prestadorNome, // 👈 passa aqui também
      ),
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class VisualizarAgendaPrestador extends StatefulWidget {
  final String prestadorId;
  final String? prestadorNome; // 👈 campo novo

  const VisualizarAgendaPrestador({
    super.key,
    required this.prestadorId,
    this.prestadorNome, // 👈 campo novo
  });

  @override
  State<VisualizarAgendaPrestador> createState() =>
      VisualizarAgendaPrestadorState();
}

class VisualizarAgendaPrestadorState extends State<VisualizarAgendaPrestador> {
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  late DateTime _selectedDay = _today;
  late DateTime _focusedDay = _today;
  CalendarFormat _format = CalendarFormat.month;

  final Set<int> _workWeekdays = {1, 2, 3, 4, 5};
  final Set<DateTime> busyDays = {};

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

  void markBusyFromDoc(Map<String, dynamic> data) {
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return;
    final start = toYMD(tsInicio);

    final tsFinalPrev = data['dataFinalPrevista'];
    if (tsFinalPrev is Timestamp) {
      final end = toYMD(tsFinalPrev);
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
    } else {
      if (isWorkday(start)) busyDays.add(start);
    }
  }

  bool _isBusy(DateTime day) => busyDays.contains(_ymd(day));

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('solicitacoesOrcamento')
        .where('prestadorId', isEqualTo: widget.prestadorId)
        .where('status', whereIn: ['aceita', 'em_andamento'])
        .orderBy('dataInicioSugerida', descending: false)
        .snapshots();

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              busyDays.clear();
              if (snap.hasData) {
                for (final doc in snap.data!.docs) {
                  markBusyFromDoc(doc.data());
                }
              }

              return Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        // ===== Título com nome do prestador =====
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text(
                            'Agenda do prestador ${widget.prestadorNome ?? ''}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepPurple,
                            ),
                            softWrap: true, // 👈 permite quebra de linha
                            overflow:
                                TextOverflow.visible, // 👈 evita reticências
                          ),
                        ),

                        // ===== Único header (custom) =====
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
                                  DateFormat(
                                    'LLLL yyyy',
                                    'pt_BR',
                                  ).format(_focusedDay),
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
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.close),
                                tooltip: 'Fechar',
                              ),
                            ],
                          ),
                        ),

                        // ===== Calendário (sem header interno) =====
                        _calendarCard(),

                        // legenda
                        _legenda(),

                        // Título do dia
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Agenda em ${fmtData(_selectedDay)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _calendarCard() {
    const clrSelBorder = Color(0xFF673AB7); // borda roxa selecionado
    const clrBusy = Color.fromARGB(255, 199, 190, 190); // indisponível
    const clrAvail = Color.fromARGB(255, 109, 221, 140); // disponível
    const clrWeekend = Color.fromARGB(255, 199, 190, 190); // fds
    const clrToday = Color(0xFF673AB7); // hoje roxo

    Color bgFor(DateTime day) {
      if (_isBusy(day)) return clrBusy;
      if (!isWorkday(day)) return clrWeekend;
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

        // === Remove o header do TableCalendar ===
        headerVisible: false, // 👈 tira "agosto de 2025" e o botão
        headerStyle: const HeaderStyle(
          formatButtonVisible: false, // redundante, mas garante
        ),

        // limpa decorações default
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
          todayBuilder: (context, day, _) {
            final isSelected = isSameDay(day, _selectedDay);
            return cell(
              day,
              clrToday,
              border: isSelected
                  ? Border.all(color: Colors.black, width: 1)
                  : null,
              text: Colors.white,
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
          chip(const Color.fromARGB(255, 199, 190, 190), 'Indisponível'),
          const SizedBox(width: 14),
          chip(const Color.fromARGB(255, 93, 248, 137), 'Disponível'),
        ],
      ),
    );
  }
}
