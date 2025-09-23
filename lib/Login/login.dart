import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cadastroUsuarios.dart';
import '../Cliente/homeCliente.dart';
import '../Administrador/perfilAdmin.dart';
import '../Prestador/homePrestador.dart';

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

  /// Normaliza qualquer valor para o padrão exigido nas regras:
  /// "Administrador", "Prestador" ou "Cliente" (default).
  String _normalizePerfil(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'administrador' || v == 'admin') return 'Administrador';
    if (v == 'prestador' || v == 'fornecedor') return 'Prestador';
    if (v == 'cliente' || v == 'user' || v == 'usuario') return 'Cliente';
    return 'Cliente';
  }

  /// Copia documentos de uma subcoleção específica do doc antigo -> novo doc (ID=uid).
  Future<void> _copiarSubcolecao({
    required CollectionReference usuariosCol,
    required String antigoId,
    required String novoUid,
    required String subcolecao,
  }) async {
    final snap = await usuariosCol.doc(antigoId).collection(subcolecao).get();
    if (snap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final s in snap.docs) {
      final destino = usuariosCol.doc(novoUid).collection(subcolecao).doc(s.id);
      batch.set(destino, s.data(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Garante que exista `usuarios/{uid}`. Se não existir:
  ///  - tenta localizar doc antigo por e-mail e migra,
  ///  - ou cria um mínimo com tipoPerfil "Cliente".
  Future<void> _migrarUsuarioSeNecessario({
    required String uid,
    required String email,
  }) async {
    final col = FirebaseFirestore.instance.collection('usuarios');

    // Já existe no padrão (ID = uid)?
    final docUID = await col.doc(uid).get();
    if (docUID.exists) return;

    // Procura doc antigo por e-mail (ID aleatório).
    final q = await col
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      // Não há doc antigo -> cria mínimo com tipoPerfil correto (Cliente).
      await col.doc(uid).set({
        'uid': uid,
        'email': email.toLowerCase(),
        'tipoPerfil': 'Cliente', // **padrão conforme regra**
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
        'migrado': true,
        'migradoObs': 'Criado automaticamente pois não havia doc antigo',
      });
      return;
    }

    // Migra dados do doc antigo para o novo (ID = uid).
    final antigo = q.docs.first;
    final antigoData = Map<String, dynamic>.from(antigo.data());

    // Normaliza tipoPerfil para o padrão das regras.
    antigoData['tipoPerfil'] = _normalizePerfil(
      antigoData['tipoPerfil'] as String?,
    );

    antigoData['uid'] = uid;
    antigoData['email'] = email.toLowerCase();
    antigoData['migrado'] = true;
    antigoData['migradoEm'] = FieldValue.serverTimestamp();
    antigoData['migradoDe'] = antigo.id;

    // Copia doc top-level
    await col.doc(uid).set(antigoData, SetOptions(merge: true));

    // Copia subcoleções conhecidas (adicione outras se houver)
    await _copiarSubcolecao(
      usuariosCol: col,
      antigoId: antigo.id,
      novoUid: uid,
      subcolecao: 'servicos',
    );
    await _copiarSubcolecao(
      usuariosCol: col,
      antigoId: antigo.id,
      novoUid: uid,
      subcolecao: 'enderecos',
    );

    // Tenta remover o doc antigo (pode falhar pelas regras — best-effort)
    try {
      await col.doc(antigo.id).delete();
    } catch (_) {
      // Sem permissão? OK. Limpeza pode ser feita por admin/Cloud Function.
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final email = emailController.text.trim().toLowerCase();
      final senha = senhaController.text.trim();

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final uid = cred.user!.uid;

      // Migra se necessário (cria/ajusta usuarios/{uid}).
      await _migrarUsuarioSeNecessario(uid: uid, email: email);

      // Releitura garantida do doc correto
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('Usuário não cadastrado no Firestore.');
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final tipoPerfil = _normalizePerfil(data['tipoPerfil'] as String?);

      // Roteamento por perfil (mantendo telas atuais do seu app)
      if (tipoPerfil == 'Administrador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PerfilAdminScreen()),
        );
      } else if (tipoPerfil == 'Prestador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePrestadorScreen()),
        );
      } else {
        // Cliente (padrão)
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
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
