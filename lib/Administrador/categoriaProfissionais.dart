import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategProf extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const CategProf({super.key, this.firestore});

  @override
  State<CategProf> createState() => _CategProfState();
}

class _CategProfState extends State<CategProf> {
  late final CollectionReference categoriasRef;

  @override
  void initState() {
    super.initState();
    categoriasRef = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('categoriasProfissionais');
  }

  void _abrirDialogo({DocumentSnapshot? categoria}) {
    final TextEditingController nomeCtrl =
        TextEditingController(text: categoria?['nome'] ?? '');
    final TextEditingController descCtrl =
        TextEditingController(text: categoria?['descricao'] ?? '');
    final bool isEdicao = categoria != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.black12, width: 1),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        backgroundColor: Colors.white,
        title: Text(
          isEdicao
              ? 'Editar Categoria de Profissional'
              : 'Nova Categoria de Profissional',
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
              const SizedBox(height: 10),
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
                  if (nomeCtrl.text.isNotEmpty &&
                      descCtrl.text.isNotEmpty) {
                    final data = {
                      'nome': nomeCtrl.text.trim(),
                      'descricao': descCtrl.text.trim(),
                      'ativo': true,
                    };
                    if (isEdicao) {
                      await categoriasRef.doc(categoria!.id).update(data);
                    } else {
                      await categoriasRef.add(data);
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
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
    );
  }

  Widget _buildCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

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
          'Categorias de Profissionais',
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
              'Gerencie as categorias utilizadas pelos prestadores cadastrados',
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
