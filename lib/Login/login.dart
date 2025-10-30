import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cadastroUsuarios.dart';
import 'recuperarSenha.dart';
import 'package:myapp/Cliente/homeCliente.dart' show HomeScreen;
import 'package:myapp/Prestador/homePrestador.dart' show HomePrestadorScreen;

class LoginScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final WidgetBuilder? homeClienteBuilder;
  final WidgetBuilder? homePrestadorBuilder;

  const LoginScreen({
    super.key,
    this.auth,
    this.firestore,
    this.homeClienteBuilder,
    this.homePrestadorBuilder,
  });

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _auth ??= widget.auth ?? FirebaseAuth.instance;
    _firestore ??= widget.firestore ?? FirebaseFirestore.instance;
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final email = emailController.text.trim().toLowerCase();
      final senha = senhaController.text.trim();

      final cred = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final uid = cred.user!.uid;
      final doc = await _firestore!.collection('usuarios').doc(uid).get();
      final tipo = (doc['tipoPerfil'] ?? 'cliente').toString().toLowerCase();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perfilAtivo', tipo);

      if (!mounted) return;

      if (tipo == 'prestador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomePrestadorScreen(key: const Key('homePrestador')),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'E-mail não cadastrado.';
          break;
        case 'wrong-password':
          msg = 'Senha incorreta.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'user-disabled':
          msg = 'Usuário desativado.';
          break;
        default:
          msg = 'Falha ao entrar: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ faz a tela reagir ao teclado
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.3,
        centerTitle: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            // ✅ permite que o conteúdo se mova com o teclado
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // ✅ centraliza
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 25),

                      // Campo E-mail
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.deepPurple,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o e-mail'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Campo Senha
                      TextFormField(
                        controller: senhaController,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.deepPurple,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        obscureText: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe a senha'
                            : null,
                      ),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecuperarSenhaScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Esqueci minha senha',
                          style: TextStyle(color: Colors.deepPurple),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Botão Entrar
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: const Text(
                            'Entrar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Botão Criar Conta
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CadastroUsuario(),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE9D7FF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: const Text(
                            'Criar conta',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
