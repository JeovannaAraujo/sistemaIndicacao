import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarServico extends StatefulWidget {
  final String serviceId;
  const EditarServico({super.key, required this.serviceId});

  @override
  State<EditarServico> createState() => _EditarServicoState();
}

class _EditarServicoState extends State<EditarServico> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

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

  // Streams: apenas documentos ATIVOS
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _unidadesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _unidadesStream = _firestore
        .collection('unidades')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();

    _categoriasStream = _firestore
        .collection('categoriasServicos')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();

    _carregarServico();
  }

  Future<void> _carregarServico() async {
    final doc = await _firestore
        .collection('servicos')
        .doc(widget.serviceId)
        .get();
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
    nomeController.text = (data['nome'] ?? '') as String;
    descricaoController.text = (data['descricao'] ?? '') as String;

    // pode existir legado 'unidade' (texto); agora usamos 'unidadeId'
    unidadeSelecionadaId = (data['unidadeId'] ?? '') as String?;
    categoriaSelecionadaId = (data['categoriaId'] ?? '') as String?;

    final num? vMin = data['valorMinimo'] as num?;
    final num? vMed = data['valorMedio'] as num?;
    final num? vMax = data['valorMaximo'] as num?;
    valorMinimoController.text = (vMin ?? 0).toString();
    valorMedioController.text = (vMed ?? 0).toString();
    valorMaximoController.text = (vMax ?? 0).toString();

    ativo = data['ativo'] == true;

    if (mounted) setState(() => _carregando = false);
  }

  @override
  void dispose() {
    nomeController.dispose();
    descricaoController.dispose();
    valorMinimoController.dispose();
    valorMedioController.dispose();
    valorMaximoController.dispose();
    super.dispose();
  }

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  Future<void> _salvar() async {
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
    final catDoc = await _firestore
        .collection('categoriasServicos')
        .doc(categoriaSelecionadaId)
        .get();
    if (!catDoc.exists || catDoc.data()?['ativo'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A categoria selecionada não está mais ativa.'),
        ),
      );
      return;
    }

    final uniDoc = await _firestore
        .collection('unidades')
        .doc(unidadeSelecionadaId)
        .get();
    if (!uniDoc.exists || uniDoc.data()?['ativo'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A unidade selecionada não está mais ativa.'),
        ),
      );
      return;
    }

    try {
      await _firestore.collection('servicos').doc(widget.serviceId).update({
        'nome': nomeController.text.trim(),
        'descricao': descricaoController.text.trim(),
        'categoriaId': categoriaSelecionadaId,
        'unidadeId': unidadeSelecionadaId,
        'valorMinimo': _parseNum(valorMinimoController.text),
        'valorMedio': _parseNum(valorMedioController.text),
        'valorMaximo': _parseNum(valorMaximoController.text),
        'ativo': ativo,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço atualizado com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  Future<void> _excluir() async {
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

    try {
      await _firestore.collection('servicos').doc(widget.serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Serviço excluído.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
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
            onPressed: _excluir,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do serviço',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                    TextFormField(
                      controller: descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição do serviço',
                      ),
                      maxLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),

                    // Unidade (apenas ativas)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _unidadesStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return DropdownButtonFormField<String>(
                            items: const [],
                            onChanged: null,
                            decoration: const InputDecoration(
                              labelText: 'Unidade de medida',
                            ),
                            hint: const Text('Carregando unidades...'),
                          );
                        }
                        if (snap.hasError) {
                          return const Text(
                            'Erro ao carregar unidades ativas.',
                          );
                        }

                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Text(
                            'Nenhuma unidade ativa disponível.',
                            style: TextStyle(color: Colors.red),
                          );
                        }

                        final itens = docs.map((d) {
                          final id = d.id;
                          final nome = (d.data()['nome'] ?? '') as String;
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(nome),
                          );
                        }).toList();

                        // se a selecionada saiu (desativou), limpa
                        if (unidadeSelecionadaId != null &&
                            !docs.any((d) => d.id == unidadeSelecionadaId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() => unidadeSelecionadaId = null);
                          });
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: unidadeSelecionadaId,
                          items: itens,
                          onChanged: (id) =>
                              setState(() => unidadeSelecionadaId = id),
                          decoration: const InputDecoration(
                            labelText: 'Unidade de medida',
                          ),
                          hint: const Text('Selecione a unidade de medida'),
                          validator: (_) =>
                              (unidadeSelecionadaId == null ||
                                  unidadeSelecionadaId!.isEmpty)
                              ? 'Obrigatório'
                              : null,
                        );
                      },
                    ),

                    // Categoria (apenas ativas)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _categoriasStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return DropdownButtonFormField<String>(
                            items: const [],
                            onChanged: null,
                            decoration: const InputDecoration(
                              labelText: 'Categoria de serviços',
                            ),
                            hint: const Text('Carregando categorias...'),
                          );
                        }
                        if (snap.hasError) {
                          return const Text(
                            'Erro ao carregar categorias ativas.',
                          );
                        }

                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Text(
                            'Nenhuma categoria ativa disponível.',
                            style: TextStyle(color: Colors.red),
                          );
                        }

                        final itens = docs.map((d) {
                          final id = d.id;
                          final nome = (d.data()['nome'] ?? '') as String;
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(nome),
                          );
                        }).toList();

                        if (categoriaSelecionadaId != null &&
                            !docs.any((d) => d.id == categoriaSelecionadaId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() => categoriaSelecionadaId = null);
                          });
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: categoriaSelecionadaId,
                          items: itens,
                          onChanged: (id) =>
                              setState(() => categoriaSelecionadaId = id),
                          decoration: const InputDecoration(
                            labelText: 'Categoria de serviços',
                          ),
                          hint: const Text('Selecione a categoria do serviço'),
                          validator: (_) =>
                              (categoriaSelecionadaId == null ||
                                  categoriaSelecionadaId!.isEmpty)
                              ? 'Obrigatório'
                              : null,
                        );
                      },
                    ),

                    TextFormField(
                      controller: valorMinimoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor por unidade (mínimo)',
                      ),
                    ),
                    TextFormField(
                      controller: valorMedioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor por unidade (médio)',
                      ),
                    ),
                    TextFormField(
                      controller: valorMaximoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor por unidade (máximo)',
                      ),
                    ),

                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ativado'),
                      value: ativo,
                      onChanged: (v) => setState(() => ativo = v),
                    ),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
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
                          horizontal: 40,
                          vertical: 16,
                        ),
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
