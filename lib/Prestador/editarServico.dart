import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarServico extends StatefulWidget {
  final String serviceId;
  final FirebaseFirestore? firestore; // ✅ injeção para testes

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

  // Seleções (por ID)
  String? unidadeSelecionadaId;
  String? categoriaSelecionadaId;
  bool ativo = true;

  // Streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> unidadesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> categoriasStream;

  bool carregando = true;

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

  // 🔹 Deixa público para testes
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

  // 🔹 Deixa público para testes
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

    // Revalida se continuam ativas
    final catDoc =
        await _db.collection('categoriasServicos').doc(categoriaSelecionadaId).get();
    if (!catDoc.exists || catDoc.data()?['ativo'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A categoria selecionada não está mais ativa.'),
        ),
      );
      return;
    }

    final uniDoc =
        await _db.collection('unidades').doc(unidadeSelecionadaId).get();
    if (!uniDoc.exists || uniDoc.data()?['ativo'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A unidade selecionada não está mais ativa.'),
        ),
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

  // 🔹 Deixa público para testes
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
                  children: [
                    TextFormField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do serviço'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    TextFormField(
                      controller: descricaoController,
                      decoration: const InputDecoration(labelText: 'Descrição do serviço'),
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
