import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cadastro_usuarios.dart';
import 'recuperar_senha.dart';
import 'package:myapp/Cliente/home_cliente.dart' show HomeScreen;
import 'package:myapp/Prestador/home_prestador.dart' show HomePrestadorScreen;

/* ==========================================================
   🔹 Função auxiliar para traduzir códigos de erro do Firebase
   ========================================================== */
String traduzErroFirebase(String code) {
  switch (code) {
    case 'network-request-failed':
      return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
    case 'user-not-found':
      return 'E-mail não cadastrado.';
    case 'wrong-password':
      return 'Senha incorreta. Tente novamente.';
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'user-disabled':
      return 'Conta desativada.';
    case 'timeout':
      return 'Conexão muito lenta. Tente novamente.';
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'E-mail ou senha incorretos.';
    case 'expired-action-code':
    case 'credential-already-in-use':
    case 'operation-not-allowed':
      return 'Credenciais inválidas ou expiradas. Tente refazer o login.';
    default:
      return 'Erro ao entrar. Verifique sua conexão e tente novamente.';
  }
}

/* ==========================================================
   🔹 LoginScreen
   ========================================================== */

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

  /* ==========================================================
     🔹 Função de Login com tratamento de erros e conexão
     ========================================================== */
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final email = emailController.text.trim().toLowerCase();
      final senha = senhaController.text.trim();

      // Mostra loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Tenta autenticar com timeout
      final cred = await _auth!
          .signInWithEmailAndPassword(email: email, password: senha)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw FirebaseAuthException(
          code: 'timeout',
          message: 'Tempo de conexão excedido.',
        );
      });

      final uid = cred.user!.uid;
      final doc = await _firestore!.collection('usuarios').doc(uid).get();

      if (!doc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não encontrado no sistema.'),
            backgroundColor: Colors.deepPurple,
          ),
        );
        return;
      }

      final tipo =
          (doc.data()?['tipoPerfil']?.toString().toLowerCase() ?? 'cliente')
              .trim();
      final perfil = tipo.isEmpty ? 'cliente' : tipo;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perfilAtivo', perfil);

      if (!mounted) return;
      Navigator.pop(context); // Fecha o loading

      if (perfil == 'prestador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                widget.homePrestadorBuilder ??
                (_) => const HomePrestadorScreen(key: Key('homePrestador')),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: widget.homeClienteBuilder ?? (_) => const HomeScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      final msg = traduzErroFirebase(e.code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      Navigator.pop(context);
      final msg = e.message?.contains('network') == true
          ? 'Falha de rede. Verifique sua conexão com a internet.'
          : 'Erro de comunicação com o servidor.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    } catch (_) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro inesperado. Tente novamente mais tarde.'),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    }
  }

  /* ==========================================================
     🔹 Interface
     ========================================================== */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 25),

                      // Campo E-mail
                      TextFormField(
                        controller: emailController,
                        decoration: _inputDecoration('E-mail'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe o e-mail'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Campo Senha
                      TextFormField(
                        controller: senhaController,
                        decoration: _inputDecoration('Senha'),
                        obscureText: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe a senha'
                            : null,
                      ),

                      // Esqueci minha senha
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

                      // Criar conta
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CadastroUsuario(),
                              ),
                            );
                          },
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

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
}
