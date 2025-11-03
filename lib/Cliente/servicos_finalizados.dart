// lib/Cliente/servicosFinalizados.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'avaliar_prestador.dart';
import 'avaliacoes.dart';

class ServicosFinalizadosScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const ServicosFinalizadosScreen({super.key, this.firestore, this.auth});

  @override
  State<ServicosFinalizadosScreen> createState() =>
      _ServicosFinalizadosScreenState();
}

class _ServicosFinalizadosScreenState extends State<ServicosFinalizadosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  FirebaseFirestore get firestore =>
      widget.firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => widget.auth ?? FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        title: const Text(
          'Serviços Finalizados',
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Finalizados'),
            Tab(text: 'Minhas avaliações'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          TabFinalizados(firestore: firestore, auth: auth),
          MinhasAvaliacoesTab(firestore: firestore, auth: auth),
        ],
      ),
    );
  }
}

class TabFinalizados extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const TabFinalizados({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final userId = auth.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('Usuário não autenticado'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('solicitacoesOrcamento')
          .where('clienteId', isEqualTo: userId)
          .where('status', isEqualTo: 'finalizada')
          .snapshots(),
      builder: (context, snapshot) {
        // ✅ Ajuste: primeiro checa se ainda está carregando
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // ✅ Só mostra “Nenhum serviço” depois que stream emitiu algo
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhum serviço finalizado.'));
        }

        final servicos = snapshot.data!.docs;

        return ListView.builder(
          itemCount: servicos.length,
          itemBuilder: (context, index) {
            final servico = servicos[index].data() as Map<String, dynamic>;

            final servicoId = servicos[index].id;
            final titulo = servico['servicoTitulo'] ?? 'Sem título';
            final descricao = servico['servicoDescricao'] ?? '';
            final prestador = servico['prestadorNome'] ?? 'Sem prestador';
            final cidade = servico['clienteEndereco']?['cidade'] ?? '';
            final servicoIdRef = servico['servicoId'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: firestore.collection('servicos').doc(servicoIdRef).get(),
              builder: (context, snapServ) {
                if (snapServ.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                String imagemUrl = '';
                if (snapServ.hasData && snapServ.data!.exists) {
                  final servicoData =
                      snapServ.data!.data() as Map<String, dynamic>;
                  final catId = servicoData['categoriaId'] ?? '';
                  if (catId.isNotEmpty) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: firestore
                          .collection('categoriasServicos')
                          .doc(catId)
                          .get(),
                      builder: (context, snapCat) {
                        if (snapCat.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        if (snapCat.hasData && snapCat.data!.exists) {
                          imagemUrl =
                              (snapCat.data!.data() as Map)['imagemUrl'] ?? '';
                        }
                        return _buildCard(
                          context,
                          imagemUrl,
                          titulo,
                          descricao,
                          prestador,
                          cidade,
                          servicoId,
                        );
                      },
                    );
                  }
                }

                return _buildCard(
                  context,
                  imagemUrl,
                  titulo,
                  descricao,
                  prestador,
                  cidade,
                  servicoId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    String imagemUrl,
    String titulo,
    String descricao,
    String prestador,
    String cidade,
    String solicitacaoId,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: SizedBox(
          width: 64,
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imagemUrl.isNotEmpty
                ? Image.network(imagemUrl, fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFFD1C4E9),
                    child: const Icon(
                      Icons.image_outlined,
                      color: Colors.deepPurple,
                    ),
                  ),
          ),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (descricao.isNotEmpty)
              Text(
                descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            const SizedBox(height: 6),
            Text('Prestador: $prestador',
                style: const TextStyle(fontSize: 13.5)),
            if (cidade.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.black54),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      cidade,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13),
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AvaliarPrestadorScreen(
                  solicitacaoId: solicitacaoId,
                  firestore: firestore,
                  auth: auth,
                ),
              ),
            );
          },
          child: const Text('Avaliar'),
        ),
      ),
    );
  }
}
