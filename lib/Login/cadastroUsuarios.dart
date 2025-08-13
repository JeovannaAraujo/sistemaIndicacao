import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroUsuario extends StatefulWidget {
  const CadastroUsuario({super.key});

  @override
  State<CadastroUsuario> createState() => _CadastroUsuarioState();
}

class _CadastroUsuarioState extends State<CadastroUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Controllers
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  final cepController = TextEditingController();
  final cidadeController = TextEditingController();
  final ruaController = TextEditingController();
  final numeroController = TextEditingController();
  final bairroController = TextEditingController();
  final complementoController = TextEditingController();
  final whatsappController = TextEditingController();
  final descricaoController = TextEditingController();
  final areaAtendimentoController = TextEditingController();

  // Estado
  String tipoPerfil = 'Cliente'; // Cliente | Prestador | Ambos
  String? categoriaProfissionalId; // salva só o ID
  String tempoExperiencia = '';
  final List<String> meiosPagamento = [];
  final List<String> jornada = [];

  // Streams
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  // Constantes auxiliares
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

  bool get isPrestador => tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos';

  @override
  void initState() {
    super.initState();
    _categoriasStream = _firestore
        .collection('categoriasProfissionais')
        .where('ativo', isEqualTo: true) // só ativas
        .orderBy('nome')
        .snapshots();
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    cepController.dispose();
    cidadeController.dispose();
    ruaController.dispose();
    numeroController.dispose();
    bairroController.dispose();
    complementoController.dispose();
    whatsappController.dispose();
    descricaoController.dispose();
    areaAtendimentoController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (senhaController.text != confirmarSenhaController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('As senhas não coincidem.')));
      return;
    }

    if (isPrestador) {
      if (categoriaProfissionalId == null ||
          tempoExperiencia.isEmpty ||
          descricaoController.text.trim().length < 100 ||
          areaAtendimentoController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preencha todos os campos obrigatórios do prestador.',
            ),
          ),
        );
        return;
      }
      // Revalida no Firestore se a categoria continua ativa
      final catDoc = await _firestore
          .collection('categoriasProfissionais')
          .doc(categoriaProfissionalId)
          .get();

      if (!catDoc.exists || catDoc.data()?['ativo'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A categoria selecionada não está mais ativa. Selecione outra.',
            ),
          ),
        );
        return;
      }
    }

    UserCredential? cred;
    try {
      final email = emailController.text.trim().toLowerCase();
      final senha = senhaController.text.trim();

      // 1) Cria usuário no Auth
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final uid = cred.user!.uid;

      // 2) Salva perfil no Firestore (doc ID = UID)
      await _firestore.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nome': nomeController.text.trim(),
        'email': email,
        'tipoPerfil': tipoPerfil, // Cliente | Prestador | Ambos (capitalizado)
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
        'endereco': {
          'cep': cepController.text.trim(),
          'cidade': cidadeController.text.trim(),
          'rua': ruaController.text.trim(),
          'numero': numeroController.text.trim(),
          'bairro': bairroController.text.trim(),
          'complemento': complementoController.text.trim(),
          'whatsapp': whatsappController.text.trim(),
        },
        if (isPrestador) ...{
          'categoriaProfissionalId': categoriaProfissionalId, // só o ID
          'descricao': descricaoController.text.trim(),
          'tempoExperiencia': tempoExperiencia,
          'areaAtendimento': areaAtendimentoController.text.trim(),
          'meiosPagamento': meiosPagamento.toSet().toList(), // evita duplicados
          'jornada': jornada.toSet().toList(),
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este e-mail já está em uso.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'weak-password':
          msg = 'Senha fraca. Use 6+ caracteres.';
          break;
        default:
          msg = 'Falha no cadastro: ${e.message ?? e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      // rollback: se Auth criou e Firestore falhou, exclui o usuário do Auth
      if (cred?.user != null) {
        try {
          await cred!.user!.delete();
        } catch (_) {}
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar dados: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Usuário')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dados básicos
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              TextFormField(
                controller: confirmarSenhaController,
                decoration: const InputDecoration(labelText: 'Confirmar senha'),
                obscureText: true,
              ),
              DropdownButtonFormField(
                initialValue: tipoPerfil,
                items: const ['Cliente', 'Prestador', 'Ambos']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => tipoPerfil = v!),
                decoration: const InputDecoration(labelText: 'Tipo de perfil'),
              ),
              const Divider(),

              // Endereço
              TextFormField(
                controller: cepController,
                decoration: const InputDecoration(labelText: 'CEP'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: cidadeController,
                decoration: const InputDecoration(labelText: 'Cidade'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: ruaController,
                decoration: const InputDecoration(labelText: 'Rua'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: numeroController,
                decoration: const InputDecoration(labelText: 'Número'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: bairroController,
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: complementoController,
                decoration: const InputDecoration(labelText: 'Complemento'),
              ),
              TextFormField(
                controller: whatsappController,
                decoration: const InputDecoration(labelText: 'WhatsApp'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),

              // Bloco do Prestador
              if (isPrestador) ...[
                const Divider(),

                // Categoria (somente ativas) via StreamBuilder
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoriasStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return DropdownButtonFormField<String>(
                        items: const [], // isto pode ser const
                        onChanged: null,
                        decoration: const InputDecoration(
                          labelText: 'Categoria Profissional',
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

                    if (categoriaProfissionalId != null &&
                        !docs.any((d) => d.id == categoriaProfissionalId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => categoriaProfissionalId = null);
                      });
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: categoriaProfissionalId,
                      items: itens,
                      onChanged: (id) =>
                          setState(() => categoriaProfissionalId = id),
                      decoration: const InputDecoration(
                        labelText: 'Categoria Profissional',
                      ),
                      hint: const Text('Selecione a categoria'),
                      validator: (_) =>
                          (isPrestador &&
                              (categoriaProfissionalId == null ||
                                  categoriaProfissionalId!.isEmpty))
                          ? 'Obrigatório'
                          : null,
                    );
                  },
                ),

                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (mín. 100 caracteres)',
                  ),
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().length < 100)
                      ? 'Mínimo 100 caracteres'
                      : null,
                ),

                DropdownButtonFormField(
                  initialValue: tempoExperiencia.isNotEmpty ? tempoExperiencia : null,
                  hint: const Text('Selecione'),
                  items: experiencias
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => tempoExperiencia = v!),
                  decoration: const InputDecoration(
                    labelText: 'Tempo de experiência',
                  ),
                  validator: (_) =>
                      tempoExperiencia.isEmpty ? 'Obrigatório' : null,
                ),

                TextFormField(
                  controller: areaAtendimentoController,
                  decoration: const InputDecoration(
                    labelText: 'Cidade / Área de atendimento',
                    hintText: 'Ex: Rio Verde',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
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
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                ),
                ...['Dinheiro', 'Pix', 'Cartão de crédito/débito'].map(
                  (e) => CheckboxListTile(
                    title: Text(e),
                    value: meiosPagamento.contains(e),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!meiosPagamento.contains(e)) meiosPagamento.add(e);
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
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple),
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
                onPressed: _cadastrar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Cadastrar'),
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
