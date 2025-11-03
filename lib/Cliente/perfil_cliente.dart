import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'rotas_navegacao.dart';
import 'editar_perfil_cliente.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Prestador/home_prestador.dart';

class PerfilCliente extends StatefulWidget {
  final String userId;
  final FirebaseFirestore? firestore;

  const PerfilCliente({
    super.key,
    required this.userId,
    this.firestore,
  });

  @override
  State<PerfilCliente> createState() => _PerfilClienteState();
}

class _PerfilClienteState extends State<PerfilCliente> {
  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore ?? FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore
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

          final rawEndereco = data['endereco'];
          final endereco = rawEndereco is Map
              ? rawEndereco.map((k, v) => MapEntry(k.toString(), v))
              : <String, dynamic>{};

          final cidade = (endereco['cidade'] ?? '') as String;
          final rua = (endereco['rua'] ?? '') as String;
          final numero = (endereco['numero'] ?? '') as String;
          final bairro = (endereco['bairro'] ?? '') as String;
          final complemento = (endereco['complemento'] ?? '') as String;
          final cep = (endereco['cep'] ?? '') as String;
          final whatsapp = (endereco['whatsapp'] ?? '') as String;

          String enderecoLinha() {
            final partes = <String>[];
            final ruaNumComp = <String>[];

            if (rua.isNotEmpty) ruaNumComp.add(rua);
            if (numero.isNotEmpty) ruaNumComp.add(numero);
            if (complemento.isNotEmpty) ruaNumComp.add(complemento);
            if (ruaNumComp.isNotEmpty) partes.add(ruaNumComp.join(', '));

            if (bairro.isNotEmpty) partes.add('bairro: $bairro');
            if (cidade.isNotEmpty) partes.add(cidade);
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
                      backgroundImage:
                          fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
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
                            Text(email,
                                style: const TextStyle(color: Colors.grey)),
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

                const Text(
                  'Endereço',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    color: Colors.deepPurple.shade50.withAlpha(102),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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

                if ((data['tipoPerfil'] ?? '') == 'Ambos') ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();

                        // ✅ aguarda, depois verifica se o widget ainda está montado
                        if (!mounted) return;

                        await prefs.setString('perfilAtivo', 'Prestador');
                        if (!mounted) return;

                        Navigator.pushReplacement(
                          // ignore: use_build_context_synchronously
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HomePrestadorScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Trocar para Prestador'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.deepPurple),
                        foregroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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

                      // ✅ garante que o widget ainda existe antes do setState
                      if (!mounted) return;
                      setState(() {});
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
      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 3),
    );
  }
}
