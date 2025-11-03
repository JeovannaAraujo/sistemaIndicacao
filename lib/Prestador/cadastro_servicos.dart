import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CadastroServicos extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const CadastroServicos({super.key, this.firestore, this.auth});

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

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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

  double? _parseMoeda(String v) {
    final s = v
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(s);
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

    try {
      await _firestore.collection('servicos').add({
        'nome': nomeController.text.trim(),
        'descricao': descricaoController.text.trim(),
        'unidadeId': unidadeSelecionadaId,
        'categoriaId': categoriaSelecionadaId,
        'valorMinimo': _parseMoeda(valorMinimoController.text) ?? 0,
        'valorMedio': _parseMoeda(valorMedioController.text) ?? 0,
        'valorMaximo': _parseMoeda(valorMaximoController.text) ?? 0,
        'prestadorId': user.uid,
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço cadastrado com sucesso!')),
      );
      // Evita fechar a tela automaticamente durante testes
      if (!const bool.hasEnvironment('FLUTTER_TEST')) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  InputDecoration _inputDecoration({String? hint, String? label}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Cadastro de Serviço'),
        backgroundColor: Colors.white,
        elevation: 0.3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
                decoration: _inputDecoration(label: 'Nome do serviço'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: descricaoController,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(label: 'Descrição do serviço'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // 🔹 CAMPO UNIDADE DE MEDIDA
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _unidadesStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return TextFormField(
                      enabled: false,
                      decoration: _inputDecoration(
                        label: 'Carregando unidades...',
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final itens = docs.map((d) {
                    final id = d.id;
                    final nome = (d.data()['nome'] ?? '') as String;
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(nome),
                    );
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            itens.any(
                              (item) => item.value == unidadeSelecionadaId,
                            )
                            ? unidadeSelecionadaId
                            : null,
                        items: itens,
                        onChanged: (id) =>
                            setState(() => unidadeSelecionadaId = id),
                        decoration: _inputDecoration(
                          label: 'Unidade de medida',
                        ),
                        validator: (_) => (unidadeSelecionadaId == null)
                            ? 'Obrigatório'
                            : null,
                      ),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E7FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.2),
                          ),
                        ),

                        child: const Text(
                          'A unidade de medida define como o serviço será cobrado '
                          '(exemplo: por hora, por metro quadrado, por unidade, etc). '
                          'Essa informação é usada no cálculo das estimativas de preço.',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // 🔹 CAMPO CATEGORIA DO SERVIÇO
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _categoriasStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return TextFormField(
                      enabled: false,
                      decoration: _inputDecoration(
                        label: 'Carregando categorias...',
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final itens = docs.map((d) {
                    final id = d.id;
                    final nome = (d.data()['nome'] ?? '') as String;
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(nome),
                    );
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            itens.any(
                              (item) => item.value == categoriaSelecionadaId,
                            )
                            ? categoriaSelecionadaId
                            : null,
                        items: itens,
                        onChanged: (id) =>
                            setState(() => categoriaSelecionadaId = id),
                        decoration: _inputDecoration(
                          label: 'Categoria do serviço',
                        ),
                        validator: (_) => (categoriaSelecionadaId == null)
                            ? 'Obrigatório'
                            : null,
                      ),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E7FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Text(
                          'A categoria define o tipo de serviço (como elétrica, hidráulica, '
                          'limpeza, jardinagem, etc). '
                          'Ela organiza e facilita a busca feita pelos clientes no aplicativo.',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                  ),
                ),

                child: const Text(
                  'Informe os valores mínimos, médios e máximos que você costuma cobrar. '
                  'Essas informações ajudam os clientes a entender a faixa de preço e servem de base para estimativas automáticas.',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🔹 CAMPO VALOR MÍNIMO
              TextFormField(
                controller: valorMinimoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.start,
                decoration: _inputDecoration(
                  hint: 'R\$ 0,00',
                  label: 'Valor por unidade (mínimo)',
                ),
                onChanged: (v) {
                  String digits = v.replaceAll(RegExp(r'[^0-9]'), '');

                  if (digits.isEmpty) {
                    valorMinimoController.text = '';
                    return;
                  }

                  double value = double.parse(digits) / 100.0;
                  final textoFormatado = _moeda.format(value);

                  if (textoFormatado != v) {
                    valorMinimoController.value = TextEditingValue(
                      text: textoFormatado,
                      selection: TextSelection.collapsed(
                        offset: textoFormatado.length,
                      ),
                    );
                  }
                },
                validator: (v) {
                  final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9,]'), '');
                  final valor = double.tryParse(cleaned.replaceAll(',', '.'));
                  if (valor == null || valor <= 0) {
                    return 'Informe um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 🔹 CAMPO VALOR MÉDIO
              TextFormField(
                controller: valorMedioController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.start,
                decoration: _inputDecoration(
                  hint: 'R\$ 0,00',
                  label: 'Valor por unidade (médio)',
                ),
                onChanged: (v) {
                  String digits = v.replaceAll(RegExp(r'[^0-9]'), '');

                  if (digits.isEmpty) {
                    valorMedioController.text = '';
                    return;
                  }

                  double value = double.parse(digits) / 100.0;
                  final textoFormatado = _moeda.format(value);

                  if (textoFormatado != v) {
                    valorMedioController.value = TextEditingValue(
                      text: textoFormatado,
                      selection: TextSelection.collapsed(
                        offset: textoFormatado.length,
                      ),
                    );
                  }
                },
                validator: (v) {
                  final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9,]'), '');
                  final valor = double.tryParse(cleaned.replaceAll(',', '.'));
                  if (valor == null || valor <= 0) {
                    return 'Informe um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 🔹 CAMPO VALOR MÁXIMO
              TextFormField(
                controller: valorMaximoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.start,
                decoration: _inputDecoration(
                  hint: 'R\$ 0,00',
                  label: 'Valor por unidade (máximo)',
                ),
                onChanged: (v) {
                  String digits = v.replaceAll(RegExp(r'[^0-9]'), '');

                  if (digits.isEmpty) {
                    valorMaximoController.text = '';
                    return;
                  }

                  double value = double.parse(digits) / 100.0;
                  final textoFormatado = _moeda.format(value);

                  if (textoFormatado != v) {
                    valorMaximoController.value = TextEditingValue(
                      text: textoFormatado,
                      selection: TextSelection.collapsed(
                        offset: textoFormatado.length,
                      ),
                    );
                  }
                },
                validator: (v) {
                  final cleaned = (v ?? '').replaceAll(RegExp(r'[^0-9,]'), '');
                  final valor = double.tryParse(cleaned.replaceAll(',', '.'));
                  if (valor == null || valor <= 0) {
                    return 'Informe um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _salvarServico,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Salvar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
