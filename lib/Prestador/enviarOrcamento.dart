import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EnviarOrcamentoScreen extends StatefulWidget {
  final String solicitacaoId;

  const EnviarOrcamentoScreen({super.key, required this.solicitacaoId});

  @override
  State<EnviarOrcamentoScreen> createState() => _EnviarOrcamentoScreenState();
}

class _EnviarOrcamentoScreenState extends State<EnviarOrcamentoScreen> {
  static const colSolicitacoes = 'solicitacoesOrcamento';

  final _formKey = GlobalKey<FormState>();

  // Controles de formulário
  final _valorPropostoCtl = TextEditingController();
  final _tempoValorCtl = TextEditingController(); // número
  final _observacoesCtl = TextEditingController();
  String _tempoUnidade = 'dia'; // 'dia' | 'hora'
  DateTime? _dataInicio; // data sugerida p/ iniciar
  TimeOfDay? _horaInicio; // hora sugerida p/ iniciar

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  DocumentSnapshot<Map<String, dynamic>>? _docSolic;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
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
    final fs = FirebaseFirestore.instance;
    final doc = await fs
        .collection(colSolicitacoes)
        .doc(widget.solicitacaoId)
        .get();
    if (mounted) setState(() => _docSolic = doc);
  }

  // ---------- helpers ----------
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('pt', 'BR'),
      helpText: 'Data para iniciar execução',
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaInicio ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
      helpText: 'Horário para iniciar execução',
    );
    if (picked != null) setState(() => _horaInicio = picked);
  }

  // ---------- ações ----------
  Future<void> _enviarOrcamento() async {
    if (_docSolic == null) return;
    if (!_formKey.currentState!.validate()) return;

    final valor = _parseMoeda(_valorPropostoCtl.text) ?? 0;
    final tempo =
        double.tryParse(_tempoValorCtl.text.replaceAll(',', '.')) ?? 0;

    DateTime? inicioSugerido;
    if (_dataInicio != null) {
      final h = _horaInicio?.hour ?? 0;
      final m = _horaInicio?.minute ?? 0;
      inicioSugerido = DateTime(
        _dataInicio!.year,
        _dataInicio!.month,
        _dataInicio!.day,
        h,
        m,
      );
    }

    setState(() => _enviando = true);
    try {
      final fs = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prestadorUid = uid!;

      // 1) Define início (usa a sugerida; se nula, usa agora alinhado)
      final inicio = inicioSugerido ?? DateTime.now();

      // 2) Carrega jornada do prestador
      final jornada = await _fetchJornadaPrestador(prestadorUid);

      // 3) Calcula data final
      late DateTime fimPrevisto;
      if (_tempoUnidade == 'hora') {
        fimPrevisto = _addWorkingHours(inicio, tempo, jornada);
      } else {
        // 'dia'
        fimPrevisto = _addWorkingDays(inicio, tempo, jornada);
      }

      await fs.collection(colSolicitacoes).doc(widget.solicitacaoId).update({
        'status': 'respondida',
        'respondidaEm': FieldValue.serverTimestamp(),
        'respondidaPor': uid,
        'valorProposto': valor,
        'tempoEstimadoValor': tempo,
        'tempoEstimadoUnidade': _tempoUnidade,
        'dataInicioSugerida': inicioSugerido != null
            ? Timestamp.fromDate(inicioSugerido)
            : null,

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

      // Quando criar a rota da tela do cliente, use:
      // Navigator.of(context).pushNamed('/cliente/solicitacoesRespondidas');
      Navigator.of(context).pop(); // por enquanto, volta
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao enviar: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recusarSolicitacao() async {
    if (_docSolic == null) return;

    final motivoCtl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar solicitação'),
        content: TextField(
          controller: motivoCtl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Opcional: informe o motivo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _enviando = true);
    try {
      final fs = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await fs.collection(colSolicitacoes).doc(widget.solicitacaoId).update({
        'status': 'recusada',
        'recusadaEm': FieldValue.serverTimestamp(),
        'recusadaPor': uid,
        'recusaMotivo': motivoCtl.text.trim(),
        'historico': FieldValue.arrayUnion([
          {
            'tipo': 'recusada',
            'quando': FieldValue.serverTimestamp(),
            'por': uid,
            'motivo': motivoCtl.text.trim(),
          },
        ]),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitação recusada.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao recusar: $e')));
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

  Widget _buildForm() {
    final d = _docSolic!.data()!;
    final titulo = (d['servicoTitulo'] ?? '').toString();
    final quantidade = (d['quantidade'] ?? 0).toString();
    final unidadeAbrev =
        (d['unidadeSelecionadaAbrev'] ?? d['servicoUnidadeAbrev'] ?? '')
            .toString();
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
            // Bloco: Estimativa (somente leitura)
            _EstimativaCard(
              valor: estimativaValor,
              unidade: unidadeAbrev.isEmpty ? 'unidade' : unidadeAbrev,
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Dados da solicitação do cliente'),
            const SizedBox(height: 8),
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
              hint:
                  'Caso indisponível no horário desejado pelo cliente, favor colocar uma'
                  ' data alternativa ao enviar sua proposta.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ReadOnlyField(
                    label: 'Quantidade ou dimensão',
                    value: quantidade,
                  ),
                ),
                const SizedBox(width: 16),
                _UnitChip(text: unidadeAbrev.isEmpty ? 'm²' : unidadeAbrev),
              ],
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Valor Proposto'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _valorPropostoCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration(hint: 'R\$ 0,00'),
              validator: (v) {
                final x = _parseMoeda(v ?? '');
                if (x == null || x <= 0) return 'Informe um valor válido';
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
            const _SectionTitle('Data para iniciar execução'),
            const SizedBox(height: 6),
            TextFormField(
              readOnly: true,
              onTap: _pickDate,
              controller: TextEditingController(
                text: _dataInicio == null
                    ? ''
                    : DateFormat('dd/MM/yyyy').format(_dataInicio!),
              ),
              decoration: _inputDecoration(
                hint: 'dd/mm/aaaa',
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 4),
            const _HelperText(
              'Caso indisponível na data desejada pelo cliente, favor colocar uma data alternativa.',
            ),

            const SizedBox(height: 16),
            const _SectionTitle('Horário para iniciar execução'),
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
            const SizedBox(height: 4),
            const _HelperText(
              'Caso indisponível no horário desejado pelo cliente, favor colocar um horário alternativo.',
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

            const SizedBox(height: 22),
            // Botões (gradiente + ação secundária)
            _PrimaryGradientButton(
              text: 'Enviar Orçamento',
              onPressed: _enviando ? null : _enviarOrcamento,
              loading: _enviando,
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _enviando ? null : _recusarSolicitacao,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEDE7F6), // lilás claro
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Recusar Solicitação'),
              ),
            ),
            const SizedBox(height: 8),

            Center(
              child: TextButton(
                onPressed: _enviando ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: const StadiumBorder(), // pílula suave
                ),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Representa a jornada de trabalho do prestador.
class _Jornada {
  final Set<int> dias; // DateTime.monday..DateTime.sunday
  final int inicioMin; // minutos a partir de 00:00 (ex.: 8*60=480)
  final int fimMin; // idem
  int get cargaMinDia => (fimMin - inicioMin).clamp(0, 24 * 60);

  const _Jornada({
    required this.dias,
    required this.inicioMin,
    required this.fimMin,
  });

  factory _Jornada.padrao() => const _Jornada(
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
Future<_Jornada> _fetchJornadaPrestador(String prestadorUid) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(prestadorUid)
        .get();
    if (!snap.exists) return _Jornada.padrao();
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

    if (dias.isEmpty) dias = _Jornada.padrao().dias;

    final inicioMin = iniStr != null
        ? _hhmmToMin(iniStr)
        : _Jornada.padrao().inicioMin;
    final fimMin = fimStr != null
        ? _hhmmToMin(fimStr)
        : _Jornada.padrao().fimMin;
    return _Jornada(dias: dias, inicioMin: inicioMin, fimMin: fimMin);
  } catch (_) {
    return _Jornada.padrao();
  }
}

bool _isWorkingDay(DateTime d, _Jornada j) => j.dias.contains(d.weekday);

DateTime _nextWorkingDayStart(DateTime date, _Jornada j) {
  var d = DateTime(date.year, date.month, date.day);
  while (!_isWorkingDay(d, j)) {
    d = d.add(const Duration(days: 1));
  }
  return _withMinutesOfDay(d, j.inicioMin);
}

/// Alinha para um instante válido dentro da jornada.
/// - Se for fim de semana / dia não trabalhado → próximo dia útil no horário de início
/// - Se antes do início → início do mesmo dia
/// - Se depois do fim → início do próximo dia útil
DateTime _alignToJornadaStart(DateTime dt, _Jornada j) {
  if (!_isWorkingDay(dt, j)) return _nextWorkingDayStart(dt, j);
  final mod = _minutesOfDay(dt);
  if (mod < j.inicioMin) return _withMinutesOfDay(dt, j.inicioMin);
  if (mod >= j.fimMin) {
    return _nextWorkingDayStart(dt.add(const Duration(days: 1)), j);
  }
  return dt;
}

/// Soma horas úteis respeitando a jornada (pula dias não trabalhados)
DateTime _addWorkingHours(DateTime start, double hours, _Jornada j) {
  var cur = _alignToJornadaStart(start, j);
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
DateTime _addWorkingDays(DateTime start, double dias, _Jornada j) {
  // Se for inteiro, contamos "N dias" como mover N dias úteis e terminar no fim do expediente
  final inteiro = dias.floor();
  final resto = dias - inteiro;

  var d = _alignToJornadaStart(start, j);

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
  return _addWorkingHours(d, horasFracao, j);
}

// --------- Widgets auxiliares de UI ---------

class _HeaderGradient extends StatelessWidget {
  final String title;
  const _HeaderGradient({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _EstimativaCard extends StatelessWidget {
  final String valor;
  final String unidade;
  const _EstimativaCard({required this.valor, required this.unidade});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E7FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
      ),
      child: Column(
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
  final String? hint;
  final Widget? suffixIcon;
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.hint,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        if (hint != null) ...[const SizedBox(height: 4), _HelperText(hint!)],
      ],
    );
  }
}

class _HelperText extends StatelessWidget {
  final String text;
  const _HelperText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.black54),
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
