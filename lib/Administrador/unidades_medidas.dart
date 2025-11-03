import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnidadeMedScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const UnidadeMedScreen({super.key, this.firestore});

  @override
  State<UnidadeMedScreen> createState() => _UnidadeMedScreenState();
}

class _UnidadeMedScreenState extends State<UnidadeMedScreen> {
  late final CollectionReference unidadesRef;

  @override
  void initState() {
    super.initState();
    unidadesRef = (widget.firestore ?? FirebaseFirestore.instance).collection(
      'unidades',
    );
  }

  void _abrirDialogo({DocumentSnapshot? unidade}) {
    final TextEditingController nomeCtrl = TextEditingController(
      text: unidade?['nome'] ?? '',
    );
    final TextEditingController abrevCtrl = TextEditingController(
      text: unidade?['abreviacao'] ?? '',
    );
    final bool isEdicao = unidade != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.black12, width: 1),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 80,
        ), // 🔹 aumenta um pouco o tamanho
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        backgroundColor: Colors.white,
        title: Text(
          isEdicao ? 'Editar Unidade de Medida' : 'Nova Unidade de Medida',
          style: const TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            TextFormField(
              controller: nomeCtrl,
              decoration: InputDecoration(
                labelText: 'Nome da unidade',
                labelStyle: const TextStyle(fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: abrevCtrl,
              decoration: InputDecoration(
                labelText: 'Abreviação',
                labelStyle: const TextStyle(fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🔴 Botão Cancelar (vermelho com texto branco)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 10,
                  ),
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
                onPressed: () {
                  if (nomeCtrl.text.isNotEmpty && abrevCtrl.text.isNotEmpty) {
                    final data = {
                      'nome': nomeCtrl.text.trim(),
                      'abreviacao': abrevCtrl.text.trim(),
                      'ativo': true,
                    };
                    if (isEdicao) {
                      unidadesRef.doc(unidade.id).update(data);
                    } else {
                      unidadesRef.add(data);
                    }
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 10,
                  ),
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
            color: Colors.deepPurple.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🔹 Nome e Abreviação empilhados
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
                  'Abreviação: ${data['abreviacao'] ?? '-'}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          // 🔹 Botão Editar
          ElevatedButton(
            onPressed: () => _abrirDialogo(unidade: doc),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Editar'),
          ),
          const SizedBox(width: 10),
          // 🔹 Switch de ativo
          Switch(
            value: data['ativo'] == true,
            activeThumbColor: Colors.deepPurple,
            onChanged: (val) => unidadesRef.doc(doc.id).update({'ativo': val}),
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
          'Unidades de Medida',
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
              'Gerencie as unidades utilizadas nos serviços cadastrados',
              style: TextStyle(color: Colors.black87, fontSize: 14.5),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _abrirDialogo(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Nova Unidade',
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
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: unidadesRef.orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Erro ao carregar unidades.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma unidade cadastrada.'),
                    );
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
