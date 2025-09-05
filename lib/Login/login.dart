import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cadastroUsuarios.dart';
import '../Cliente/homeCliente.dart';
import '../Administrador/perfilAdmin.dart';
import '../Prestador/perfilPrestador.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  Future<void> _migrarUsuarioSeNecessario({
    required String uid,
    required String email,
  }) async {
    final col = FirebaseFirestore.instance.collection('usuarios');

    // Se já existe no padrão correto (doc ID = uid), nada a fazer.
    final docUID = await col.doc(uid).get();
    if (docUID.exists) return;

    // Buscar um doc antigo pelo e-mail (ID aleatório)
    final q = await col
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      // Não existe documento antigo — cria um mínimo, para não travar o fluxo.
      await col.doc(uid).set({
        'uid': uid,
        'email': email.toLowerCase(),
        'tipoPerfil': 'cliente',
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
        'migrado': true,
        'migradoObs': 'Criado automaticamente pois não havia doc antigo',
      });
      return;
    }

    // Copiar dados do doc antigo para o novo doc com ID = uid
    final antigo = q.docs.first;
    final antigoData = Map<String, dynamic>.from(antigo.data());

    antigoData['uid'] = uid;
    antigoData['email'] = email.toLowerCase();
    antigoData['migrado'] = true;
    antigoData['migradoEm'] = FieldValue.serverTimestamp();
    antigoData['migradoDe'] = antigo.id;

    // 1) Copia o doc top-level
    await col.doc(uid).set(antigoData, SetOptions(merge: true));

    // 2) (Opcional) copiar subcoleções conhecidas (ex.: 'servicos')
    // Se tiver outras, repita o bloco alterando o nome.
    final subServicosSnap = await col
        .doc(antigo.id)
        .collection('servicos')
        .get();
    if (subServicosSnap.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final s in subServicosSnap.docs) {
        final destino = col.doc(uid).collection('servicos').doc(s.id);
        batch.set(destino, s.data(), SetOptions(merge: true));
      }
      await batch.commit();
    }

    // 3) (Recomendado) apagar doc antigo após validar no console
    await col.doc(antigo.id).delete();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final email = emailController.text.trim().toLowerCase();
      final senha = senhaController.text.trim();

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final uid = cred.user!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get(); // permitido pelas regras acima

      // MIGRAR se necessário (antigos com ID aleatório)
      await _migrarUsuarioSeNecessario(uid: uid, email: email);

      // Agora ler SEMPRE por doc(uid)
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Usuário não cadastrado no Firestore.');
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final tipoPerfil = (data['tipoPerfil'] as String?)?.toLowerCase();

      if (tipoPerfil == 'administrador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PerfilAdminScreen()),
        );
      } else if (tipoPerfil == 'prestador' || tipoPerfil == 'ambos') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PerfilPrestador(userId: uid)),
        );
      } else {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

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
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _login, child: const Text('Entrar')),
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
