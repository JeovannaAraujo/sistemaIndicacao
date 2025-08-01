import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BuscarServicosScreen extends StatefulWidget {
  const BuscarServicosScreen({super.key});

  @override
  State<BuscarServicosScreen> createState() => _BuscarServicosScreenState();
}

class _BuscarServicosScreenState extends State<BuscarServicosScreen> {
  final TextEditingController _buscaController = TextEditingController();
  final TextEditingController _minValueController = TextEditingController();
  final TextEditingController _maxValueController = TextEditingController();
  final TextEditingController _localizacaoController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();

  String? _categoriaSelecionada;
  String? _profissionalSelecionado;
  String? _unidadeSelecionada;
  String? _disponibilidadeSelecionada;
  DateTime? _dataSelecionada;
  int _avaliacaoMinima = 0;
  double _raioDistancia = 10.0;
  List<String> _pagamentosAceitos = [];
  bool _filtrosExibidos = true;
  bool _exibirMapa = false;

  // ignore: unused_field
  late GoogleMapController _mapController;
  final Set<Marker> _marcadores = {
    const Marker(
      markerId: MarkerId('1'),
      position: LatLng(-17.7945, -50.9192),
      infoWindow: InfoWindow(title: 'Assentamento de pisos cerâmicos', snippet: 'Jorge Antônio'),
    ),
    const Marker(
      markerId: MarkerId('2'),
      position: LatLng(-17.7975, -50.9245),
      infoWindow: InfoWindow(title: 'Assentamento de Porcelanato', snippet: 'Tiago Mendes'),
    ),
    const Marker(
      markerId: MarkerId('3'),
      position: LatLng(-17.7990, -50.9210),
      infoWindow: InfoWindow(title: 'Piso Intertravado', snippet: 'Bruno Vieira'),
    ),
  };

  void _selecionarData() async {
    DateTime? data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (data != null) {
      setState(() => _dataSelecionada = data);
    }
  }

  void _buscarServicos() {
    setState(() {
      _filtrosExibidos = false;
      _exibirMapa = false;
    });
  }

  void _limparFiltros() {
    setState(() {
      _buscaController.clear();
      _minValueController.clear();
      _maxValueController.clear();
      _localizacaoController.clear();
      _horarioController.clear();
      _categoriaSelecionada = null;
      _profissionalSelecionado = null;
      _unidadeSelecionada = null;
      _disponibilidadeSelecionada = null;
      _dataSelecionada = null;
      _avaliacaoMinima = 0;
      _raioDistancia = 10.0;
      _pagamentosAceitos = [];
      _filtrosExibidos = true;
    });
  }

  void _alternarVisualizacao() {
    setState(() => _exibirMapa = !_exibirMapa);
  }

// ignore: unused_element
Widget _buildResultadoHeader() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              hintText: 'Buscar serviços ou profissionais...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.filter_alt_outlined, color: Colors.deepPurple),
          onPressed: () => setState(() => _filtrosExibidos = true),
        ),
        IconButton(
          icon: Icon(_exibirMapa ? Icons.list : Icons.map, color: Colors.deepPurple),
          onPressed: _alternarVisualizacao,
        ),
      ],
    ),
  );
}

  Widget _buildMapa() {
    return SizedBox(
      height: 400,
      child: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        markers: _marcadores,
        initialCameraPosition: const CameraPosition(
          target: LatLng(-17.7960, -50.9220),
          zoom: 14,
        ),
      ),
    );
  }

Widget _buildServicoCard({
  required String titulo,
  required String descricao,
  required String prestador,
  required String local,
  required String preco,
  required double nota,
  required int avaliacoes,
}) {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone da categoria
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.construction, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),

          // Informações do serviço
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(descricao, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('Prestador: $prestador', style: const TextStyle(fontSize: 13)),
                Text(local, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(preco, style: const TextStyle(color: Colors.deepPurple)),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text('$nota', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('  ($avaliacoes avaliações)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),

               // Botões
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                      ),
                      child: const Text('Perfil Prestador'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: const Text('Solicitar'),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    ),
  );
}

Widget _buildResultado() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('3 serviços encontrados', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _exibirMapa
          ? _buildMapa()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServicoCard(
                  titulo: 'Assentamento de pisos cerâmicos',
                  descricao: 'Instalação de pisos cerâmicos em áreas internas ou externas.',
                  prestador: 'Jorge Antônio',
                  local: 'Rio Verde, GO',
                  preco: 'R\$25,00 - R\$50,00 por m²',
                  nota: 5.0,
                  avaliacoes: 60,
                ),
                _buildServicoCard(
                  titulo: 'Assentamento de Porcelanato',
                  descricao: 'Aplicação com técnicas para evitar desnivelamentos.',
                  prestador: 'Tiago Mendes',
                  local: 'Rio Verde, GO',
                  preco: 'R\$35,00 - R\$60,00 por m²',
                  nota: 4.7,
                  avaliacoes: 40,
                ),
                _buildServicoCard(
                  titulo: 'Assentamento de Piso Intertravado',
                  descricao: 'Instalação para áreas externas com preparo do solo.',
                  prestador: 'Bruno Vieira',
                  local: 'Rio Verde, GO',
                  preco: 'R\$40,00 - R\$75,00 por m²',
                  nota: 4.5,
                  avaliacoes: 35,
                ),
              ],
            ),
    ],
  );
}

