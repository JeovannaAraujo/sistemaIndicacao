// lib/Cliente/solicitarOrcamento.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class SolicitarOrcamentoScreen extends StatefulWidget {
  final String prestadorId;
  final String servicoId;

  const SolicitarOrcamentoScreen({
    super.key,
    required this.prestadorId,
    required this.servicoId,
  });

  @override
  State<SolicitarOrcamentoScreen> createState() =>
      _SolicitarOrcamentoScreenState();
}

class _SolicitarOrcamentoScreenState extends State<SolicitarOrcamentoScreen> {
  // coleções (ajuste se seus nomes diferirem)
  static const colUsuarios = 'usuarios';
  static const colServicos = 'servicos';
  static const colUnidades = 'unidades';
  static const colSolicitacoes = 'solicitacoesOrcamento';
  static const colCategoriasServ = 'categoriasServicos';

  final _formKey = GlobalKey<FormState>();
  final _descricaoCtl = TextEditingController();
  final _quantCtl = TextEditingController(text: '0');

  DateTime? _dataDesejada;
  TimeOfDay? _horaDesejada;

  // dados carregados
  DocumentSnapshot<Map<String, dynamic>>? _docServico;
  DocumentSnapshot<Map<String, dynamic>>? _docPrestador;
  DocumentSnapshot<Map<String, dynamic>>? _docCliente;

  // unidade
  String? _selectedUnidadeId;
  String? _selectedUnidadeAbrev; // rótulo
  double? _valorMedio; // do serviço

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final fs = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    final servico = await fs
        .collection(colServicos)
        .doc(widget.servicoId)
        .get();
    final prestador = await fs
        .collection(colUsuarios)
        .doc(widget.prestadorId)
        .get();
    final cliente = await fs
        .collection(colUsuarios)
        .doc(auth.currentUser!.uid)
        .get();

    final s = servico.data() ?? {};
    // preselect unidade do serviço
    _selectedUnidadeId =
        (s['unidadeId'] ?? s['unidade'] ?? '').toString().isEmpty
        ? null
        : (s['unidadeId'] ?? s['unidade']).toString();
    _selectedUnidadeAbrev = (s['unidadeAbreviacao'] ?? '').toString().isEmpty
        ? null
        : (s['unidadeAbreviacao'] as String);
    // valor médio do serviço (double ou string)
    _valorMedio = _parseValor(s['valorMedio']);

