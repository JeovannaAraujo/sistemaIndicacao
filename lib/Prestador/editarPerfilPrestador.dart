import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// kIsWeb

class EditarPerfilPrestador extends StatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final FirebaseStorage? storage;

  const EditarPerfilPrestador({
    super.key,
    required this.userId,
    this.firestore,
    this.auth,
    this.storage,
  });

  @override
  State<EditarPerfilPrestador> createState() => EditarPerfilPrestadorState();
}

class EditarPerfilPrestadorState extends State<EditarPerfilPrestador> {
  final _formKey = GlobalKey<FormState>();
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;


  // form controllers
  final nomeCtrl = TextEditingController();
  final emailCtrl = TextEditingController(); // somente leitura
  final cepCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final ruaCtrl = TextEditingController();
  final numeroCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final complementoCtrl = TextEditingController();
  final whatsappCtrl = TextEditingController();
  final descricaoCtrl = TextEditingController();
  final areaAtendimentoCtrl = TextEditingController();

  // estado
  bool carregando = true;
  String tipoPerfil = 'Prestador'; // Prestador | Ambos
  String? categoriaProfId; // salvamos só o ID
  String tempoExperiencia = '';
  final List<String> meiosPagamento = [];
  final List<String> jornada = [];
  final List<String> areaAtendimento = [];

  // foto de perfil
  String? fotoUrl; // URL pública salva no Firestore (usuarios/{uid}.fotoUrl)
  String? _fotoPath; // caminho no Storage para facilitar remoção
  bool _enviandoFoto = false;

  // streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

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
    _auth = widget.auth ?? FirebaseAuth.instance;
    _db = widget.firestore ?? FirebaseFirestore.instance;
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

      nomeCtrl.text = (d['nome'] ?? '') as String;
      emailCtrl.text = (d['email'] ?? '') as String;

      final end = (d['endereco'] as Map<String, dynamic>?) ?? {};
      cepCtrl.text = (end['cep'] ?? '') as String;
      cidadeCtrl.text = (end['cidade'] ?? '') as String;
      ruaCtrl.text = (end['rua'] ?? '') as String;
      numeroCtrl.text = (end['numero'] ?? '') as String;
      bairroCtrl.text = (end['bairro'] ?? '') as String;
      complementoCtrl.text = (end['complemento'] ?? '') as String;
      whatsappCtrl.text = (end['whatsapp'] ?? '') as String;

      tipoPerfil = (d['tipoPerfil'] ?? 'Prestador') as String;
      categoriaProfId = (d['categoriaProfissionalId'] ?? '') as String?;
      descricaoCtrl.text = (d['descricao'] ?? '') as String;
      tempoExperiencia = (d['tempoExperiencia'] ?? '') as String;
      areaAtendimentoCtrl.text = (d['areaAtendimento'] ?? '') as String;

      (d['meiosPagamento'] as List?)?.forEach((e) {
        final s = '$e';
        if (!meiosPagamento.contains(s)) meiosPagamento.add(s);
      });
      (d['jornada'] as List?)?.forEach((e) {
        final s = '$e';
        if (!jornada.contains(s)) jornada.add(s);
      });

      // foto
      fotoUrl = (d['fotoUrl'] ?? '') as String?;
      _fotoPath = (d['fotoPath'] ?? '') as String?;
      (d['areasAtendimento'] as List?)?.forEach((e) {
        final s = '$e';
        if (!areaAtendimento.contains(s)) areaAtendimento.add(s);
      });

      // foto
      fotoUrl = (d['fotoUrl'] ?? '') as String?;
      _fotoPath = (d['fotoPath'] ?? '') as String?;

