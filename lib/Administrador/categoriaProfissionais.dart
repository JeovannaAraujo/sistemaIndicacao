import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategProf extends StatefulWidget {
  const CategProf({super.key});

  @override
  State<CategProf> createState() => _CategProfState();
}

class _CategProfState extends State<CategProf> {
  final CollectionReference categoriasRef =
      FirebaseFirestore.instance.collection('categoriasProfissionais');

  void _abrirDialogo({DocumentSnapshot? categoria}) {
    final TextEditingController nomeCtrl =
        TextEditingController(text: categoria?['nome'] ?? '');
    final TextEditingController descCtrl =
        TextEditingController(text: categoria?['descricao'] ?? '');
    final bool isEdicao = categoria != null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isEdicao
                          ? 'Alteração de categoria de profissional'
                          : 'Nova categoria de profissional',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preencha os campos abaixo para criar uma nova categoria.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da categoria',
                      hintText: 'Ex: Eletricista',
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
      ),
    );
  }

  Widget _buildLinha(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 40),
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
        title: const Text('Categorias de profissionais'),
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
              'Gerencie as categorias disponíveis de profissionais',
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
                label: const Text('Nova Categoria', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              ),
            ),
            const Divider(),
            const Row(
              children: [
                SizedBox(width: 40),
                SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 4,
                  child: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    return const Center(child: Text('Erro ao carregar categorias'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('Nenhuma categoria cadastrada.'));
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
