// lib/Cliente/editarPerfilCliente.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditarPerfilCliente extends StatefulWidget {
  final String userId;
  const EditarPerfilCliente({super.key, required this.userId});

  @override
  State<EditarPerfilCliente> createState() => _EditarPerfilClienteState();
}

class _EditarPerfilClienteState extends State<EditarPerfilCliente> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // pessoais / contato
  final nomeCtrl = TextEditingController();
  final emailCtrl = TextEditingController(); // somente leitura
  final whatsappCtrl = TextEditingController();

  // endereço
  final cepCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final ruaCtrl = TextEditingController();
  final numeroCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final complementoCtrl = TextEditingController();

  // profissionais (mostrados apenas se tipoPerfil = Prestador | Ambos)
  final descricaoCtrl = TextEditingController();
  final areaAtendimentoCtrl = TextEditingController();
  String tipoPerfil = 'Cliente'; // Cliente | Prestador | Ambos
  String? categoriaProfId;
  String tempoExperiencia = '';
  final List<String> meiosPagamento = [];
  final List<String> jornada = [];

  // foto de perfil
  String? _fotoUrl;
  String? _fotoPath;
  bool _enviandoFoto = false;

  bool carregando = true;

  // streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  final experiencias = const [
    '0-1 ano',
    '1-3 anos',
    '3-5 anos',
    '5-10 anos',
    '+10 anos',
  ];

  final diasSemana = const [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  bool get _ehPrestador =>
      tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos';

  @override
  void initState() {
    super.initState();
    _categoriasStream = _db
        .collection('categoriasProfissionais')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    try {
      final doc = await _db.collection('usuarios').doc(widget.userId).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil não encontrado.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final d = doc.data()!;
      // básicos
      nomeCtrl.text = (d['nome'] ?? '') as String;
      emailCtrl.text = (d['email'] ?? '') as String;

      // endereço
      final end = (d['endereco'] as Map<String, dynamic>?) ?? {};
      whatsappCtrl.text = (end['whatsapp'] ?? '') as String;
      cepCtrl.text = (end['cep'] ?? '') as String;
      cidadeCtrl.text = (end['cidade'] ?? '') as String;
      ruaCtrl.text = (end['rua'] ?? '') as String;
      numeroCtrl.text = (end['numero'] ?? '') as String;
      bairroCtrl.text = (end['bairro'] ?? '') as String;
      complementoCtrl.text = (end['complemento'] ?? '') as String;

      // profissionais
      tipoPerfil = (d['tipoPerfil'] ?? 'Cliente') as String;
      categoriaProfId = (d['categoriaProfissionalId'] ?? '') as String?;
      descricaoCtrl.text = (d['descricao'] ?? '') as String;
      tempoExperiencia = (d['tempoExperiencia'] ?? '') as String;
      areaAtendimentoCtrl.text = (d['areaAtendimento'] ?? '') as String;

      (d['meiosPagamento'] as List?)
          ?.map((e) => '$e')
          .forEach((s) => meiosPagamento.contains(s)
              ? null
              : meiosPagamento.add(s));

      (d['jornada'] as List?)
          ?.map((e) => '$e')
          .forEach((s) => jornada.contains(s) ? null : jornada.add(s));

      // foto
      _fotoUrl = (d['fotoUrl'] ?? '') as String?;
      _fotoPath = (d['fotoPath'] ?? '') as String?;

      if (mounted) setState(() => carregando = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _selecionarFotoPerfil() async {
    try {
      final picker = ImagePicker();
      final XFile? img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (img == null) return;

      setState(() => _enviandoFoto = true);

      final bytes = await img.readAsBytes();
      final storage = FirebaseStorage.instance;
      final path =
          'usuarios/${widget.userId}/perfil_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child(path);

      final meta = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=604800',
      );

      await ref.putData(bytes, meta);
      final url = await ref.getDownloadURL();

      await _db.collection('usuarios').doc(widget.userId).set({
        'fotoUrl': url,
        'fotoPath': path,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _fotoUrl = url;
        _fotoPath = path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar a foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _removerFotoPerfil() async {
    try {
      if (_fotoPath != null && _fotoPath!.isNotEmpty) {
        await FirebaseStorage.instance
            .ref()
            .child(_fotoPath!)
            .delete()
            .catchError((_) {});
      }
      await _db.collection('usuarios').doc(widget.userId).set({
        'fotoUrl': FieldValue.delete(),
        'fotoPath': FieldValue.delete(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _fotoUrl = null;
        _fotoPath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto removida.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível remover a foto: $e')),
        );
      }
    }
  }

  Future<void> _salvar() async {
    // validações básicas
    if (!_formKey.currentState!.validate()) return;

    // se for Prestador/Ambos, exigimos campos profissionais
    if (_ehPrestador) {
      if ((categoriaProfId == null || categoriaProfId!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione a categoria profissional.')),
        );
        return;
      }
      // revalida se a categoria ainda está ativa
      final cat = await _db
          .collection('categoriasProfissionais')
          .doc(categoriaProfId)
          .get();
      if (!cat.exists || cat.data()?['ativo'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A categoria selecionada não está mais ativa.')),
        );
        return;
      }
      if (descricaoCtrl.text.trim().length < 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A descrição deve ter pelo menos 100 caracteres.')),
        );
        return;
      }
      if (tempoExperiencia.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o tempo de experiência.')),
        );
        return;
      }
      if (areaAtendimentoCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Informe a cidade/área de atendimento.')),
        );
        return;
      }
    }

    try {
      // bloco base (sempre salvo)
      final updateBase = <String, dynamic>{
        'nome': nomeCtrl.text.trim(),
        'tipoPerfil': tipoPerfil, // Cliente | Prestador | Ambos
        'endereco': {
          'whatsapp': whatsappCtrl.text.trim(),
          'cep': cepCtrl.text.trim(),
          'cidade': cidadeCtrl.text.trim(),
          'rua': ruaCtrl.text.trim(),
          'numero': numeroCtrl.text.trim(),
          'bairro': bairroCtrl.text.trim(),
          'complemento': complementoCtrl.text.trim(),
        },
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      // se prestador/ambos, inclui campos profissionais
      if (_ehPrestador) {
        updateBase.addAll({
          'categoriaProfissionalId': categoriaProfId,
          'descricao': descricaoCtrl.text.trim(),
          'tempoExperiencia': tempoExperiencia,
          'areaAtendimento': areaAtendimentoCtrl.text.trim(),
          'meiosPagamento': meiosPagamento.toSet().toList(),
          'jornada': jornada.toSet().toList(),
        });
      }

      await _db
          .collection('usuarios')
          .doc(widget.userId)
          .set(updateBase, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  Future<void> _excluirConta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Excluir sua conta removerá seus dados do aplicativo. '
          'Esta ação não pode ser desfeita.',
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
      // apaga foto se existir
      if (_fotoPath != null && _fotoPath!.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(_fotoPath!).delete();
        } catch (_) {}
      }

      // apaga documento do usuário
      await _db.collection('usuarios').doc(widget.userId).delete();

      // tenta excluir do Auth (pode exigir reautenticação)
      final user = _auth.currentUser;
      if (user != null && user.uid == widget.userId) {
        await user.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta excluída.')),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível excluir a conta agora (${e.toString()}). '
              'Você pode sair e entrar novamente e tentar de novo.',
            ),
          ),
        );
      }
    }
  }

  Widget _secTitle(String t) => Padding(
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
  void dispose() {
    nomeCtrl.dispose();
    emailCtrl.dispose();
    whatsappCtrl.dispose();
    cepCtrl.dispose();
    cidadeCtrl.dispose();
    ruaCtrl.dispose();
    numeroCtrl.dispose();
    bairroCtrl.dispose();
    complementoCtrl.dispose();
    descricaoCtrl.dispose();
    areaAtendimentoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== CABEÇALHO COM AVATAR =====
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.deepPurple.shade50,
                            backgroundImage:
                                (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                                    ? NetworkImage(_fotoUrl!)
                                    : null,
                            child: (_fotoUrl == null || _fotoUrl!.isEmpty)
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
                              onPressed:
                                  _enviandoFoto ? null : _selecionarFotoPerfil,
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
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_fotoUrl != null && _fotoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          onPressed: _removerFotoPerfil,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover foto'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // ===== INFORMAÇÕES PESSOAIS =====
                    _secTitle('Informações pessoais'),
                    DropdownButtonFormField<String>(
                      value: tipoPerfil,
                      items: const ['Cliente', 'Prestador', 'Ambos']
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        tipoPerfil = v ?? 'Cliente';
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Tipo de perfil',
                      ),
                    ),
                    TextFormField(
                      controller: nomeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nome completo'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    TextFormField(
                      controller: emailCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),

                    // ===== CONTATO E ENDEREÇO =====
                    _secTitle('Contato e endereço'),
                    TextFormField(
                      controller: whatsappCtrl,
                      decoration:
                          const InputDecoration(labelText: 'WhatsApp'),
                    ),
                    TextFormField(
                      controller: cepCtrl,
                      decoration: const InputDecoration(labelText: 'CEP'),
                    ),
                    TextFormField(
                      controller: cidadeCtrl,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                    TextFormField(
                      controller: ruaCtrl,
                      decoration: const InputDecoration(labelText: 'Rua'),
                    ),
                    TextFormField(
                      controller: numeroCtrl,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                    TextFormField(
                      controller: bairroCtrl,
                      decoration: const InputDecoration(labelText: 'Bairro'),
                    ),
                    TextFormField(
                      controller: complementoCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Complemento'),
                    ),

                    // ===== CAMPOS PROFISSIONAIS (CONDICIONAIS) =====
                    if (_ehPrestador) ...[
                      _secTitle('Informações profissionais'),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _categoriasStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return DropdownButtonFormField<String>(
                              items: const [],
                              onChanged: null,
                              decoration: const InputDecoration(
                                labelText: 'Categoria profissional',
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

                          // se categoria salva não está mais ativa, limpa
                          if (categoriaProfId != null &&
                              !docs.any((d) => d.id == categoriaProfId)) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              setState(() => categoriaProfId = null);
                            });
                          }

                          final itens = docs.map((d) {
                            final id = d.id;
                            final nome = (d.data()['nome'] ?? '') as String;
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(nome),
                            );
                          }).toList();

                          return DropdownButtonFormField<String>(
                            value: categoriaProfId,
                            items: itens,
                            onChanged: (v) =>
                                setState(() => categoriaProfId = v),
                            decoration: const InputDecoration(
                              labelText: 'Categoria profissional',
                            ),
                            validator: (_) => !_ehPrestador
                                ? null
                                : (categoriaProfId == null ||
                                        categoriaProfId!.isEmpty)
                                    ? 'Obrigatório'
                                    : null,
                          );
                        },
                      ),

                      TextFormField(
                        controller: descricaoCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText:
                              'Descrição do profissional (mín. 100 caracteres)',
                        ),
                        validator: (_) => !_ehPrestador
                            ? null
                            : (descricaoCtrl.text.trim().length < 100)
                                ? 'Mínimo 100 caracteres'
                                : null,
                      ),

                      DropdownButtonFormField<String>(
                        value: tempoExperiencia.isEmpty
                            ? null
                            : tempoExperiencia,
                        items: experiencias
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => tempoExperiencia = v ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Tempo de experiência',
                        ),
                        validator: (_) => !_ehPrestador
                            ? null
                            : (tempoExperiencia.isEmpty
                                ? 'Obrigatório'
                                : null),
                      ),

                      TextFormField(
                        controller: areaAtendimentoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cidade / Área de atendimento',
                          hintText: 'Ex: Rio Verde',
                        ),
                        validator: (_) => !_ehPrestador
                            ? null
                            : (areaAtendimentoCtrl.text.trim().isEmpty
                                ? 'Obrigatório'
                                : null),
                      ),

                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, bottom: 4.0),
                        child: Text(
                          'Meios de pagamento aceitos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Text(
                        'Os meios de pagamento servem apenas para informativo; o app não processa pagamentos.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.deepPurple),
                      ),
                      ...['Dinheiro', 'Pix', 'Cartão de crédito/débito'].map(
                        (e) => CheckboxListTile(
                          title: Text(e),
                          value: meiosPagamento.contains(e),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              if (!meiosPagamento.contains(e)) {
                                meiosPagamento.add(e);
                              }
                            } else {
                              meiosPagamento.remove(e);
                            }
                          }),
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, bottom: 4.0),
                        child: Text(
                          'Jornada de trabalho',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Text(
                        'Informe os dias em que você está disponível para prestar serviços.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.deepPurple),
                      ),
                      ...diasSemana.map(
                        (e) => CheckboxListTile(
                          title: Text(e),
                          value: jornada.contains(e),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              if (!jornada.contains(e)) jornada.add(e);
                            } else {
                              jornada.remove(e);
                            }
                          }),
                        ),
                      ),
                    ],

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
                      child: const Text('Salvar'),
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
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _excluirConta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Excluir Conta'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
