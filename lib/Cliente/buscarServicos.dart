// lib/Cliente/buscarServicos.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'rotasNavegacao.dart';
import 'visualizarPerfilPrestador.dart';
import 'solicitarOrcamento.dart';
import '../Prestador/visualizarAvaliacoes.dart';
import '../Prestador/avaliacoesPrestador.dart';

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
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  // ====== Filtros
  String? _categoriaSelecionadaId;
  String? _categoriaSelecNome;
  String? _profissionalSelecionadoId;
  String? _profissionalSelecNome;
  String? _unidadeSelecionada;
  String? _disponibilidadeSelecionada;
  DateTime? _dataSelecionada;
  int _avaliacaoMinima = 0;
  double _raioDistancia = 10.0;
  List<String> _pagamentosAceitos = [];
  bool _filtrosExibidos = true;
  bool _exibirMapa = false;

  // Resultado: decide automaticamente se mostra serviços ou prestadores
  bool _exibirProfissionais = false;

  // ====== Google Maps
  GoogleMapController? _mapController;
  final Set<Marker> _marcadores = {};

  // ====== Firestore refs
  static const String _colCategoriasServ = 'categoriasServicos';
  static const String _colCategoriasProf = 'categoriasProfissionais';
  static const String _colUnidades = 'unidades';
  static const String _colServicos = 'servicos';
  static const String _colUsuarios = 'usuarios';
  static const String _colAgenda = 'agendaPrestador';

  // ====== Dados de dropdown
  List<_ItemRef> _categoriasServ = [];
  List<_ItemRef> _categoriasProf = [];
  List<String> _unidades = [];

  // ====== Resultados
  List<Map<String, dynamic>> _resultados = [];
  bool _carregando = false;

  // ====== Caches p/ enriquecer cards
  final Map<String, String> _cacheNomePrestador = {};
  final Map<String, String> _cacheImagemCategoria = {};
  final Map<String, String> _cacheUnidadeAbrev = {};

  // ====== NOVOS CACHES (avaliações e categoria profissional)
  final Map<String, Map<String, num>> _cacheAvalsPrest = {};
  final Map<String, Map<String, num>> _cacheAvalsServ = {};
  final Map<String, String> _cacheCategoriaProfNome = {};

  // === UI helpers / tema local ===
  final _gStart = const Color(0xFFB196FF);
  final _gEnd = const Color(0xFF6C3AF2);
  final _ink = const Color(0xFF1E1E24);
  final _muted = const Color(0xFF6B7280);
  final _stroke = const Color(0xFFE5E7EB);
  final _pillBg = const Color(0xFFF7F7FB);

  InputDecoration _input(String label, {String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _gEnd, width: 1.6),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );

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
    final fs = FirebaseFirestore.instance;

    final futures = await Future.wait([
      fs.collection(_colCategoriasServ).where('ativo', isEqualTo: true).get(),
      fs.collection(_colCategoriasProf).where('ativo', isEqualTo: true).get(),
      fs.collection(_colUnidades).where('ativo', isEqualTo: true).get(),
    ]);

    final servCats = futures[0].docs
        .map(
          (d) => _ItemRef(id: d.id, nome: (d.data()['nome'] ?? '').toString()),
        )
        .where((e) => e.nome.isNotEmpty)
        .toList();

    final profCats = futures[1].docs
        .map(
          (d) => _ItemRef(id: d.id, nome: (d.data()['nome'] ?? '').toString()),
        )
        .where((e) => e.nome.isNotEmpty)
        .toList();

    final unidades = futures[2].docs
        .map(
          (d) => (d.data()['abreviacao'] ?? d.data()['nome'] ?? '').toString(),
        )
        .where((e) => e.isNotEmpty)
        .toList();

    if (!mounted) return;
    setState(() {
      _categoriasServ = servCats;
      _categoriasProf = profCats;
      _unidades = unidades;
    });
  }

  Future<void> _buscar() async {
    setState(() {
      _filtrosExibidos = false;
      _exibirMapa = false;
      _carregando = true;
      _resultados.clear();
      _marcadores.clear();
      _exibirProfissionais = false;
    });

    if (!_validarHorarioDesejado()) {
      setState(() => _carregando = false);
      return;
    }

    final termo = _buscaController.text.trim().toLowerCase();

    try {
      final fs = FirebaseFirestore.instance;

      // ================= SERVIÇOS =================
      Query<Map<String, dynamic>> qs = fs
          .collection(_colServicos)
          .where('ativo', isEqualTo: true);

      if (_categoriaSelecionadaId != null &&
          _categoriaSelecionadaId!.isNotEmpty) {
        qs = qs.where('categoriaId', isEqualTo: _categoriaSelecionadaId);
      }
      if (_profissionalSelecionadoId != null &&
          _profissionalSelecionadoId!.isNotEmpty) {
        qs = qs.where('categoriaProfId', isEqualTo: _profissionalSelecionadoId);
      }
      if (_unidadeSelecionada != null && _unidadeSelecionada!.isNotEmpty) {
        qs = qs.where('unidade', isEqualTo: _unidadeSelecionada);
      }
      if (_pagamentosAceitos.isNotEmpty) {
        qs = qs.where('pagamentos', arrayContainsAny: _pagamentosAceitos);
      }

      final snapServ = await qs.limit(250).get();
      List<Map<String, dynamic>> servicos = snapServ.docs.map((d) {
        final m = d.data();
        m['id'] = d.id;
        return m;
      }).toList();

      // Filtro por nome
      servicos = servicos.where((e) {
        final nome = (e['titulo'] ?? e['nome'] ?? '').toString().toLowerCase();
        return termo.isEmpty || nome.contains(termo);
      }).toList();

      // ================= PROFISSIONAIS =================
      Query<Map<String, dynamic>> qu = fs
          .collection(_colUsuarios)
          .where('ativo', isEqualTo: true)
          .where('tipoPerfil', isEqualTo: 'Prestador');

      if (_profissionalSelecionadoId != null &&
          _profissionalSelecionadoId!.isNotEmpty) {
        qu = qu.where(
          'categoriaProfissionalId',
          isEqualTo: _profissionalSelecionadoId,
        );
      }

      final snapUsers = await qu.limit(200).get();
      List<Map<String, dynamic>> profissionais = snapUsers.docs.map((d) {
        final m = d.data();
        m['id'] = d.id;
        if (d.data().containsKey('geo')) m['geo'] = d.get('geo');
        return m;
      }).toList();

      profissionais = profissionais.where((u) {
        final nome = (u['nome'] ?? '').toString().toLowerCase();
        return termo.isEmpty || nome.contains(termo);
      }).toList();

      // ============ Decide o que mostrar ============
      final mostrarProf =
          profissionais.isNotEmpty &&
          (servicos.isEmpty || termo.split(' ').length <= 3);

      if (!mostrarProf) {
        servicos = await _enriquecerServicos(servicos);
      }

      final itens = mostrarProf ? profissionais : servicos;
      final markers = <Marker>{};

      // ============ Cria os marcadores ============
      if (mostrarProf) {
        // 🔹 Busca por profissionais diretos
        for (final e in profissionais) {
          final geo = e['geo'];
          LatLng? pos;

          if (geo is GeoPoint) {
            pos = LatLng(geo.latitude, geo.longitude);
          } else if (geo is Map) {
            final lat = (geo['latitude'] ?? geo['lat'])?.toDouble();
            final lon = (geo['longitude'] ?? geo['lng'])?.toDouble();
            if (lat != null && lon != null) pos = LatLng(lat, lon);
          }

          if (pos != null) {
            markers.add(
              Marker(
                markerId: MarkerId(e['id']),
                position: pos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
                onTap: () async {
                  final categoria = await _nomeCategoriaProf(
                    e['categoriaProfissionalId'] ?? '',
                  );
                  final rating = await _ratingPrestador(e['id']);
                  _customInfoWindowController.addInfoWindow!(
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F10D6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            e['nome'] ?? 'Prestador',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$categoria | ⭐ ${(rating['media'] ?? 0).toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisualizarPerfilPrestador(
                                    prestadorId: e['id'],
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Ver Perfil',
                              style: TextStyle(color: Color(0xFF3F10D6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pos!,
                  );
                },
              ),
            );
          }
        }
      } else {
        // 🔹 Busca por serviços → pegar geo do prestador
        final prestadoresUsados = <String>{};
        for (final serv in servicos) {
          final prestadorId = serv['prestadorId'];
          if (prestadorId == null || prestadoresUsados.contains(prestadorId))
            continue;

          final docPrest = await fs
              .collection(_colUsuarios)
              .doc(prestadorId)
              .get();
          if (!docPrest.exists) continue;
          final prestador = docPrest.data();
          if (prestador == null || !prestador.containsKey('geo')) continue;

          final geo = prestador['geo'];
          LatLng? pos;

          if (geo is GeoPoint) {
            pos = LatLng(geo.latitude, geo.longitude);
          } else if (geo is Map) {
            final lat = (geo['latitude'] ?? geo['lat'])?.toDouble();
            final lon = (geo['longitude'] ?? geo['lng'])?.toDouble();
            if (lat != null && lon != null) pos = LatLng(lat, lon);
          }

          if (pos != null) {
            prestadoresUsados.add(prestadorId);
            markers.add(
              Marker(
                markerId: MarkerId(prestadorId),
                position: pos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
                onTap: () async {
                  // pega o nome do serviço atual que está sendo iterado no loop
                  final nomeServico =
                      (serv['titulo'] ?? serv['nome'] ?? 'Serviço').toString();
                  final prestadorNome = (prestador['nome'] ?? '').toString();

                  final cat = await _nomeCategoriaProf(
                    prestador['categoriaProfissionalId'] ?? '',
                  );
                  final rating = await _ratingPrestador(prestadorId);

                  _customInfoWindowController.addInfoWindow!(
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F10D6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // nome do serviço
                          Text(
                            nomeServico,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // nome do prestador
                          Text(
                            prestadorNome,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // categoria + avaliação média
                          Text(
                            '$cat | ⭐ ${(rating['media'] ?? 0).toStringAsFixed(1)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // botão de ver perfil
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisualizarPerfilPrestador(
                                    prestadorId: prestadorId,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Perfil Prestador',
                              style: TextStyle(
                                color: Color(0xFF3F10D6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pos!,
                  );
                },
              ),
            );
          }
        }
      }

      // ============ Atualiza estado ============
      if (!mounted) return;
      setState(() {
        _exibirProfissionais = mostrarProf;
        _resultados = itens;
        _marcadores.addAll(markers);
        _carregando = false;
      });

      // Centraliza mapa
      if (_mapController != null) {
        if (markers.isNotEmpty) {
          if (markers.length == 1) {
            final pos = markers.first.position;
            _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
          } else {
            LatLngBounds bounds = _boundsFromMarkers(markers);
            _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 60),
            );
          }
        } else {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              const CameraPosition(
                target: LatLng(-17.792765, -50.919582), // Rio Verde
                zoom: 13,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar: $e')));
    }
  }

  // Helper para centralizar em vários marcadores
  LatLngBounds _boundsFromMarkers(Set<Marker> markers) {
    final latitudes = markers.map((m) => m.position.latitude).toList();
    final longitudes = markers.map((m) => m.position.longitude).toList();

    final southwest = LatLng(
      latitudes.reduce((a, b) => a < b ? a : b),
      longitudes.reduce((a, b) => a < b ? a : b),
    );
    final northeast = LatLng(
      latitudes.reduce((a, b) => a > b ? a : b),
      longitudes.reduce((a, b) => a > b ? a : b),
    );

    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  /// Enriquecer lista de serviços com nome prestador / imagem categoria / unidade
  Future<List<Map<String, dynamic>>> _enriquecerServicos(
    List<Map<String, dynamic>> servicos,
  ) async {
    final fs = FirebaseFirestore.instance;

    Future<String> nomePrest(String id) async {
      if (id.isEmpty) return '';
      if (_cacheNomePrestador.containsKey(id)) return _cacheNomePrestador[id]!;
      final doc = await fs.collection(_colUsuarios).doc(id).get();
      final nome = (doc.data()?['nome'] ?? '').toString();
      _cacheNomePrestador[id] = nome;
      return nome;
    }

    Future<String> imgCategoria(String id) async {
      if (id.isEmpty) return '';
      if (_cacheImagemCategoria.containsKey(id)) {
        return _cacheImagemCategoria[id]!;
      }
      final doc = await fs.collection(_colCategoriasServ).doc(id).get();
      final url = (doc.data()?['imagemUrl'] ?? '').toString();
      _cacheImagemCategoria[id] = url;
      return url;
    }

    Future<String> abrevUnidade(String id) async {
      if (id.isEmpty) return '';
      if (_cacheUnidadeAbrev.containsKey(id)) return _cacheUnidadeAbrev[id]!;
      final doc = await fs.collection(_colUnidades).doc(id).get();
      final ab = (doc.data()?['abreviacao'] ?? doc.data()?['sigla'] ?? '')
          .toString();
      _cacheUnidadeAbrev[id] = ab;
      return ab;
    }

    final futures = servicos.map((s) async {
      final m = Map<String, dynamic>.from(s);

      final pid = (m['prestadorId'] ?? '').toString();
      final nomeInline = (m['prestadorNome'] ?? '').toString();
      if (nomeInline.isEmpty && pid.isNotEmpty) {
        m['prestadorNome'] = await nomePrest(pid);
      }

      final catId = (m['categoriaServicoId'] ?? m['categoriaId'] ?? '')
          .toString();
      if ((m['imagemUrl'] ?? '').toString().isEmpty && catId.isNotEmpty) {
        m['categoriaImagemUrl'] = await imgCategoria(catId);
      }

      final uid = (m['unidadeId'] ?? m['unidade'] ?? '').toString();
      if ((m['unidadeAbreviacao'] ?? '').toString().isEmpty && uid.isNotEmpty) {
        m['unidadeAbreviacao'] = await abrevUnidade(uid);
      }

      return m;
    }).toList();

    return await Future.wait(futures);
  }

  Future<Set<String>> _prestadoresDisponiveisNaDataHora(
    DateTime data,
    String horaHHmm,
  ) async {
    final fs = FirebaseFirestore.instance;
    final dataStr = DateFormat('yyyy-MM-dd').format(data);

    final snap = await fs
        .collection(_colAgenda)
        .where('data', isEqualTo: dataStr)
        .get();

    final set = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final prestadorId = (m['prestadorId'] ?? '').toString();
      final horas = (m['horasLivres'] ?? []) as List<dynamic>;
      if (horaHHmm.isEmpty) {
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
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _validarHorarioDesejado() {
    // nada pra validar se não tem data ou não tem horário
    if (_dataSelecionada == null || _horarioController.text.trim().isEmpty) {
      return true;
    }

    final now = DateTime.now();
    final hhmm = _horarioController.text.trim();
    final parts = hhmm.split(':');
    if (parts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o horário no formato HH:mm')),
      );
      return false;
    }

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horário inválido. Use HH:mm')),
      );
      return false;
    }

    final escolhido = DateTime(
      _dataSelecionada!.year,
      _dataSelecionada!.month,
      _dataSelecionada!.day,
      h,
      m,
    );

    if (_isSameDay(_dataSelecionada!, now) && escolhido.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O horário desejado não pode ser no passado para hoje.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

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
      _exibirProfissionais = false;
    });
  }

  // ======= Helpers de avaliações e categoria profissional =======
  Future<String> _nomeCategoriaProf(String id) async {
    if (id.isEmpty) return '';
    if (_cacheCategoriaProfNome.containsKey(id)) {
      return _cacheCategoriaProfNome[id]!;
    }
    final local = _categoriasProf
        .firstWhere((c) => c.id == id, orElse: () => const _ItemRef.empty())
        .nome;
    if (local.isNotEmpty) {
      _cacheCategoriaProfNome[id] = local;
      return local;
    }
    final doc = await FirebaseFirestore.instance
        .collection(_colCategoriasProf)
        .doc(id)
        .get();
    final nome = (doc.data()?['nome'] ?? '').toString();
    _cacheCategoriaProfNome[id] = nome;
    return nome;
  }

  Future<Map<String, num>> _ratingPrestador(
    String prestadorId, {
    num? notaAgg,
    num? qtdAgg,
  }) async {
    if (_cacheAvalsPrest.containsKey(prestadorId)) {
      return _cacheAvalsPrest[prestadorId]!;
    }
    if (notaAgg != null && qtdAgg != null) {
      final r = {'media': notaAgg.toDouble(), 'total': qtdAgg.toInt()};
      _cacheAvalsPrest[prestadorId] = r;
      return r;
    }
    final fs = FirebaseFirestore.instance;
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await fs
          .collection('avaliacoes')
          .where('prestadorId', isEqualTo: prestadorId)
          .get();
    } catch (_) {
      try {
        snap = await fs
            .collection('avaliacoesPrestador')
            .where('prestadorId', isEqualTo: prestadorId)
            .get();
      } catch (__) {
        return {'media': 0.0, 'total': 0};
      }
    }
    double soma = 0;
    int tot = 0;
    for (final d in snap.docs) {
      final n = (d.data()['nota'] ?? d.data()['rating'] ?? 0);
      if (n is num) {
        soma += n.toDouble();
        tot++;
      }
    }
    final res = {'media': tot > 0 ? soma / tot : 0.0, 'total': tot};
    _cacheAvalsPrest[prestadorId] = res;
    return res;
  }

  Future<Map<String, num>> _ratingServico(
    String servicoId, {
    num? notaAgg,
    num? qtdAgg,
  }) async {
    if (_cacheAvalsServ.containsKey(servicoId)) {
      return _cacheAvalsServ[servicoId]!;
    }
    if (notaAgg != null && qtdAgg != null) {
      final r = {'media': notaAgg.toDouble(), 'total': qtdAgg.toInt()};
      _cacheAvalsServ[servicoId] = r;
      return r;
    }
    final fs = FirebaseFirestore.instance; // ✅ CORRIGIDO
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await fs
          .collection('avaliacoes')
          .where('servicoId', isEqualTo: servicoId)
          .get();
    } catch (_) {
      try {
        snap = await fs
            .collection('avaliacoesServico')
            .where('servicoId', isEqualTo: servicoId)
            .get();
      } catch (__) {
        return {'media': 0.0, 'total': 0};
      }
    }
    double soma = 0;
    int tot = 0;
    for (final d in snap.docs) {
      final n = (d.data()['nota'] ?? d.data()['rating'] ?? 0);
      if (n is num) {
        soma += n.toDouble();
        tot++;
      }
    }
    final res = {'media': tot > 0 ? soma / tot : 0.0, 'total': tot};
    _cacheAvalsServ[servicoId] = res;
    return res;
  }

  // Mostra ⭐ média (N avaliações)
  Widget _ratingInline(
    Future<Map<String, num>> future, {
    bool showChevron = false,
    VoidCallback? onTap,
  }) {
    final child = FutureBuilder<Map<String, num>>(
      future: future,
      builder: (_, snap) {
        final media = (snap.data?['media'] ?? 0).toDouble();
        final total = (snap.data?['total'] ?? 0).toInt();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              media.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text('($total avaliações)', style: const TextStyle(fontSize: 12)),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.deepPurple,
              ),
            ],
          ],
        );
      },
    );

    return onTap == null
        ? child
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
  }

  // versão com navegação para a tela de avaliações de SERVIÇO
  Widget _ratingInlineLink({
    required String prestadorId,
    required String servicoId,
    required String servicoTitulo,
    required Future<Map<String, num>> future,
  }) {
    return _ratingInline(
      future,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisualizarAvaliacoesScreen(
              prestadorId: prestadorId,
              servicoId: servicoId,
              servicoTitulo: servicoTitulo,
            ),
          ),
        );
      },
    );
  }

  // =================== UI ===================

  // Topo com gradiente
  Widget _buildTopoComBusca() {
    // antes: Container(... decoration: BoxDecoration(gradient: ...), child: Row(...))
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          // antes tinha style com fundo branco translúcido; pode remover:
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Se estiver nos Filtros E já houver resultados, volta para a lista
              if (_filtrosExibidos && _resultados.isNotEmpty) {
                setState(() => _filtrosExibidos = false);
                return;
              }
              // Caso contrário, vai para a Home do Cliente
              context.goHome(); // same as RotasNavegacao.irParaHome(context)
            },
          ),

          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _buscaController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: _input(
                '',
                hint: 'Buscar serviços ou profissionais...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (!_filtrosExibidos) ...[
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFF3F10D6),
              ),
              onPressed: () => setState(() => _filtrosExibidos = true),
            ),
          ],
        ],
      ),
    );
  }

  // Toggle Lista/Mapa com visual “pill”
  Widget _buildToggleListaMapa() {
    return Container(
      decoration: BoxDecoration(
        color: _pillBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(10),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 64),
        isSelected: [!_exibirMapa, _exibirMapa],
        onPressed: (i) => setState(() => _exibirMapa = (i == 1)),
        selectedColor: Colors.white,
        color: const Color(0xFF3F10D6),
        fillColor: const Color(0xFF3F10D6),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [Icon(Icons.list), SizedBox(width: 6), Text('Lista')],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [Icon(Icons.map), SizedBox(width: 6), Text('Mapa')],
            ),
          ),
        ],
      ),
    );
  }

  // título com singular/plural
  String _tituloResultados(int total) {
    final base = _exibirProfissionais ? 'prestador' : 'serviço';
    final palavra = total == 1
        ? base
        : (base == 'prestador' ? 'prestadores' : 'serviços');
    final verbo = total == 1 ? 'encontrado' : 'encontrados';
    return '$total $palavra $verbo';
  }

  Widget _buildMapa() {
    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },
            markers: _marcadores,
            onTap: (pos) => _customInfoWindowController.hideInfoWindow!(),
            onCameraMove: (pos) => _customInfoWindowController.onCameraMove!(),
            initialCameraPosition: const CameraPosition(
              target: LatLng(-17.7960, -50.9220), // Rio Verde
              zoom: 13,
            ),
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 160,
            width: 230,
            offset: 50,
          ),
        ],
      ),
    );
  }

  // ---------------- CARDS ----------------

  Widget _buildServicoCard(Map<String, dynamic> e) {
    final servicoId = (e['id'] ?? '').toString();
    final titulo = (e['titulo'] ?? e['nome'] ?? 'Serviço').toString();
    final descricao = (e['descricao'] ?? '').toString();
    final prestadorId = (e['prestadorId'] ?? '').toString();
    final prestador = (e['prestadorNome'] ?? '').toString().isNotEmpty
        ? (e['prestadorNome'] ?? '').toString()
        : (e['prestadorNome'] = _cacheNomePrestador[prestadorId] ?? '')
              .toString();

    final cidade = (e['cidade'] ?? '').toString();
    final valorMedio = e['valorMedio'] ?? e['precoMin'];
    final unidadeAbrev = (e['unidadeAbreviacao'] ?? '').toString();

    final double? nota = (e['nota'] is num)
        ? (e['nota'] as num).toDouble()
        : (e['notaMedia'] is num)
        ? (e['notaMedia'] as num).toDouble()
        : null;
    final int? avaliacoes = (e['avaliacoes'] is num)
        ? (e['avaliacoes'] as num).toInt()
        : (e['qtdAvaliacoes'] is num)
        ? (e['qtdAvaliacoes'] as num).toInt()
        : null;

    final imagemServico = (e['imagemUrl'] ?? '').toString();
    final imagemCateg = (e['categoriaImagemUrl'] ?? '').toString();

    // ✅ Mantém a exibição original: se o serviço não tiver imagem, usa da categoria
    final imagemFinal = imagemServico.isNotEmpty ? imagemServico : imagemCateg;

    String formatPreco(dynamic v) {
      double? valor;
      if (v is num) valor = v.toDouble();
      if (v is String) {
        final cleaned = v
            .replaceAll('R\$', '')
            .replaceAll('.', '')
            .replaceAll(',', '.')
            .trim();
        valor = double.tryParse(cleaned);
      }
      if (valor == null) return 'R\$0,00';
      return 'R\$${valor.toStringAsFixed(2).replaceAll('.', ',')}';
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    image: (imagemFinal.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(imagemFinal),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imagemFinal.isEmpty
                      ? const Icon(Icons.handyman, color: Colors.deepPurple)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _ratingInlineLink(
                            prestadorId: prestadorId,
                            servicoId: servicoId,
                            servicoTitulo: titulo,
                            future: _ratingServico(
                              servicoId,
                              notaAgg: nota,
                              qtdAgg: avaliacoes,
                            ),
                          ),
                        ],
                      ),
                      if (descricao.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Prestador: ${prestador.isNotEmpty ? prestador : prestadorId}',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cidade.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(cidade, style: const TextStyle(fontSize: 13)),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${formatPreco(valorMedio)}${unidadeAbrev.isNotEmpty ? '/$unidadeAbrev' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VisualizarPerfilPrestador(prestadorId: prestadorId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Perfil Prestador'),
                ),
                Flexible(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SolicitarOrcamentoScreen(
                            prestadorId: prestadorId,
                            servicoId: servicoId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Solicitar Orçamento',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestadorCard(Map<String, dynamic> u) {
    final id = (u['id'] ?? '').toString();
    final nome = (u['nome'] ?? id).toString();
    final endereco = (u['endereco'] is Map)
        ? (u['endereco'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final cidade = (endereco['cidade'] ?? u['cidade'] ?? '').toString();
    final fotoUrl = (u['fotoUrl'] ?? '').toString().trim();
    final tempoExp = (u['tempoExperiencia'] ?? '').toString();
    final catProfId = (u['categoriaProfissionalId'] ?? '').toString();

    final double? nota = (u['nota'] is num)
        ? (u['nota'] as num).toDouble()
        : (u['avaliacao'] is num)
        ? (u['avaliacao'] as num).toDouble()
        : (u['rating'] is num)
        ? (u['rating'] as num).toDouble()
        : null;
    final int? avaliacoes = (u['avaliacoes'] is num)
        ? (u['avaliacoes'] as num).toInt()
        : (u['qtdAvaliacoes'] is num)
        ? (u['qtdAvaliacoes'] as num).toInt()
        : null;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (fotoUrl.isNotEmpty)
                  ? NetworkImage(fotoUrl)
                  : null,
              child: (fotoUrl.isEmpty)
                  ? const Icon(Icons.person, size: 32, color: Colors.deepPurple)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ratingInline(
                        _ratingPrestador(id, notaAgg: nota, qtdAgg: avaliacoes),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VisualizarAvaliacoesPrestador(
                                prestadorId: id,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: _nomeCategoriaProf(catProfId),
                    builder: (_, snapCat) {
                      final cat = (snapCat.data ?? '').trim();
                      return Row(
                        children: [
                          Flexible(
                            child: Text(
                              cat.isNotEmpty ? cat : 'Categoria não informada',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '|',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              cidade,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: 18,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tempoExp.isEmpty
                            ? 'Experiência não informada'
                            : tempoExp,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VisualizarPerfilPrestador(prestadorId: id),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                            side: const BorderSide(color: Colors.deepPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Ver Perfil'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Abrir Agenda (implementar rota)',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Agenda',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
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

  Widget _buildResultado() {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_resultados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhum resultado encontrado. Ajuste os filtros e tente novamente.',
        ),
      );
    }

    final total = _resultados.length;
    final childrenList = _exibirMapa
        ? [_buildMapa()]
        : (_exibirProfissionais
              ? _resultados.map(_buildPrestadorCard).toList()
              : _resultados.map(_buildServicoCard).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _tituloResultados(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildToggleListaMapa(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...childrenList,
      ],
    );
  }

  // ======= Filtro UI =======
  Widget _buildFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        _sectionTitle('Categoria de serviço'),
        DropdownButtonFormField<String>(
          initialValue: _categoriaSelecionadaId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._categoriasServ.map(
              (e) => DropdownMenuItem(value: e.id, child: Text(e.nome)),
            ),
          ],
          onChanged: (v) {
            setState(() {
              _categoriaSelecionadaId = v;
              _categoriaSelecNome = _categoriasServ
                  .firstWhere(
                    (c) => c.id == v,
                    orElse: () => const _ItemRef.empty(),
                  )
                  .nome;
            });
          },
          decoration: _input(''),
        ),

        _sectionTitle('Categoria profissional'),
        DropdownButtonFormField<String>(
          initialValue: _profissionalSelecionadoId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._categoriasProf.map(
              (e) => DropdownMenuItem(value: e.id, child: Text(e.nome)),
            ),
          ],
          onChanged: (v) {
            setState(() {
              _profissionalSelecionadoId = v;
              _profissionalSelecNome = _categoriasProf
                  .firstWhere(
                    (c) => c.id == v,
                    orElse: () => const _ItemRef.empty(),
                  )
                  .nome;
            });
          },
          decoration: _input(''),
        ),

        _sectionTitle('Unidade de medida'),
        DropdownButtonFormField<String>(
          initialValue: _unidadeSelecionada,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))),
          ],
          onChanged: (v) => setState(() => _unidadeSelecionada = v),
          decoration: _input(''),
        ),

        // --- Valor por unidade ---
        _sectionTitle('Valor por unidade'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minValueController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  _MoedaPtBrInputFormatter(), // ⬅️ máscara pt-BR (R$ 1.234,56)
                ],
                decoration: _input('Mínimo', hint: 'R\$ 0,00'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _maxValueController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  _MoedaPtBrInputFormatter(), // ⬅️ máscara pt-BR (R$ 1.234,56)
                ],
                decoration: _input('Máximo', hint: 'R\$ 0,00'),
              ),
            ),
          ],
        ),

        // --- Avaliação mínima (sem checkmark e com toggle) ---
        _sectionTitle('Avaliação mínima'),
        LayoutBuilder(
          builder: (context, constraints) {
            const numberSize = 16.0; // ajuste se quiser maior
            const starSize = 22.0; // ajuste se quiser maior
            const chipHPad = 12.0;
            const chipVPad = 8.0;

            const gap = 8.0;
            final itemW = (constraints.maxWidth - gap * 4) / 5;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [5, 4, 3, 2, 1].map((v) {
                final selected = _avaliacaoMinima == v;
                return SizedBox(
                  width: itemW,
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _avaliacaoMinima = selected ? 0 : v; // toggle
                    }),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$v',
                          style: const TextStyle(
                            fontSize: numberSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star,
                          size: starSize,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                    side: BorderSide(
                      color: selected ? _gEnd : _stroke,
                      width: 1.2,
                    ),
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    backgroundColor: _pillBg,
                    selectedColor: const Color(0xFFEDE7FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: chipHPad,
                      vertical: chipVPad,
                    ),
                    labelPadding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),

        _sectionTitle('Localização'),
        TextField(
          controller: _localizacaoController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CepInputFormatter(), // máscara 00000-000
          ],
          decoration: _input(
            '',
            hint: 'Informe seu CEP',
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
        ),

        _sectionTitle('Raio de distância (km)'),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _raioDistancia,
                onChanged: (v) => setState(() => _raioDistancia = v),
                min: 1,
                max: 50,
                divisions: 49,
                label: _raioDistancia.toStringAsFixed(0),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                '${_raioDistancia.toStringAsFixed(0)} km',
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),

        _sectionTitle('Disponibilidade'),
        DropdownButtonFormField<String>(
          initialValue: _disponibilidadeSelecionada,
          items: const [
            DropdownMenuItem(
              value: null,
              child: Text('Ignorar disponibilidade'),
            ),
            DropdownMenuItem(value: 'Disponível', child: Text('Disponível')),
            DropdownMenuItem(
              value: 'Indisponível',
              child: Text('Indisponível'),
            ),
          ],
          onChanged: (v) => setState(() => _disponibilidadeSelecionada = v),
          decoration: _input(''),
        ),
        const SizedBox(height: 12),

        // Data desejada (campo inteiro, embaixo)
        TextField(
          readOnly: true,
          controller: TextEditingController(
            text: _dataSelecionada == null
                ? ''
                : DateFormat('dd/MM/yyyy').format(_dataSelecionada!),
          ),
          decoration:
              _input(
                'Data desejada',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ).copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.event),
                  onPressed: _selecionarData,
                ),
              ),
        ),
        const SizedBox(height: 12),

        // Horário desejado (campo inteiro, embaixo) + MÁSCARA HH:mm
        TextField(
          controller: _horarioController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _HoraInputFormatter(), // máscara HH:mm
          ],
          decoration: _input(
            'Horário desejado',
            hint: '00:00',
            prefixIcon: const Icon(Icons.access_time_outlined),
          ),
        ),

        _sectionTitle('Meios de pagamento aceitos'),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Os meios de pagamento servem apenas para informativo; não processamos pagamentos.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ),
        _payTile('Dinheiro'),
        _payTile('Pix'),
        _payTile('Cartão de crédito/débito'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _payTile(String label) {
    final checked = _pagamentosAceitos.contains(label);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: CheckboxListTile(
        dense: true,
        value: checked,
        onChanged: (v) => setState(
          () => v!
              ? _pagamentosAceitos.add(label)
              : _pagamentosAceitos.remove(label),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 16, // ajuste se quiser
            fontWeight: FontWeight.w600,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
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
        child: Container(
          color: const Color(0xFFF6F6FB),
          child: Column(
            children: [
              _buildTopoComBusca(),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _filtrosExibidos
                            ? _buildFiltro()
                            : _buildResultado(),
                      ),
                    ),
                    if (_filtrosExibidos)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            // === Buscar (igual ao "Solicitar Orçamento") ===
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _buscar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  minimumSize: const Size(0, 40),
                                  alignment: Alignment.center,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Buscar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // === Limpar Filtros (igual ao "Perfil Prestador") ===
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _limparFiltros,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  side: const BorderSide(
                                    color: Colors.deepPurple,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  minimumSize: const Size(0, 40),
                                  alignment: Alignment.center,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Limpar Filtros'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ClienteBottomNav(selectedIndex: 1),
    );
  }
}

class _CepInputFormatter extends TextInputFormatter {
  // Aplica máscara 00000-000 e limita a 8 dígitos
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    String out;
    if (limited.length <= 5) {
      out = limited;
    } else {
      out = '${limited.substring(0, 5)}-${limited.substring(5)}';
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

/// Formatter de moeda pt-BR: “R$ 1.234,56”
class _MoedaPtBrInputFormatter extends TextInputFormatter {
  final NumberFormat _nf = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final value = double.parse(digits) / 100.0;
    final text = _nf.format(value);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _HoraInputFormatter extends TextInputFormatter {
  // Aplica máscara HH:mm enquanto digita (limita a 4 dígitos -> 00:00)
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    String out;
    if (limited.length <= 2) {
      out = limited;
    } else {
      out = '${limited.substring(0, 2)}:${limited.substring(2)}';
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

// ======== Botões customizados ========
class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _GradientButton({required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onPressed,
      child: Ink(
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C3AF2), Color(0xFF3F10D6)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _GhostButton({required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3F10D6),
        side: const BorderSide(color: Color(0xFFDDD7FF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        minimumSize: const Size.fromHeight(44),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ======== Modelo simples de item ========
class _ItemRef {
  final String id;
  final String nome;
  const _ItemRef({required this.id, required this.nome});
  const _ItemRef.empty() : id = '', nome = '';
}
