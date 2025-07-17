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
  String tempoExperiencia = '0-1 ano';
  List<String> meiosPagamento = [];
  List<String> jornada = [];

  final categorias = ['Pedreiro', 'Eletricista', 'Encanador', 'Diarista'];
  final experiencias = ['0-1 ano', '1-3 anos', '3-5 anos', '5-10 anos', '+10 anos'];
  final diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];

  bool get isPrestador => tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos';

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (senhaController.text != confirmarSenhaController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.')),
      );
      return;
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
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
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
            children: [
              TextFormField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome completo'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: senhaController, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true, validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null),
              TextFormField(controller: confirmarSenhaController, decoration: const InputDecoration(labelText: 'Confirmar senha'), obscureText: true),
              DropdownButtonFormField(value: tipoPerfil, items: ['Cliente', 'Prestador', 'Ambos'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => tipoPerfil = v!), decoration: const InputDecoration(labelText: 'Tipo de perfil')),
              const Divider(),
              TextFormField(controller: cepController, decoration: const InputDecoration(labelText: 'CEP'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: cidadeController, decoration: const InputDecoration(labelText: 'Cidade'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: ruaController, decoration: const InputDecoration(labelText: 'Rua'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: numeroController, decoration: const InputDecoration(labelText: 'Número'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: bairroController, decoration: const InputDecoration(labelText: 'Bairro'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              TextFormField(controller: complementoController, decoration: const InputDecoration(labelText: 'Complemento')),
              TextFormField(controller: whatsappController, decoration: const InputDecoration(labelText: 'WhatsApp'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
              if (isPrestador) ...[
                const Divider(),
                DropdownButtonFormField(value: categoriaProfissional.isEmpty ? null : categoriaProfissional, items: categorias.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => categoriaProfissional = v!), decoration: const InputDecoration(labelText: 'Categoria Profissional')),
                TextFormField(controller: descricaoController, decoration: const InputDecoration(labelText: 'Descrição (mín. 100 caracteres)'), maxLines: 3, validator: (v) => v != null && v.length < 100 ? 'Mínimo 100 caracteres' : null),
                DropdownButtonFormField(value: tempoExperiencia, items: experiencias.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => tempoExperiencia = v!), decoration: const InputDecoration(labelText: 'Tempo de experiência')),
                TextFormField(controller: areaAtendimentoController, decoration: const InputDecoration(labelText: 'Área de atendimento'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
                Wrap(
                  children: ['Dinheiro', 'PIX', 'Cartão'].map((e) => CheckboxListTile(
                    title: Text(e), value: meiosPagamento.contains(e),
                    onChanged: (v) => setState(() => v! ? meiosPagamento.add(e) : meiosPagamento.remove(e)),
                  )).toList(),
                ),
                Wrap(
                  children: diasSemana.map((e) => CheckboxListTile(
                    title: Text(e), value: jornada.contains(e),
                    onChanged: (v) => setState(() => v! ? jornada.add(e) : jornada.remove(e)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _cadastrar,
                child: const Text('Cadastrar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
