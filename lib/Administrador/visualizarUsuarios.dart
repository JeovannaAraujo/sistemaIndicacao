import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisualizarUsuarios extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const VisualizarUsuarios({super.key, this.firestore});

  @override
  State<VisualizarUsuarios> createState() => _VisualizarUsuariosState();
}

class _VisualizarUsuariosState extends State<VisualizarUsuarios> {
  String _filtroSelecionado = 'todos';

  CollectionReference<Map<String, dynamic>> get usuariosRef =>
      (widget.firestore ?? FirebaseFirestore.instance)
          .collection('usuarios');

  Query<Map<String, dynamic>> _buildQuery() {
    final base = usuariosRef;
    switch (_filtroSelecionado) {
      case 'todos':
        return base.orderBy('nome');
      case 'Cliente':
      case 'Prestador':
      case 'Administrador':
      case 'Ambos':
        return base
            .where('tipoPerfil', isEqualTo: _filtroSelecionado)
            .orderBy('nome');
      default:
        return base.orderBy('nome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _buildQuery();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Usuários Cadastrados',
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visualize e gerencie todos os usuários cadastrados no sistema',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Filtro estilizado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filtroSelecionado,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _filtroSelecionado = value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'Cliente', child: Text('Clientes')),
                    DropdownMenuItem(value: 'Prestador', child: Text('Prestadores')),
                    DropdownMenuItem(value: 'Ambos', child: Text('Ambos')),
                    DropdownMenuItem(value: 'Administrador', child: Text('Administradores')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Lista de usuários
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final e = snapshot.error;
                    String code = '-', msg = e.toString();
                    if (e is FirebaseException) {
                      code = e.code;
                      msg = e.message ?? e.toString();
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Erro ao carregar usuários.\ncode: $code\n$msg',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final usuarios = snapshot.data!.docs;
                  if (usuarios.isEmpty) {
                    return const Center(
                      child: Text('Nenhum usuário encontrado.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: usuarios.length,
                    itemBuilder: (context, index) {
                      final user = usuarios[index].data();
                      final nome = (user['nome'] ?? '-') as String;
                      final email = (user['email'] ?? '-') as String;
                      final tipoPerfil =
                          (user['tipoPerfil'] ?? 'Cliente') as String;
                      final ativo = user['ativo'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // 🔹 Ícone genérico
                            const Icon(Icons.person, color: Colors.deepPurple),
                            const SizedBox(width: 12),

                            // 🔹 Nome, e-mail e tipo
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nome,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(email,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text('Tipo: $tipoPerfil',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54)),
                                ],
                              ),
                            ),

                            // 🔹 Switch de ativo/inativo
                            Switch(
                              value: ativo,
                              activeColor: Colors.deepPurple,
                              onChanged: (val) async {
                                try {
                                  await usuariosRef
                                      .doc(usuarios[index].id)
                                      .update({
                                    'ativo': val,
                                    'atualizadoEm':
                                        FieldValue.serverTimestamp(),
                                  });
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        val
                                            ? 'Usuário ativado'
                                            : 'Usuário desativado',
                                      ),
                                    ),
                                  );
                                } on FirebaseException catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Falha ao atualizar: ${e.code}'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Falha ao atualizar: $e'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
