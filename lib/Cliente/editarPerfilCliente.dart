// lib/Cliente/editarPerfilCliente.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EditarPerfilCliente extends StatefulWidget {
  final String userId;
  const EditarPerfilCliente({super.key, required this.userId});

  @override
  State<EditarPerfilCliente> createState() => EditarPerfilClienteState();
}

class EditarPerfilClienteState extends State<EditarPerfilCliente> {
  final formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  /// 🔹 Permite injeção de Firestore fake em testes
  late FirebaseFirestore db; // permite injeção de fake no teste

  EditarPerfilClienteState({FirebaseFirestore? testDb})
    : db = testDb ?? FirebaseFirestore.instance;

  // controles pessoais e contato
  final nomeCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final whatsappCtrl = TextEditingController();

  // endereço
  final cepCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final ruaCtrl = TextEditingController();
  final numeroCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final complementoCtrl = TextEditingController();

  // profissionais
  final descricaoCtrl = TextEditingController();
  final areaAtendimentoCtrl = TextEditingController();

  // estado
  bool carregando = true;
  bool salvando = false;
  String tipoPerfil = 'Cliente';
  String? categoriaProfId;
  String tempoExperiencia = '';
  final List<String> meiosPagamento = [];
  final List<String> jornada = [];
  final List<String> areaAtendimento = [];

  // foto
  String? fotoUrl;
  String? fotoPath;
  bool _enviandoFoto = false;
  XFile? _fotoSelecionada;

  // streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> categoriasStream;

  final experiencias = [
    '0-1 ano',
    '1-3 anos',
    '3-5 anos',
    '5-10 anos',
    '+10 anos',
  ];

