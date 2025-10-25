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
import 'package:geolocator/geolocator.dart';

class BuscarServicosScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const BuscarServicosScreen({super.key, this.firestore});

  @override
  State<BuscarServicosScreen> createState() => BuscarServicosScreenState();
}

class BuscarServicosScreenState extends State<BuscarServicosScreen> {
  final TextEditingController buscaController = TextEditingController();
  final TextEditingController minValueController = TextEditingController();
  final TextEditingController maxValueController = TextEditingController();
  final TextEditingController localizacaoController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  String? categoriaSelecionadaId;
  String? _profissionalSelecionadoId;
  String? _unidadeSelecionada;
  String? _disponibilidadeSelecionada;
  DateTime? dataSelecionada;
  int avaliacaoMinima = 0;
  double _raioDistancia = 10.0;
  List<String> pagamentosAceitos = [];
  bool _filtrosExibidos = true;
  bool _exibirMapa = false;
  bool exibirProfissionais = false;

  GoogleMapController? _mapController;
  final Set<Marker> _marcadores = {};
  LatLng? _centroBusca;
  Set<Circle> _circulos = {};
  static const String _colCategoriasServ = 'categoriasServicos';
  static const String _colCategoriasProf = 'categoriasProfissionais';
  static const String _colUnidades = 'unidades';
  static const String _colServicos = 'servicos';
  static const String _colUsuarios = 'usuarios';
  static const String _colAgenda = 'agendaPrestador';
  List<_ItemRef> _categoriasServ = [];
  List<_ItemRef> _categoriasProf = [];
  List<String> _unidades = [];

  List<Map<String, dynamic>> _resultados = [];
  bool _carregando = false;

  final Map<String, String> _cacheNomePrestador = {};
  final Map<String, String> _cacheImagemCategoria = {};
  final Map<String, String> _cacheUnidadeAbrev = {};
  final Map<String, Map<String, num>> cacheAvalsPrest = {};
  final Map<String, Map<String, num>> _cacheAvalsServ = {};
  final Map<String, String> cacheCategoriaProfNome = {};

  final _gEnd = const Color(0xFF6C3AF2);
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

  // 🔧 Banco de dados
  // 🔧 Banco de dados
  FirebaseFirestore? _db;

  // Construtor usado para testes (injeta o fake)
  BuscarServicosScreenState.forTest(FirebaseFirestore db) {
    _db = db;
  }

  // Construtor padrão
  BuscarServicosScreenState();

  @override
  void initState() {
    super.initState();

    // Inicializa o Firestore — usa o fake se fornecido no widget, senão o real
    _db ??= widget.firestore ?? FirebaseFirestore.instance;

    // Evita execução desnecessária em ambiente de teste
    if (!mounted) return;

    _verificarPermissaoLocalizacao();
    _carregarFiltrosBase();
  }