      if (mounted) setState(() => carregando = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> selecionarFotoPerfil() async {
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
      final String path =
          'usuarios/${widget.userId}/perfil_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child(path);

      final meta = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=604800',
      );
      await ref.putData(bytes, meta);

      final String url = await ref.getDownloadURL();

      await _db.collection('usuarios').doc(widget.userId).set({
        'fotoUrl': url,
        'fotoPath': path,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        fotoUrl = url;
        _fotoPath = path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao enviar a foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

 Future<void> removerFotoPerfil() async {
  try {
    // 🔹 Deleta a imagem do Storage (usando o mock injetado)
    if (_fotoPath != null && _fotoPath!.isNotEmpty) {
      try {
        await (widget.storage ?? FirebaseStorage.instance)
            .ref()
            .child(_fotoPath!)
            .delete();
      } catch (_) {
        debugPrint('⚠️ Erro ao deletar no Storage (ignorado no teste)');
      }
    }

    // 🔹 Atualiza o Firestore (usando o mock injetado)
    await (widget.firestore ?? FirebaseFirestore.instance)
        .collection('usuarios')
        .doc(widget.userId)
        .set({
      'fotoUrl': null,
      'fotoPath': null,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 🔹 Atualiza estado e mostra SnackBar
    if (mounted) {
      setState(() {
        fotoUrl = null;
        _fotoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto removida com sucesso!')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover foto: $e')),
      );
    }
  }
}

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // revalida categoria ativa
    if (categoriaProfId != null && categoriaProfId!.isNotEmpty) {
      final cat = await _db
          .collection('categoriasProfissionais')
          .doc(categoriaProfId)
          .get();
      if (!cat.exists || cat.data()?['ativo'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A categoria selecionada não está mais ativa.'),
          ),
        );
        return;
      }
    }

    try {
      await _db.collection('usuarios').doc(widget.userId).update({
        'nome': nomeCtrl.text.trim(),
        // email: mantemos como está (editar email exige reautenticação)
        'tipoPerfil': tipoPerfil, // Prestador | Ambos
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
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil atualizado!')));
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

  Future<void> excluirConta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Excluir sua conta removerá também seus serviços. Esta ação não pode ser desfeita.',
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
      // remove serviços do prestador
      final servs = await _db
          .collection('servicos')
          .where('prestadorId', isEqualTo: widget.userId)
          .get();
      final batch = _db.batch();
      for (final d in servs.docs) {
        batch.delete(d.reference);
      }

      // apaga foto do Storage se existir
      if (_fotoPath != null && _fotoPath!.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(_fotoPath!).delete();
        } catch (_) {}
      }

      batch.delete(_db.collection('usuarios').doc(widget.userId));
      await batch.commit();

      // tenta remover do auth (pode exigir reautenticação)
      final user = _auth.currentUser;
      if (user != null && user.uid == widget.userId) {
        await user.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conta excluída.')));
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
    cepCtrl.dispose();
    cidadeCtrl.dispose();
    ruaCtrl.dispose();
    numeroCtrl.dispose();
    bairroCtrl.dispose();
    complementoCtrl.dispose();
    whatsappCtrl.dispose();
    descricaoCtrl.dispose();
    areaAtendimentoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black12),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black12),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.deepPurple),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

    return Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: inputDecoration),
      child: Scaffold(
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
                      // ===== CABEÇALHO COM AVATAR + BOTÃO CÂMERA =====
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ClipOval(
                              child: (fotoUrl != null && fotoUrl!.isNotEmpty)
                                  ? Image.network(
                                      fotoUrl!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.deepPurple,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.deepPurple,
                                    ),
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: ElevatedButton(
                                onPressed: _enviandoFoto
                                    ? null
                                    : selecionarFotoPerfil,
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
                      if (fotoUrl != null && fotoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed: removerFotoPerfil,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover foto'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // ===== FIM CABEÇALHO =====
                      _secTitle('Informações Pessoais'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value:
                            (tipoPerfil.isEmpty ||
                                ![
                                  'Cliente',
                                  'Prestador',
                                  'Ambos',
                                ].contains(tipoPerfil))
                            ? 'Cliente'
                            : tipoPerfil,
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
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null,
                        onChanged: (_) =>
                            setState(() {}), // atualiza o cabeçalho com o nome
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: emailCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                      ),
                      const SizedBox(height: 15),
                      _secTitle('Endereço e contato'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: whatsappCtrl,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null,
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obrigatório'
                            : null,
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

                      _secTitle('Informações Profissionais'),
                      const SizedBox(height: 8),
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

                          final itens = docs.map((d) {
                            final id = d.id;
                            final nome = (d.data()['nome'] ?? '') as String;
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(nome),
                            );
                          }).toList();

                          // ✅ Garante que só define value se existir na lista
                          final value = docs.any((d) => d.id == categoriaProfId)
                              ? categoriaProfId
                              : null;

                          return DropdownButtonFormField<String>(
                            value: value,
                            items: itens,
                            onChanged: (v) =>
                                setState(() => categoriaProfId = v),
                            decoration: const InputDecoration(
                              labelText: 'Categoria profissional',
                            ),
                            hint: const Text('Selecione sua categoria'),
                          );
                        },
                      ),

                      const SizedBox(height: 15),
                      TextFormField(
                        controller: descricaoCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descrição do profissional',
                          hintText: 'Fale um pouco sobre seus serviços',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        // ❌ Removemos o limite de 100 caracteres
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: tempoExperiencia.isEmpty
                            ? null
                            : tempoExperiencia,
                        items: experiencias
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => tempoExperiencia = v ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Tempo de experiência',
                        ),
                        validator: (_) =>
                            tempoExperiencia.isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 15),
                      // ===== ÁREA DE ATENDIMENTO (múltiplas cidades) =====
                      _secTitle('Cidade / Área de atendimento'),
                      TextField(
                        controller: areaAtendimentoCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ex: Rio Verde',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              final txt = areaAtendimentoCtrl.text.trim();
                              if (txt.isEmpty) return;
                              final normalizado =
                                  txt[0].toUpperCase() +
                                  txt.substring(1).toLowerCase();
                              if (!areaAtendimento.contains(normalizado)) {
                                setState(
                                  () => areaAtendimento.add(normalizado),
                                );
                              }
                              areaAtendimentoCtrl.clear();
                            },
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        onSubmitted: (_) {
                          final txt = areaAtendimentoCtrl.text.trim();
                          if (txt.isEmpty) return;
                          final normalizado =
                              txt[0].toUpperCase() +
                              txt.substring(1).toLowerCase();
                          if (!areaAtendimento.contains(normalizado)) {
                            setState(() => areaAtendimento.add(normalizado));
                          }
                          areaAtendimentoCtrl.clear();
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Informe todas as cidades e áreas onde você atende.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Colors.deepPurple),
                          );
                        }).toList(),
                      ),

                      // ===== MEIOS DE PAGAMENTO =====
                      _secTitle('Meios de pagamento aceitos'),
                      const Text(
                        'Os meios de pagamento servem apenas para informativo; o app não processa pagamentos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                        ),
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

                      // ===== JORNADA =====
                      _secTitle('Jornada de trabalho'),
                      const Text(
                        'Informe os dias em que você está disponível para prestar serviços.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple,
                        ),
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

                      const SizedBox(height: 30),

                      // ===== BOTÕES PADRONIZADOS =====
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Salvar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // 🔹 texto branco
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.deepPurple),
                            foregroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: excluirConta,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // 🔹 texto branco
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
