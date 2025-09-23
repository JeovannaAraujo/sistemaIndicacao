// lib/Cliente/buscarServicos.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class BuscarServicosScreen extends StatefulWidget {
  const BuscarServicosScreen({super.key});

  @override
  State<BuscarServicosScreen> createState() => _BuscarServicosScreenState();
}

class _BuscarServicosScreenState extends State<BuscarServicosScreen> {
  // ====== Controllers
  final TextEditingController _buscaController = TextEditingController();
  final TextEditingController _minValueController = TextEditingController();
  final TextEditingController _maxValueController = TextEditingController();
  final TextEditingController _localizacaoController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();

  // ====== Filtros
  String? _categoriaSelecionadaId;
  String? _categoriaSelecNome;
  String? _profissionalSelecionadoId;
  String? _profissionalSelecNome;
  String? _unidadeSelecionada;
  String? _disponibilidadeSelecionada; // "Disponível" | "Indisponível" | null
  DateTime? _dataSelecionada;
  int _avaliacaoMinima = 0;
  double _raioDistancia = 10.0;
  List<String> _pagamentosAceitos = [];
  bool _filtrosExibidos = true;
  bool _exibirMapa = false;
  bool _mostrarServicos = true; // alterna entre mostrar serviços ou prestadores

  // ====== Google Maps
  GoogleMapController? _mapController;
  final Set<Marker> _marcadores = {};

  // ====== Firestore refs
  static const String _colCategoriasServ = 'categoriasServicos';
  static const String _colCategoriasProf = 'categoriasProfissionais';
  static const String _colUnidades = 'unidades';
  static const String _colServicos = 'servicos';
  static const String _colAgenda = 'agendaPrestador';

  // ====== Dados de dropdown
  List<_ItemRef> _categoriasServ = [];
  List<_ItemRef> _categoriasProf = [];
  List<String> _unidades = [];

