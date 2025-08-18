import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class AgendaPrestadorScreen extends StatefulWidget {
  const AgendaPrestadorScreen({super.key});

  @override
  State<AgendaPrestadorScreen> createState() => _AgendaPrestadorScreenState();
}

class _AgendaPrestadorScreenState extends State<AgendaPrestadorScreen> {
  // Hoje (sem hora)
  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  // ✅ Já inicializados aqui (nada de late)
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _focusedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  CalendarFormat _format = CalendarFormat.month;

  String _fmtData(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEDE7F6), Color(0xFFD1C4E9)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SizedBox(height: 6),
                      Text(
                        'Agenda do Prestador',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5E35B1),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Calendário e serviços agendados',
                        style: TextStyle(color: Color(0xFF5E35B1)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _format,
                    onFormatChanged: (f) => setState(() => _format = f),

                    // pinta de roxo o dia selecionado (inicia em hoje)
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),

                    // ao tocar um dia: muda o selecionado e mantém o foco
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                        );
                        _focusedDay = focused;
                      });
                    },

                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0x22673AB7), // aro claro em "hoje"
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFF673AB7), // roxo no selecionado
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Row(
                    children: const [
                      _LegendaDot(color: Colors.red, label: 'Indisponível'),
                      SizedBox(width: 14),
                      _LegendaDot(color: Colors.green, label: 'Disponível'),
                      SizedBox(width: 14),
                      _LegendaDot(color: Colors.grey, label: 'Finalizado'),
                    ],
                  ),
                ),

                Padding(
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
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SizedBox(
                    height: 80,
                    child: Center(
                      child: Text('Sem serviços agendados para esta data.'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
