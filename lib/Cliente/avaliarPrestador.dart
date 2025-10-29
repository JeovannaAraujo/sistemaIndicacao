import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AvaliarPrestadorScreen extends StatefulWidget {
  final String solicitacaoId;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseStorage? storage;

  const AvaliarPrestadorScreen({
    super.key,
    required this.solicitacaoId,
    required this.firestore,
    required this.auth,
    this.storage,
  });

  @override
  State<AvaliarPrestadorScreen> createState() =>
      _AvaliarPrestadorScreenState();
}

class _AvaliarPrestadorScreenState extends State<AvaliarPrestadorScreen> {
  double nota = 0;
  bool enviando = false;
  final comentarioCtrl = TextEditingController();
  List<File> imagens = [];
  late final FirebaseStorage storage;

  @override
  void initState() {
    super.initState();
    storage = widget.storage ?? FirebaseStorage.instance;
  }

  @override
  void dispose() {
    comentarioCtrl.dispose();
    super.dispose();
  }

  // 🔹 Escolhe múltiplas imagens da galeria
  Future<void> _escolherImagens() async {
    final picker = ImagePicker();
    final imagensSelecionadas = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (imagensSelecionadas.isNotEmpty) {
      setState(() {
        // Adiciona as novas imagens à lista existente
        imagens.addAll(imagensSelecionadas.map((img) => File(img.path)));
        
        // Limita a um número máximo (ex: 5 imagens)
        if (imagens.length > 5) {
          imagens = imagens.sublist(0, 5);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Máximo de 5 imagens atingido')),
          );
        }
      });
    }
  }

  // 🔹 Remove uma imagem específica
  void _removerImagem(int index) {
    setState(() {
      imagens.removeAt(index);
    });
  }

  // 🔹 Faz upload de múltiplas imagens para o Storage
  Future<List<String>> _uploadImagens(String clienteId) async {
    if (imagens.isEmpty) return [];
    
    final List<String> urls = [];
    
    try {
      for (final imagem in imagens) {
        // Cria referência única para cada imagem
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = storage
            .ref()
            .child('avaliacoes')
            .child(clienteId)
            .child('${timestamp}_${urls.length}.jpg');

        // Faz upload da imagem
        final uploadTask = await ref.putFile(imagem);
        final url = await uploadTask.ref.getDownloadURL();
        urls.add(url);
        
        debugPrint('✅ Imagem ${urls.length} enviada: $url');
      }
      return urls;
    } catch (e) {
      debugPrint('❌ Erro ao enviar imagens: $e');
      throw Exception('Erro ao enviar imagens: $e');
    }
  }

  // 🔹 Envia avaliação completa com múltiplas imagens
  Future<void> _enviarAvaliacao() async {
    if (nota == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma nota antes de enviar.')),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      final clienteId = widget.auth.currentUser?.uid;
      if (clienteId == null) throw Exception('Usuário não autenticado.');

      final doc = await widget.firestore
          .collection('solicitacoesOrcamento')
          .doc(widget.solicitacaoId)
          .get();

      if (!doc.exists) throw Exception('Solicitação não encontrada.');

      final dados = doc.data()!;
      final prestadorId = dados['prestadorId'] ?? '';
      final servicoId = dados['servicoId'] ?? '';

      // ✅ Upload de múltiplas imagens para o Storage
      final imagensUrls = await _uploadImagens(clienteId);

      // ✅ Cria a avaliação COM array de URLs das imagens
      await widget.firestore.collection('avaliacoes').add({
        'solicitacaoId': widget.solicitacaoId,
        'servicoId': servicoId,
        'clienteId': clienteId,
        'prestadorId': prestadorId,
        'nota': nota,
        'comentario': comentarioCtrl.text.trim(),
        'data': FieldValue.serverTimestamp(),
        'imagensUrls': imagensUrls, // ✅ Array com URLs das imagens no Storage
        'quantidadeImagens': imagensUrls.length,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      // ✅ Atualiza status no Firestore
      await widget.firestore
          .collection('solicitacoesOrcamento')
          .doc(widget.solicitacaoId)
          .update({'status': 'avaliada'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avaliação enviada com ${imagensUrls.length} imagem(ns)!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Erro ao enviar avaliação: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Widget _estrela(int index) {
    return IconButton(
      icon: Icon(
        index <= nota ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 32,
      ),
      onPressed: () => setState(() => nota = index.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Avaliar Serviço',
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: widget.firestore
            .collection('solicitacoesOrcamento')
            .doc(widget.solicitacaoId)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Serviço não encontrado.'));
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final titulo = d['servicoTitulo'] ?? '';
          final prestador = d['prestadorNome'] ?? '';
          final endereco = d['clienteEndereco']?['rua'] ?? '';
          final valor = d['valorProposto'] ?? 0;
          final dataIni = d['dataInicioSugerida'] is Timestamp
              ? (d['dataInicioSugerida'] as Timestamp).toDate()
              : null;
          final dataFim = d['dataFinalizacaoReal'] is Timestamp
              ? (d['dataFinalizacaoReal'] as Timestamp).toDate()
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟣 Card de informações do serviço
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Prestador: $prestador',
                          style: const TextStyle(fontSize: 13.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month,
                              size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 5),
                          Text(
                            '${dataIni != null ? DateFormat('dd/MM/yyyy').format(dataIni) : '--'}'
                            ' - '
                            '${dataFim != null ? DateFormat('dd/MM/yyyy').format(dataFim) : '--'}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(endereco,
                                style: const TextStyle(fontSize: 13.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        NumberFormat.simpleCurrency(locale: 'pt_BR')
                            .format(valor),
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Sua avaliação',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Como você avalia esse serviço?',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => _estrela(i + 1)),
                ),
                const Center(
                  child: Text('Selecione uma nota',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),

                const SizedBox(height: 20),
                const Text('Comentário (opcional)',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: comentarioCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Escreva um comentário...',
                  ),
                ),

                const SizedBox(height: 20),
                // Upload de múltiplas imagens
                Row(
                  children: [
                    const Text('Upload de Imagens',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text(
                      '(${imagens.length}/5)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Grid de imagens selecionadas
                if (imagens.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: imagens.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                imagens[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removerImagem(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Botão para adicionar mais imagens
                if (imagens.length < 5)
                  GestureDetector(
                    onTap: _escolherImagens,
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Colors.grey, size: 28),
                            SizedBox(height: 4),
                            Text('Adicionar Imagens',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                // 🔹 Botões Enviar e Cancelar
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: enviando ? null : _enviarAvaliacao,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6E3BFF),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: enviando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Enviar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.deepPurple, width: 1),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}