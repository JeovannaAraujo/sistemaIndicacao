import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:myapp/Cliente/visualizarPerfilPrestador.dart';
import 'buscarServicos.dart';
import 'listarProfissionais.dart';
import 'rotasNavegacao.dart';
import 'servicosFinalizados.dart';

class HomeScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth; // ✅ Novo parâmetro para injetar o mock nos testes

  const HomeScreen({super.key, this.firestore, this.auth});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late FirebaseFirestore db;
  late FirebaseAuth auth;
  User? user;

  @override
  void initState() {
    super.initState();
    db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance; // ✅ Usa o mock se existir
    user = auth.currentUser;
  }

  int selectedIndex = 0;

  // 🔹 Categorias fixas
  static final categoriasFixas = [
    {
      'id': 'zONJ5iQBpjDNvWpSsQUS',
      'nome': 'Eletricista',
      'icone': Icons.flash_on,
      'cor': Colors.yellow,
    },
    {
      'id': 'iaRfReLyzu25IbClqnUp',
      'nome': 'Pedreiro',
      'icone': Icons.construction,
      'cor': Colors.green,
    },
    {
      'id': '6ChBGIhb3hPbBUfhfwBU',
      'nome': 'Encanador',
      'icone': Icons.water_drop,
      'cor': Colors.blue,
    },
    {
      'id': '5HO4ZYeUMU4h4yjPIIaO',
      'nome': 'Diarista',
      'icone': Icons.cleaning_services,
      'cor': Colors.grey,
    },
    {
      'id': 'HBXIAmBdcBWIiQb46h0T',
      'nome': 'Pintor',
      'icone': Icons.format_paint,
      'cor': Colors.purple,
    },
    {
      'id': 'j5WKHDv9XMu9ZcVXjRf1',
      'nome': 'Montador',
      'icone': Icons.chair_alt,
      'cor': Colors.orange,
    },
  ];

  // 🔹 Atualiza índice da BottomNav
  void onItemTapped(int index) {
    setState(() => selectedIndex = index);
  }

  // 🔹 Abre página de profissionais por categoria
  void abrirCategoria(String categoriaId, String categoriaNome) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfissionaisPorCategoriaScreen(
          categoriaId: categoriaId,
          categoriaNome: categoriaNome,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: GlobalKey<ScaffoldState>(), // ✅ garante controle independente
      drawerEnableOpenDragGesture:
          false, // ✅ evita comportamento inconsistente no teste
      // =================== DRAWER (cliente) ===================
      drawer: Drawer(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (auth.currentUser == null)
              ? const Stream.empty()
              : db
                    .collection('usuarios')
                    .doc(auth.currentUser!.uid)
                    .snapshots(),

          builder: (context, snap) {
            final dados = snap.data?.data() ?? {};
            final nome = (dados['nome'] ?? user?.displayName ?? 'Cliente')
                .toString();

            // cidade pode vir na raiz OU dentro de endereco
            final endereco = (dados['endereco'] as Map<String, dynamic>?) ?? {};
            final cidade = ((dados['cidade'] ?? endereco['cidade']) ?? '')
                .toString()
                .trim();

            // whatsapp pode vir como 'whatsApp' na raiz, ou 'whatsapp' no endereco
            final whatsRoot =
                (dados['whatsApp'] ?? dados['WhatsApp'] ?? '') as String?;
            final whatsEnd =
                (endereco['whatsapp'] ?? endereco['WhatsApp'] ?? '') as String?;
            final whatsapp = (whatsRoot?.trim().isNotEmpty == true
                ? whatsRoot!.trim()
                : (whatsEnd ?? '').trim());

            // foto (opcional)
            final fotoUrl = (dados['fotoUrl'] ?? '') as String?;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Colors.deepPurple),
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: (fotoUrl == null || fotoUrl.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.deepPurple,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),

                            if (cidade.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      cidade,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 6),

                            Row(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    whatsapp.isNotEmpty
                                        ? whatsapp
                                        : (user?.email ?? ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  context.goPerfil(replace: false);
                                },
                                child: const Text(
                                  'Ver perfil',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== Itens de menu (ajustado) =====
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Solicitações'),
                  onTap: () {
                    Navigator.pop(context);
                    context.goRespondidas();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: const Text('Serviços Finalizados'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServicosFinalizadosScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () async {
                    Navigator.pop(context); // 🔹 Fecha o Drawer primeiro
                    await auth.signOut(); // 🔹 Desloga o usuário
                    if (!context.mounted) return;

                    // 🔹 Remove todas as telas anteriores e limpa as streams
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BuscarServicosScreen(
                          firestore: db,
                          auth: auth, // ✅ passa o mock nos testes
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),

      appBar: AppBar(),
      body: buildBody(),

      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 0),
    );
  }

  // ==================== CONTEÚDO ====================
  Widget buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Indica Aí',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const Text(
            'Encontre os melhores profissionais de sua região',
            style: TextStyle(color: Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuscarServicosScreen()),
              );
            },
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar serviços ou profissionais...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Categorias',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: categoriasFixas.map((cat) {
                return categoriaItem(
                  label: cat['nome'].toString(),
                  iconData: cat['icone'] as IconData,
                  color: cat['cor'] as Color,
                  onTap: () => abrirCategoria(
                    cat['id'].toString(),
                    cat['nome'].toString(),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // ====== PROFISSIONAIS EM DESTAQUE ======
          const Text(
            'Profissionais em destaque',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: db.collection('avaliacoes').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'Nenhum profissional avaliado ainda.',
                  style: TextStyle(color: Colors.grey),
                );
              }

              final avaliacoes = snapshot.data!.docs;
              final Map<String, List<double>> notasPorPrestador = {};

              // Agrupa notas por prestadorId
              for (var doc in avaliacoes) {
                final dados = doc.data() as Map<String, dynamic>;
                final prestadorId = dados['prestadorId'];
                final nota = (dados['nota'] ?? 0).toDouble();

                if (prestadorId == null) continue;

                notasPorPrestador.putIfAbsent(prestadorId, () => []);
                notasPorPrestador[prestadorId]!.add(nota);
              }

              // Calcula média e total de avaliações
              final ranking = notasPorPrestador.map((id, notas) {
                final media = notas.reduce((a, b) => a + b) / notas.length;
                return MapEntry(id, {'media': media, 'total': notas.length});
              });

              // Ordena pela média e total de avaliações
              // Ordena pela média e total de avaliações (tratando nulos)
              final destaqueIds = ranking.keys.toList()
                ..sort((a, b) {
                  final mediaA = ranking[a]?['media'] ?? 0.0;
                  final mediaB = ranking[b]?['media'] ?? 0.0;
                  final totalA = ranking[a]?['total'] ?? 0;
                  final totalB = ranking[b]?['total'] ?? 0;

                  // Primeiro compara pela média, depois pelo total de avaliações
                  if (mediaA != mediaB) {
                    return mediaB.compareTo(mediaA);
                  }
                  return totalB.compareTo(totalA);
                });

              final top5 = destaqueIds.take(5).toList();

              if (top5.isEmpty) {
                return const Text(
                  'Nenhum profissional em destaque no momento.',
                  style: TextStyle(color: Colors.grey),
                );
              }

              // Busca dados dos profissionais (Prestador e Ambos)
              return StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('usuarios')
                    .where(FieldPath.documentId, whereIn: top5)
                    .where('ativo', isEqualTo: true)
                    .where('tipoPerfil', whereIn: ['Prestador', 'Ambos'])
                    .snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!userSnap.hasData || userSnap.data!.docs.isEmpty) {
                    return const Text(
                      'Nenhum profissional em destaque no momento.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  final profissionais = userSnap.data!.docs;

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: Future.wait(
                      profissionais.map((doc) async {
                        final dados = doc.data() as Map<String, dynamic>;
                        final categoriaId = dados['categoriaProfissionalId'];
                        String categoriaNome = 'Sem categoria';

                        if (categoriaId != null &&
                            categoriaId.toString().isNotEmpty) {
                          final catSnap = await db
                              .collection('categoriasProfissionais')
                              .doc(categoriaId)
                              .get();
                          if (catSnap.exists) {
                            categoriaNome =
                                (catSnap.data()?['nome'] ?? 'Sem categoria')
                                    .toString();
                          }
                        }

                        final id = doc.id;
                        return {
                          'id': id,
                          'nome': dados['nome'] ?? 'Profissional sem nome',
                          'categoria': categoriaNome,
                          'fotoUrl': dados['fotoUrl'] ?? '',
                          'media': ranking[id]!['media'],
                          'total': ranking[id]!['total'],
                        };
                      }),
                    ),
                    builder: (context, futureSnap) {
                      if (futureSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!futureSnap.hasData || futureSnap.data!.isEmpty) {
                        return const Text(
                          'Nenhum profissional em destaque no momento.',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      final lista = futureSnap.data!;

                      return Column(
                        children: lista.map((prof) {
                          return ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisualizarPerfilPrestador(
                                    prestadorId: prof['id'],
                                    firestore: db, // ✅ injeta o fake Firestore
                                    auth: auth,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.deepPurple.shade100,
                              backgroundImage: (prof['fotoUrl'].isNotEmpty)
                                  ? NetworkImage(prof['fotoUrl'])
                                  : null,
                              child: (prof['fotoUrl'].isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.deepPurple,
                                    )
                                  : null,
                            ),
                            title: Text(
                              prof['nome'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  prof['categoria'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                Text(
                                  ' ${prof['media'].toStringAsFixed(1)} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '(${prof['total']} ${prof['total'] == 1 ? 'avaliação' : 'avaliações'})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.deepPurple,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget categoriaItem({
    required String label,
    required Color color,
    required IconData iconData,
    required VoidCallback onTap,
    String imagemUrl = '',
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(48),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            radius: 28,
            child: (imagemUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      imagemUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(iconData, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 90,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
