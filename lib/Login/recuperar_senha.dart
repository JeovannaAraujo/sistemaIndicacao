import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecuperarSenhaScreen extends StatefulWidget {
  final FirebaseAuth? auth; // ✅ injeção via construtor

  const RecuperarSenhaScreen({super.key, this.auth});

  @override
  State<RecuperarSenhaScreen> createState() => _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends State<RecuperarSenhaScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final FirebaseAuth _auth; // ✅ instanciado a partir do widget

  bool _enviando = false;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance; // ✅ usa mock se existir
  }

  Future<void> _recuperarSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _mensagem = null;
    });

    try {
      try {
        await _auth.setLanguageCode('pt');
      } catch (_) {
        // Ignora se o mock do FirebaseAuth não implementa esse método
      }

      await _auth.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      setState(() {
        _mensagem =
            'Um link para redefinir sua senha foi enviado para o e-mail informado.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _mensagem = 'Não há usuário registrado com este e-mail.';
        } else if (e.code == 'invalid-email') {
          _mensagem = 'E-mail inválido.';
        } else {
          _mensagem = 'Erro ao enviar o e-mail. Tente novamente.';
        }
      });
    } finally {
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Digite seu e-mail cadastrado para receber o link de redefinição de senha:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Informe seu e-mail';
                  }
                  if (!v.contains('@')) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _recuperarSenha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _enviando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Enviar link',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              if (_mensagem != null)
                Text(
                  _mensagem!,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
