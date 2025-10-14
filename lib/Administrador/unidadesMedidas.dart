import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnidadeMedScreen extends StatefulWidget {
  final FirebaseFirestore? firestore; // 🔹 injeta o Firestore fake nos testes

  const UnidadeMedScreen({super.key, this.firestore});

  @override
  State<UnidadeMedScreen> createState() => _UnidadeMedScreenState();
}

class _UnidadeMedScreenState extends State<UnidadeMedScreen> {
  late final CollectionReference unidadesRef;

  @override
  void initState() {
    super.initState();
    unidadesRef =
        (widget.firestore ?? FirebaseFirestore.instance).collection('unidades');
  }

  void _abrirDialogo({DocumentSnapshot? unidade}) {
    final TextEditingController nomeCtrl =
        TextEditingController(text: unidade?['nome'] ?? '');
    final TextEditingController abrevCtrl =
        TextEditingController(text: unidade?['abreviacao'] ?? '');
    final bool isEdicao = unidade != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdicao
            ? 'Alteração de unidade de medida'
            : 'Nova unidade de Medida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome da unidade'),
            ),
            TextFormField(
              controller: abrevCtrl,
              decoration: const InputDecoration(labelText: 'Abreviação'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomeCtrl.text.isNotEmpty && abrevCtrl.text.isNotEmpty) {
                final data = {
                  'nome': nomeCtrl.text,
                  'abreviacao': abrevCtrl.text,
                  'ativo': true,
                };
                if (isEdicao) {
                  unidadesRef.doc(unidade!.id).update(data);
                } else {
                  unidadesRef.add(data);
                }
                Navigator.pop(context);
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinha(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(data['nome'] ?? '-')),
          Expanded(flex: 2, child: Text(data['abreviacao'] ?? '-')),
          ElevatedButton(
            onPressed: () => _abrirDialogo(unidade: doc),
            style: ElevatedButton.styleFrom(minimumSize: const Size(60, 36)),
            child: const Text('Editar'),
          ),
          const SizedBox(width: 12),
          Switch(
            value: data['ativo'] == true,
            onChanged: (val) => unidadesRef.doc(doc.id).update({'ativo': val}),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unidades de Medida'),
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
              'Gerencie as unidades de medida disponíveis para os serviços',
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
                  'Nova Unidade',
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
                Expanded(
                  flex: 4,
                  child: Text(
                    'Nome',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Abreviação',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 80),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: unidadesRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Erro ao carregar dados'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma unidade cadastrada.'),
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
