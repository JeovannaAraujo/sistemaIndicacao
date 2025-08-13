import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CategServ extends StatefulWidget {
  const CategServ({super.key});

  @override
  State<CategServ> createState() => _CategServState();
}

class _CategServState extends State<CategServ> {
  final CollectionReference categoriasRef = FirebaseFirestore.instance
      .collection('categoriasServicos');

  void _abrirDialogo({DocumentSnapshot? categoria}) {
    final TextEditingController nomeCtrl = TextEditingController(
      text: categoria?['nome'] ?? '',
    );
    final TextEditingController descCtrl = TextEditingController(
      text: categoria?['descricao'] ?? '',
    );
    final bool isEdicao = categoria != null;

    String? imagemUrl = categoria?['imagemUrl'];
    File? imagemSelecionada;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEdicao
                        ? 'Alteração de categoria de serviço'
                        : 'Nova categoria de serviço',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final XFile? imagem = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (imagem != null) {
                      final File file = File(imagem.path);
                      final nomeArquivo =
                          'categorias/${DateTime.now().millisecondsSinceEpoch}.jpg';
                      final ref = FirebaseStorage.instance.ref().child(
                        nomeArquivo,
                      );
                      await ref.putFile(file);
                      final url = await ref.getDownloadURL();
                      setDialogState(() {
                        imagemUrl = url;
                        imagemSelecionada = file;
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: imagemUrl != null && imagemUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imagemUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.image,
                                size: 40,
                                color: Colors.grey,
                              ),
                      ),
                      const Positioned(
                        bottom: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.deepPurple,
                          child: Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da categoria',
                    hintText: 'Ex: Elétrica',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da categoria',
                    hintText: 'Descreva a categoria.',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (nomeCtrl.text.isNotEmpty && descCtrl.text.isNotEmpty) {
                      final data = {
                        'nome': nomeCtrl.text,
                        'descricao': descCtrl.text,
                        'ativo': true,
                        'imagemUrl': imagemUrl ?? '',
                      };
                      if (isEdicao) {
                        categoriasRef.doc(categoria.id).update(data);
                      } else {
                        categoriasRef.add(data);
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Salvar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    side: const BorderSide(color: Colors.black),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinha(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imagem = data['imagemUrl'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: imagem.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(imagem, fit: BoxFit.cover),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 40, height: 40, color: Colors.grey[300]),
                      const Icon(Icons.image, size: 18, color: Colors.grey),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: Text(data['nome'] ?? '-')),
          Expanded(flex: 4, child: Text(data['descricao'] ?? '-')),
          ElevatedButton(
            onPressed: () => _abrirDialogo(categoria: doc),
            style: ElevatedButton.styleFrom(minimumSize: const Size(60, 36)),
            child: const Text('Editar'),
          ),
          const SizedBox(width: 12),
          Switch(
            value: data['ativo'] == true,
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
      appBar: AppBar(
        title: const Text('Categorias de Serviço'),
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
              'Gerencie as categorias disponíveis de serviços',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _abrirDialogo(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Nova Categoria',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ),
            const Divider(),
            const Row(
              children: [
                SizedBox(width: 40),
                SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Nome',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Descrição',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 80),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: categoriasRef.orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Erro ao carregar categorias'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma categoria cadastrada.'),
                    );
                  }
                  return ListView(children: docs.map(_buildLinha).toList());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