    setState(() {
      _docServico = servico;
      _docPrestador = prestador;
      _docCliente = cliente;
    });
  }

  double? _parseValor(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v
          .replaceAll('R\$', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return double.tryParse(cleaned);
    }
    return null;
  }

  double? get _estimativaValor {
    final q = double.tryParse(_quantCtl.text.replaceAll(',', '.'));
    if (q == null || q <= 0) return null;
    if (_valorMedio == null) return null;

    // só calcula se a unidade selecionada for a mesma unidade do serviço (quando soubermos)
    final s = _docServico?.data() ?? {};
    final unidadeServicoId = (s['unidadeId'] ?? s['unidade'] ?? '').toString();
    if (unidadeServicoId.isNotEmpty && _selectedUnidadeId != unidadeServicoId) {
      return null; // sem conversão automática entre unidades
    }
    return q * _valorMedio!;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataDesejada ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2),
      helpText: 'Data desejada para início',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _dataDesejada = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaDesejada ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Horário desejado',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _horaDesejada = picked);
  }

  Future<void> _enviar() async {
    if (_docServico == null || _docPrestador == null || _docCliente == null) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final auth = FirebaseAuth.instance;
    final serv = _docServico!.data()!;
    final prest = _docPrestador!.data()!;
    final cli = _docCliente!.data() ?? {};

    // compõe data-hora (pode ser só data)
    DateTime? dataHora;
    if (_dataDesejada != null) {
      final h = _horaDesejada?.hour ?? 0;
      final m = _horaDesejada?.minute ?? 0;
      dataHora = DateTime(
        _dataDesejada!.year,
        _dataDesejada!.month,
        _dataDesejada!.day,
        h,
        m,
      );
    }

    final endereco = (cli['endereco'] is Map)
        ? (cli['endereco'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final whatsappCli = (endereco['whatsapp'] ?? cli['whatsapp'] ?? '')
        .toString();

    final doc = <String, dynamic>{
      'clienteId': auth.currentUser!.uid,
      'clienteNome': (cli['nome'] ?? '').toString(),
      'clienteWhatsapp': whatsappCli,
      'clienteEndereco': {
        'rua': endereco['rua'] ?? '',
        'numero': endereco['numero'] ?? '',
        'complemento': endereco['complemento'] ?? '',
        'bairro': endereco['bairro'] ?? '',
        'cep': endereco['cep'] ?? '',
        'cidade': endereco['cidade'] ?? '',
      },

      'prestadorId': widget.prestadorId,
      'prestadorNome': (prest['nome'] ?? '').toString(),

      'servicoId': widget.servicoId,
      'servicoTitulo': (serv['titulo'] ?? serv['nome'] ?? '').toString(),
      'servicoDescricao': (serv['descricao'] ?? '').toString(),
      'servicoValorMedio': _valorMedio,
      'servicoUnidadeId': (serv['unidadeId'] ?? serv['unidade'] ?? '')
          .toString(),
      'servicoUnidadeAbrev': (serv['unidadeAbreviacao'] ?? '').toString(),

      'quantidade': double.tryParse(_quantCtl.text.replaceAll(',', '.')) ?? 0,
      'unidadeSelecionadaId': _selectedUnidadeId ?? '',
      'unidadeSelecionadaAbrev': _selectedUnidadeAbrev ?? '',

      'descricaoDetalhada': _descricaoCtl.text.trim(),
      'dataDesejada': dataHora != null ? Timestamp.fromDate(dataHora) : null,
      'estimativaValor': _estimativaValor,

      'status': 'pendente',
      'criadoEm': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection(colSolicitacoes).add(doc);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação enviada com sucesso!')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _descricaoCtl.dispose();
    _quantCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicoCarregado = _docServico != null && _docPrestador != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitação de Orçamento')),
      body: servicoCarregado
          ? _buildLoaded()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildLoaded() {
    final serv = _docServico!.data()!;
    final prest = _docPrestador!.data()!;
    final cliente = _docCliente?.data() ?? {};

    final enderecoCli = (cliente['endereco'] is Map)
        ? (cliente['endereco'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final enderecoLinha = _formatEndereco(enderecoCli);
    final whatsappCli = (enderecoCli['whatsapp'] ?? cliente['whatsapp'] ?? '')
        .toString();

    final tituloServico = (serv['titulo'] ?? serv['nome'] ?? '').toString();
    final descricaoServico = (serv['descricao'] ?? '').toString();
    final unidadeServicoAbrev = (_selectedUnidadeAbrev ?? '').toString();
    final cidadePrest = (() {
      final end = (prest['endereco'] is Map)
          ? (prest['endereco'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      return (end['cidade'] ?? prest['cidade'] ?? '').toString();
    })();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD INFORMAÇÕES DO SERVIÇO
            _ServicoResumoCard(
              titulo: tituloServico,
              descricao: descricaoServico,
              categoriaServicoId:
                  (serv['categoriaServicoId'] ?? serv['categoriaId'] ?? '')
                      .toString(),
              prestadorNome: (prest['nome'] ?? '').toString(),
              cidade: cidadePrest,
              unidadeAbrev: unidadeServicoAbrev,
              valorMinimo: _parseValor(
                serv['valorMinimo'] ?? serv['precoMinimo'],
              ),
              valorMedio: _valorMedio,
              valorMaximo: _parseValor(
                serv['valorMaximo'] ?? serv['precoMaximo'],
              ),
            ),

            const SizedBox(height: 16),

            // DESCRIÇÃO DETALHADA
            const _SectionTitle('Descrição detalhada da Solicitação'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descricaoCtl,
              minLines: 3,
              maxLines: 5,
              decoration: _inputDecoration(
                hint: 'Descreva todos os detalhes sobre o serviço',
              ),
            ),

            const SizedBox(height: 16),

            // QUANTIDADE + UNIDADE (abreviação do banco)
            const _SectionTitle('Quantidade ou dimensão'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration(hint: '0'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final q = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (q == null || q <= 0) return 'Informe a quantidade';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown de abreviações da coleção "unidades"
                _UnidadesDropdown(
                  selectedId: _selectedUnidadeId,
                  onChanged: (id, abrev) {
                    setState(() {
                      _selectedUnidadeId = id;
                      _selectedUnidadeAbrev = abrev;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // DATA e HORA
            const _SectionTitle('Data desejada para início'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: _pickDate,
                    controller: TextEditingController(
                      text: _dataDesejada == null
                          ? ''
                          : DateFormat('dd/MM/yyyy').format(_dataDesejada!),
                    ),
                    decoration: _inputDecoration(
                      hint: 'dd/mm/aaaa',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: _pickTime,
                    controller: TextEditingController(
                      text: _horaDesejada == null
                          ? ''
                          : '${_horaDesejada!.hour.toString().padLeft(2, '0')}:${_horaDesejada!.minute.toString().padLeft(2, '0')}',
                    ),
                    decoration: _inputDecoration(
                      hint: '00:00',
                      suffixIcon: const Icon(Icons.access_time_outlined),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ESTIMATIVA (somente leitura)
            const _SectionTitle('Estimativa de Valor'),
            const SizedBox(height: 6),
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: _estimativaValor == null
                    ? 'R\$0,00'
                    : _moeda.format(_estimativaValor),
              ),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 6),
            _HintBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Este valor é calculado automaticamente com base na quantidade informada e na média de preço do serviço.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fórmula: Quantidade × Valor Médio por ${_selectedUnidadeAbrev ?? 'unidade'}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Este campo é apenas informativo e não pode ser editado manualmente.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (_estimativaValor == null && (_selectedUnidadeId != null))
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Observação: estimativa desativada porque a unidade selecionada é diferente da unidade do serviço.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ENDEREÇO E CONTATO (CARD)
            const _SectionTitle('Endereço e contato'),
            const SizedBox(height: 6),
            _EnderecoContatoCard(
              enderecoLinha: enderecoLinha.isEmpty
                  ? 'Endereço não informado'
                  : enderecoLinha,
              whatsapp: whatsappCli,
              onEditar: () {
                // TODO: abrir tela de edição do endereço do cliente
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Editar endereço (implementar)'),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // IMAGENS (OPCIONAL)
            const _SectionTitle('Imagens (opcional)'),
            const SizedBox(height: 6),
            _UploadPlaceholder(),

            const SizedBox(height: 20),

            // AÇÕES
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Enviar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatEndereco(Map<String, dynamic> e) {
    final partes = <String>[];
    void add(String? s) {
      if (s != null && s.toString().trim().isNotEmpty) {
        partes.add(s.toString().trim());
      }
    }

    final rua = e['rua'];
    final numero = e['numero'];
    final comp = e['complemento'];
    final bairro = e['bairro'];
    final cep = e['cep'];
    final cidade = e['cidade'];

    if ((rua ?? '').toString().isNotEmpty) {
      var ln = rua.toString();
      if ((numero ?? '').toString().isNotEmpty) {
        ln += ', Nº ${numero.toString()}';
      }
      if ((comp ?? '').toString().isNotEmpty) ln += ', ${comp.toString()}';
      add(ln);
    }
    add(bairro);
    if ((cep ?? '').toString().isNotEmpty) add('CEP ${cep.toString()}');
    add(cidade);
    return partes.join('. ');
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
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
}

// ---------- widgets auxiliares ----------

class _HintBox extends StatelessWidget {
  final Widget child;
  const _HintBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E7FE), // roxinho bem claro
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    );
  }
}

class _ServicoResumoCard extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String categoriaServicoId; // sempre buscar imagem aqui
  final String prestadorNome;
  final String cidade;
  final String? unidadeAbrev;
  final double? valorMinimo;
  final double? valorMedio;
  final double? valorMaximo;

  const _ServicoResumoCard({
    required this.titulo,
    required this.descricao,
    required this.categoriaServicoId,
    required this.prestadorNome,
    required this.cidade,
    this.unidadeAbrev,
    this.valorMinimo,
    this.valorMedio,
    this.valorMaximo,
  });

  Future<String> _imagemCategoria() async {
    if (categoriaServicoId.isEmpty) return '';
    final doc = await FirebaseFirestore.instance
        .collection(_SolicitarOrcamentoScreenState.colCategoriasServ)
        .doc(categoriaServicoId)
        .get();
    final d = doc.data();
    return (d == null) ? '' : (d['imagemUrl'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final larguraThumb = 54.0;

    String precosFmt(BuildContext ctx) {
      String fmt(double v) =>
          NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
      final partes = <String>[];
      if (valorMinimo != null) partes.add(fmt(valorMinimo!));
      if (valorMedio != null) partes.add(fmt(valorMedio!));
      if (valorMaximo != null) partes.add(fmt(valorMaximo!));
      if (partes.isEmpty) return '';
      final unidade = unidadeAbrev?.isNotEmpty == true
          ? ' por ${unidadeAbrev!}'
          : '';
      return '${partes.join(' – ')}$unidade';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE7F6), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // THUMB da categoria de serviço
          FutureBuilder<String>(
            future: _imagemCategoria(),
            builder: (context, snap) {
              final url = snap.data ?? '';
              return Container(
                width: larguraThumb,
                height: larguraThumb,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                  image: (url.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Conteúdo textual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // título
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // descrição curta
                if (descricao.isNotEmpty)
                  Text(descricao, maxLines: 2, overflow: TextOverflow.ellipsis),

                const SizedBox(height: 6),
                // Prestador (linha separada)
                Text(
                  'Prestador: $prestadorNome',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Cidade (linha de baixo)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        cidade,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Preços (mín – méd – máx) logo abaixo
                Builder(
                  builder: (ctx) {
                    final precoStr = precosFmt(ctx);
                    if (precoStr.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        precoStr,
                        style: const TextStyle(color: Colors.deepPurple),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnidadesDropdown extends StatelessWidget {
  final String? selectedId;
  final void Function(String id, String abrev) onChanged;

  const _UnidadesDropdown({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection(_SolicitarOrcamentoScreenState.colUnidades)
        .orderBy('abreviacao');

    return SizedBox(
      width: 92, // fica certinho na linha
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return DropdownButtonFormField<String>(
              items: const [],
              onChanged: null,
              decoration: InputDecoration(
                hintText: 'un.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            );
          }

          final docs = snap.data!.docs;
          final items = docs.map((d) {
            final m = d.data();
            final abrev = (m['abreviacao'] ?? m['sigla'] ?? '').toString();
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(abrev.isEmpty ? d.id : abrev),
            );
          }).toList();

          final hasSelected =
              selectedId != null && items.any((it) => it.value == selectedId);

          return DropdownButtonFormField<String>(
            isDense: true,
            initialValue: hasSelected ? selectedId : null,
            items: items,
            onChanged: (v) {
              if (v == null) return;
              final d = docs.firstWhere(
                (e) => e.id == v,
              ); // docs não está vazio
              final m = d.data();
              final abrev = (m['abreviacao'] ?? m['sigla'] ?? '').toString();
              onChanged(v, abrev);
            },
            decoration: InputDecoration(
              hintText: 'un.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EnderecoContatoCard extends StatelessWidget {
  final String enderecoLinha;
  final String whatsapp;
  final VoidCallback onEditar;

  const _EnderecoContatoCard({
    required this.enderecoLinha,
    required this.whatsapp,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.home_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(enderecoLinha),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        size: 16,
                        color: Color(0xFF25D366),
                      ),
                      const SizedBox(width: 6),
                      Text(whatsapp.isEmpty ? 'Sem WhatsApp' : whatsapp),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onEditar,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Editar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.photo_camera_outlined),
          SizedBox(height: 6),
          Text('Foto'),
        ],
      ),
    );
  }
}
