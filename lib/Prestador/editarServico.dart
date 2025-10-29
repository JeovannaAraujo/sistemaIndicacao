import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarServico extends StatefulWidget {
  final String serviceId;
  final FirebaseFirestore? firestore;

  const EditarServico({
    super.key,
    required this.serviceId,
    this.firestore,
  });

  @override
  State<EditarServico> createState() => EditarServicoState();
}

class EditarServicoState extends State<EditarServico> {
  final _formKey = GlobalKey<FormState>();
  late final FirebaseFirestore _db;

  // Controllers
  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final valorMinimoController = TextEditingController();
  final valorMedioController = TextEditingController();
  final valorMaximoController = TextEditingController();

  // Seleções
  String? unidadeSelecionadaId;
  String? categoriaSelecionadaId;
  bool ativo = true;

  bool carregando = true;

  // Streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> unidadesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> categoriasStream;

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
    valorMinimoController.text = (data['valorMinimo'] ?? 0).toString();
    valorMedioController.text = (data['valorMedio'] ?? 0).toString();
    valorMaximoController.text = (data['valorMaximo'] ?? 0).toString();
    ativo = data['ativo'] == true;

    if (mounted) setState(() => carregando = false);
  }

  double parseNum(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

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
      'valorMinimo': parseNum(valorMinimoController.text),
      'valorMedio': parseNum(valorMedioController.text),
      'valorMaximo': parseNum(valorMaximoController.text),
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

  Future<void> excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir serviço'),
        content: const Text('Tem certeza que deseja excluir este serviço?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _db.collection('servicos').doc(widget.serviceId).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço excluído com sucesso!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar serviço'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: 'Excluir serviço',
            icon: const Icon(Icons.delete_outline),
            onPressed: excluir,
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nome
                    TextFormField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do serviço',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),

                    // Descrição
                    TextFormField(
                      controller: descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição do serviço',
                      ),
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: categoriasStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final docs = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: categoriaSelecionadaId,
                          decoration:
                              const InputDecoration(labelText: 'Categoria'),
                          items: docs.map((doc) {
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(doc['nome']),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => categoriaSelecionadaId = v),
                          validator: (v) =>
                              v == null ? 'Selecione uma categoria' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Unidade de medida
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: unidadesStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final docs = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: unidadeSelecionadaId,
                          decoration:
                              const InputDecoration(labelText: 'Unidade de medida'),
                          items: docs.map((doc) {
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(doc['nome']),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => unidadeSelecionadaId = v),
                          validator: (v) =>
                              v == null ? 'Selecione uma unidade' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Valores
                    TextFormField(
                      controller: valorMinimoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valor mínimo (R\$)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: valorMedioController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valor médio (R\$)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: valorMaximoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valor máximo (R\$)'),
                    ),
                    const SizedBox(height: 16),

                    // Switch de ativo
                    SwitchListTile(
                      title: const Text('Serviço ativo'),
                      value: ativo,
                      activeColor: Colors.deepPurple,
                      onChanged: (v) => setState(() => ativo = v),
                    ),
                    const SizedBox(height: 24),

                    // Botões
                    ElevatedButton(
                      onPressed: salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Salvar alterações'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
