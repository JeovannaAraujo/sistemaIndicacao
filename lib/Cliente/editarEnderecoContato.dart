import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class EditarEnderecoContatoScreen extends StatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const EditarEnderecoContatoScreen({
    super.key,
    required this.userId,
    this.firestore,
    this.auth,
  });

  @override
  State<EditarEnderecoContatoScreen> createState() =>
      _EditarEnderecoContatoScreenState();
}

class _EditarEnderecoContatoScreenState
    extends State<EditarEnderecoContatoScreen> {
  final _formKey = GlobalKey<FormState>();
  late FirebaseFirestore db;

  // Controllers para endereço e contato
  final cepCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final ruaCtrl = TextEditingController();
  final numeroCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final complementoCtrl = TextEditingController();
  final whatsappCtrl = TextEditingController();

  bool _carregando = true;
  bool _salvando = false;
  bool _buscandoCep = false;
  String _cepAnterior = '';

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    _carregarEnderecoContato();
  }

  // Aplicar máscara de CEP
  String _aplicarMascaraCep(String value) {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.length <= 5) {
      return value;
    } else {
      return '${value.substring(0, 5)}-${value.substring(5)}';
    }
  }

  // Aplicar máscara de WhatsApp
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

  void _onCepChanged() {
    final cepFormatado = cepCtrl.text;
    final cepApenasNumeros = cepFormatado.replaceAll(RegExp(r'[^0-9]'), '');

    // Aplica máscara
    if (cepFormatado != _aplicarMascaraCep(cepApenasNumeros)) {
      final selection = cepCtrl.selection;
      cepCtrl.text = _aplicarMascaraCep(cepApenasNumeros);
      cepCtrl.selection = TextSelection.collapsed(
        offset:
            selection.baseOffset + (cepCtrl.text.length - cepFormatado.length),
      );
    }

    // Busca CEP apenas se for diferente do anterior e tiver 8 dígitos
    if (cepApenasNumeros.length == 8 && cepApenasNumeros != _cepAnterior) {
      _cepAnterior = cepApenasNumeros;
      _buscarCep(cepApenasNumeros);
    }
  }

  void _onWhatsAppChanged() {
    final whatsappFormatado = whatsappCtrl.text;
    final whatsappApenasNumeros = whatsappFormatado.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // Aplica máscara
    if (whatsappFormatado != _aplicarMascaraWhatsApp(whatsappApenasNumeros)) {
      final selection = whatsappCtrl.selection;
      whatsappCtrl.text = _aplicarMascaraWhatsApp(whatsappApenasNumeros);
      whatsappCtrl.selection = TextSelection.collapsed(
        offset:
            selection.baseOffset +
            (whatsappCtrl.text.length - whatsappFormatado.length),
      );
    }
  }

  Future<void> _buscarCep(String cep) async {
    if (_buscandoCep) return;

    setState(() => _buscandoCep = true);

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['erro'] != true) {
          // Limpa os campos de endereço antes de preencher com os novos dados
          setState(() {
            ruaCtrl.text = data['logradouro'] ?? '';
            bairroCtrl.text = data['bairro'] ?? '';
            cidadeCtrl.text = data['localidade'] ?? '';
            complementoCtrl.text = data['complemento'] ?? '';
            numeroCtrl.text = ''; // Limpa o número para o usuário preencher
          });

          // Foca automaticamente no campo número
          FocusScope.of(context).requestFocus(FocusNode());
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(context).requestFocus(_numeroFocus);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Endereço preenchido automaticamente!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          _mostrarErroCep('CEP não encontrado');
        }
      } else {
        _mostrarErroCep('Erro ao buscar CEP');
      }
    } catch (e) {
      debugPrint('❌ Erro na busca do CEP: $e');
      _mostrarErroCep('Erro de conexão');
    } finally {
      if (mounted) {
        setState(() => _buscandoCep = false);
      }
    }
  }

  void _mostrarErroCep(String mensagem) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _carregarEnderecoContato() async {
    try {
      final doc = await db.collection('usuarios').doc(widget.userId).get();

      if (doc.exists) {
        final dados = doc.data() ?? {};
        final endereco = (dados['endereco'] as Map<String, dynamic>?) ?? {};

        final cep = (endereco['cep'] ?? '') as String;
        final whatsapp = (endereco['whatsapp'] ?? '') as String;

        setState(() {
          // Aplica máscaras ao carregar os dados
          whatsappCtrl.text = _aplicarMascaraWhatsApp(whatsapp);
          cepCtrl.text = _aplicarMascaraCep(cep);
          _cepAnterior = cep.replaceAll(RegExp(r'[^0-9]'), '');

          cidadeCtrl.text = (endereco['cidade'] ?? '') as String;
          ruaCtrl.text = (endereco['rua'] ?? '') as String;
          numeroCtrl.text = (endereco['numero'] ?? '') as String;
          bairroCtrl.text = (endereco['bairro'] ?? '') as String;
          complementoCtrl.text = (endereco['complemento'] ?? '') as String;
          _carregando = false;
        });

        // Adiciona listeners após carregar os dados
        cepCtrl.addListener(_onCepChanged);
        whatsappCtrl.addListener(_onWhatsAppChanged);
      } else {
        setState(() => _carregando = false);
        // Adiciona listeners mesmo se não houver dados
        cepCtrl.addListener(_onCepChanged);
        whatsappCtrl.addListener(_onWhatsAppChanged);
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar endereço: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _salvarEnderecoContato() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() => _salvando = true);

    try {
      // Remove máscaras antes de salvar
      final cepSemMascara = cepCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final whatsappSemMascara = whatsappCtrl.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      final dadosAtualizacao = {
        'endereco': {
          'whatsapp': whatsappSemMascara,
          'cep': cepSemMascara,
          'cidade': cidadeCtrl.text.trim(),
          'rua': ruaCtrl.text.trim(),
          'numero': numeroCtrl.text.trim(),
          'bairro': bairroCtrl.text.trim(),
          'complemento': complementoCtrl.text.trim(),
        },
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      await db
          .collection('usuarios')
          .doc(widget.userId)
          .set(dadosAtualizacao, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço e contato atualizados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar endereço: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  final _numeroFocus = FocusNode();

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    Widget? suffixIcon,
    bool? enabled,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: suffixIcon,
      enabled: enabled ?? true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar Endereço e Contato',
          style: TextStyle(
            color: Colors.deepPurple, // ✅ Texto roxo
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white, // ✅ Fundo branco uniforme
        foregroundColor: Colors.deepPurple, // ✅ Seta roxa
        elevation: 1, // ✅ Pequena sombra para definir o AppBar
        iconTheme: const IconThemeData(
          color: Colors.deepPurple, // ✅ Garante que a seta fique roxa
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16,
                2,
                16,
                16,
              ), // ← Top reduzido para 8
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === CONTATO ===
                    _buildSectionTitle('Contato'),
                    TextFormField(
                      controller: whatsappCtrl,
                      decoration: _inputDecoration('WhatsApp'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final digits =
                            value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                        if (digits.isEmpty) {
                          return 'Informe o WhatsApp';
                        }
                        if (digits.length < 10 || digits.length > 11) {
                          return 'WhatsApp deve ter 10 ou 11 dígitos';
                        }
                        return null;
                      },
                    ),

                    // === ENDEREÇO ===
                    _buildSectionTitle('Endereço'),
                    TextFormField(
                      controller: cepCtrl,
                      decoration: _inputDecoration(
                        'CEP',
                        suffixIcon: _buscandoCep
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final digits =
                            value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                        if (digits.isEmpty) {
                          return 'Informe o CEP';
                        }
                        if (digits.length != 8) {
                          return 'CEP deve ter 8 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: cidadeCtrl,
                      decoration: _inputDecoration('Cidade'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe a cidade';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: ruaCtrl,
                      decoration: _inputDecoration('Rua'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe a rua';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: numeroCtrl,
                            focusNode: _numeroFocus,
                            decoration: _inputDecoration('Número'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe o número';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: bairroCtrl,
                            decoration: _inputDecoration('Bairro'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe o bairro';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: complementoCtrl,
                      decoration: _inputDecoration('Complemento (opcional)'),
                    ),
                    // === BOTÕES ===
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _salvando
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.deepPurple),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _salvando
                                ? null
                                : _salvarEnderecoContato,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _salvando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Salvar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
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

  @override
  void dispose() {
    cepCtrl.removeListener(_onCepChanged);
    whatsappCtrl.removeListener(_onWhatsAppChanged);
    cepCtrl.dispose();
    cidadeCtrl.dispose();
    ruaCtrl.dispose();
    numeroCtrl.dispose();
    bairroCtrl.dispose();
    complementoCtrl.dispose();
    whatsappCtrl.dispose();
    _numeroFocus.dispose();
    super.dispose();
  }
}
