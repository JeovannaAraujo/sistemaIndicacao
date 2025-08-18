// lib/Cliente/visualizarAgendaPrestador.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VisualizarAgendaPrestador extends StatefulWidget {
  final String prestadorId;
  const VisualizarAgendaPrestador({super.key, required this.prestadorId});

  @override
  State<VisualizarAgendaPrestador> createState() => _VisualizarAgendaPrestadorState();
}

class _VisualizarAgendaPrestadorState extends State<VisualizarAgendaPrestador> {
  // Coleções/fields (ajuste se necessário)
  static const String colUsuarios = 'usuarios';
  static const String colAgendamentos = 'agendamentos';
  static const String fieldData = 'data'; // Timestamp do agendamento (usar data de início)
  static const String fieldStatus = 'status';
  static const String fieldPrestadorId = 'prestadorId';

  // Estado local de mês/seleção
  DateTime _cursorMonth = _monthStart(DateTime.now());
  DateTime? _selectedDate;

  // Mapeia nomes (com/sem acento) -> weekday (1=seg ... 7=dom)
  static final Map<String, int> _weekdayMap = {
    'segunda': 1, 'segunda-feira': 1,
    'terca': 2, 'terça': 2, 'terca-feira': 2, 'terça-feira': 2,
    'quarta': 3, 'quarta-feira': 3,
    'quinta': 4, 'quinta-feira': 4,
    'sexta': 5, 'sexta-feira': 5,
    'sabado': 6, 'sábado': 6,
    'domingo': 7,
  };

  static DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime _monthEndExclusive(DateTime d) => DateTime(d.year, d.month + 1, 1);

  void _prevMonth() => setState(() => _cursorMonth = _monthStart(DateTime(_cursorMonth.year, _cursorMonth.month - 1)));
  void _nextMonth() => setState(() => _cursorMonth = _monthStart(DateTime(_cursorMonth.year, _cursorMonth.month + 1)));

