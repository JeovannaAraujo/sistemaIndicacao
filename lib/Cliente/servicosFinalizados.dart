import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// importa a aba "Minhas avaliações" separada
import 'avaliacoes.dart';

class ServicosFinalizadosScreen extends StatefulWidget {
  const ServicosFinalizadosScreen({super.key});

  @override
  State<ServicosFinalizadosScreen> createState() =>
      _ServicosFinalizadosScreenState();
}

class _ServicosFinalizadosScreenState extends State<ServicosFinalizadosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

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
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Serviços Finalizados'),
        backgroundColor: Colors.white,
        elevation: 0.3,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tab,
              labelColor: const Color(0xFF5E35B1),
              unselectedLabelColor: Colors.black87,
              indicatorColor: const Color(0xFF5E35B1),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Finalizado'),
                Tab(text: 'Minhas avaliações'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_TabFinalizados(), MinhasAvaliacoesTab()],
      ),
    );
  }
}

/* ======================== TAB 1: FINALIZADOS ======================== */

class _TabFinalizados extends StatelessWidget {
  const _TabFinalizados();

  static const _colSolic = 'solicitacoesOrcamento';

  String _fmtData(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection(_colSolic)
        .where('clienteId', isEqualTo: uid)
        .where('status', isEqualTo: 'finalizada')
        .orderBy('dataFinalizacaoReal', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Erro: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Nenhum serviço finalizado ainda.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();

            final titulo = (d['servicoTitulo'] ?? 'Serviço').toString();
            final prestadorId = (d['prestadorId'] ?? '').toString();
            final servicoId = (d['servicoId'] ?? '').toString();

            final endereco = _fmtEndereco(
              (d['clienteEndereco'] ?? d['endereco']) as Map<String, dynamic>?,
            );
            final inicio = _fmtData(d['dataInicioSugerida']);
            final fim = _fmtData(
              d['dataFinalizacaoReal'] ?? d['dataFinalPrevista'],
            );
            final valor = _fmtMoeda(d['valorProposto']);

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Imagem: servicoId -> servicos -> categoriaId -> categoriasServicos.imagemUrl
                  _CategoriaImageFromServicoId(servicoId: servicoId),

                  const SizedBox(width: 12),

                  // Conteúdo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Prestador
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(prestadorId)
                              .get(),
                          builder: (_, usnap) {
                            if (usnap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            if (usnap.hasError) {
                              return const Text(
                                'Prestador',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.black54,
                                ),
                              );
                            }

                            final nome =
                                (usnap.data?.data()?['nome'] ?? 'Prestador')
                                    .toString();

                            return Text(
                              'Prestador: $nome',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.black54,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        // Período
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$inicio – $fim',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Endereço
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                endereco,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Valor
                        Text(
                          valor,
                          style: const TextStyle(
                            color: Color(0xFF5E35B1),
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Botão Avaliar (embaixo e full width)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AvaliarServicoScreen(
                                    solicitacaoId: doc.id,
                                    prestadorId: prestadorId,
                                    tituloServico: titulo,
                                    periodoTexto: '$inicio – $fim',
                                    enderecoTexto: endereco,
                                    valorTexto: valor,
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF5E35B1),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Avaliar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmtMoeda(dynamic v) {
    if (v is num) {
      return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);
    }
    return '—';
  }

  String _fmtEndereco(Map<String, dynamic>? e) {
    if (e == null) return '—';
    String rua = (e['rua'] ?? e['logradouro'] ?? '').toString();
    String numero = (e['numero'] ?? '').toString();
    String bairro = (e['bairro'] ?? '').toString();
    String compl = (e['complemento'] ?? '').toString();
    String cidade = (e['cidade'] ?? '').toString();
    String uf = (e['estado'] ?? e['uf'] ?? '').toString();
    String cep = (e['cep'] ?? '').toString();
    final partes = <String>[];
    if (rua.isNotEmpty && numero.isNotEmpty) {
      partes.add('$rua, nº $numero');
    } else if (rua.isNotEmpty) {
      partes.add(rua);
    }
    if (bairro.isNotEmpty) partes.add(bairro);
    if (compl.isNotEmpty) partes.add(compl);
    if (cidade.isNotEmpty && uf.isNotEmpty) {
      partes.add('$cidade - $uf');
    } else if (cidade.isNotEmpty) {
      partes.add(cidade);
    }
    final end = partes.join(', ');
    return cep.isNotEmpty ? '$end, CEP $cep' : (end.isEmpty ? '—' : end);
  }
}

/* ============= WIDGET: Foto da categoria a partir do servicoId ============= */

class _CategoriaImageFromServicoId extends StatelessWidget {
  final String servicoId;
  const _CategoriaImageFromServicoId({required this.servicoId});

  @override
  Widget build(BuildContext context) {
    if (servicoId.isEmpty) return _emptyBox();

    // 1) servicos/{servicoId} -> categoriaId
    final servicoFut = FirebaseFirestore.instance
        .collection('servicos')
        .doc(servicoId)
        .get();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: servicoFut,
      builder: (context, servSnap) {
        if (servSnap.connectionState == ConnectionState.waiting) {
          return _emptyBox();
        }
        if (!servSnap.hasData || !servSnap.data!.exists) {
          return _emptyBox();
        }

        final serv = servSnap.data!.data() ?? {};
        final categoriaId = (serv['categoriaId'] ?? '').toString();
        if (categoriaId.isEmpty) return _emptyBox();

        // 2) categoriasServicos/{categoriaId} -> imagemUrl
        final catFut = FirebaseFirestore.instance
            .collection('categoriasServicos')
            .doc(categoriaId)
            .get();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: catFut,
          builder: (context, catSnap) {
            if (catSnap.connectionState == ConnectionState.waiting) {
              return _emptyBox();
            }
            final cat = catSnap.data?.data();
            final img = (cat?['imagemUrl'] ?? '').toString();

            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade200,
                child: img.isNotEmpty
                    ? Image.network(img, fit: BoxFit.cover)
                    : _emptyBox(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyBox() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
      );
}

/* ===================== TELA: AVALIAR SERVIÇO ===================== */

class AvaliarServicoScreen extends StatefulWidget {
  final String solicitacaoId;
  final String prestadorId;
  final String tituloServico;
  final String periodoTexto;
  final String enderecoTexto;
  final String valorTexto;

  const AvaliarServicoScreen({
    super.key,
    required this.solicitacaoId,
    required this.prestadorId,
    required this.tituloServico,
    required this.periodoTexto,
    required this.enderecoTexto,
    required this.valorTexto,
  });

  @override
  State<AvaliarServicoScreen> createState() => _AvaliarServicoScreenState();
}

class _AvaliarServicoScreenState extends State<AvaliarServicoScreen> {
  double _nota = 0;
  bool _enviando = false;

  final _comentarioCtl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _imagens = [];

  // futuro compartilhado para nome do prestador
  late final Future<String> _prestadorNomeFuture = FirebaseFirestore.instance
      .collection('usuarios')
      .doc(widget.prestadorId)
      .get()
      .then((d) => (d.data()?['nome'] ?? 'Prestador').toString());

  @override
  void dispose() {
    _comentarioCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (f != null) {
      setState(() => _imagens.add(f));
    }
  }

  Future<List<String>> _uploadImagensSeNecessario() async {
    // TODO: integrar com Firebase Storage e retornar URLs públicas
    return _imagens.map((x) => x.path).toList();
  }

  Future<void> _enviarAvaliacao() async {
    if (_nota <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma nota.')),
      );
      return;
    }
    if (_enviando) return;

    setState(() => _enviando = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final fotos = await _uploadImagensSeNecessario();

      // pega o nome do prestador pra salvar junto
      final prestadorSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.prestadorId)
          .get();
      final prestadorNome =
          (prestadorSnap.data()?['nome'] ?? 'Prestador').toString();

      // 1) cria avaliação
      final payload = {
        'solicitacaoId': widget.solicitacaoId,
        'clienteId': uid,
        'prestadorId': widget.prestadorId,
        'prestadorNome': prestadorNome,
        'nota': _nota,
        'comentario': _comentarioCtl.text.trim(),
        'imagens': fotos,
        'criadoEm': FieldValue.serverTimestamp(),

        // extras para listagem
        'servicoTitulo': widget.tituloServico,
        'valorTexto': widget.valorTexto,
        'periodoTexto': widget.periodoTexto,
        'enderecoTexto': widget.enderecoTexto,
      };

      await FirebaseFirestore.instance.collection('avaliacoes').add(payload);

      // 2) atualiza solicitação: finalizada -> avaliada
      await FirebaseFirestore.instance
          .collection('solicitacoesOrcamento')
          .doc(widget.solicitacaoId)
          .update({
        'status': 'avaliada',
        'avaliadaEm': FieldValue.serverTimestamp(),
        'avaliadaPor': uid,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada!')),
      );
      Navigator.of(context).pop(); // some da aba "Finalizado"
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        title: const Text('Avaliar Serviço'),
        backgroundColor: Colors.white,
        elevation: 0.3,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResumoServicoCard(
              titulo: widget.tituloServico,
              periodo: widget.periodoTexto,
              endereco: widget.enderecoTexto,
              valor: widget.valorTexto,
              prestadorNomeFuture: _prestadorNomeFuture,
            ),
            const SizedBox(height: 18),
            const Text(
              'Sua avaliação',
              style: TextStyle(
                color: Color(0xFF5E35B1),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _StarsInput(
              initial: _nota,
              onChanged: (v) => setState(() => _nota = v),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione uma nota',
              style: TextStyle(color: Colors.black54, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _comentarioCtl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Comentário (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload de Imagens',
              style: TextStyle(
                color: Color(0xFF5E35B1),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final x in _imagens)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(x.path),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                InkWell(
                  onTap: _enviando ? null : _pickImage,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarAvaliacao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E35B1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _enviando ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Color(0xFF5E35B1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF5E35B1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====================== WIDGETS DE APOIO ====================== */

class _ResumoServicoCard extends StatelessWidget {
  final String titulo;
  final String periodo;
  final String endereco;
  final String valor;
  final Future<String> prestadorNomeFuture;

  const _ResumoServicoCard({
    required this.titulo,
    required this.periodo,
    required this.endereco,
    required this.valor,
    required this.prestadorNomeFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          FutureBuilder<String>(
            future: prestadorNomeFuture,
            builder: (_, snap) {
              final nome = (snap.data ?? 'Prestador').toString();
              return Text(
                'Prestador: $nome',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14),
              const SizedBox(width: 6),
              Text(periodo, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(endereco, style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(
              color: Color(0xFF5E35B1),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsInput extends StatelessWidget {
  final double initial;
  final ValueChanged<double> onChanged;

  const _StarsInput({required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    double rating = initial;
    return StatefulBuilder(
      builder: (context, setSt) {
        Widget star(int i) {
          final filled = rating >= i;
          return GestureDetector(
            onTap: () {
              setSt(() => rating = i.toDouble());
              onChanged(rating);
            },
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: 34,
              color: const Color(0xFFFFC107),
            ),
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [for (var i = 1; i <= 5; i++) star(i)],
        );
      },
    );
  }
}