  // Getter defensivo — garante _db não nulo em métodos diretos (ex: testes)
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    if (mounted) {
      buscaController.dispose();
      minValueController.dispose();
      maxValueController.dispose();
      localizacaoController.dispose();
      horarioController.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarFiltrosBase() async {
    final fs = db; // usa o getter defensivo, nunca é nulo

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

  Future<void> _verificarPermissaoLocalizacao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ative o GPS para buscar serviços próximos.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissão de localização negada. Habilite nas configurações para usar o mapa.',
          ),
        ),
      );
      return;
    }

    // ✅ pega localização atual
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _centroBusca = LatLng(pos.latitude, pos.longitude);
      atualizarCirculo();
    });

    // centraliza o mapa
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
      ),
    );

    // já filtra por raio inicial
    filtrarPorRaio();
  }

  Future<void> _buscar() async {
    if (!mounted) return;
    setState(() {
      _filtrosExibidos = false;
      _exibirMapa = false;
      _carregando = true;
      _resultados.clear();
      _marcadores.clear();
      exibirProfissionais = false;
    });

    if (!validarHorarioDesejado()) {
      setState(() => _carregando = false);
      return;
    }

    final termo = buscaController.text.trim().toLowerCase();
    final fs = db; // ✅ usa o getter defensivo

    try {
      bool buscarServicos = true;
      if (_profissionalSelecionadoId != null &&
          _profissionalSelecionadoId!.isNotEmpty &&
          (categoriaSelecionadaId == null || categoriaSelecionadaId!.isEmpty)) {
        buscarServicos = false;
      }

      if (buscarServicos) {
        Query<Map<String, dynamic>> qs = fs
            .collection(_colServicos)
            .where('ativo', isEqualTo: true);

        if (categoriaSelecionadaId?.isNotEmpty ?? false) {
          qs = qs.where('categoriaId', isEqualTo: categoriaSelecionadaId);
        }
        if (_profissionalSelecionadoId?.isNotEmpty ?? false) {
          qs = qs.where(
            'categoriaProfId',
            isEqualTo: _profissionalSelecionadoId,
          );
        }

        if (_unidadeSelecionada != null && _unidadeSelecionada!.isNotEmpty) {
          final unidadeAbrev = _unidadeSelecionada!.trim().toLowerCase();
          final queryUnidade = await db
              .collection(_colUnidades)
              .where('abreviacao', isEqualTo: unidadeAbrev)
              .limit(1)
              .get();

          if (queryUnidade.docs.isNotEmpty) {
            final unidadeId = queryUnidade.docs.first.id;
            qs = qs.where('unidadeId', isEqualTo: unidadeId);
          } else {
            qs = qs.where('unidadeId', isEqualTo: '__nao_existente__');
          }
        }

        if (pagamentosAceitos.isNotEmpty) {
          qs = qs.where('pagamentos', arrayContainsAny: pagamentosAceitos);
        }

        final snapServ = await qs.limit(250).get();
        List<Map<String, dynamic>> servicos = snapServ.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList();

        servicos = servicos.where((e) {
          final nome = (e['titulo'] ?? e['nome'] ?? '')
              .toString()
              .toLowerCase();
          return termo.isEmpty || nome.contains(termo);
        }).toList();

        double? minVal = double.tryParse(
          minValueController.text
              .replaceAll(RegExp(r'[^0-9,\.]'), '')
              .replaceAll(',', '.'),
        );
        double? maxVal = double.tryParse(
          maxValueController.text
              .replaceAll(RegExp(r'[^0-9,\.]'), '')
              .replaceAll(',', '.'),
        );

        if (minVal != null || maxVal != null) {
          servicos = servicos.where((e) {
            final minimo = (e['valorMinimo'] ?? 0).toDouble();
            final medio = (e['valorMedio'] ?? 0).toDouble();
            final maximo = (e['valorMaximo'] ?? 0).toDouble();
            final base = medio > 0 ? medio : ((minimo + maximo) / 2);

            if (minVal != null && base < minVal) return false;
            if (maxVal != null && base > maxVal) return false;
            return true;
          }).toList();
        }

        if (avaliacaoMinima > 0) {
          List<Map<String, dynamic>> filtrados = [];
          for (final s in servicos) {
            final rate = await ratingServico(s['id']);
            if ((rate['media'] ?? 0) >= avaliacaoMinima) filtrados.add(s);
          }
          servicos = filtrados;
        }

        if (_disponibilidadeSelecionada != null &&
            _disponibilidadeSelecionada != 'Ignorar disponibilidade' &&
            dataSelecionada != null) {
          final hora = horarioController.text.trim();
          final disponiveis = await prestadoresDisponiveisNaDataHora(
            dataSelecionada!,
            hora,
          );
          if (_disponibilidadeSelecionada == 'Disponível') {
            servicos = servicos
                .where((s) => disponiveis.contains(s['prestadorId']))
                .toList();
          } else if (_disponibilidadeSelecionada == 'Indisponível') {
            servicos = servicos
                .where((s) => !disponiveis.contains(s['prestadorId']))
                .toList();
          }
        }

        // Filtro de localização + raio
        if (_centroBusca != null) {
          atualizarCirculo();
          await filtrarPorRaio();
        }
      } else {
        Query<Map<String, dynamic>> qu = fs
            .collection(_colUsuarios)
            .where('ativo', isEqualTo: true)
            .where('tipoPerfil', isEqualTo: 'Prestador');

        if (_profissionalSelecionadoId?.isNotEmpty ?? false) {
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

        final markers = <Marker>{};
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
                  final categoria = await nomeCategoriaProf(
                    e['categoriaProfissionalId'] ?? '',
                  );
                  final rating = await ratingPrestador(e['id']);
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

        if (!mounted) return;
        setState(() {
          _resultados = profissionais;
          _marcadores.addAll(markers);
          exibirProfissionais = true;
          _carregando = false;
        });
      }

      if (_mapController != null && _marcadores.isNotEmpty) {
        if (_marcadores.length == 1) {
          final pos = _marcadores.first.position;
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));
        } else {
          LatLngBounds bounds = boundsFromMarkers(_marcadores);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 60),
          );
        }
      } else {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              target: LatLng(-17.792765, -50.919582),
              zoom: 13,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar: $e')));
    }
  }

  void atualizarCirculo() {
    if (_centroBusca == null) return;
    setState(() {
      _circulos = {
        Circle(
          circleId: const CircleId('raio_busca'),
          center: _centroBusca!,
          radius: _raioDistancia * 1000,
          fillColor: Colors.deepPurple.withOpacity(0.15),
          strokeColor: Colors.deepPurple,
          strokeWidth: 2,
        ),
      };
    });
    filtrarPorRaio();
  }

  Future<void> filtrarPorRaio() async {
    if (_centroBusca == null) return;

    final fs = db; // usa o getter defensivo
    final raioKm = _raioDistancia;

    final snap = await fs
        .collection('servicos')
        .where('ativo', isEqualTo: true)
        .get();

    final todosServicos = snap.docs.map((d) {
      final m = d.data();
      m['id'] = d.id;
      return m;
    }).toList();

    List<Map<String, dynamic>> dentroRaio = [];

    for (final s in todosServicos) {
      final prestadorId = s['prestadorId'];
      if (prestadorId == null) continue;

      final docPrest = await fs.collection('usuarios').doc(prestadorId).get();
      if (!docPrest.exists) continue;

      final geo = docPrest.data()?['geo'];
      if (geo == null) continue;

      double? lat;
      double? lon;

      if (geo is GeoPoint) {
        lat = geo.latitude;
        lon = geo.longitude;
      } else if (geo is Map) {
        lat = (geo['latitude'] ?? geo['lat'])?.toDouble();
        lon = (geo['longitude'] ?? geo['lng'])?.toDouble();
      } else if (geo is String) {
        final regex = RegExp(r'([-0-9.]+)[^0-9.]+([-0-9.]+)');
        final match = regex.firstMatch(geo);
        if (match != null) {
          lat = double.tryParse(match.group(1)!);
          lon = double.tryParse(match.group(2)!);
        }
      }

      if (lat == null || lon == null) continue;

      final dist = distanciaKm(
        _centroBusca!.latitude,
        _centroBusca!.longitude,
        lat,
        lon,
      );

      if (dist <= raioKm) {
        dentroRaio.add(s);
      }
    }

    setState(() {
      _resultados = dentroRaio;
      _marcadores.clear();

      for (final s in dentroRaio) {
        final prestadorId = s['prestadorId'];
        final docPrest = fs.collection('usuarios').doc(prestadorId);
        docPrest.get().then((p) {
          final geo = p.data()?['geo'];
          if (geo is GeoPoint) {
            final pos = LatLng(geo.latitude, geo.longitude);
            _marcadores.add(
              Marker(
                markerId: MarkerId(prestadorId),
                position: pos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
              ),
            );
          }
        });
      }
    });
  }

  LatLngBounds boundsFromMarkers(Set<Marker> markers) {
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

  Future<List<Map<String, dynamic>>> enriquecerServicos(
    List<Map<String, dynamic>> servicos,
  ) async {
    final fs = db; // usa o getter defensivo

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

  // =====================================================
  // 🔹 Agora acessíveis pela classe (para testes também)
  // =====================================================

  Future<String> abrevUnidade(String id) async {
    if (id.isEmpty) return '';
    if (_cacheUnidadeAbrev.containsKey(id)) return _cacheUnidadeAbrev[id]!;

    final doc = await db.collection(_colUnidades).doc(id).get();
    final ab = (doc.data()?['abreviacao'] ?? doc.data()?['sigla'] ?? '')
        .toString();

    _cacheUnidadeAbrev[id] = ab;
    return ab;
  }

  Future<String> nomePrest(String id) async {
    if (id.isEmpty) return '';
    if (_cacheNomePrestador.containsKey(id)) return _cacheNomePrestador[id]!;

    final doc = await db.collection(_colUsuarios).doc(id).get();
    final nome = (doc.data()?['nome'] ?? '').toString();

    _cacheNomePrestador[id] = nome;
    return nome;
  }

  Future<Set<String>> prestadoresDisponiveisNaDataHora(
    DateTime data,
    String horaHHmm,
  ) async {
    // Usa o getter defensivo, garantindo que db nunca será null
    final fs = db;
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

  double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = deg2rad(lat2 - lat1);
    final dLon = deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(lat1)) *
            math.cos(deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double deg2rad(double deg) => deg * (math.pi / 180.0);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool validarHorarioDesejado({bool emTeste = false}) {
    if (dataSelecionada == null || horarioController.text.trim().isEmpty) {
      return true;
    }

    final partes = horarioController.text.trim().split(':');
    if (partes.length != 2) return false;

    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59)
      return false;

    final agora = DateTime.now();

    // 🧠 Cria horário apenas para o mesmo dia (ignorando fusos e datas cruzadas)
    final selecionadoHoje = DateTime(agora.year, agora.month, agora.day, h, m);


    // 🚫 Se data selecionada é o mesmo dia e hora já passou
    if (isSameDay(dataSelecionada!, agora) && selecionadoHoje.isBefore(agora)) {
      return false;
    }

    // 🚫 Se a data selecionada é anterior a hoje
    if (dataSelecionada!.isBefore(
      DateTime(agora.year, agora.month, agora.day),
    )) {
      return false;
    }

    // 🟢 Caso contrário, é válido
    return true;
  }

  void limparFiltros() {
    if (!mounted) {
      // ⚙️ Apenas limpa os campos diretamente em ambiente de teste
      buscaController.clear();
      minValueController.clear();
      maxValueController.clear();
      localizacaoController.clear();
      horarioController.clear();
      categoriaSelecionadaId = null;
      _profissionalSelecionadoId = null;
      _unidadeSelecionada = null;
      _disponibilidadeSelecionada = null;
      dataSelecionada = null;
      avaliacaoMinima = 0;
      _raioDistancia = 10.0;
      pagamentosAceitos = [];
      _resultados.clear();
      _marcadores.clear();
      exibirProfissionais = false;
      return;
    }

    // 🟣 Modo normal (UI ativa)
    setState(() {
      buscaController.clear();
      minValueController.clear();
      maxValueController.clear();
      localizacaoController.clear();
      horarioController.clear();
      categoriaSelecionadaId = null;
      _profissionalSelecionadoId = null;
      _unidadeSelecionada = null;
      _disponibilidadeSelecionada = null;
      dataSelecionada = null;
      avaliacaoMinima = 0;
      _raioDistancia = 10.0;
      pagamentosAceitos = [];
      _filtrosExibidos = true;
      _resultados.clear();
      _marcadores.clear();
      exibirProfissionais = false;
    });
  }

  Future<String> nomeCategoriaProf(String id) async {
    if (id.isEmpty) return '';
    if (cacheCategoriaProfNome.containsKey(id)) {
      return cacheCategoriaProfNome[id]!;
    }
    final local = _categoriasProf
        .firstWhere((c) => c.id == id, orElse: () => const _ItemRef.empty())
        .nome;
    if (local.isNotEmpty) {
      cacheCategoriaProfNome[id] = local;
      return local;
    }
    final doc = await db.collection(_colCategoriasProf).doc(id).get();
    final nome = (doc.data()?['nome'] ?? '').toString();
    cacheCategoriaProfNome[id] = nome;
    return nome;
  }

  Future<Map<String, num>> ratingPrestador(
    String prestadorId, {
    num? notaAgg,
    num? qtdAgg,
  }) async {
    if (cacheAvalsPrest.containsKey(prestadorId)) {
      return cacheAvalsPrest[prestadorId]!;
    }

    if (notaAgg != null && qtdAgg != null) {
      final r = {'media': notaAgg.toDouble(), 'total': qtdAgg.toInt()};
      cacheAvalsPrest[prestadorId] = r;
      return r;
    }

    final fs = db; // ✅ usa o getter defensivo

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
    cacheAvalsPrest[prestadorId] = res;
    return res;
  }

  Future<Map<String, num>> ratingServico(
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

    final fs = db; // ✅ usa o getter defensivo

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

  Widget buildTopoComBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_filtrosExibidos && _resultados.isNotEmpty) {
                setState(() => _filtrosExibidos = false);
                return;
              }
              context.goHome();
            },
          ),

          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: buscaController,
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

  Widget buildToggleListaMapa() {
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

  String tituloResultados(int total) {
    final base = exibirProfissionais ? 'prestador' : 'serviço';
    final palavra = total == 1
        ? base
        : (base == 'prestador' ? 'prestadores' : 'serviços');
    final verbo = total == 1 ? 'encontrado' : 'encontrados';
    return '$total $palavra $verbo';
  }

  Widget buildMapa() {
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
            circles: _circulos,
            onTap: (pos) {
              _customInfoWindowController.hideInfoWindow!();
              setState(() {
                _centroBusca = pos;
                atualizarCirculo();
              });
              filtrarPorRaio();
            },
            onCameraMove: (pos) => _customInfoWindowController.onCameraMove!(),
            initialCameraPosition: const CameraPosition(
              target: LatLng(-17.7960, -50.9220),
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

  Widget buildServicoCard(Map<String, dynamic> e) {
    final servicoId = (e['id'] ?? '').toString();
    final titulo = (e['titulo'] ?? e['nome'] ?? 'Serviço').toString();
    final descricao = (e['descricao'] ?? '').toString();
    final prestadorId = (e['prestadorId'] ?? '').toString();
    final prestador = (e['prestadorNome'] ?? '').toString().isNotEmpty
        ? (e['prestadorNome'] ?? '').toString()
        : (e['prestadorNome'] = _cacheNomePrestador[prestadorId] ?? '')
              .toString();

    final cidade = (e['cidade'] ?? '').toString();
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
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _ratingInlineLink(
                prestadorId: prestadorId,
                servicoId: servicoId,
                servicoTitulo: titulo,
                future: ratingServico(
                  servicoId,
                  notaAgg: nota,
                  qtdAgg: avaliacoes,
                ),
              ),
            ),

            const SizedBox(height: 6),

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
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                cidade,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mín: ${formatPreco(e['valorMinimo'])}   '
                'Méd: ${formatPreco(e['valorMedio'])}   '
                'Máx: ${formatPreco(e['valorMaximo'])}'
                '${unidadeAbrev.isNotEmpty ? '/$unidadeAbrev' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.deepPurple,
                  fontSize: 12,
                ),
              ),
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

  Widget buildPrestadorCard(Map<String, dynamic> u) {
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _ratingInline(
                ratingPrestador(id, notaAgg: nota, qtdAgg: avaliacoes),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VisualizarAvaliacoesPrestador(prestadorId: id),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (fotoUrl.isNotEmpty)
                      ? NetworkImage(fotoUrl)
                      : null,
                  child: (fotoUrl.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 34,
                          color: Colors.deepPurple,
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),

                      const SizedBox(height: 4),

                      FutureBuilder<String>(
                        future: nomeCategoriaProf(catProfId),
                        builder: (_, snapCat) {
                          final cat = (snapCat.data ?? '').trim();
                          return Text(
                            cat.isNotEmpty ? cat : 'Categoria não informada',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          );
                        },
                      ),

                      const SizedBox(height: 4),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              cidade,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.work_outline,
                            size: 17,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tempoExp.isEmpty
                                  ? 'Experiência não informada'
                                  : tempoExp,
                              style: const TextStyle(fontSize: 13.5),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

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
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Abrir Agenda (implementar rota)'),
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
    );
  }

  Widget buildResultado() {
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
        ? [buildMapa()]
        : (exibirProfissionais
              ? _resultados.map(buildPrestadorCard).toList()
              : _resultados.map(buildServicoCard).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tituloResultados(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              buildToggleListaMapa(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...childrenList,
      ],
    );
  }

  Widget buildFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        _sectionTitle('Categoria de serviço'),
        DropdownButtonFormField<String>(
          initialValue: categoriaSelecionadaId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._categoriasServ.map(
              (e) => DropdownMenuItem(value: e.id, child: Text(e.nome)),
            ),
          ],
          onChanged: (v) {
            setState(() {
              categoriaSelecionadaId = v;
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

        _sectionTitle('Valor por unidade'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minValueController,
                keyboardType: TextInputType.number,
                inputFormatters: [MoedaPtBrInputFormatter()],
                decoration: _input('Mínimo', hint: 'R\$ 0,00'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: maxValueController, // ✅ usa o controller correto
                keyboardType: TextInputType.number,
                inputFormatters: [MoedaPtBrInputFormatter()],
                decoration: _input('Máximo', hint: 'R\$ 0,00'),
              ),
            ),
          ],
        ),

        _sectionTitle('Avaliação mínima'),
        LayoutBuilder(
          builder: (context, constraints) {
            const numberSize = 16.0;
            const starSize = 22.0;
            const chipHPad = 12.0;
            const chipVPad = 8.0;

            const gap = 8.0;
            final itemW = (constraints.maxWidth - gap * 4) / 5;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [5, 4, 3, 2, 1].map((v) {
                final selected = avaliacaoMinima == v;
                return SizedBox(
                  width: itemW,
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: selected,
                    onSelected: (_) => setState(() {
                      avaliacaoMinima = selected ? 0 : v;
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

        _sectionTitle('Raio de distância (km)'),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _raioDistancia,
                onChanged: (v) {
                  setState(() => _raioDistancia = v);
                  atualizarCirculo();
                },
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

        TextField(
          readOnly: true,
          controller: TextEditingController(
            text: dataSelecionada == null
                ? ''
                : DateFormat('dd/MM/yyyy').format(dataSelecionada!),
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

        TextField(
          controller: horarioController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            HoraInputFormatter(),
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
        payTile('Dinheiro'),
        payTile('Pix'),
        payTile('Cartão de crédito/débito'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget payTile(String label) {
    final checked = pagamentosAceitos.contains(label);
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
              ? pagamentosAceitos.add(label)
              : pagamentosAceitos.remove(label),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      setState(() => dataSelecionada = data);
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
              buildTopoComBusca(),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _filtrosExibidos
                            ? buildFiltro()
                            : buildResultado(),
                      ),
                    ),
                    if (_filtrosExibidos)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
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

                            Expanded(
                              child: OutlinedButton(
                                onPressed: limparFiltros,
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

class CepInputFormatter extends TextInputFormatter {
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

class MoedaPtBrInputFormatter extends TextInputFormatter {
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

class HoraInputFormatter extends TextInputFormatter {
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

class _ItemRef {
  final String id;
  final String nome;
  const _ItemRef({required this.id, required this.nome});
  const _ItemRef.empty() : id = '', nome = '';
}