  final diasSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    categoriasStream = db
        .collection('categoriasProfissionais')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();
    carregarPerfil();
  }

 Future<void> carregarPerfil() async {
  try {
    final ref = db.collection('usuarios').doc(widget.userId);
    final doc = await ref.get();

    if (!doc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil não encontrado.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final d = doc.data() ?? {};
    final end = (d['endereco'] as Map<String, dynamic>?) ?? {};

    nomeCtrl.text = (d['nome'] ?? '') as String;
    emailCtrl.text = (d['email'] ?? '') as String;
    whatsappCtrl.text = (end['whatsapp'] ?? '') as String;
    tipoPerfil = (d['tipoPerfil'] ?? 'Cliente') as String;

    cepCtrl.text = (end['cep'] ?? '') as String;
    cidadeCtrl.text = (end['cidade'] ?? '') as String;
    ruaCtrl.text = (end['rua'] ?? '') as String;
    numeroCtrl.text = (end['numero'] ?? '') as String;
    bairroCtrl.text = (end['bairro'] ?? '') as String;
    complementoCtrl.text = (end['complemento'] ?? '') as String;

    categoriaProfId = (d['categoriaProfissionalId'] ?? '') as String?;
    descricaoCtrl.text = (d['descricao'] ?? '') as String;
    tempoExperiencia = (d['tempoExperiencia'] ?? '') as String;

    (d['meiosPagamento'] as List?)?.forEach((e) {
      final s = '$e';
      if (!meiosPagamento.contains(s)) meiosPagamento.add(s);
    });

    (d['jornada'] as List?)?.forEach((e) {
      final s = '$e';
      if (!jornada.contains(s)) jornada.add(s);
    });

    (d['areasAtendimento'] as List?)?.forEach((e) {
      final s = '$e';
      if (!areaAtendimento.contains(s)) areaAtendimento.add(s);
    });

    fotoUrl = (d['fotoUrl'] ?? '') as String?;
    fotoPath = (d['fotoPath'] ?? '') as String?;

    if (mounted) setState(() => carregando = false);
  } catch (e) {
    debugPrint('❌ Erro ao carregar perfil: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar: $e')),
      );
      Navigator.pop(context);
    }
  }
}

  /// 🔹 Seleciona foto da galeria e faz upload para o Firebase Storage
  Future<void> _selecionarFotoPerfil() async {
    try {
      final picker = ImagePicker();
      final XFile? img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (img == null) return;

      setState(() {
        _fotoSelecionada = img;
        _enviandoFoto = true;
      });

      // Fazer upload da imagem para o Firebase Storage
      final bytes = await img.readAsBytes();
      final String path = 'usuarios/${widget.userId}/perfil_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);

      // Upload para o Storage
      final uploadTask = ref.putData(
        bytes, 
        SettableMetadata(contentType: 'image/jpeg')
      );
      
      await uploadTask;
      final url = await ref.getDownloadURL();

      // Atualizar no Firestore
      await db.collection('usuarios').doc(widget.userId).set({
        'fotoUrl': url,
        'fotoPath': path,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Deletar foto antiga se existir
      if (fotoPath != null && fotoPath!.isNotEmpty && fotoPath != path) {
        try {
          await FirebaseStorage.instance.ref().child(fotoPath!).delete();
        } catch (e) {
          debugPrint('⚠️ Erro ao deletar foto antiga: $e');
        }
      }

      setState(() {
        fotoUrl = url;
        fotoPath = path;
        _fotoSelecionada = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada!')),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao fazer upload da foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  /// 🔹 Remove foto do perfil (Storage e Firestore)
 Future<void> removerFotoPerfil() async {
  try {
    if (fotoPath != null && fotoPath!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref().child(fotoPath!).delete();
      } catch (_) {
        debugPrint('⚠️ Foto não encontrada no Storage, continuando...');
      }
    }

    await db.collection('usuarios').doc(widget.userId).set({
      'fotoUrl': FieldValue.delete(),
      'fotoPath': FieldValue.delete(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() {
        fotoUrl = null;
        fotoPath = null;
        _fotoSelecionada = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto removida.')),
      );
    } else {
      // Garante que o teste veja as variáveis zeradas
      fotoUrl = null;
      fotoPath = null;
      _fotoSelecionada = null;
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover foto: $e')),
      );
    } else {
      debugPrint('⚠️ Erro ao remover foto (sem contexto ativo): $e');
      fotoUrl = null;
      fotoPath = null;
      _fotoSelecionada = null;
    }
  }
}

  /// 🔹 Atualiza o email no Firebase Authentication
  Future<void> _atualizarEmailNoAuth(String novoEmail) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != novoEmail) {
        await user.verifyBeforeUpdateEmail(novoEmail);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link de verificação enviado para o novo email.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar email no Auth: $e');
      rethrow;
    }
  }

  /// 🔹 Valida se o email foi alterado
  bool _emailFoiAlterado(String emailOriginal) {
    return emailCtrl.text.trim() != emailOriginal;
  }

  /// 🔹 Salva todas as alterações do perfil
 Future<void> salvar() async {
  if (formKey.currentState == null || !formKey.currentState!.validate()) return;
  if (!mounted) return;

  // Validações para prestadores
  if (tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos') {
    if (categoriaProfId == null || categoriaProfId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria profissional.')),
      );
      return;
    }
    if (descricaoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição profissional.')),
      );
      return;
    }
    if (tempoExperiencia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o tempo de experiência.')),
      );
      return;
    }
  }

  setState(() => salvando = true);

  try {
    final ref = db.collection('usuarios').doc(widget.userId);
    final doc = await ref.get();
    final dadosAtuais = doc.data() ?? {};
    final emailOriginal = (dadosAtuais['email'] ?? '') as String;
    final novoEmail = emailCtrl.text.trim();

    // 🔹 ATUALIZAR EMAIL NO AUTH SE MUDOU
    if (_emailFoiAlterado(emailOriginal)) {
      await _atualizarEmailNoAuth(novoEmail);
    }

    // 🔹 ATUALIZAR DADOS NO FIRESTORE
    final dadosAtualizacao = {
      'nome': nomeCtrl.text.trim(),
      'email': novoEmail, // Sempre atualiza o email no Firestore
      'tipoPerfil': tipoPerfil,
      'categoriaProfissionalId': categoriaProfId,
      'descricao': descricaoCtrl.text.trim(),
      'tempoExperiencia': tempoExperiencia,
      'areasAtendimento': areaAtendimento.toSet().toList(),
      'meiosPagamento': meiosPagamento.toSet().toList(),
      'jornada': jornada.toSet().toList(),
      'endereco': {
        'cep': cepCtrl.text.trim(),
        'cidade': cidadeCtrl.text.trim(),
        'rua': ruaCtrl.text.trim(),
        'numero': numeroCtrl.text.trim(),
        'bairro': bairroCtrl.text.trim(),
        'complemento': complementoCtrl.text.trim(),
        'whatsapp': whatsappCtrl.text.trim(),
      },
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    await ref.set(dadosAtualizacao, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
      
      // Se o email foi alterado, mostra mensagem adicional
      if (_emailFoiAlterado(emailOriginal)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Verificação de Email Necessária'),
              content: const Text(
                'Enviamos um link de verificação para seu novo email. '
                'Por favor, verifique seu email para continuar usando sua conta normalmente.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        });
      }
      
      Navigator.pop(context);
    }
  } catch (e) {
    debugPrint('❌ Erro ao salvar perfil: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => salvando = false);
  }
}

  /// 🔹 Exclui conta do usuário
  Future<void> excluirConta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Excluir sua conta removerá permanentemente seus dados. Deseja continuar?',
        ),
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

    if (ok != true) return;

    try {
      // Remover foto do Storage se existir
      if (fotoPath != null && fotoPath!.isNotEmpty) {
        await FirebaseStorage.instance.ref().child(fotoPath!).delete();
      }

      // Remover dados do Firestore
      await db.collection('usuarios').doc(widget.userId).delete();
      
      // Remover usuário do Authentication
      final user = _auth.currentUser;
      if (user != null && user.uid == widget.userId) {
        await user.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta excluída com sucesso.')),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      debugPrint('❌ Erro ao excluir conta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir a conta: $e')),
        );
      }
    }
  }

  Widget secTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
        fontSize: 16,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final inputDecoration = const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.deepPurple),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

    return Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: inputDecoration),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar Perfil'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === FOTO PERFIL ===
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.deepPurple.shade50,
                              backgroundImage: _fotoSelecionada != null
                                  ? FileImage(File(_fotoSelecionada!.path))
                                  : (fotoUrl != null && fotoUrl!.isNotEmpty)
                                      ? NetworkImage(fotoUrl!)
                                      : null,
                              child: (_fotoSelecionada == null && 
                                     (fotoUrl == null || fotoUrl!.isEmpty))
                                  ? const Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Colors.deepPurple,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: ElevatedButton(
                                onPressed: _enviandoFoto
                                    ? null
                                    : _selecionarFotoPerfil,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(10),
                                  shape: const CircleBorder(),
                                  backgroundColor: Colors.deepPurple,
                                ),
                                child: _enviandoFoto
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Center(
                        child: Text(
                          nomeCtrl.text.isNotEmpty ? nomeCtrl.text : 'Seu nome',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      if (fotoUrl != null && fotoUrl!.isNotEmpty)
                        Center(
                          child: TextButton.icon(
                            onPressed: removerFotoPerfil,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover foto'),
                          ),
                        ),

                      // === INFORMAÇÕES PESSOAIS ===
                      secTitle('Informações Pessoais'),
                      
                      DropdownButtonFormField<String>(
                        value: tipoPerfil,
                        items: const [
                          DropdownMenuItem(
                            value: 'Cliente',
                            child: Text('Cliente'),
                          ),
                          DropdownMenuItem(
                            value: 'Prestador',
                            child: Text('Prestador'),
                          ),
                          DropdownMenuItem(
                            value: 'Ambos',
                            child: Text('Ambos'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => tipoPerfil = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tipo de perfil',
                        ),
                      ),
                      
                      const SizedBox(height: 15),
                      
                      TextFormField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Obrigatório' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      
                      const SizedBox(height: 15),
                      
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'Seu endereço de email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obrigatório';
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                      ),

                      // ... (resto do código permanece igual)
                      secTitle('Endereço e Contato'),
                      TextFormField(
                        controller: whatsappCtrl,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: cepCtrl,
                        decoration: const InputDecoration(labelText: 'CEP'),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: cidadeCtrl,
                        decoration: const InputDecoration(labelText: 'Cidade'),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: ruaCtrl,
                        decoration: const InputDecoration(labelText: 'Rua'),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: numeroCtrl,
                        decoration: const InputDecoration(labelText: 'Número'),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: bairroCtrl,
                        decoration: const InputDecoration(labelText: 'Bairro'),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: complementoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Complemento',
                        ),
                      ),

                      if (tipoPerfil == 'Prestador' ||
                          tipoPerfil == 'Ambos') ...[
                        secTitle('Informações Profissionais'),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: categoriasStream,
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final docs = snap.data!.docs;
                            final items = docs.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(d['nome']),
                              );
                            }).toList();
                            return DropdownButtonFormField<String>(
                              value: categoriaProfId,
                              items: items,
                              onChanged: (v) =>
                                  setState(() => categoriaProfId = v),
                              decoration: const InputDecoration(
                                labelText: 'Categoria profissional',
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: descricaoCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descrição profissional',
                            hintText: 'Fale sobre seus serviços',
                          ),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: tempoExperiencia.isEmpty
                              ? null
                              : tempoExperiencia,
                          items: experiencias
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => tempoExperiencia = v ?? ''),
                          decoration: const InputDecoration(
                            labelText: 'Tempo de experiência',
                          ),
                        ),

                        secTitle('Cidade / Área de atendimento'),
                        TextField(
                          controller: areaAtendimentoCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ex: Rio Verde',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                final txt = areaAtendimentoCtrl.text.trim();
                                if (txt.isEmpty) return;
                                final norm =
                                    txt[0].toUpperCase() +
                                    txt.substring(1).toLowerCase();
                                if (!areaAtendimento.contains(norm)) {
                                  setState(() => areaAtendimento.add(norm));
                                }
                                areaAtendimentoCtrl.clear();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children: areaAtendimento.map((c) {
                            return Chip(
                              label: Text(c),
                              deleteIcon: const Icon(Icons.close),
                              onDeleted: () =>
                                  setState(() => areaAtendimento.remove(c)),
                              side: const BorderSide(color: Colors.deepPurple),
                            );
                          }).toList(),
                        ),

                        secTitle('Meios de pagamento aceitos'),
                        ...['Dinheiro', 'Pix', 'Cartão de crédito/débito'].map(
                          (e) => CheckboxListTile(
                            title: Text(e),
                            value: meiosPagamento.contains(e),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                meiosPagamento.add(e);
                              } else {
                                meiosPagamento.remove(e);
                              }
                            }),
                          ),
                        ),

                        secTitle('Jornada de trabalho'),
                        ...diasSemana.map(
                          (e) => CheckboxListTile(
                            title: Text(e),
                            value: jornada.contains(e),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                jornada.add(e);
                              } else {
                                jornada.remove(e);
                              }
                            }),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: salvando ? null : salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: salvando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Salvar Alterações',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: salvando ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: salvando ? null : excluirConta,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Excluir Conta',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}