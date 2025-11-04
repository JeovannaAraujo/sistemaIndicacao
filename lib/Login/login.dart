import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/Administrador/perfil_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cadastro_usuarios.dart';
import 'recuperar_senha.dart';
import 'package:myapp/Cliente/home_cliente.dart' show HomeScreen;
import 'package:myapp/Prestador/home_prestador.dart' show HomePrestadorScreen;

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

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário não encontrado no sistema.'),
              backgroundColor: Colors.deepPurple,
            ),
          );
        }
        return;
      }

      final tipo =
          (doc.data()?['tipoPerfil']?.toString().toLowerCase() ?? 'cliente')
              .trim();
      final perfil = tipo.isEmpty ? 'cliente' : tipo;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perfilAtivo', perfil);

      if (!mounted) return;

      // 🔥 CORREÇÃO: Verificar TODOS os tipos de perfil
      switch (perfil) {
        case 'administrador':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const PerfilAdminScreen(), // ✅ Vai para admin
            ),
          );
          break;
        case 'prestador':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePrestadorScreen()),
          );
          break;
        case 'ambos':
          // 🔥 Decide qual painel mostrar para usuários com ambos os perfis
          // Pode mostrar um diálogo para escolher ou definir um padrão
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const HomePrestadorScreen(), // ou PerfilAdminScreen()
            ),
          );
          break;
        default: // cliente
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro inesperado ao fazer login.'),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    }
  }

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

                      // Esqueci minha senha
                      TextButton(
                        onPressed: () {
                          if (widget.homeClienteBuilder != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Scaffold(
                                  body: Center(
                                    child: Text('Recuperar Senha Mock'),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RecuperarSenhaScreen(),
                              ),
                            );
                          }
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
                          onPressed: () {
                            if (widget.homeClienteBuilder != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Scaffold(
                                    body: Center(child: Text('Cadastro Mock')),
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CadastroUsuario(),
                                ),
                              );
                            }
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
}
