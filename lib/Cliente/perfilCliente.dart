// lib/Cliente/perfilCliente.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'rotasNavegacao.dart';
import 'editarPerfilCliente.dart';

class PerfilCliente extends StatefulWidget {
  final String userId;
  const PerfilCliente({super.key, required this.userId});

  @override
  State<PerfilCliente> createState() => _PerfilClienteState();
}

class _PerfilClienteState extends State<PerfilCliente> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Cliente não encontrado.'));
          }

          final data = snap.data!.data()!;
          final nome = (data['nome'] ?? '') as String;
          final email = (data['email'] ?? '') as String;
          final fotoUrl = (data['fotoUrl'] ?? '') as String;
          final endereco = (data['endereco'] as Map<String, dynamic>?) ?? {};

          final cidade = (endereco['cidade'] ?? '') as String;
          final rua = (endereco['rua'] ?? '') as String;
          final numero = (endereco['numero'] ?? '') as String;
          final bairro = (endereco['bairro'] ?? '') as String;
          final complemento = (endereco['complemento'] ?? '') as String;
          final cep = (endereco['cep'] ?? '') as String;
          final whatsapp = (endereco['whatsapp'] ?? '') as String;

          // "Rua alelo, 123, qd 1, bairro: ababa, Rio Verde, CEP: 75900-000"
          String enderecoLinha() {
            final partes = <String>[];

            // Rua + número + complemento
            final ruaNumComp = <String>[];
            if (rua.isNotEmpty) ruaNumComp.add(rua);
            if (numero.isNotEmpty) ruaNumComp.add(numero);
            if (complemento.isNotEmpty) ruaNumComp.add(complemento);
            if (ruaNumComp.isNotEmpty) partes.add(ruaNumComp.join(', '));

            // Bairro com rótulo
            if (bairro.isNotEmpty) partes.add('bairro: $bairro');

            // Cidade
            if (cidade.isNotEmpty) partes.add(cidade);

            // CEP com rótulo
            if (cep.isNotEmpty) partes.add('CEP: $cep');

            return partes.join(', ');
          }

          final enderecoFormatado = enderecoLinha();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Cabeçalho =====
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.deepPurple.shade50,
                      backgroundImage: fotoUrl.isNotEmpty
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: fotoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 34,
                              color: Colors.deepPurple,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome.isNotEmpty ? nome : 'Cliente',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.locationDot,
                                size: 14,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  cidade.isNotEmpty
                                      ? cidade
                                      : 'Cidade não informada',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (whatsapp.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(whatsapp),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ===== Título "Endereço" fora do card =====
                const Text(
                  'Endereço',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                // ===== Card de endereço ocupando a largura =====
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    color: Colors.deepPurple.shade50.withOpacity(0.4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        enderecoFormatado.isNotEmpty
                            ? enderecoFormatado
                            : 'Endereço ainda não cadastrado.',
                        style: TextStyle(
                          color: enderecoFormatado.isNotEmpty
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== Botão: Editar Perfil =====
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditarPerfilCliente(userId: widget.userId),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Perfil'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // ======= BottomNavigationBar do cliente =======
      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 3),
    );
  }
}
