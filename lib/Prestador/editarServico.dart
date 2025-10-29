import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditarServico extends StatefulWidget {
  final String serviceId;
  final FirebaseFirestore? firestore;

  const EditarServico({super.key, required this.serviceId, this.firestore});

  @override
  State<EditarServico> createState() => EditarServicoState();
}

class EditarServicoState extends State<EditarServico> {
  final _formKey = GlobalKey<FormState>();
  late final FirebaseFirestore _db;

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final valorMinimoController = TextEditingController();
  final valorMedioController = TextEditingController();
  final valorMaximoController = TextEditingController();

  String? unidadeSelecionadaId;
  String? categoriaSelecionadaId;
  bool ativo = true;
  bool carregando = true;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> unidadesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> categoriasStream;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _db = widget.firestore ?? FirebaseFirestore.instance;

    unidadesStream = _db
        .collection('unidades')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();

    categoriasStream = _db
        .collection('categoriasServicos')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();

    carregarServico();
  }

  Future<void> carregarServico() async {
    final doc = await _db.collection('servicos').doc(widget.serviceId).get();

    if (!doc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço não encontrado.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final data = doc.data()!;
    nomeController.text = data['nome'] ?? '';
    descricaoController.text = data['descricao'] ?? '';
    unidadeSelecionadaId = data['unidadeId'];
    categoriaSelecionadaId = data['categoriaId'];

    valorMinimoController.text = _moeda.format(data['valorMinimo'] ?? 0);
    valorMedioController.text = _moeda.format(data['valorMedio'] ?? 0);
    valorMaximoController.text = _moeda.format(data['valorMaximo'] ?? 0);
    ativo = data['ativo'] == true;

    if (mounted) setState(() => carregando = false);
  }

  double parseValor(String valor) {
    final limpo = valor
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(limpo) ?? 0.0;
  }

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (categoriaSelecionadaId == null || categoriaSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a categoria do serviço.')),
      );
      return;
    }

    if (unidadeSelecionadaId == null || unidadeSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a unidade de medida.')),
      );
      return;
    }

    await _db.collection('servicos').doc(widget.serviceId).update({
      'nome': nomeController.text.trim(),
      'descricao': descricaoController.text.trim(),
      'categoriaId': categoriaSelecionadaId,
      'unidadeId': unidadeSelecionadaId,
      'valorMinimo': parseValor(valorMinimoController.text),
      'valorMedio': parseValor(valorMedioController.text),
      'valorMaximo': parseValor(valorMaximoController.text),
      'ativo': ativo,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço atualizado com sucesso!')),
      );
      Navigator.pop(context);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Editar Serviço'),
        backgroundColor: Colors.white,
        elevation: 0.3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Informações Gerais'),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: nomeController,
                      decoration: _inputDecoration('Nome do serviço'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: descricaoController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoration('Descrição do serviço'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: categoriasStream,
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snap.data!.docs;
                        final itens = docs.map((d) {
                          final id = d.id;
                          final nome = (d.data()['nome'] ?? '') as String;
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(nome),
                          );
                        }).toList();

                        return DropdownButtonFormField<String>(
                          value: categoriaSelecionadaId,
                          items: itens,
                          onChanged: (id) =>
                              setState(() => categoriaSelecionadaId = id),
                          decoration: _inputDecoration('Categoria do serviço'),
                          validator: (_) => (categoriaSelecionadaId == null)
                              ? 'Obrigatório'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Unidade de Medida
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: unidadesStream,
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snap.data!.docs;
                        final itens = docs.map((d) {
                          final id = d.id;
                          final nome = (d.data()['nome'] ?? '') as String;
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(nome),
                          );
                        }).toList();

                        return DropdownButtonFormField<String>(
                          value: unidadeSelecionadaId,
                          items: itens,
                          onChanged: (id) =>
                              setState(() => unidadeSelecionadaId = id),
                          decoration: _inputDecoration('Unidade de medida'),
                          validator: (_) => (unidadeSelecionadaId == null)
                              ? 'Obrigatório'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    const _SectionTitle('Valores do Serviço'),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E7FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurple.withOpacity(0.2),
                        ),
                      ),
                      child: const Text(
                        'Atualize os valores mínimos, médios e máximos cobrados '
                        'para que os clientes saibam a faixa de preço estimada do serviço.',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: valorMinimoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Valor por unidade (mínimo)',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: valorMedioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('Valor por unidade (médio)'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: valorMaximoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Valor por unidade (máximo)',
                      ),
                    ),
                    const SizedBox(height: 20),

                    SwitchListTile(
                      title: const Text('Serviço ativo'),
                      activeColor: Colors.deepPurple,
                      value: ativo,
                      onChanged: (v) => setState(() => ativo = v),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: salvar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Salvar alterações'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE9D7FF),
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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