  @override
  Widget build(BuildContext context) {
    final usuariosRef = FirebaseFirestore.instance.collection(colUsuarios).doc(widget.prestadorId);

    return Scaffold(
      // fundo levemente escuro pra parecer sobreposição
      backgroundColor: Colors.black.withOpacity(0.06),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: usuariosRef.snapshots(),
                  builder: (context, userSnap) {
                    if (userSnap.hasError) return const SizedBox(height: 240, child: Center(child: Text('Erro ao carregar agenda.')));
                    if (!userSnap.hasData) return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
                    if (!userSnap.data!.exists) return const SizedBox(height: 240, child: Center(child: Text('Prestador não encontrado.')));

                    final u = (userSnap.data!.data() as Map<String, dynamic>?) ?? {};
                    // Jornada: array de strings — default seg-sex
                    final List jornadaList = (u['jornada'] is List) ? (u['jornada'] as List) : const [];
                    final Set<int> workingDays = jornadaList.isEmpty
                        ? {1, 2, 3, 4, 5}
                        : jornadaList.map((e) => _weekdayFromString(e.toString())).where((w) => w != null).cast<int>().toSet();

                    // Legenda de cidade (se quiser exibir no header)
                    final endereco = (u['endereco'] is Map) ? (u['endereco'] as Map).cast<String, dynamic>() : <String, dynamic>{};
                    final cidade = (endereco['cidade'] ?? u['cidade'] ?? '').toString();

                    // Stream de agendamentos do mês atual
                    final start = _monthStart(_cursorMonth);
                    final end = _monthEndExclusive(_cursorMonth);
                    final statusBloqueiam = ['aceito', 'confirmado', 'em_andamento']; // ajuste se necessário

                    final q = FirebaseFirestore.instance
                        .collection(colAgendamentos)
                        .where(fieldPrestadorId, isEqualTo: widget.prestadorId)
                        .where(fieldData, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                        .where(fieldData, isLessThan: Timestamp.fromDate(end))
                        .where(fieldStatus, whereIn: statusBloqueiam);

                    return StreamBuilder<QuerySnapshot>(
                      stream: q.snapshots(),
                      builder: (context, agSnap) {
                        if (agSnap.hasError) {
                          // se o whereIn pedir índice, mostre fallback com sem filtro de status
                          return _buildCalendar(
                            workingDays: workingDays,
                            reservedDays: const <DateTime>{},
                            cidade: cidade,
                          );
                        }
                        if (!agSnap.hasData) {
                          return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
                        }
                        // Normaliza os dias reservados (somente AAAA-MM-DD)
                        final reserved = <DateTime>{};
                        for (final doc in agSnap.data!.docs) {
                          final m = (doc.data() as Map<String, dynamic>?) ?? {};
                          final ts = (m[fieldData] as Timestamp?);
                          if (ts == null) continue;
                          final d = ts.toDate();
                          reserved.add(DateTime(d.year, d.month, d.day));
                        }

                        return _buildCalendar(
                          workingDays: workingDays,
                          reservedDays: reserved,
                          cidade: cidade,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar({
    required Set<int> workingDays,
    required Set<DateTime> reservedDays,
    required String cidade,
  }) {
    final monthName = _mesPtBr(_cursorMonth.month);
    final year = _cursorMonth.year;

    // Datas para a grade
    final first = _monthStart(_cursorMonth);
    final daysInMonth = DateTime(_cursorMonth.year, _cursorMonth.month + 1, 0).day;
    // grade começando no domingo (0 deslocamentos se domingo)
    final leading = first.weekday % 7; // 1..6, 0 para domingo
    final totalCells = leading + daysInMonth;
    final trailing = (totalCells % 7 == 0) ? 0 : (7 - (totalCells % 7));
    final gridCount = totalCells + trailing;

    // estilização
    const availableFill = 0x1FD1C4F3; // roxinho bem claro (opacity via ARGB)
    final availableColor = const Color(availableFill);
    final selectedFill = Colors.deepPurple;
    final unavailableFill = Colors.grey.shade200;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header (mês, navegação, fechar)
        Row(
          children: [
            IconButton(onPressed: _prevMonth, icon: const Icon(Icons.arrow_drop_up)), // setinhas estilo protótipo
            Expanded(
              child: Column(
                children: [
                  Text('$monthName $year',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  if (cidade.isNotEmpty)
                    Text(cidade, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            IconButton(onPressed: _nextMonth, icon: const Icon(Icons.arrow_drop_down)),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Semana (dom..sáb)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _WeekLabel('dom.'), _WeekLabel('seg.'), _WeekLabel('ter.'), _WeekLabel('qua.'),
            _WeekLabel('qui.'), _WeekLabel('sex.'), _WeekLabel('sáb.'),
          ],
        ),
        const SizedBox(height: 8),

        // Grade de dias
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: gridCount,
          itemBuilder: (_, idx) {
            final dayNumber = idx - leading + 1;
            final inMonth = (dayNumber >= 1 && dayNumber <= daysInMonth);

            DateTime? date;
            if (inMonth) {
              date = DateTime(_cursorMonth.year, _cursorMonth.month, dayNumber);
            }

            final today = DateTime.now();
            final isPast = date != null &&
                DateTime(date.year, date.month, date.day)
                    .isBefore(DateTime(today.year, today.month, today.day));

            final isWorking = date != null && workingDays.contains(_weekdayFromDart(date.weekday));
            final isReserved = date != null && reservedDays.contains(DateTime(date.year, date.month, date.day));

            final available = inMonth && !isPast && isWorking && !isReserved;

            final isSelected = _selectedDate != null &&
                date != null &&
                _selectedDate!.year == date.year &&
                _selectedDate!.month == date.month &&
                _selectedDate!.day == date.day;

            final bg = !inMonth
                ? Colors.transparent
                : (available
                    ? (isSelected ? selectedFill : availableColor)
                    : unavailableFill);

            final textStyle = TextStyle(
              fontWeight: FontWeight.w600,
              color: (available && isSelected) ? Colors.white : Colors.black87,
            );

            return InkWell(
              onTap: (available)
                  ? () => setState(() => _selectedDate = date)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(inMonth ? '$dayNumber' : '',
                    style: inMonth ? textStyle : const TextStyle(color: Colors.transparent)),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        // Legenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: Colors.grey.shade300, label: 'Indisponível'),
            const SizedBox(width: 16),
            _LegendDot(color: const Color(availableFill), label: 'Disponível'),
          ],
        ),
      ],
    );
  }

  static int _weekdayFromString(String raw) {
    final s = raw.toLowerCase().trim()
        .replaceAll('á', 'a').replaceAll('ã', 'a').replaceAll('â', 'a')
        .replaceAll('é', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ô', 'o')
        .replaceAll('ú', 'u').replaceAll('ç', 'c');
    for (final k in _weekdayMap.keys) {
      if (s.contains(k)) return _weekdayMap[k]!;
    }
    return -1; // desconhecido
  }

  // Converte weekday do Dart (1=Mon..7=Sun) para nosso set (1=Seg..7=Dom)
  static int _weekdayFromDart(int dartWeekday) {
    // Dart: 1=Mon..7=Sun  => queremos 1=Seg..7=Dom (igual)
    return dartWeekday;
  }

  static String _mesPtBr(int m) {
    const nomes = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return nomes[m];
  }
}

class _WeekLabel extends StatelessWidget {
  final String text;
  const _WeekLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
