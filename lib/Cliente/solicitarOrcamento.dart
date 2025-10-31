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
import 'package:myapp/Cliente/editarEnderecoContato.dart';
import 'package:table_calendar/table_calendar.dart';

class SolicitarOrcamentoScreen extends StatefulWidget {
  final String prestadorId;
  final String servicoId;

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final FirebaseStorage? storage;

  const SolicitarOrcamentoScreen({
    super.key,
    required this.prestadorId,
    required this.servicoId,
    this.firestore,
    this.auth,
    this.storage,
  });

  @override
  State<SolicitarOrcamentoScreen> createState() =>
      SolicitarOrcamentoScreenState();
}

class SolicitarOrcamentoScreenState extends State<SolicitarOrcamentoScreen> {
  static const colUsuarios = 'usuarios';
  static const colServicos = 'servicos';
  static const colUnidades = 'unidades';
  static const colSolicitacoes = 'solicitacoesOrcamento';
  static const colCategoriasServ = 'categoriasServicos';

  final _formKey = GlobalKey<FormState>();
  final descricaoCtl = TextEditingController();
  final quantCtl = TextEditingController();
  late FirebaseFirestore db;
  late FirebaseAuth auth;

  DateTime? _dataDesejada;
  TimeOfDay? _horaDesejada;

  DocumentSnapshot<Map<String, dynamic>>? docServico;
  DocumentSnapshot<Map<String, dynamic>>? docPrestador;
  DocumentSnapshot<Map<String, dynamic>>? docCliente;