Widget _buildTopoComBusca() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!_filtrosExibidos) {
              // Voltar para os filtros
              setState(() => _filtrosExibidos = true);
            } else {
              // Navegar para tela anterior
              Navigator.of(context).pop();
            }
          },
        ),
        Expanded(
          child: TextField(
            controller: _buscaController,
            decoration: InputDecoration(
              hintText: 'Buscar serviços ou profissionais...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        if (!_filtrosExibidos) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.deepPurple),
            onPressed: () => setState(() => _filtrosExibidos = true),
          ),
          IconButton(
            icon: Icon(
              _exibirMapa ? Icons.list : Icons.map,
              color: Colors.deepPurple,
            ),
            onPressed: _alternarVisualizacao,
          ),
        ]
      ],
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          _buildTopoComBusca(), // Topo com busca e seta
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _filtrosExibidos ? _buildFiltro() : _buildResultado(),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _filtrosExibidos
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _buscarServicos,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 199, 194, 209)),
                    child: const Text('Buscar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _limparFiltros,
                    child: const Text('Limpar Filtros'),
                  ),
                ),
              ],
            ),
          )
        : null,
  );
}

  Widget _buildFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _categoriaSelecionada,
          items: ['Todas', 'Hidráulica', 'Elétrica'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _categoriaSelecionada = v),
          decoration: const InputDecoration(labelText: 'Categoria de serviço'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _profissionalSelecionado,
          items: ['Todas', 'Pedreiro', 'Pintor'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _profissionalSelecionado = v),
          decoration: const InputDecoration(labelText: 'Categoria profissional'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _unidadeSelecionada,
          items: ['Todas', 'm²', 'hora'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _unidadeSelecionada = v),
          decoration: const InputDecoration(labelText: 'Unidade de medida'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minValueController,
          decoration: const InputDecoration(labelText: 'Valor mínimo (R\$)'),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _maxValueController,
          decoration: const InputDecoration(labelText: 'Valor máximo (R\$)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        const Text('Avaliação mínima:'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) => GestureDetector(
            onTap: () => setState(() => _avaliacaoMinima = 5 - index),
            child: Column(children: [Text('${5 - index}'), Icon(Icons.star, color: _avaliacaoMinima >= (5 - index) ? Colors.amber : Colors.grey)])
          )),
        ),
        TextField(
          controller: _localizacaoController,
          decoration: const InputDecoration(labelText: 'Localização'),
        ),
        TextField(
          controller: TextEditingController(text: _raioDistancia.toString()),
          decoration: const InputDecoration(labelText: 'Raio de distância (km)'),
          keyboardType: TextInputType.number,
        ),
        DropdownButtonFormField<String>(
          initialValue: _disponibilidadeSelecionada,
          items: ['Disponível', 'Indisponível'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _disponibilidadeSelecionada = v),
          decoration: const InputDecoration(labelText: 'Disponibilidade'),
        ),
        Row(children: [
          const Text('Data desejada: '),
          TextButton(
            onPressed: _selecionarData,
            child: Text(_dataSelecionada == null ? 'Selecionar' : DateFormat('dd/MM/yyyy').format(_dataSelecionada!)),
          ),
        ]),
        TextField(
          controller: _horarioController,
          decoration: const InputDecoration(labelText: 'Horário desejado'),
        ),
        const SizedBox(height: 8),
        const Text('Meios de pagamento aceitos:'),
        CheckboxListTile(
          title: const Text('Dinheiro'),
          value: _pagamentosAceitos.contains('Dinheiro'),
          onChanged: (v) => setState(() => v! ? _pagamentosAceitos.add('Dinheiro') : _pagamentosAceitos.remove('Dinheiro')),
        ),
        CheckboxListTile(
          title: const Text('Pix'),
          value: _pagamentosAceitos.contains('Pix'),
          onChanged: (v) => setState(() => v! ? _pagamentosAceitos.add('Pix') : _pagamentosAceitos.remove('Pix')),
        ),
        CheckboxListTile(
          title: const Text('Cartão de crédito/débito'),
          value: _pagamentosAceitos.contains('Cartão de crédito/débito'),
          onChanged: (v) => setState(() => v! ? _pagamentosAceitos.add('Cartão de crédito/débito') : _pagamentosAceitos.remove('Cartão de crédito/débito')),
        ),
      ],
    );
  }
} 
