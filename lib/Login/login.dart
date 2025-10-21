import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cadastroUsuarios.dart';
import 'recuperarSenha.dart';
import 'package:myapp/Cliente/homeCliente.dart' show HomeScreen;
import 'package:myapp/Prestador/homePrestador.dart' show HomePrestadorScreen;

// ============================================================
// 🟣 Tela de Login
// ============================================================
class LoginScreen extends StatefulWidget {
  // ✅ Injeção para testes
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  // ✅ Builders opcionais (usados nos testes)
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

  // ✅ Construtor alternativo para testes isolados
  LoginScreenState({FirebaseAuth? auth, FirebaseFirestore? firestore}) {
    _auth = auth;
    _firestore = firestore;
  }

  @override
  void initState() {
    super.initState();
    _auth ??= widget.auth ?? FirebaseAuth.instance;
    _firestore ??= widget.firestore ?? FirebaseFirestore.instance;
  }

  // ============================================================
  // 🔹 Normaliza o tipo de perfil
  // ============================================================
  String normalizePerfil(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'administrador' || v == 'admin') return 'Administrador';
    if (v == 'prestador' || v == 'fornecedor') return 'Prestador';
    if (v == 'cliente' || v == 'user' || v == 'usuario') return 'Cliente';
    return 'Cliente';
  }

  // ============================================================
  // 🔹 Copia subcoleções de um usuário antigo para o novo UID
  // ============================================================
  Future<void> copiarSubcolecao({
    required CollectionReference usuariosCol,
    required String antigoId,
    required String novoUid,
    required String subcolecao,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? _firestore!;
    final snap = await usuariosCol.doc(antigoId).collection(subcolecao).get();
    if (snap.docs.isEmpty) return;

    final batch = db.batch();
    for (final s in snap.docs) {
      final destino = usuariosCol.doc(novoUid).collection(subcolecao).doc(s.id);
      batch.set(destino, s.data(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ============================================================
  // 🔹 Migra usuário antigo, se necessário
  // ============================================================
  Future<void> migrarUsuarioSeNecessario({
    required String uid,
    required String email,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? _firestore!;
    final col = db.collection('usuarios');

    final docUID = await col.doc(uid).get();
    if (docUID.exists) return;

    final q = await col.where('email', isEqualTo: email.toLowerCase()).limit(1).get();

    if (q.docs.isEmpty) {
      await col.doc(uid).set({
        'uid': uid,
        'email': email.toLowerCase(),
        'tipoPerfil': 'Cliente',
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
        'migrado': true,
        'migradoObs': 'Criado automaticamente pois não havia doc antigo',
      });
      return;
    }

    final antigo = q.docs.first;
    final antigoData = Map<String, dynamic>.from(antigo.data());
    antigoData['tipoPerfil'] = normalizePerfil(antigoData['tipoPerfil'] as String?);
    antigoData['uid'] = uid;
    antigoData['email'] = email.toLowerCase();
    antigoData['migrado'] = true;
    antigoData['migradoEm'] = FieldValue.serverTimestamp();
    antigoData['migradoDe'] = antigo.id;

    await col.doc(uid).set(antigoData, SetOptions(merge: true));

    await copiarSubcolecao(
      usuariosCol: col,
      antigoId: antigo.id,
      novoUid: uid,
      subcolecao: 'servicos',
      firestore: db,
    );
    await copiarSubcolecao(
      usuariosCol: col,
      antigoId: antigo.id,
      novoUid: uid,
      subcolecao: 'enderecos',
      firestore: db,
    );

    try {
      await col.doc(antigo.id).delete();
    } catch (_) {}
  }

  // ============================================================
  // 🔹 Login principal
  // ============================================================
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
      await migrarUsuarioSeNecessario(uid: uid, email: email);

      final doc = await _firestore!.collection('usuarios').doc(uid).get();
      final tipo = (doc['tipoPerfil'] ?? 'cliente').toString().toLowerCase();

      final prefs = await SharedPreferences.getInstance();
      String perfilAtivo = tipo;

      if (tipo == 'ambos') {
        perfilAtivo = prefs.getString('perfilAtivo') ?? 'cliente';
        await prefs.setString('perfilAtivo', perfilAtivo);
      } else {
        await prefs.setString('perfilAtivo', tipo);
      }

      if (!mounted) return;

      if (perfilAtivo == 'prestador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: widget.homePrestadorBuilder ??
                (_) => HomePrestadorScreen(key: const Key('homePrestador')),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: widget.homeClienteBuilder ?? (_) => HomeScreen(),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  // ============================================================
  // 🔹 Interface de Login
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
              ),
              TextFormField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a senha' : null,
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
              const SizedBox(height: 20),
              ElevatedButton(onPressed: login, child: const Text('Entrar')),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CadastroUsuario()),
                ),
                child: const Text('Criar conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
