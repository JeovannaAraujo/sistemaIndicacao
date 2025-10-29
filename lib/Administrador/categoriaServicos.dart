import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CategServ extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;

  const CategServ({super.key, this.firestore, this.storage});

  @override
  State<CategServ> createState() => _CategServState();
}

class _CategServState extends State<CategServ> {
  late final CollectionReference categoriasRef;
  late final FirebaseStorage storage;

  @override
  void initState() {
    super.initState();
    categoriasRef = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('categoriasServicos');
    storage = widget.storage ?? FirebaseStorage.instance;
  }

  Future<String?> _uploadImagem(File imagem) async {
    try {
      final nomeArquivo =
          'categorias/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child(nomeArquivo);
      final uploadTask = await ref.putFile(imagem);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro ao enviar imagem: $e');
      return null;
    }
  }

  void _abrirDialogo({DocumentSnapshot? categoria}) {
    final data = categoria?.data() as Map<String, dynamic>? ?? {};
    final TextEditingController nomeCtrl =
        TextEditingController(text: data['nome'] ?? '');
    final TextEditingController descCtrl =
        TextEditingController(text: data['descricao'] ?? '');
    final bool isEdicao = categoria != null;

    String? imagemUrl = data['imagemUrl'] ?? '';
    File? imagemSelecionada;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.black12, width: 1),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
          backgroundColor: Colors.white,
          title: Text(
            isEdicao
                ? 'Editar Categoria de Serviço'
                : 'Nova Categoria de Serviço',
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final XFile? imagem =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (imagem != null) {
                      setDialogState(() {
                        imagemSelecionada = File(imagem.path);
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: imagemSelecionada != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  imagemSelecionada!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : (imagemUrl?.isNotEmpty ?? false)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imagemUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.image,
                                    size: 40, color: Colors.grey),
                      ),
                      const Positioned(
                        bottom: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.deepPurple,
                          child: Icon(Icons.edit,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nomeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nome da categoria',
                    labelStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.deepPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Descrição da categoria',
                    labelStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.deepPurple),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔴 Botão Cancelar
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // 🟣 Botão Salvar
                ElevatedButton(
                  onPressed: () async {
                    if (nomeCtrl.text.isEmpty ||
                        descCtrl.text.isEmpty) return;

                    // 🔹 Se o usuário escolheu nova imagem, envia para o Storage
                    if (imagemSelecionada != null) {
                      final url = await _uploadImagem(imagemSelecionada!);
                      if (url != null) imagemUrl = url;
                    }

                    final data = {
                      'nome': nomeCtrl.text.trim(),
                      'descricao': descCtrl.text.trim(),
                      'imagemUrl': imagemUrl ?? '',
                      'ativo': true,
                    };

                    if (isEdicao) {
                      await categoriasRef.doc(categoria!.id).update(data);
                    } else {
                      await categoriasRef.add(data);
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Salvar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imagem = data['imagemUrl'] ?? '';

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
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.deepPurple.withOpacity(0.05),
            ),
            child: imagem.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imagem, fit: BoxFit.cover),
                  )
                : const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['nome'] ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['descricao'] ?? '-',
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _abrirDialogo(categoria: doc),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Editar'),
          ),
          const SizedBox(width: 10),
          Switch(
            value: data['ativo'] == true,
            activeColor: Colors.deepPurple,
            onChanged: (val) =>
                categoriasRef.doc(doc.id).update({'ativo': val}),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Categorias de Serviço',
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
              'Gerencie as categorias utilizadas nos serviços cadastrados',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _abrirDialogo(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Nova Categoria',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: categoriasRef.orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Erro ao carregar categorias.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('Nenhuma categoria cadastrada.'));
                  }
                  return ListView(children: docs.map(_buildCard).toList());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
