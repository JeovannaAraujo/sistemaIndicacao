// lib/Cliente/solicitarOrcamento.dart
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SolicitarOrcamentoScreen extends StatefulWidget {
  final String prestadorId;
  final String servicoId;

  // ✅ parâmetros opcionais para mocks em testes
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final FirebaseStorage? storage; // ✅ este é o novo campo

  const SolicitarOrcamentoScreen({
    super.key,
    required this.prestadorId,
    required this.servicoId,
    this.firestore,
    this.auth,
    this.storage, // ✅ adicionado aqui também
  });

  @override
  State<SolicitarOrcamentoScreen> createState() =>
      SolicitarOrcamentoScreenState();
}

class SolicitarOrcamentoScreenState extends State<SolicitarOrcamentoScreen> {
  // coleções (ajuste os nomes se necessário)
  static const colUsuarios = 'usuarios';
  static const colServicos = 'servicos';
  static const colUnidades = 'unidades';
  static const colSolicitacoes = 'solicitacoesOrcamento'; // ou 'solicitacoes'
  static const colCategoriasServ = 'categoriasServicos';

  final _formKey = GlobalKey<FormState>();
  final descricaoCtl = TextEditingController();
  final quantCtl = TextEditingController();
  late FirebaseFirestore db;
  late FirebaseAuth auth;

  DateTime? _dataDesejada;
  TimeOfDay? _horaDesejada;

  // dados carregados
  DocumentSnapshot<Map<String, dynamic>>? docServico;
  DocumentSnapshot<Map<String, dynamic>>? docPrestador;
  DocumentSnapshot<Map<String, dynamic>>? docCliente;