  String? selectedUnidadeId;
  String? _selectedUnidadeAbrev;
  double? valorMedio;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final ImagePicker _picker = ImagePicker();
  final List<XFile> imagens = [];
  final Map<String, double> _uploadProgress = {};

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
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
      return null;
    }
    return q * valorMedio!;
  }

  Future<void> _selecionarDataDisponivel() async {
    final dataSelecionada = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarioSelecaoData(
        prestadorId: widget.prestadorId,
        prestadorNome: docPrestador?.data()?['nome'] ?? '',
      ),
    );

    if (dataSelecionada != null && mounted) {
      setState(() {
        _dataDesejada = dataSelecionada;

        // 🔥 Se selecionou hoje, reseta a hora para evitar conflito
        final hoje = DateTime.now();
        if (_dataDesejada!.day == hoje.day &&
            _dataDesejada!.month == hoje.month &&
            _dataDesejada!.year == hoje.year) {
          _horaDesejada =
              null; // Reseta a hora para o usuário escolher novamente
        }
      });
    }
  }

  void removeImage(XFile x) {
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

        if (storage is MockFirebaseStorage) {
          final fakeUrl = 'https://fake.storage/$fname';
          urls.add(fakeUrl);
          continue;
        }

        final snap = await ref.putFile(file);
        final url = await snap.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('⚠️ uploadImagens fallback: $e');
        urls.add(
          'https://fallback.storage/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
    }

    return urls;
  }

  Future<void> enviar() async {
    if (_enviando) return;

    if (docServico == null || docPrestador == null || docCliente == null) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // 🔥 VALIDAÇÃO MELHORADA: Data/hora não pode ser no passado
    if (_dataDesejada != null) {
      final now = DateTime.now();
      final dataHoraSelecionada = DateTime(
        _dataDesejada!.year,
        _dataDesejada!.month,
        _dataDesejada!.day,
        _horaDesejada?.hour ?? 0,
        _horaDesejada?.minute ?? 0,
      );

      // 🔹 Verifica se a data/hora selecionada já passou
      if (dataHoraSelecionada.isBefore(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não é possível selecionar uma data/hora que já passou.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _enviando = true);

    try {
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

      final docRef = fs.collection(colSolicitacoes).doc();

      final imagensUrls = await uploadImagens(docRef.id);

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
        'servicoUnidadeId': servUnidadeId,
        if (unidadeSelecionadaIdFinal != null)
          'unidadeSelecionadaId': unidadeSelecionadaIdFinal,
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
        const SnackBar(
          content: Text('Solicitação enviada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initialTime =
        _dataDesejada != null &&
            _dataDesejada!.day == now.day &&
            _dataDesejada!.month == now.month &&
            _dataDesejada!.year == now.year
        ? TimeOfDay.fromDateTime(now) // Se for hoje, começa da hora atual
        : TimeOfDay.now();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null && mounted) {
      // 🔥 VALIDAÇÃO: Se for hoje, não permite hora passada
      if (_dataDesejada != null) {
        final hoje = DateTime.now();
        final isHoje =
            _dataDesejada!.day == hoje.day &&
            _dataDesejada!.month == hoje.month &&
            _dataDesejada!.year == hoje.year;

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
        _horaDesejada = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> novas = await _picker.pickMultiImage();

    if (novas.isNotEmpty && mounted) {
      setState(() {
        imagens.addAll(novas);
      });
    }
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

    return Stack(
      children: [
        Form(
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
                          final q = double.tryParse(
                            (v ?? '').replaceAll(',', '.'),
                          );
                          if (q == null || q <= 0)
                            return 'Informe a quantidade';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _UnidadesDropdown(
                        selectedId: selectedUnidadeId,
                        onChanged: (id) =>
                            setState(() => selectedUnidadeId = id),
                        firestore: db,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const _SectionTitle('Data e hora desejada para início'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selecionarDataDisponivel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _dataDesejada == null
                                  ? 'Selecionar Data'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_dataDesejada!),
                            ),
                          ],
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
                const SizedBox(height: 6),
                _HintBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clique em "Selecionar Data" para ver a agenda do prestador e escolher uma data disponível. Horários do passado não podem ser selecionados.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dataDesejada == null
                            ? 'Nenhuma data selecionada'
                            : 'Data selecionada: ${DateFormat('dd/MM/yyyy').format(_dataDesejada!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _dataDesejada == null
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
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
                                (s['unidadeId'] ?? s['unidade'] ?? '')
                                    .toString();
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditarEnderecoContatoScreen(
                          userId: auth.currentUser!.uid,
                          firestore: db,
                          auth: auth,
                        ),
                      ),
                    ).then((_) {
                      // Recarregar os dados do endereço após editar
                      if (mounted) {
                        _loadAll(); // Isso vai recarregar todos os dados incluindo o endereço
                      }
                    });
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
                        onPressed: _enviando ? null : enviar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _enviando
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Enviando...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              )
                            : const Text(
                                'Enviar',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _enviando
                            ? null
                            : () => Navigator.pop(context),
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
        ),

        if (_enviando)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
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

class _UnidadesDropdown extends StatelessWidget {
  final String? selectedId;
  final Function(String?) onChanged;
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
            final abrev = data['abreviacao'] ?? '';
            return DropdownMenuItem<String>(value: d.id, child: Text('$abrev'));
          }).toList(),
          onChanged: onChanged,
        );
      },
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

  // 🔥 ADICIONE ESTA FUNÇÃO DE MÁSCARA
  String _aplicarMascaraWhatsApp(String value) {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.length <= 2) {
      return value;
    } else if (value.length <= 7) {
      return '(${value.substring(0, 2)}) ${value.substring(2)}';
    } else {
      return '(${value.substring(0, 2)}) ${value.substring(2, 7)}-${value.substring(7)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 APLIQUE A MÁSCARA AO EXIBIR
    final whatsappFormatado = whatsapp.isEmpty 
        ? 'Sem WhatsApp' 
        : _aplicarMascaraWhatsApp(whatsapp);

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
                      Text(whatsappFormatado), // 🔥 AGORA COM MÁSCARA
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
  final Map<String, double> progresso;
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

// ================== CALENDÁRIO DE SELEÇÃO DE DATA CORRIGIDO ==================

// ================== CALENDÁRIO DE SELEÇÃO DE DATA CORRIGIDO ==================

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

  // 🔥 CORREÇÃO: Busca data real de finalização
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

  bool isFinalStatus(String? s) {
    final txt = (s ?? '').toLowerCase().trim();
    return txt.startsWith('finaliz') || txt.startsWith('avalia');
  }

  // 🔥 CORREÇÃO: Marca dias ocupados considerando todos os status
  void markBusyFromDoc(Map<String, dynamic> data) {
    final tsInicio = data['dataInicioSugerida'];
    if (tsInicio is! Timestamp) return;
    final start = toYMD(tsInicio);

    final status = (data['status'] ?? '').toString().toLowerCase();
    final realEnd = getFinalizacaoReal(data);

    // 🔹 Para serviços finalizados/avaliados, usa período real se existir
    if (isFinalStatus(status) && realEnd != null) {
      var d = start;
      while (!d.isAfter(realEnd)) {
        if (isWorkday(d)) busyDays.add(d);
        d = d.add(const Duration(days: 1));
      }
      return;
    }

    // 🔹 Para outros status, usa a previsão
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
    // 🔥 CORREÇÃO: Busca TODOS os status relevantes
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
                'Agenda do prestador ${widget.prestadorNome}',
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
                  // 🔥 CORREÇÃO: Processa todos os documentos
                  for (final doc in snap.data!.docs) {
                    markBusyFromDoc(doc.data());
                  }
                }

                return _calendarCard();
              },
            ),

            // ===== Legenda =====
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

// ignore: unused_element
class _LegendaCor extends StatelessWidget {
  final Color cor;
  final String texto;
  const _LegendaCor({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
