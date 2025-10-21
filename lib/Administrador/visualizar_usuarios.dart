import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisualizarUsuarios extends StatefulWidget {
  final FirebaseFirestore? firestore; // 🔹 permite injetar o Firestore fake nos testes
  const VisualizarUsuarios({super.key, this.firestore});

  @override
  State<VisualizarUsuarios> createState() => _VisualizarUsuariosState();
}

class _VisualizarUsuariosState extends State<VisualizarUsuarios> {
  String _filtroSelecionado = 'todos';

  // 🔹 usa o firestore injetado nos testes, ou o real no app
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
      appBar: AppBar(
        title: const Text('Usuários Cadastrados'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visualize todos os usuários cadastrados no sistema',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _filtroSelecionado,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _filtroSelecionado = value);
                }
              },
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'Cliente', child: Text('Clientes')),
                DropdownMenuItem(value: 'Prestador', child: Text('Prestadores')),
                DropdownMenuItem(value: 'Administrador', child: Text('Administradores')),
              ],
            ),
            const SizedBox(height: 16),
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

                  return ListView.separated(
                    itemCount: usuarios.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final user = usuarios[index].data();
                      final nome = (user['nome'] ?? '-') as String;
                      final email = (user['email'] ?? '-') as String;
                      final tipoPerfil = (user['tipoPerfil'] ?? 'Cliente') as String;
                      final ativo = user['ativo'] == true;

                      return ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Colors.deepPurple,
                        ),
                        title: Text(nome),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email),
                            const SizedBox(height: 4),
                            Text('Tipo: $tipoPerfil'),
                          ],
                        ),
                        trailing: Switch(
                          value: ativo,
                          onChanged: (val) async {
                            try {
                              await usuariosRef.doc(usuarios[index].id).update({
                                'ativo': val,
                                'atualizadoEm': FieldValue.serverTimestamp(),
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
                                  content: Text(
                                    'Falha ao atualizar: ${e.code}',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Falha ao atualizar: $e'),
                                ),
                              );
                            }
                          },
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