  // ====== Resultados
  List<Map<String, dynamic>> _resultados = []; // lista de docs "servicos" enriquecidos
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarFiltrosBase();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    _localizacaoController.dispose();
    _horarioController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _carregarFiltrosBase() async {
    // Carrega categorias, profissionais e unidades (apenas ativos)
    final fs = FirebaseFirestore.instance;

    final futures = await Future.wait([
      fs.collection(_colCategoriasServ).where('ativo', isEqualTo: true).get(),
      fs.collection(_colCategoriasProf).where('ativo', isEqualTo: true).get(),
      fs.collection(_colUnidades).where('ativo', isEqualTo: true).get(),
    ]);

    final servCats = futures[0].docs
        .map((d) => _ItemRef(id: d.id, nome: (d.data()['nome'] ?? '').toString()))
        .where((e) => e.nome.isNotEmpty)
        .toList();

    final profCats = futures[1].docs
        .map((d) => _ItemRef(id: d.id, nome: (d.data()['nome'] ?? '').toString()))
        .where((e) => e.nome.isNotEmpty)
        .toList();

    final unidades = futures[2].docs
        .map((d) => (d.data()['abreviacao'] ?? d.data()['nome'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    if (!mounted) return;
    setState(() {
      _categoriasServ = servCats;
      _categoriasProf = profCats;
      _unidades = unidades;
    });
  }

  // ========== BUSCA PRINCIPAL ==========
  Future<void> _buscarServicos() async {
    setState(() {
      _filtrosExibidos = false;
      _exibirMapa = false;
      _carregando = true;
      _resultados.clear();
      _marcadores.clear();
    });

    try {
      final fs = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> q = fs.collection(_colServicos);

      // Texto de busca (título/descrição) – filtraremos em memória para flexibilidade
      final termo = _buscaController.text.trim().toLowerCase();

      // Categoria de serviço
      if (_categoriaSelecionadaId != null && _categoriaSelecionadaId!.isNotEmpty) {
        q = q.where('categoriaId', isEqualTo: _categoriaSelecionadaId); // TODO: confirme campo
      }

      // Categoria profissional (se seu serviço armazena isso)
      if (_profissionalSelecionadoId != null && _profissionalSelecionadoId!.isNotEmpty) {
        q = q.where('categoriaProfId', isEqualTo: _profissionalSelecionadoId); // TODO: confirme campo
      }

      // Unidade
      if (_unidadeSelecionada != null && _unidadeSelecionada!.isNotEmpty) {
        q = q.where('unidade', isEqualTo: _unidadeSelecionada); // TODO: confirme campo
      }

      // Pagamentos aceitos (array)
      if (_pagamentosAceitos.isNotEmpty) {
        // Usa arrayContainsAny para bater qualquer um dos meios marcados
        q = q.where('pagamentos', arrayContainsAny: _pagamentosAceitos); // TODO: confirme campo
      }

      // Intervalo de preço
      final minVal = double.tryParse(_minValueController.text.replaceAll(',', '.'));
      final maxVal = double.tryParse(_maxValueController.text.replaceAll(',', '.'));
      // Se você guarda faixa [precoMin, precoMax], filtramos em memória pra não criar índices demais
      final snap = await q.limit(200).get();

      List<Map<String, dynamic>> itens = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      // Filtro em memória – texto, avaliação, preço
      itens = itens.where((e) {
        final titulo = (e['titulo'] ?? '').toString().toLowerCase();
        final desc = (e['descricao'] ?? '').toString().toLowerCase();
        final nota = (e['notaMedia'] ?? 0).toDouble();
        final precoMin = (e['precoMin'] ?? 0).toDouble();
        final precoMax = (e['precoMax'] ?? precoMin).toDouble();

        final bateTexto = termo.isEmpty || titulo.contains(termo) || desc.contains(termo);
        final bateAvaliacao = _avaliacaoMinima <= 0 || nota >= _avaliacaoMinima;
        final batePrecoMin = minVal == null || precoMax >= minVal; // existe interseção
        final batePrecoMax = maxVal == null || precoMin <= maxVal;

        return bateTexto && bateAvaliacao && batePrecoMin && batePrecoMax;
      }).toList();

      // Disponibilidade (se marcado "Disponível" e tiver data/hora)
      if (_disponibilidadeSelecionada == 'Disponível' && _dataSelecionada != null) {
        final hhmm = _horarioController.text.trim(); // "14:00"
        final disponiveis = await _prestadoresDisponiveisNaDataHora(_dataSelecionada!, hhmm);
        itens = itens.where((e) => disponiveis.contains(e['prestadorId'])).toList();
      } else if (_disponibilidadeSelecionada == 'Indisponível' && _dataSelecionada != null) {
        final hhmm = _horarioController.text.trim();
        final disponiveis = await _prestadoresDisponiveisNaDataHora(_dataSelecionada!, hhmm);
        itens = itens.where((e) => !disponiveis.contains(e['prestadorId'])).toList();
      }

      // Distância (se houver geo + raio informado). Localização digitada é livre;
      // ideal é você popular a posição do cliente (GPS) e filtrar por Haversine.
      final raioKm = _raioDistancia;
      LatLng? origem; // TODO: substituir pela localização real do cliente
      // Exemplo: se você já tiver geo do usuário salvo, injete aqui.
      // if (suaGeoCliente != null) origem = LatLng(suaGeoCliente.latitude, suaGeoCliente.longitude);

      if (origem != null) {
        itens = itens.where((e) {
          final geo = e['geo'];
          if (geo is GeoPoint) {
            final dist = _distanciaKm(origem.latitude, origem.longitude, geo.latitude, geo.longitude);
            return dist <= raioKm;
          }
          return true;
        }).toList();
      }

      // Popula resultados e marcadores do mapa
      final markers = <Marker>{};
      for (final e in itens) {
        final geo = e['geo'];
        if (geo is GeoPoint) {
          markers.add(Marker(
            markerId: MarkerId(e['id']),
            position: LatLng(geo.latitude, geo.longitude),
            infoWindow: InfoWindow(
              title: (e['titulo'] ?? 'Serviço').toString(),
              snippet: (e['cidade'] ?? '').toString(),
            ),
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _resultados = itens;
        _marcadores.addAll(markers);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar serviços: $e')),
      );
    }
  }

  Future<Set<String>> _prestadoresDisponiveisNaDataHora(DateTime data, String horaHHmm) async {
    // Consulta "agendaPrestador" por data (yyyy-MM-dd) contendo a hora pedida
    final fs = FirebaseFirestore.instance;
    final dataStr = DateFormat('yyyy-MM-dd').format(data);

    final snap = await fs
        .collection(_colAgenda)
        .where('data', isEqualTo: dataStr) // TODO: confirme formato do campo
        .get();

    final set = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final prestadorId = (m['prestadorId'] ?? '').toString();
      final horas = (m['horasLivres'] ?? []) as List<dynamic>; // array de "HH:mm"
      if (horaHHmm.isEmpty) {
        // Se não informar hora, considera disponível se tiver qualquer hora livre
        if (horas.isNotEmpty) set.add(prestadorId);
      } else {
        if (horas.any((h) => '$h' == horaHHmm)) set.add(prestadorId);
      }
    }
    return set;
  }

  double _distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  void _limparFiltros() {
    setState(() {
      _buscaController.clear();
      _minValueController.clear();
      _maxValueController.clear();
      _localizacaoController.clear();
      _horarioController.clear();
      _categoriaSelecionadaId = null;
      _categoriaSelecNome = null;
      _profissionalSelecionadoId = null;
      _profissionalSelecNome = null;
      _unidadeSelecionada = null;
      _disponibilidadeSelecionada = null;
      _dataSelecionada = null;
      _avaliacaoMinima = 0;
      _raioDistancia = 10.0;
      _pagamentosAceitos = [];
      _filtrosExibidos = true;
      _resultados.clear();
      _marcadores.clear();
    });
  }

  void _alternarVisualizacao() {
    setState(() => _exibirMapa = !_exibirMapa);
  }

  // =================== UI ===================

  Widget _buildTopoComBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!_filtrosExibidos) {
                setState(() => _filtrosExibidos = true);
              } else {
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
              icon: Icon(_exibirMapa ? Icons.list : Icons.map, color: Colors.deepPurple),
              onPressed: _alternarVisualizacao,
            ),
          ],
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
          zoom: 13,
        ),
      ),
    );
  }

  Widget _buildServicoCard(Map<String, dynamic> e) {
    final titulo = (e['titulo'] ?? 'Serviço').toString();
    final descricao = (e['descricao'] ?? '').toString();
    final prestador = (e['prestadorNome'] ?? e['prestadorId'] ?? '').toString(); // TODO: se quiser join de nome do prestador, faça lookup
    final local = (e['cidade'] ?? '').toString();
    final precoMin = (e['precoMin'] ?? 0).toDouble();
    final precoMax = (e['precoMax'] ?? precoMin).toDouble();
    final nota = (e['notaMedia'] ?? 0).toDouble();
    final qtdAval = (e['qtdAvaliacoes'] ?? 0).toInt();

    String precoFaixa;
    if (precoMin > 0 && precoMax > 0 && precoMax >= precoMin) {
      precoFaixa = 'R\$ ${precoMin.toStringAsFixed(2)} - R\$ ${precoMax.toStringAsFixed(2)}';
    } else if (precoMin > 0) {
      precoFaixa = 'A partir de R\$ ${precoMin.toStringAsFixed(2)}';
    } else {
      precoFaixa = 'A combinar';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Text(precoFaixa, style: const TextStyle(color: Colors.deepPurple)),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(nota.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('  ($qtdAval avaliações)', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // TODO: navegar para perfil prestador (use o prestadorId)
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple),
                        child: const Text('Perfil Prestador'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: abrir fluxo de solicitar orçamento/agenda
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        child: const Text('Solicitar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestadorCard(Map<String, dynamic> eAgrupado) {
    // eAgrupado: { prestadorId, prestadorNome?, cidade?, notaMediaAgregada, qtdServicos, geo?, ... }
    final prestadorId = (eAgrupado['prestadorId'] ?? '').toString();
    final prestadorNome = (eAgrupado['prestadorNome'] ?? prestadorId).toString();
    final cidade = (eAgrupado['cidade'] ?? '').toString();
    final nota = (eAgrupado['notaMediaAgregada'] ?? 0).toDouble();
    final qtdServ = (eAgrupado['qtdServicos'] ?? 0).toInt();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, color: Colors.deepPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prestadorNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(cidade, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(nota.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('  • $qtdServ serviços', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // TODO: navegar para perfil do prestador
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple),
                        child: const Text('Ver Perfil'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: iniciar solicitação/orçamento
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        child: const Text('Solicitar'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado() {
    if (_carregando) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ));
    }
    if (_resultados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhum resultado encontrado. Ajuste os filtros e tente novamente.'),
      );
    }

    // Cabeçalho
    final total = _mostrarServicos ? _resultados.length : _agruparPorPrestador(_resultados).length;
    final titulo = _mostrarServicos ? '$total serviços encontrados' : '$total prestadores encontrados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            // Switch: lista de serviços X prestadores
            Row(
              children: [
                const Text('Prestadores'),
                Switch(
                  value: _mostrarServicos,
                  onChanged: (v) => setState(() => _mostrarServicos = v),
                  activeColor: Colors.deepPurple,
                ),
                const Text('Serviços'),
              ],
            ),
            IconButton(
              icon: Icon(_exibirMapa ? Icons.list : Icons.map, color: Colors.deepPurple),
              onPressed: _alternarVisualizacao,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _exibirMapa
            ? _buildMapa()
            : (_mostrarServicos
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _resultados.map(_buildServicoCard).toList(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _agruparPorPrestador(_resultados).map(_buildPrestadorCard).toList(),
                  )),
      ],
    );
  }

  // Agrupa serviços por prestador para exibição de prestador
  List<Map<String, dynamic>> _agruparPorPrestador(List<Map<String, dynamic>> itens) {
    final byPrest = <String, List<Map<String, dynamic>>>{};
    for (final e in itens) {
      final pid = (e['prestadorId'] ?? '').toString();
      byPrest.putIfAbsent(pid, () => []).add(e);
    }

    final lista = <Map<String, dynamic>>[];
    byPrest.forEach((pid, servs) {
      final media = servs.isEmpty
          ? 0.0
          : servs.map((s) => (s['notaMedia'] ?? 0).toDouble()).fold<double>(0.0, (a, b) => a + b) / servs.length;
      // Pega cidade/geo do primeiro serviço
      final cidade = (servs.first['cidade'] ?? '').toString();
      final geo = servs.first['geo'];
      lista.add({
        'prestadorId': pid,
        'prestadorNome': servs.first['prestadorNome'] ?? pid, // TODO: opcional: lookup em /usuarios
        'cidade': cidade,
        'notaMediaAgregada': media,
        'qtdServicos': servs.length,
        'geo': geo,
      });
    });
    return lista;
  }

  // ======= Filtro UI =======
  Widget _buildFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Categoria de serviço
        DropdownButtonFormField<String>(
          value: _categoriaSelecionadaId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._categoriasServ.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nome))),
          ],
          onChanged: (v) {
            setState(() {
              _categoriaSelecionadaId = v;
              _categoriaSelecNome = _categoriasServ.firstWhere(
                (c) => c.id == v,
                orElse: () => _ItemRef.empty(),
              ).nome;
            });
          },
          decoration: const InputDecoration(labelText: 'Categoria de serviço'),
        ),

        // Categoria profissional
        DropdownButtonFormField<String>(
          value: _profissionalSelecionadoId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._categoriasProf.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nome))),
          ],
          onChanged: (v) {
            setState(() {
              _profissionalSelecionadoId = v;
              _profissionalSelecNome = _categoriasProf.firstWhere(
                (c) => c.id == v,
                orElse: () => _ItemRef.empty(),
              ).nome;
            });
          },
          decoration: const InputDecoration(labelText: 'Categoria profissional'),
        ),

        // Unidade
        DropdownButtonFormField<String>(
          value: _unidadeSelecionada,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))),
          ],
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
          children: List.generate(5, (i) {
            final v = 5 - i;
            final ativo = _avaliacaoMinima >= v;
            return GestureDetector(
              onTap: () => setState(() => _avaliacaoMinima = v),
              child: Column(
                children: [
                  Text('$v'),
                  Icon(Icons.star, color: ativo ? Colors.amber : Colors.grey),
                ],
              ),
            );
          }),
        ),

        const SizedBox(height: 8),
        TextField(
          controller: _localizacaoController,
          decoration: const InputDecoration(
            labelText: 'Localização (opcional)',
            helperText: 'Dica: ative GPS e salve sua localização para filtro de raio',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _raioDistancia,
                onChanged: (v) => setState(() => _raioDistancia = v),
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_raioDistancia.toStringAsFixed(0)} km',
              ),
            ),
            SizedBox(
              width: 70,
              child: Text('${_raioDistancia.toStringAsFixed(0)} km',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),

        // Disponibilidade
        DropdownButtonFormField<String>(
          value: _disponibilidadeSelecionada,
          items: const [
            DropdownMenuItem(value: null, child: Text('Ignorar disponibilidade')),
            DropdownMenuItem(value: 'Disponível', child: Text('Disponível')),
            DropdownMenuItem(value: 'Indisponível', child: Text('Indisponível')),
          ],
          onChanged: (v) => setState(() => _disponibilidadeSelecionada = v),
          decoration: const InputDecoration(labelText: 'Disponibilidade'),
        ),

        Row(children: [
          const Text('Data desejada: '),
          TextButton(
            onPressed: _selecionarData,
            child: Text(_dataSelecionada == null
                ? 'Selecionar'
                : DateFormat('dd/MM/yyyy').format(_dataSelecionada!)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _horarioController,
              decoration: const InputDecoration(labelText: 'Horário (ex: 14:00)'),
            ),
          ),
        ]),

        const SizedBox(height: 8),
        const Text('Meios de pagamento aceitos:'),
        CheckboxListTile(
          dense: true,
          title: const Text('Dinheiro'),
          value: _pagamentosAceitos.contains('Dinheiro'),
          onChanged: (v) => setState(() =>
              v! ? _pagamentosAceitos.add('Dinheiro') : _pagamentosAceitos.remove('Dinheiro')),
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('Pix'),
          value: _pagamentosAceitos.contains('Pix'),
          onChanged: (v) => setState(() =>
              v! ? _pagamentosAceitos.add('Pix') : _pagamentosAceitos.remove('Pix')),
        ),
        CheckboxListTile(
          dense: true,
          title: const Text('Cartão de crédito/débito'),
          value: _pagamentosAceitos.contains('Cartão de crédito/débito'),
          onChanged: (v) => setState(() => v!
              ? _pagamentosAceitos.add('Cartão de crédito/débito')
              : _pagamentosAceitos.remove('Cartão de crédito/débito')),
        ),
      ],
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopoComBusca(),
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
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _buscarServicos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 199, 194, 209),
                      ),
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
}

class _ItemRef {
  final String id;
  final String nome;
  const _ItemRef({required this.id, required this.nome});
  const _ItemRef.empty() : id = '', nome = '';
}
