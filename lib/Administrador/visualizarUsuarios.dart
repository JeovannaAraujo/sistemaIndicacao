import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisualizarUsuarios extends StatefulWidget {
  const VisualizarUsuarios({super.key});

  @override
  State<VisualizarUsuarios> createState() => _VisualizarUsuariosState();
}

class _VisualizarUsuariosState extends State<VisualizarUsuarios> {
  String _filtroSelecionado = 'todos';
  final usuariosRef = FirebaseFirestore.instance.collection('usuarios');

  @override
  Widget build(BuildContext context) {
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
                  setState(() {
                    _filtroSelecionado = value;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'cliente', child: Text('Clientes')),
                DropdownMenuItem(
                  value: 'prestador',
                  child: Text('Prestadores'),
                ),
                DropdownMenuItem(
                  value: 'administrador',
                  child: Text('Administradores'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _filtroSelecionado == 'todos'
                    ? usuariosRef.orderBy('nome').snapshots()
                    : usuariosRef
                          .where('tipoPerfil', isEqualTo: _filtroSelecionado)
                          .orderBy('nome')
                          .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Erro ao carregar usuários'),
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
                      final user =
                          usuarios[index].data() as Map<String, dynamic>;

                      return ListTile(
                        leading: const Icon(
                          Icons.person_outline,
                          color: Colors.deepPurple,
                        ),
                        title: Text(user['nome'] ?? '-'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? '-'),
                            const SizedBox(height: 4),
                            Text('Tipo: ${user['tipoPerfil'] ?? 'cliente'}'),
                          ],
                        ),
                        trailing: Switch(
                          value: user['ativo'] == true,
                          onChanged: (val) => usuariosRef
                              .doc(usuarios[index].id)
                              .update({'ativo': val}),
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