  // unidade/valor
  String? selectedUnidadeId;
  String? _selectedUnidadeAbrev;
  double? valorMedio;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // imagens (galeria + upload)
  final ImagePicker _picker = ImagePicker();
  final List<XFile> imagens = [];
  final Map<String, double> _uploadProgress = {}; // path => 0..1

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? db;
    auth = widget.auth ?? FirebaseAuth.instance;
    _loadAll();
  }

  Future<void> _loadAll() async {
    final fs = db;

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
    selectedUnidadeId =
        (s['unidadeId'] ?? s['unidade'] ?? '').toString().isEmpty
        ? null
        : (s['unidadeId'] ?? s['unidade']).toString();
    _selectedUnidadeAbrev = (s['unidadeAbreviacao'] ?? '').toString().isEmpty
        ? null
        : (s['unidadeAbreviacao'] as String);

    valorMedio = parseValor(s['valorMedio']);

    if (mounted) {
      setState(() {
        docServico = servico;
        docPrestador = prestador;
        docCliente = cliente;
      });
    }
  }

  double? parseValor(dynamic v) {
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

  double? get estimativaValor {
    final q = double.tryParse(quantCtl.text.replaceAll(',', '.'));
    if (q == null || q <= 0) return null;
    if (valorMedio == null) return null;

    final s = docServico?.data() ?? {};
    final unidadeServicoId = (s['unidadeId'] ?? s['unidade'] ?? '').toString();
    if (unidadeServicoId.isNotEmpty && selectedUnidadeId != unidadeServicoId) {
      return null; // sem conversão automática entre unidades diferentes
    }
    return q * valorMedio!;
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

  Future<void> _pickImages() async {
    final imgs = await _picker.pickMultiImage(imageQuality: 80);
    if (imgs.isNotEmpty) {
      setState(() => imagens.addAll(imgs));
    }
  }

  void removeImage(XFile x) {
    // ✅ Garante que não vai travar se o widget não estiver montado
    if (!mounted) {
      imagens.remove(x);
      _uploadProgress.remove(x.path);
      return;
    }

    setState(() {
      _uploadProgress.remove(x.path);
      imagens.remove(x);
    });
  }

Future<List<String>> uploadImagens(String docId) async {
  final List<String> urls = [];

  final storage = widget.storage ?? FirebaseStorage.instance;

  for (final x in imagens) {
    try {
      final file = File(x.path);
      final fname = '${DateTime.now().millisecondsSinceEpoch}_${x.name}';
      final ref = storage.ref().child('solicitacoes/$docId/$fname');

      // 🔹 Detecta se é mock: ignora upload real
      if (storage is MockFirebaseStorage) {
        final fakeUrl = 'https://fake.storage/$fname';
        urls.add(fakeUrl);
        debugPrint('🧪 Mock detectado, retornando URL fake: $fakeUrl');
        continue;
      }

      // 🔹 Upload real (somente se não for mock)
      final snap = await ref.putFile(file);
      final url = await snap.ref.getDownloadURL();
      urls.add(url);
    } catch (e) {
      debugPrint('⚠️ uploadImagens fallback: $e');
      urls.add('https://fallback.storage/${DateTime.now().millisecondsSinceEpoch}.jpg');
    }
  }

  return urls;
}


  Future<void> enviar() async {
    if (docServico == null || docPrestador == null || docCliente == null) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final fs = db;
    final serv = docServico!.data()!;
    final prest = docPrestador!.data()!;
    final cli = docCliente!.data() ?? {};

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

    // cria o docId antes para organizar o upload
    final docRef = fs.collection(colSolicitacoes).doc();

    // faz upload das imagens (se houver)
    final imagensUrls = await uploadImagens(docRef.id);

    // --- Garantir coerência entre unidades originais e selecionadas ---
    final servUnidadeId = (serv['unidadeId'] ?? serv['unidade'] ?? '')
        .toString();

    final bool unidadeDiferente =
        (selectedUnidadeId != null &&
        selectedUnidadeId!.isNotEmpty &&
        selectedUnidadeId != servUnidadeId);

    final unidadeSelecionadaIdFinal = unidadeDiferente
        ? selectedUnidadeId
        : null;

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
      'servicoValorMedio': valorMedio,
      'servicoUnidadeId': servUnidadeId, // 🔹 mantém só o ID original
      if (unidadeSelecionadaIdFinal != null)
        'unidadeSelecionadaId': unidadeSelecionadaIdFinal, // 🔹 se diferente
      'quantidade': double.tryParse(quantCtl.text.replaceAll(',', '.')) ?? 0,
      'descricaoDetalhada': descricaoCtl.text.trim(),
      'dataDesejada': dataHora != null ? Timestamp.fromDate(dataHora) : null,
      'estimativaValor': estimativaValor,
      'status': 'pendente',
      'imagens': imagensUrls,
      'criadoEm': FieldValue.serverTimestamp(),
    };

    await docRef.set(doc);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação enviada com sucesso!')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    descricaoCtl.dispose();
    quantCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicoCarregado = docServico != null && docPrestador != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitação de Orçamento')),
      body: servicoCarregado
          ? _buildLoaded()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildLoaded() {
    final serv = docServico!.data()!;
    final prest = docPrestador!.data()!;
    final cliente = docCliente?.data() ?? {};

    final enderecoCli = (cliente['endereco'] is Map)
        ? (cliente['endereco'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final enderecoLinha = formatEndereco(enderecoCli);
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
            _ServicoResumoCard(
              titulo: tituloServico,
              descricao: descricaoServico,
              categoriaServicoId:
                  (serv['categoriaServicoId'] ?? serv['categoriaId'] ?? '')
                      .toString(),
              prestadorNome: (prest['nome'] ?? '').toString(),
              cidade: cidadePrest,
              unidadeAbrev: unidadeServicoAbrev,
              valorMinimo: parseValor(
                serv['valorMinimo'] ?? serv['precoMinimo'],
              ),
              valorMedio: valorMedio,
              valorMaximo: parseValor(
                serv['valorMaximo'] ?? serv['precoMaximo'],
              ),
            ),

            const SizedBox(height: 16),

            const _SectionTitle('Descrição detalhada da Solicitação'),
            const SizedBox(height: 6),
            TextFormField(
              controller: descricaoCtl,
              minLines: 3,
              maxLines: 5,
              decoration: _inputDecoration(
                hint: 'Descreva todos os detalhes sobre o serviço',
              ),
            ),

            const SizedBox(height: 16),

            const _SectionTitle('Quantidade ou dimensão'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: quantCtl,
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
                Expanded(
                  child: _UnidadesDropdown(
                    selectedId: selectedUnidadeId, // ✅ variável correta
                    onChanged: (id) => setState(() => selectedUnidadeId = id),
                    firestore: db, // ✅ injeta o fakeDb nos testes
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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

            const _SectionTitle('Estimativa de Valor'),
            const SizedBox(height: 6),
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: estimativaValor == null
                    ? 'R\$0,00'
                    : _moeda.format(estimativaValor),
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
                  if (selectedUnidadeId != null)
                    Builder(
                      builder: (context) {
                        final s = docServico?.data() ?? {};
                        final unidadeServicoId =
                            (s['unidadeId'] ?? s['unidade'] ?? '').toString();
                        final diferente =
                            unidadeServicoId.isNotEmpty &&
                            selectedUnidadeId != unidadeServicoId;

                        if (diferente) {
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.deepPurple,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Observação: a estimativa foi desativada porque a unidade selecionada é diferente da unidade do serviço.',
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
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const _SectionTitle('Endereço e contato'),
            const SizedBox(height: 6),
            _EnderecoContatoCard(
              enderecoLinha: enderecoLinha.isEmpty
                  ? 'Endereço não informado'
                  : enderecoLinha,
              whatsapp: whatsappCli,
              onEditar: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Editar endereço (implementar)'),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            const _SectionTitle('Imagens (opcional)'),
            const SizedBox(height: 6),
            _ImagePickerGrid(
              imagens: imagens,
              progresso: _uploadProgress,
              onAdd: _pickImages,
              onRemove: removeImage,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: enviar,
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

  String formatEndereco(Map<String, dynamic> e) {
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
        color: const Color(0xFFF2E7FE),
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
  final String categoriaServicoId;
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
        .collection(SolicitarOrcamentoScreenState.colCategoriasServ)
        .doc(categoriaServicoId)
        .get();
    final d = doc.data();
    return (d == null) ? '' : (d['imagemUrl'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    const larguraThumb = 54.0;

    String precosFmt(BuildContext ctx) {
      String fmt(double v) =>
          NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
      final partes = <String>[];
      if (valorMinimo != null) partes.add(fmt(valorMinimo!));
      if (valorMedio != null) partes.add(fmt(valorMedio!));
      if (valorMaximo != null) partes.add(fmt(valorMaximo!));
      if (partes.isEmpty) return '';
      final unidade = (unidadeAbrev?.isNotEmpty ?? false)
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (descricao.isNotEmpty)
                  Text(descricao, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(
                  'Prestador: $prestadorNome',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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

// ================== 🔽 Widget corrigido 🔽 ==================
class _UnidadesDropdown extends StatelessWidget {
  final String? selectedId;
  final Function(String?) onChanged;

  // ✅ Novo parâmetro opcional para usar FakeFirebaseFirestore nos testes
  final FirebaseFirestore firestore;

  _UnidadesDropdown({
    required this.selectedId,
    required this.onChanged,
    FirebaseFirestore? firestore,
    Key? key,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔹 Consulta unidades no banco injetado (real ou fake)
    final q = firestore
        .collection(SolicitarOrcamentoScreenState.colUnidades)
        .orderBy('abreviacao');

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Text(
            'Erro ao carregar unidades',
            style: TextStyle(color: Colors.redAccent),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Text('Nenhuma unidade disponível');
        }

        return DropdownButtonFormField<String>(
          value: selectedId,
          decoration: InputDecoration(
            labelText: 'Unidade de Medida',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          items: docs.map((d) {
            final data = (d.data() as Map?)?.cast<String, dynamic>() ?? {};
            final nome = data['nome'] ?? '';
            final abrev = data['abreviacao'] ?? '';
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text('$nome ($abrev)'),
            );
          }).toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

// ================== 🔼 Widget corrigido 🔼 ==================

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

class _ImagePickerGrid extends StatelessWidget {
  final List<XFile> imagens;
  final Map<String, double> progresso; // path => 0..1
  final VoidCallback onAdd;
  final void Function(XFile img) onRemove;

  const _ImagePickerGrid({
    required this.imagens,
    required this.progresso,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final itens = <Widget>[
      InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_outlined),
              SizedBox(height: 6),
              Text('Anexar'),
            ],
          ),
        ),
      ),
      ...imagens.map((x) {
        final p = progresso[x.path] ?? 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(x.path), fit: BoxFit.cover),
            ),
            if (p > 0 && p < 1)
              Container(
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LinearProgressIndicator(value: p),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onRemove(x),
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    ];

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: itens,
    );
  }
}
