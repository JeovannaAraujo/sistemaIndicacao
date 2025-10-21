import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CadastroServicos extends StatefulWidget {
  final FirebaseFirestore? firestore; // ✅ injeção para testes
  final FirebaseAuth? auth; // ✅ injeção para testes

  const CadastroServicos({
    super.key,
    this.firestore,
    this.auth,
  });

  @override
  State<CadastroServicos> createState() => _CadastroServicosState();
}

class _CadastroServicosState extends State<CadastroServicos> {
  final _formKey = GlobalKey<FormState>();
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final valorMinimoController = TextEditingController();
  final valorMedioController = TextEditingController();
  final valorMaximoController = TextEditingController();

  String? unidadeSelecionadaId;
  String? categoriaSelecionadaId;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _unidadesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;

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

  Future<void> _salvarServico() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa estar logado.')),
      );
      return;
    }

    if (unidadeSelecionadaId == null || unidadeSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a unidade de medida.')),
      );
      return;
    }
    if (categoriaSelecionadaId == null || categoriaSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a categoria do serviço.')),
      );
      return;
    }

    // Revalida no servidor se ainda estão ativas
    final unidadeDoc =
        await _firestore.collection('unidades').doc(unidadeSelecionadaId).get();
    if (!unidadeDoc.exists || unidadeDoc.data()?['ativo'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'A unidade selecionada não está mais ativa. Selecione outra.'),
        ),
      );
      return;
    }

    final catDoc = await _firestore
        .collection('categoriasServicos')
        .doc(categoriaSelecionadaId)
        .get();
    if (!catDoc.exists || catDoc.data()?['ativo'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'A categoria selecionada não está mais ativa. Selecione outra.'),
        ),
      );
      return;
    }

    try {
      await _firestore.collection('servicos').add({
        'nome': nomeController.text.trim(),
        'descricao': descricaoController.text.trim(),
        'unidadeId': unidadeSelecionadaId,
        'categoriaId': categoriaSelecionadaId,
        'valorMinimo': double.tryParse(
                valorMinimoController.text.replaceAll(',', '.')) ??
            0,
        'valorMedio': double.tryParse(
                valorMedioController.text.replaceAll(',', '.')) ??
            0,
        'valorMaximo': double.tryParse(
                valorMaximoController.text.replaceAll(',', '.')) ??
            0,
        'prestadorId': user.uid,
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço cadastrado com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de serviço'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informe as seguintes informações para cadastrar seu serviço.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome do serviço'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),

              TextFormField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição do serviço',
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),

              // ---------- Unidades (ATIVAS) — usa ID ----------
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
                    return const Text('Erro ao carregar unidades ativas.');
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Text(
                      'Nenhuma unidade ativa disponível. Cadastre/ative uma unidade primeiro.',
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

                  // ✅ evita crash: se ID atual não está mais na lista
                  return DropdownButtonFormField<String>(
                    value: docs.any((d) => d.id == unidadeSelecionadaId)
                        ? unidadeSelecionadaId
                        : null,
                    items: itens,
                    onChanged: (id) => setState(() => unidadeSelecionadaId = id),
                    decoration: const InputDecoration(
                      labelText: 'Unidade de medida',
                    ),
                    hint: const Text('Selecione a unidade de medida'),
                    validator: (_) => (unidadeSelecionadaId == null ||
                            unidadeSelecionadaId!.isEmpty)
                        ? 'Obrigatório'
                        : null,
                  );
                },
              ),

              // ---------- Categorias (ATIVAS) — usa ID ----------
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
                    return const Text('Erro ao carregar categorias ativas.');
                  }

                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Text(
                      'Nenhuma categoria ativa disponível. Cadastre/ative uma categoria primeiro.',
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

                  // ✅ evita crash também
                  return DropdownButtonFormField<String>(
                    value: docs.any((d) => d.id == categoriaSelecionadaId)
                        ? categoriaSelecionadaId
                        : null,
                    items: itens,
                    onChanged: (id) =>
                        setState(() => categoriaSelecionadaId = id),
                    decoration: const InputDecoration(
                      labelText: 'Categoria de serviços',
                    ),
                    hint: const Text('Selecione a categoria do serviço'),
                    validator: (_) => (categoriaSelecionadaId == null ||
                            categoriaSelecionadaId!.isEmpty)
                        ? 'Obrigatório'
                        : null,
                  );
                },
              ),

              TextFormField(
                controller: valorMinimoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor por unidade (mínimo)',
                ),
              ),
              TextFormField(
                controller: valorMedioController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor por unidade (médio)',
                ),
              ),
              TextFormField(
                controller: valorMaximoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor por unidade (máximo)',
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvarServico,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Salvar'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
