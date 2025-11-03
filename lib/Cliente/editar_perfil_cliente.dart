// lib/Cliente/editarPerfilCliente.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class EditarPerfilCliente extends StatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final FirebaseStorage? storage;

  const EditarPerfilCliente({
    super.key,
    required this.userId,
    this.firestore,
    this.auth,
    this.storage,
  });

  @override
  State<EditarPerfilCliente> createState() => EditarPerfilClienteState();
}

class EditarPerfilClienteState extends State<EditarPerfilCliente> {
  final formKey = GlobalKey<FormState>();
  late final FirebaseAuth auth;
  final _picker = ImagePicker();

  /// 🔹 Permite injeção de dependências fake em testes
  late final FirebaseFirestore db;
  late final FirebaseStorage storage;

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

    db = widget.firestore ?? FirebaseFirestore.instance;
    storage = widget.storage ?? FirebaseStorage.instance;
    auth = widget.auth ?? FirebaseAuth.instance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      categoriasStream = db
          .collection('categoriasProfissionais')
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .snapshots();

      carregarPerfil();
    });
  }

  /// 🔹 Solicita permissões para acessar a galeria
  Future<bool> _solicitarPermissoesGaleria() async {
    try {
      // Para Android 13+ (API 33+)
      if (await Permission.photos.isGranted) {
        return true;
      }

      // Para versões anteriores
      if (await Permission.storage.isGranted) {
        return true;
      }

      // Solicitar permissão
      final status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      }

      // Tentar com storage para versões mais antigas
      final statusStorage = await Permission.storage.request();
      if (statusStorage.isGranted) {
        return true;
      }

      // Se negado, abrir configurações do app
      if (status.isPermanentlyDenied || statusStorage.isPermanentlyDenied) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permissão Necessária'),
              content: const Text(
                'Para selecionar uma foto, é necessário permitir o acesso à galeria. '
                'Deseja abrir as configurações para conceder a permissão?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Abrir Configurações'),
                ),
              ],
            ),
          );
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Erro ao solicitar permissões: $e');
      return false;
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
        Navigator.pop(context);
      }
    }
  }

  /// 🔹 Seleciona foto da galeria com verificação de permissões
  Future<void> _selecionarFotoPerfil() async {
    try {
      // Solicitar permissões primeiro
      final temPermissao = await _solicitarPermissoesGaleria();
      if (!temPermissao) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão para acessar a galeria é necessária'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (img == null) return;

      setState(() {
        _fotoSelecionada = img;
        _enviandoFoto = true;
      });

      await _fazerUploadFoto(img);
    } catch (e) {
      debugPrint('❌ Erro ao selecionar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar foto: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  /// 🔹 Faz upload da foto para o Firebase Storage
  Future<void> _fazerUploadFoto(XFile imagem) async {
    try {
      // 1. Ler bytes da imagem
      final bytes = await imagem.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Imagem vazia ou corrompida');
      }

      // 2. Criar referência no Storage com nome único
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String path = 'usuarios/${widget.userId}/perfil_$timestamp.jpg';
      final Reference ref = storage.ref().child(path);

      // 3. Configurar metadata
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': widget.userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // 4. Fazer upload
      final UploadTask uploadTask = ref.putData(bytes, metadata);

      // Monitorar progresso (opcional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('📤 Progresso upload: ${progress.toStringAsFixed(1)}%');
      });

      // 5. Aguardar conclusão do upload
      final TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        // 6. Obter URL de download
        final String url = await ref.getDownloadURL();
        debugPrint('✅ Upload concluído: $url');

        // 7. Deletar foto antiga se existir
        await _deletarFotoAntiga();

        // 8. Atualizar no Firestore
        await _atualizarFotoNoFirestore(url, path);

        setState(() {
          fotoUrl = url;
          fotoPath = path;
          _fotoSelecionada = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil atualizada com sucesso!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Falha no upload: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('❌ Erro no upload da foto: $e');

      // Tratamento específico para erros comuns
      String mensagemErro = 'Erro ao fazer upload da foto';

      if (e.toString().contains('permission') ||
          e.toString().contains('permissão')) {
        mensagemErro = 'Sem permissão para fazer upload';
      } else if (e.toString().contains('network') ||
          e.toString().contains('rede')) {
        mensagemErro = 'Erro de conexão. Verifique sua internet';
      } else if (e.toString().contains('quota') ||
          e.toString().contains('cota')) {
        mensagemErro = 'Limite de armazenamento excedido';
      } else if (e.toString().contains('canceled')) {
        mensagemErro = 'Upload cancelado';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagemErro),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

  /// 🔹 Deleta foto antiga do Storage
  Future<void> _deletarFotoAntiga() async {
    if (fotoPath != null && fotoPath!.isNotEmpty && fotoPath != 'temp') {
      try {
        await storage.ref().child(fotoPath!).delete();
        debugPrint('🗑️ Foto antiga deletada: $fotoPath');
      } catch (e) {
        // Não impede o processo se falhar em deletar a foto antiga
        debugPrint('⚠️ Não foi possível deletar foto antiga: $e');
      }
    }
  }

  /// 🔹 Atualiza URL da foto no Firestore
  Future<void> _atualizarFotoNoFirestore(String url, String path) async {
    try {
      await db.collection('usuarios').doc(widget.userId).set({
        'fotoUrl': url,
        'fotoPath': path,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Foto atualizada no Firestore');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar foto no Firestore: $e');
      throw Exception('Erro ao salvar foto no perfil');
    }
  }

  /// 🔹 Remove foto do perfil
  Future<void> removerFotoPerfil() async {
    try {
      // Mostrar confirmação
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover foto'),
          content: const Text(
            'Tem certeza que deseja remover sua foto de perfil?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      setState(() => _enviandoFoto = true);

      // Deletar do Storage
      await _deletarFotoAntiga();

      // Remover referências no Firestore
      await db.collection('usuarios').doc(widget.userId).set({
        'fotoUrl': FieldValue.delete(),
        'fotoPath': FieldValue.delete(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        fotoUrl = null;
        fotoPath = null;
        _fotoSelecionada = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto removida com sucesso.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao remover foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover foto: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
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
      setState(() => salvando = true);

      // Remover foto do Storage se existir
      if (fotoPath != null && fotoPath!.isNotEmpty) {
        await _deletarFotoAntiga();
      }

      // Remover dados do Firestore
      await db.collection('usuarios').doc(widget.userId).delete();

      // Remover usuário do Authentication
      final user = auth.currentUser;
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
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  /// 🔹 Salva todas as alterações do perfil (SEM ALTERAR EMAIL)
  Future<void> salvar() async {
    if (formKey.currentState == null || !formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) {
      return;
    }

    // Validações para prestadores
    if (tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos') {
      if (categoriaProfId == null || categoriaProfId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma categoria profissional.'),
          ),
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

      // 🔹 ATUALIZAR DADOS NO FIRESTORE (SEM ALTERAR EMAIL)
      final dadosAtualizacao = {
        'nome': nomeCtrl.text.trim(),
        // ❌ REMOVIDO: Não atualiza mais o email por segurança
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
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
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
    const inputDecoration = InputDecorationTheme(
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
          backgroundColor: const Color(0xFFF6F6FB),
          foregroundColor: Colors.black,
          elevation: 0,
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
                      _buildFotoPerfil(),

                      // === INFORMAÇÕES PESSOAIS ===
                      secTitle('Informações Pessoais'),
                      const SizedBox(height: 10),
                      _buildInformacoesPessoais(),
                      // === ENDEREÇO E CONTATO ===
                      secTitle('Endereço e Contato'),
                      const SizedBox(height: 10),
                      _buildEnderecoContato(),

                      // === INFORMAÇÕES PROFISSIONAIS (se aplicável) ===
                      if (tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos')
                        _buildSecaoProfissional(),

                      // === BOTÕES DE AÇÃO ===
                      const SizedBox(height: 30),
                      _buildBotoesAcao(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 🔹 Constrói a seção de informações pessoais
  Widget _buildInformacoesPessoais() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: tipoPerfil,
          items: const [
            DropdownMenuItem(value: 'Cliente', child: Text('Cliente')),
            DropdownMenuItem(value: 'Prestador', child: Text('Prestador')),
            DropdownMenuItem(value: 'Ambos', child: Text('Ambos')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => tipoPerfil = v);
          },
          decoration: const InputDecoration(labelText: 'Tipo de perfil'),
        ),

        const SizedBox(height: 15),

        TextFormField(
          controller: nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome completo'),
          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 15),

        // 🔹 CAMPO EMAIL APENAS LEITURA COM FUNDO ROXO CLARO
        TextFormField(
          controller: emailCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            filled: true,
            fillColor: Color(0xFFEDE7FF),
          ),
          style: const TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 🔹 Constrói a seção da foto do perfil
  Widget _buildFotoPerfil() {
    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color.fromARGB(255, 223, 219, 228),
                  backgroundImage: _fotoSelecionada != null
                      ? FileImage(File(_fotoSelecionada!.path))
                      : (fotoUrl != null && fotoUrl!.isNotEmpty)
                      ? NetworkImage(fotoUrl!) as ImageProvider
                      : null,
                  child:
                      (_fotoSelecionada == null &&
                          (fotoUrl == null || fotoUrl!.isEmpty))
                      ? const Icon(
                          Icons.person,
                          size: 48,
                          color: Colors.deepPurple,
                        )
                      : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _enviandoFoto ? null : _selecionarFotoPerfil,
                    icon: _enviandoFoto
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        if (fotoUrl != null && fotoUrl!.isNotEmpty)
          Center(
            child: TextButton.icon(
              onPressed: _enviandoFoto ? null : removerFotoPerfil,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover foto'),
            ),
          ),
      ],
    );
  }

  /// 🔹 Constrói a seção de endereço e contato
  Widget _buildEnderecoContato() {
    return Column(
      children: [
        TextFormField(
          controller: whatsappCtrl,
          decoration: const InputDecoration(
            labelText: 'WhatsApp',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: cepCtrl,
          decoration: const InputDecoration(
            labelText: 'CEP',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: cidadeCtrl,
          decoration: const InputDecoration(
            labelText: 'Cidade',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: ruaCtrl,
          decoration: const InputDecoration(
            labelText: 'Rua',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: numeroCtrl,
          decoration: const InputDecoration(
            labelText: 'Número',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: bairroCtrl,
          decoration: const InputDecoration(
            labelText: 'Bairro',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: complementoCtrl,
          decoration: const InputDecoration(
            labelText: 'Complemento',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 🔹 Constrói a seção de informações profissionais
  Widget _buildSecaoProfissional() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        secTitle('Informações Profissionais'),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: categoriasStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Text('Nenhuma categoria disponível');
            }

            final docs = snap.data!.docs;
            final items = docs.map((d) {
              return DropdownMenuItem<String>(
                value: d.id,
                child: Text(d['nome'] ?? 'Sem nome'),
              );
            }).toList();

            return DropdownButtonFormField<String>(
              initialValue: categoriaProfId,
              items: items,
              onChanged: (v) => setState(() => categoriaProfId = v),
              decoration: const InputDecoration(
                labelText: 'Categoria profissional',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
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
            hintText: 'Fale sobre seus serviços e experiência',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),

        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          initialValue: tempoExperiencia.isEmpty ? null : tempoExperiencia,
          items: experiencias
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => tempoExperiencia = v ?? ''),
          decoration: const InputDecoration(
            labelText: 'Tempo de experiência',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),

        secTitle('Área de atendimento'),
        TextField(
          controller: areaAtendimentoCtrl,
          decoration: const InputDecoration(
            hintText: 'Digite uma cidade e pressione +',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: Icon(Icons.add_circle, color: Colors.deepPurple),
          ),
          onSubmitted: (value) {
            final txt = value.trim();
            if (txt.isNotEmpty) {
              final norm =
                  txt[0].toUpperCase() + txt.substring(1).toLowerCase();
              if (!areaAtendimento.contains(norm)) {
                setState(() => areaAtendimento.add(norm));
              }
              areaAtendimentoCtrl.clear();
            }
          },
        ),

        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: areaAtendimento.map((c) {
            return Chip(
              label: Text(c),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => areaAtendimento.remove(c)),
              backgroundColor: Colors.deepPurple.shade50,
              side: BorderSide.none,
            );
          }).toList(),
        ),

        secTitle('Meios de pagamento aceitos'),
        ...['Dinheiro', 'Pix', 'Cartão de crédito/débito'].map(
          (e) => CheckboxListTile(
            dense: true,
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

        secTitle('Dias de trabalho'),
        ...diasSemana.map(
          (e) => CheckboxListTile(
            dense: true,
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
    );
  }

  /// 🔹 Constrói os botões de ação
  Widget _buildBotoesAcao() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: salvando ? null : salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: salvando ? null : excluirConta,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
    );
  }
}
