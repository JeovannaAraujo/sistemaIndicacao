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

  String tipoPerfil = 'Cliente';
  String categoriaProfissional = '';
  String tempoExperiencia = '';
  List<String> meiosPagamento = [];
  List<String> jornada = [];

  List<String> categoriasBanco = [];
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
    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categoriasProfissionais')
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .get();

    setState(() {
      categoriasBanco = snapshot.docs
          .map((doc) => doc['nome'] as String)
          .toList();
    });
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
      if (categoriaProfissional.isEmpty ||
          tempoExperiencia.isEmpty ||
          descricaoController.text.length < 50 ||
          areaAtendimentoController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preencha todos os campos obrigatórios do prestador.',
            ),
          ),
        );
        return;
      }
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      await _firestore.collection('usuarios').doc(cred.user!.uid).set({
        'nome': nomeController.text,
        'email': emailController.text,
        'tipoPerfil': tipoPerfil,
        'ativo': true,
        'endereco': {
          'cep': cepController.text,
          'cidade': cidadeController.text,
          'rua': ruaController.text,
          'numero': numeroController.text,
          'bairro': bairroController.text,
          'complemento': complementoController.text,
          'whatsapp': whatsappController.text,
        },
        if (isPrestador) ...{
          'categoriaProfissional': categoriaProfissional,
          'descricao': descricaoController.text,
          'tempoExperiencia': tempoExperiencia,
          'areaAtendimento': areaAtendimentoController.text,
          'meiosPagamento': meiosPagamento,
          'jornada': jornada,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
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
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              TextFormField(
                controller: confirmarSenhaController,
                decoration: const InputDecoration(labelText: 'Confirmar senha'),
                obscureText: true,
              ),
              DropdownButtonFormField(
                value: tipoPerfil,
                items: ['Cliente', 'Prestador', 'Ambos']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => tipoPerfil = v!),
                decoration: const InputDecoration(labelText: 'Tipo de perfil'),
              ),
              const Divider(),
              TextFormField(
                controller: cepController,
                decoration: const InputDecoration(labelText: 'CEP'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: cidadeController,
                decoration: const InputDecoration(labelText: 'Cidade'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: ruaController,
                decoration: const InputDecoration(labelText: 'Rua'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: numeroController,
                decoration: const InputDecoration(labelText: 'Número'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: bairroController,
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              TextFormField(
                controller: complementoController,
                decoration: const InputDecoration(labelText: 'Complemento'),
              ),
              TextFormField(
                controller: whatsappController,
                decoration: const InputDecoration(labelText: 'WhatsApp'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              if (isPrestador) ...[
                const Divider(),
                DropdownButtonFormField(
                  value: categoriaProfissional.isNotEmpty
                      ? categoriaProfissional
                      : null,
                  hint: const Text('Selecione a categoria'),
                  items: categoriasBanco
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => categoriaProfissional = v!),
                  decoration: const InputDecoration(
                    labelText: 'Categoria Profissional',
                  ),
                ),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (mín. 100 caracteres)',
                  ),
                  validator: (v) => v != null && v.length < 50
                      ? 'Mínimo 100 caracteres'
                      : null,
                ),
                DropdownButtonFormField(
                  value: tempoExperiencia.isNotEmpty ? tempoExperiencia : null,
                  hint: const Text('Selecione'),
                  items: experiencias
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => tempoExperiencia = v!),
                  decoration: const InputDecoration(
                    labelText: 'Tempo de experiência',
                  ),
                ),
                TextFormField(
                  controller: areaAtendimentoController,
                  decoration: const InputDecoration(
                    labelText: 'Cidade / Área de atendimento',
                    hintText: 'Ex: Rio Verde',
                  ),
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 4.0),
                  child: Text(
                    'Meios de pagamento aceitos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(
                  'Os meios de pagamento servem apenas para informativo para os clientes, nosso aplicativo não processa pagamentos!',
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                ),
                ...['Dinheiro', 'Pix', 'Cartão de crédito/débito'].map(
                  (e) => CheckboxListTile(
                    title: Text(e),
                    value: meiosPagamento.contains(e),
                    onChanged: (v) => setState(
                      () =>
                          v! ? meiosPagamento.add(e) : meiosPagamento.remove(e),
                    ),
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
                    onChanged: (v) =>
                        setState(() => v! ? jornada.add(e) : jornada.remove(e)),
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
