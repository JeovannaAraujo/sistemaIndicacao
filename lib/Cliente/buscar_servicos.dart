import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myapp/Cliente/rotas_navegacao.dart';
import 'package:myapp/Cliente/visualizar_agenda_prestador.dart';
import 'package:myapp/Prestador/avaliacoes_prestador.dart';
import 'package:myapp/Prestador/visualizar_avaliacoes.dart';
import 'visualizar_perfil_prestador.dart';
import 'solicitar_orcamento.dart';

class BuscarServicosScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  const BuscarServicosScreen({super.key, this.firestore, this.auth});

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
  double _raioDistancia = 0.0;
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
  List<_ItemRef> _categoriasServ = [];
  List<_ItemRef> _categoriasProf = [];
  List<String> _unidades = [];
  final Map<String, String> _unidadesMap = {};

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

  // 🔧 Banco de dados
  FirebaseFirestore? _db;
  late FirebaseAuth auth;

  @override
  void initState() {
    super.initState();

    // Inicializa o Firestore — usa o fake se fornecido no widget, senão o real
    _db = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;

    // Evita execução desnecessária em ambiente de teste
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _carregarFiltrosBase();
        _verificarAutenticacao();
      }
    });
  }

  // Getter defensivo — garante _db não nulo em métodos diretos (ex: testes)
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    // Limpa os controllers
    buscaController.dispose();
    minValueController.dispose();
    maxValueController.dispose();
    localizacaoController.dispose();
    horarioController.dispose();

    // Fecha o info window controller
    _customInfoWindowController.dispose();

    super.dispose();
  }

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

  Future<void> _carregarFiltrosBase() async {
    final fs = db;

    try {
      final futures = await Future.wait([
        fs.collection(_colCategoriasServ).where('ativo', isEqualTo: true).get(),
        fs.collection(_colCategoriasProf).where('ativo', isEqualTo: true).get(),
        fs.collection(_colUnidades).where('ativo', isEqualTo: true).get(),
      ]);

      final servCats = futures[0].docs
          .map(
            (d) =>
                _ItemRef(id: d.id, nome: (d.data()['nome'] ?? '').toString()),
          )
          .where((e) => e.nome.isNotEmpty)
          .toList();

      final profCats = futures[1].docs
          .map(
            (d) =>
                _ItemRef(id: d.id, nome: (d.data()['nome'] ?? '').toString()),
          )
          .where((e) => e.nome.isNotEmpty)
          .toList();

      // CORREÇÃO: Buscar unidades com id e nome
      final unidadesDocs = futures[2].docs;
      final unidadesList = unidadesDocs
          .map(
            (d) => _ItemRef(
              id: d.id,
              nome: (d.data()['abreviacao'] ?? d.data()['nome'] ?? '')
                  .toString(),
            ),
          )
          .where((e) => e.nome.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _categoriasServ = servCats;
        _categoriasProf = profCats;
        _unidades = unidadesList.map((u) => u.id).toList();
        _unidadesMap.clear();
        for (var u in unidadesList) {
          _unidadesMap[u.id] = u.nome;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar filtros: $e');
    }
  }

  // ================== FILTRO DE DISPONIBILIDADE ==================

  /// 🔹 Verifica se um prestador está disponível em uma data específica (CORRIGIDO)
  Future<bool> verificarDisponibilidadePrestador(
    String prestadorId,
    DateTime dataConsulta,
  ) async {
    try {
      final dataYmd = DateTime(
        dataConsulta.year,
        dataConsulta.month,
        dataConsulta.day,
      );

      // 1️⃣ Buscar jornada de trabalho do prestador
      final userDoc = await db.collection('usuarios').doc(prestadorId).get();
      if (!userDoc.exists) {
        return true; // Se não existe, considera disponível
      }

      final userData = userDoc.data()!;
      final jornada = (userData['jornada'] ?? []) as List<dynamic>;

      // Mapear dias da semana
      final Map<String, int> diasSemana = {
        'Segunda-feira': DateTime.monday,
        'Terça-feira': DateTime.tuesday,
        'Quarta-feira': DateTime.wednesday,
        'Quinta-feira': DateTime.thursday,
        'Sexta-feira': DateTime.friday,
        'Sábado': DateTime.saturday,
        'Domingo': DateTime.sunday,
      };

      final workWeekdays = jornada
          .map((d) => diasSemana[d.toString()])
          .whereType<int>()
          .toSet();

      // Se não tem jornada definida, usa padrão (segunda a sexta)
      if (workWeekdays.isEmpty) {
        workWeekdays.addAll([1, 2, 3, 4, 5]);
      }

      // 2️⃣ Verificar se é dia de trabalho
      if (!workWeekdays.contains(dataYmd.weekday)) {
        return false; // Não trabalha neste dia = INDISPONÍVEL
      }

      // 3️⃣ Verificar se é uma data passada
      final hoje = DateTime.now();
      final hojeYmd = DateTime(hoje.year, hoje.month, hoje.day);
      if (dataYmd.isBefore(hojeYmd)) {
        return false; // Datas passadas não estão disponíveis
      }

      // 4️⃣ Buscar solicitações que ocupam esta data
      final solicitacoesSnap = await db
          .collection('solicitacoesOrcamento')
          .where('prestadorId', isEqualTo: prestadorId)
          .where('status', whereIn: ['aceita', 'em andamento', 'em_andamento'])
          .get();

      // Se não tem solicitações, está disponível
      if (solicitacoesSnap.docs.isEmpty) {
        return true;
      }

      // Função auxiliar para converter timestamp
      DateTime toYMD(Timestamp ts) {
        final dt = ts.toDate();
        return DateTime(dt.year, dt.month, dt.day);
      }

      // Verificar cada solicitação
      for (final doc in solicitacoesSnap.docs) {
        final data = doc.data();
        final tsInicio = data['dataInicioSugerida'];
        if (tsInicio is! Timestamp) continue;

        final start = toYMD(tsInicio);

        // 🔹 Verificar finalização prevista
        final tsFinal = data['dataFinalPrevista'];
        if (tsFinal is Timestamp) {
          final end = toYMD(tsFinal);
          if (!dataYmd.isBefore(start) && !dataYmd.isAfter(end)) {
            return false; // Data ocupada por este serviço
          }
          continue;
        }

        // 🔹 Verificar por tempo estimado
        final unidade = (data['tempoEstimadoUnidade'] ?? '')
            .toString()
            .toLowerCase();
        final valor = (data['tempoEstimadoValor'] as num?)?.ceil() ?? 0;

        if (unidade.startsWith('dia') && valor > 0) {
          // Calcular próximos dias úteis
          final diasUteis = <DateTime>[];
          var d = start;
          int added = 0;

          while (added < valor) {
            if (workWeekdays.contains(d.weekday)) {
              diasUteis.add(d);
              added++;
            }
            d = d.add(const Duration(days: 1));
          }

          if (diasUteis.contains(dataYmd)) {
            return false; // Data ocupada
          }
        } else {
          // Serviço de um dia apenas
          if (dataYmd == start) {
            return false;
          }
        }
      }

      // 5️⃣ Se passou por todas as verificações, está disponível
      return true;
    } catch (e) {
      return true; // Em caso de erro, considera disponível para segurança
    }
  }

  // ================== FILTRO DE DISPONIBILIDADE ==================

  /// 🔹 Filtra resultados por disponibilidade
  Future<List<Map<String, dynamic>>> _filtrarPorDisponibilidade(
    List<Map<String, dynamic>> resultados,
  ) async {
    // 🔥 CORREÇÃO: Se não tem data selecionada, usa data de hoje
    final dataParaFiltrar = dataSelecionada ?? DateTime.now();

    if (_disponibilidadeSelecionada == null) {
      return resultados;
    }

    final List<Map<String, dynamic>> filtrados = [];

    for (final item in resultados) {
      String prestadorId;

      if (exibirProfissionais) {
        prestadorId = item['id'];
      } else {
        prestadorId = item['prestadorId'];
      }

      if (prestadorId.isEmpty) {
        filtrados.add(item);
        continue;
      }

      final disponivel = await verificarDisponibilidadePrestador(
        prestadorId,
        dataParaFiltrar, // 🔥 Usa a data (hoje ou selecionada)
      );

      final deveIncluir = (_disponibilidadeSelecionada == 'Disponível')
          ? disponivel
          : !disponivel;

      if (deveIncluir) {
        filtrados.add(item);
      }
    }

    return filtrados;
  }

  Future<void> _verificarPermissaoLocalizacao() async {
    try {
      // Se o raio for 0, não precisa checar permissão
      if (_raioDistancia <= 0) {
        return;
      }

      // Verifica se o serviço de localização está ativo
      final servicoAtivo = await Geolocator.isLocationServiceEnabled();
      if (!servicoAtivo) {
        return;
      }

      // Verifica permissão atual
      LocationPermission permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) {
          return;
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        return;
      }

      // Obtém posição atual
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
      } catch (e) {
        return;
      }

      setState(() {
        _centroBusca = LatLng(pos!.latitude, pos.longitude);
        atualizarCirculo();
      });
    } catch (e) {
      debugPrint('Erro ao verificar localização: $e');
    }
  }

  /// 🔹 Busca serviços de forma inteligente
  Future<void> _buscarServicosInteligente(String termo) async {
    final fs = db;

    Query<Map<String, dynamic>> qs = fs
        .collection(_colServicos)
        .where('ativo', isEqualTo: true);

    // Aplica filtro de categoria de serviço
    if (categoriaSelecionadaId?.isNotEmpty ?? false) {
      qs = qs.where('categoriaId', isEqualTo: categoriaSelecionadaId);
    }

    // Aplica filtro de unidade
    if (_unidadeSelecionada?.isNotEmpty ?? false) {
      qs = qs.where('unidadeId', isEqualTo: _unidadeSelecionada);
    }

    final snapServ = await qs.limit(250).get();
    List<Map<String, dynamic>> servicos = snapServ.docs.map((d) {
      final m = d.data();
      m['id'] = d.id;
      return m;
    }).toList();

    // Filtra por termo de busca se houver
    if (termo.isNotEmpty) {
      servicos = await _filtrarServicosPorTermo(servicos, termo);
    }

    // Aplica filtro de raio se necessário
    if (_raioDistancia > 0 && _centroBusca != null) {
      servicos = await _filtrarServicosPorRaio(servicos);
    }

    final enriquecidos = await enriquecerServicos(servicos);
    if (mounted) {
      setState(() {
        _resultados = enriquecidos;
        exibirProfissionais = false;
      });
    }
  }

/// 🔹 Busca prestadores de forma inteligente (case-insensitive)
Future<void> _buscarPrestadoresInteligente(String termo) async {
  final fs = db;

  Query<Map<String, dynamic>> qs = fs
      .collection(_colUsuarios)
      .where('tipoPerfil', whereIn: ['Prestador', 'Ambos'])
      .where('ativo', isEqualTo: true);

  // Aplica filtro de categoria profissional se selecionado
  if (_profissionalSelecionadoId?.isNotEmpty ?? false) {
    qs = qs.where(
      'categoriaProfissionalId',
      isEqualTo: _profissionalSelecionadoId,
    );
  }

  final snapUsers = await qs.limit(250).get();
  List<Map<String, dynamic>> profissionais = snapUsers.docs.map((d) {
    final m = d.data();
    m['id'] = d.id;
    return m;
  }).toList();

  // 🔥 CORREÇÃO: Filtro case-insensitive por termo
  if (termo.isNotEmpty) {
    profissionais = _filtrarPrestadoresPorTermo(profissionais, termo);
  }

  // Aplica filtro de raio se necessário
  if (_raioDistancia > 0 && _centroBusca != null) {
    profissionais = await _filtrarProfissionaisPorRaio(profissionais);
  }

  if (mounted) {
    setState(() {
      _resultados = profissionais;
      exibirProfissionais = true;
    });
  }
}

/// 🔹 Filtra prestadores por termo de busca (case-insensitive)
List<Map<String, dynamic>> _filtrarPrestadoresPorTermo(
  List<Map<String, dynamic>> prestadores,
  String termo,
) {
  final termoNormalizado = _normalizarTexto(termo);
  
  return prestadores.where((p) {
    final nome = (p['nome'] ?? '').toString();
    final nomeNormalizado = _normalizarTexto(nome);
    
    final especialidades = (p['especialidades'] ?? '').toString();
    final especialidadesNormalizado = _normalizarTexto(especialidades);
    
    final descricao = (p['descricao'] ?? '').toString();
    final descricaoNormalizado = _normalizarTexto(descricao);

    // 🔥 BUSCA FLEXÍVEL: Verifica em nome, especialidades e descrição
    return nomeNormalizado.contains(termoNormalizado) ||
           especialidadesNormalizado.contains(termoNormalizado) ||
           descricaoNormalizado.contains(termoNormalizado) ||
           // Busca por partes do nome (para nomes compostos)
           nomeNormalizado.split(' ').any((parte) => parte.contains(termoNormalizado));
  }).toList();
}

  /// 🔹 Método de debug para verificar a busca
  void _debugBusca(
    String termo,
    bool existePrestador,
    bool deveBuscarServicos,
  ) {
    debugPrint('=== DEBUG BUSCA ===');
    debugPrint('Termo: "$termo"');
    debugPrint('Existe prestador com nome: $existePrestador');
    debugPrint('Deve buscar serviços: $deveBuscarServicos');
    debugPrint('Exibindo profissionais: $exibirProfissionais');
    debugPrint('Resultados: ${_resultados.length}');
    if (_resultados.isNotEmpty) {
      debugPrint('Primeiro resultado: ${_resultados.first}');
    }
    debugPrint('===================');
  }

  /// 🔹 Filtra resultados pelos meios de pagamento aceitos pelo prestador
  Future<List<Map<String, dynamic>>> _filtrarPorPagamentos(
    List<Map<String, dynamic>> resultados,
  ) async {
    // Se não há filtro de pagamento, retorna todos
    if (pagamentosAceitos.isEmpty) {
      return resultados;
    }

    final List<Map<String, dynamic>> filtrados = [];

    for (final item in resultados) {
      String prestadorId;

      if (exibirProfissionais) {
        prestadorId = item['id'];
      } else {
        prestadorId = item['prestadorId'];
      }

      if (prestadorId.isEmpty) {
        // Se não tem prestador ID, mantém o item
        filtrados.add(item);
        continue;
      }

      // Busca os meios de pagamento do prestador
      final pagamentosPrestador = await _obterPagamentosPrestador(prestadorId);

      // ✅ CORREÇÃO: Verifica se o prestador aceita TODOS os meios de pagamento selecionados
      // Mas pode aceitar outros além dos selecionados
      final aceitaTodosSelecionados = pagamentosAceitos.every(
        (pagamentoSelecionado) =>
            pagamentosPrestador.contains(pagamentoSelecionado),
      );

      if (aceitaTodosSelecionados) {
        filtrados.add(item);
      }
    }

    return filtrados;
  }

  /// 🔹 Busca os meios de pagamento aceitos pelo prestador
  Future<List<String>> _obterPagamentosPrestador(String prestadorId) async {
    try {
      final doc = await db.collection(_colUsuarios).doc(prestadorId).get();

      if (!doc.exists) {
        return [];
      }

      final data = doc.data()!;

      // Tenta obter de diferentes campos possíveis
      final dynamic pagamentos =
          data['meiosPagamentoAceitos'] ??
          data['pagamentosAceitos'] ??
          data['formasPagamento'] ??
          data['meiosPagamento'] ?? // ← campo adicional
          [];

      if (pagamentos is List) {
        // Converte para lista de strings e remove valores nulos/vazios
        return pagamentos
            .map((p) => p?.toString().trim() ?? '')
            .where((p) => p.isNotEmpty)
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

/// 🔹 Filtra serviços por termo de busca (case-insensitive)
Future<List<Map<String, dynamic>>> _filtrarServicosPorTermo(
  List<Map<String, dynamic>> servicos,
  String termo,
) async {
  final termoNormalizado = _normalizarTexto(termo);
  
  // Adiciona o nome do prestador a cada serviço para busca
  servicos = await Future.wait(
    servicos.map((e) async {
      final m = Map<String, dynamic>.from(e);
      final pid = (m['prestadorId'] ?? '').toString();
      if (pid.isNotEmpty) {
        m['prestadorNome'] = await nomePrest(pid);
      }
      return m;
    }),
  );

  return servicos.where((e) {
    final nomeServ = (e['titulo'] ?? e['nome'] ?? '').toString();
    final nomeServNormalizado = _normalizarTexto(nomeServ);
    
    final nomePrest = (e['prestadorNome'] ?? '').toString();
    final nomePrestNormalizado = _normalizarTexto(nomePrest);
    
    final descricao = (e['descricao'] ?? '').toString();
    final descricaoNormalizado = _normalizarTexto(descricao);

    return nomeServNormalizado.contains(termoNormalizado) ||
           nomePrestNormalizado.contains(termoNormalizado) ||
           descricaoNormalizado.contains(termoNormalizado);
  }).toList();
}

  /// 🔹 Decide se deve buscar serviços ou prestadores baseado nos filtros
  Future<bool> _deveBuscarServicos(String termo) async {
    // ✅ CONDIÇÕES PARA BUSCAR SERVIÇOS:

    // 1. Tem categoria de serviço selecionada
    if (categoriaSelecionadaId?.isNotEmpty ?? false) {
      return true;
    }

    // 2. Tem unidade de medida selecionada
    if (_unidadeSelecionada?.isNotEmpty ?? false) {
      return true;
    }

    // 3. Tem filtro de valor mínimo/máximo
    if (minValueController.text.isNotEmpty ||
        maxValueController.text.isNotEmpty) {
      return true;
    }

    // 🔥 LÓGICA PRINCIPAL: Se existe prestador com o nome, busca profissionais
    if (termo.isNotEmpty) {
      final existePrestadorComNome = await _verificarSeExistePrestadorComNome(
        termo,
      );
      // Se encontrou prestador com o nome, busca profissionais (retorna false)
      // Se não encontrou, busca serviços (retorna true)
      return !existePrestadorComNome;
    }

    // Se não há termo e nenhum filtro específico, busca serviços por padrão
    return true;
  }

  Future<void> _buscar() async {
    setState(() {
      _filtrosExibidos = false;
      _carregando = true;
      _resultados.clear();
      _marcadores.clear();
    });

    try {
      final termo = buscaController.text.trim().toLowerCase();

      // Se tem raio, verifica permissão de localização
      if (_raioDistancia > 0) {
        await _verificarPermissaoLocalizacao();
      }

      // ===== LÓGICA INTELIGENTE - DECIDIR O QUE BUSCAR =====
      final bool deveBuscarServicos = await _deveBuscarServicos(termo);

      // 🔥 DEBUG
      final existePrestador = await _verificarSeExistePrestadorComNome(termo);
      _debugBusca(termo, existePrestador, deveBuscarServicos);

      // 🔥 CORREÇÃO: Se tem categoria profissional selecionada, força busca por profissionais
      if (_profissionalSelecionadoId?.isNotEmpty ?? false) {
        await _buscarPrestadoresInteligente(termo);
      } else if (deveBuscarServicos) {
        await _buscarServicosInteligente(termo);
      } else {
        await _buscarPrestadoresInteligente(termo);
      }
      // ===== APLICA FILTROS ADICIONAIS =====
      if (_resultados.isNotEmpty) {
        // 🔥 CORREÇÃO: Filtro de valor APENAS para serviços (não para profissionais)
        if (!exibirProfissionais) {
          // ❌ TROQUEI exibirProfissionais por !exibirProfissionais
          _resultados = _filtrarPorValor(_resultados);
        }

        // Filtro de avaliação
        _resultados = await _filtrarPorAvaliacao(_resultados);

        // Filtro de disponibilidade
        _resultados = await _filtrarPorDisponibilidade(_resultados);
        // 🔥 NOVO: Filtro de meios de pagamento (para serviços e profissionais)
        _resultados = await _filtrarPorPagamentos(_resultados);
      }
      // Atualiza marcadores no mapa
      await _criarMarcadoresNoMapa();

      // Ajusta a câmera do mapa se necessário
      if (_exibirMapa && _mapController != null && _marcadores.isNotEmpty) {
        if (_marcadores.length == 1) {
          final pos = _marcadores.first.position;
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));
        } else {
          LatLngBounds bounds = _boundsFromMarkers(_marcadores);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 60),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar: $e')));
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  List<Map<String, dynamic>> _filtrarPorValor(
    List<Map<String, dynamic>> resultados,
  ) {
    final minValor = _parseValor(minValueController.text);
    final maxValor = _parseValor(maxValueController.text);

    // Se não há filtro de valor, retorna todos
    if (minValor == null && maxValor == null) {
      return resultados;
    }

    final filtrados = resultados.where((item) {
      final valorMedio = _obterValorMedio(item);
      if (valorMedio == null) {
        return false;
      }

      bool passaMin = minValor == null || valorMedio >= minValor;
      bool passaMax = maxValor == null || valorMedio <= maxValor;

      final passa = passaMin && passaMax;

      return passa;
    }).toList();

    return filtrados;
  }

  double? _obterValorMedio(Map<String, dynamic> servico) {
    // Tenta obter o valor médio de várias formas
    final valorMedio = servico['valorMedio'];
    if (valorMedio is num) return valorMedio.toDouble();

    final valorMinimo = servico['valorMinimo'];
    final valorMaximo = servico['valorMaximo'];

    // Se tem mínimo e máximo, calcula a média
    if (valorMinimo is num && valorMaximo is num) {
      return (valorMinimo.toDouble() + valorMaximo.toDouble()) / 2;
    }

    // Se só tem mínimo, usa ele
    if (valorMinimo is num) return valorMinimo.toDouble();

    // Se só tem máximo, usa ele
    if (valorMaximo is num) return valorMaximo.toDouble();

    return null;
  }

  double? _parseValor(String texto) {
    if (texto.isEmpty) return null;

    try {
      // Remove "R$", pontos, espaços e substitui vírgula por ponto
      final cleaned = texto
          .replaceAll('R\$', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .replaceAll(' ', '')
          .trim();

      final valor = double.tryParse(cleaned);
      return valor;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _filtrarPorAvaliacao(
    List<Map<String, dynamic>> resultados,
  ) async {
    // Se não há filtro de avaliação, retorna todos
    if (avaliacaoMinima == 0) {
      return resultados;
    }

    final List<Map<String, dynamic>> filtrados = [];

    for (final item in resultados) {
      double mediaAvaliacao = 0.0;

      if (exibirProfissionais) {
        // Para profissionais: busca avaliação do prestador
        final rating = await ratingPrestador(item['id']);
        mediaAvaliacao = rating['media']?.toDouble() ?? 0.0;
      } else {
        // Para serviços: usa a avaliação já calculada ou busca
        if (item['nota'] is num) {
          mediaAvaliacao = (item['nota'] as num).toDouble();
        } else {
          final rating = await ratingServico(item['id']);
          mediaAvaliacao = rating['media']?.toDouble() ?? 0.0;
        }
      }

      // Arredonda para baixo para comparar com a avaliação mínima
      final mediaArredondada = mediaAvaliacao.floor();

      if (mediaArredondada >= avaliacaoMinima) {
        filtrados.add(item);
      }
    }

    return filtrados;
  }

  Future<List<Map<String, dynamic>>> _filtrarServicosPorRaio(
    List<Map<String, dynamic>> servicos,
  ) async {
    final fs = db;
    List<Map<String, dynamic>> dentroRaio = [];

    for (final s in servicos) {
      final prestadorId = s['prestadorId'];
      if (prestadorId == null) continue;

      final docPrest = await fs.collection(_colUsuarios).doc(prestadorId).get();
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
      }

      if (lat == null || lon == null) continue;

      final dist = _distanciaKm(
        _centroBusca!.latitude,
        _centroBusca!.longitude,
        lat,
        lon,
      );

      if (dist <= _raioDistancia) {
        dentroRaio.add(s);
      }
    }

    return dentroRaio;
  }

  /// 🔹 Filtra profissionais por raio de distância
  Future<List<Map<String, dynamic>>> _filtrarProfissionaisPorRaio(
    List<Map<String, dynamic>> profissionais,
  ) async {
    final fs = db;
    List<Map<String, dynamic>> dentroRaio = [];

    for (final p in profissionais) {
      final prestadorId = p['id'];
      final docPrest = await fs.collection(_colUsuarios).doc(prestadorId).get();
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
      }

      if (lat == null || lon == null) continue;

      final dist = _distanciaKm(
        _centroBusca!.latitude,
        _centroBusca!.longitude,
        lat,
        lon,
      );

      if (dist <= _raioDistancia) {
        dentroRaio.add(p);
      }
    }

    return dentroRaio;
  }

  Future<void> _criarMarcadoresNoMapa() async {
    if (!_exibirMapa) return;

    final fs = db;
    _marcadores.clear();

    // Agrupar serviços por prestador para mostrar múltiplos serviços no mesmo marcador
    final Map<String, List<Map<String, dynamic>>> servicosPorPrestador = {};

    if (!exibirProfissionais) {
      // Agrupa serviços por prestador
      for (final servico in _resultados) {
        final prestadorId = servico['prestadorId']?.toString() ?? '';
        if (prestadorId.isNotEmpty) {
          if (!servicosPorPrestador.containsKey(prestadorId)) {
            servicosPorPrestador[prestadorId] = [];
          }
          servicosPorPrestador[prestadorId]!.add(servico);
        }
      }
    }

    for (final resultado in _resultados) {
      String prestadorId;
      String titulo;
      String subtitulo;
      bool isProfissional = exibirProfissionais;

      if (isProfissional) {
        prestadorId = resultado['id'];
        titulo = resultado['nome'] ?? 'Profissional';
        final catId = resultado['categoriaProfissionalId'] ?? '';
        final catNome = await nomeCategoriaProf(catId);
        subtitulo = catNome;
      } else {
        prestadorId = resultado['prestadorId'];

        // Se há múltiplos serviços do mesmo prestador, mostra lista
        final servicosDoPrestador = servicosPorPrestador[prestadorId] ?? [];
        if (servicosDoPrestador.length > 1) {
          titulo = '${servicosDoPrestador.length} serviços';
          final nomesServicos = servicosDoPrestador
              .map((s) => s['titulo'] ?? s['nome'] ?? 'Serviço')
              .take(3)
              .join(', ');
          subtitulo = nomesServicos;
        } else {
          titulo = resultado['titulo'] ?? resultado['nome'] ?? 'Serviço';
          subtitulo = resultado['prestadorNome'] ?? '';
        }
      }

      // Busca coordenadas do prestador
      final docPrest = await fs.collection(_colUsuarios).doc(prestadorId).get();
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
      }

      if (lat == null || lon == null) continue;

      final markerId = MarkerId(
        prestadorId + (isProfissional ? '_prof' : '_serv'),
      );
      final marker = Marker(
        markerId: markerId,
        position: LatLng(lat, lon),
        icon: await _getCustomMarkerIcon(isProfissional),
        onTap: () {
          _customInfoWindowController.addInfoWindow!(
            _buildInfoWindow(titulo, subtitulo, prestadorId, isProfissional),
            LatLng(lat!, lon!),
          );
        },
      );

      _marcadores.add(marker);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<BitmapDescriptor> _getCustomMarkerIcon(bool isProfissional) async {
    return BitmapDescriptor.defaultMarkerWithHue(
      isProfissional ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueViolet,
    );
  }

  // CORREÇÃO: Info window sem overflow
  Widget _buildInfoWindow(
    String titulo,
    String subtitulo,
    String prestadorId,
    bool isProfissional,
  ) {
    return Container(
      width: 220,
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(64), // 0.25 * 255 ≈ 64
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente
        crossAxisAlignment:
            CrossAxisAlignment.center, // Centraliza horizontalmente
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título centralizado
          Text(
            titulo,
            textAlign: TextAlign.center, // Centraliza o texto
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.deepPurple,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Subtítulo centralizado
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Rating centralizado com fundo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200, width: 1),
            ),
            child: FutureBuilder<Map<String, num>>(
              future: isProfissional
                  ? ratingPrestador(prestadorId)
                  : _getRatingParaPrestador(prestadorId),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {'media': 0.0, 'total': 0};
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      data['media']?.toStringAsFixed(1) ?? '0.0',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '(${data['total']})',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Botão estilizado e centralizado
          Container(
            width: double.infinity,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [Color(0xFF6C3AF2), Color(0xFF3F10D6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withAlpha(77), // 0.3 * 255 ≈ 77
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                _customInfoWindowController.hideInfoWindow!();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VisualizarPerfilPrestador(prestadorId: prestadorId),
                      ),
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 4),
                  Text(
                    'Ver Perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, num>> _getRatingParaPrestador(String prestadorId) async {
    return await ratingPrestador(prestadorId);
  }

  void atualizarCirculo() {
    if (_centroBusca == null) return;
    setState(() {
      _circulos = {
        Circle(
          circleId: const CircleId('raio_busca'),
          center: _centroBusca!,
          radius: _raioDistancia * 1000,
          fillColor: Colors.deepPurple.withAlpha(38), // 0.15 * 255 ≈ 38
          strokeColor: Colors.deepPurple,
          strokeWidth: 2,
        ),
      };
    });
  }

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

  Future<List<Map<String, dynamic>>> enriquecerServicos(
    List<Map<String, dynamic>> servicos,
  ) async {
    final fs = db;

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

      // ADIÇÃO: Inclui o nome completo da unidade para exibição
      if (uid.isNotEmpty) {
        m['unidadeNome'] = _unidadesMap[uid] ?? await _getNomeUnidade(uid);
      }

      final rate = await ratingServico(m['id']);
      m['nota'] = rate['media'] ?? 0.0;
      m['avaliacoes'] = rate['total'] ?? 0;

      return m;
    }).toList();

    return await Future.wait(futures);
  }

  Future<String> abrevUnidade(String id) async {
    if (id.isEmpty) return '';
    if (_cacheUnidadeAbrev.containsKey(id)) return _cacheUnidadeAbrev[id]!;

    final doc = await db.collection(_colUnidades).doc(id).get();
    final ab = (doc.data()?['abreviacao'] ?? doc.data()?['sigla'] ?? '')
        .toString();

    _cacheUnidadeAbrev[id] = ab;
    return ab;
  }

  Future<String> _getNomeUnidade(String id) async {
    if (id.isEmpty) return '';
    final doc = await db.collection(_colUnidades).doc(id).get();
    return (doc.data()?['abreviacao'] ?? doc.data()?['nome'] ?? '').toString();
  }

  Future<String> nomePrest(String id) async {
    if (id.isEmpty) return '';
    if (_cacheNomePrestador.containsKey(id)) return _cacheNomePrestador[id]!;

    final doc = await db.collection(_colUsuarios).doc(id).get();
    final nome = (doc.data()?['nome'] ?? '').toString();

    _cacheNomePrestador[id] = nome;
    return nome;
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

    final fs = db;

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

    final fs = db;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> avaliacoesRelacionadas =
        [];

    try {
      final avaliacoesSnap = await fs.collection('avaliacoes').get();

      for (final doc in avaliacoesSnap.docs) {
        final dados = doc.data();
        final solicitacaoId = dados['solicitacaoId'];
        if (solicitacaoId == null) continue;

        final sol = await fs
            .collection('solicitacoesOrcamento')
            .doc(solicitacaoId)
            .get();

        if (!sol.exists) continue;

        final idServicoLigado = sol.data()?['servicoId'];
        if (idServicoLigado == servicoId) {
          avaliacoesRelacionadas.add(doc);
        }
      }
    } catch (e) {
      return {'media': 0.0, 'total': 0};
    }

    double soma = 0;
    int total = 0;

    for (final d in avaliacoesRelacionadas) {
      final n = (d.data()['nota'] ?? d.data()['rating'] ?? 0);
      if (n is num) {
        soma += n.toDouble();
        total++;
      }
    }

    final media = total > 0 ? soma / total : 0.0;
    final res = {'media': media, 'total': total};

    _cacheAvalsServ[servicoId] = res;
    return res;
  }

  // CORREÇÃO DO PROBLEMA DE LOGOUT
  void _verificarAutenticacao() {
    auth.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      }
    });
  }

  // WIDGETS DE CONSTRUÇÃO DA INTERFACE
  Widget buildTopoComBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          // 🔥 REMOVIDO: IconButton de voltar (não é mais necessário com a BottomNavigationBar)
          const SizedBox(width: 10), // Mantém o espaçamento
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
    if (_profissionalSelecionadoId?.isNotEmpty ?? false) {
      const base = 'prestador';
      final palavra = total == 1 ? base : 'prestadores';
      final verbo = total == 1 ? 'encontrado' : 'encontrados';
      return '$total $palavra $verbo';
    } else {
      final base = exibirProfissionais ? 'prestador' : 'serviço';
      final palavra = total == 1
          ? base
          : (base == 'prestador' ? 'prestadores' : 'serviços');
      final verbo = total == 1 ? 'encontrado' : 'encontrados';
      return '$total $palavra $verbo';
    }
  }

  Widget buildMapa() {
    return SizedBox(
      height: 450,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _customInfoWindowController.googleMapController = controller;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_resultados.isNotEmpty) {
                  _criarMarcadoresNoMapa();
                }
              });
            },
            markers: _marcadores,
            circles: _circulos,
            onTap: (pos) {
              _customInfoWindowController.hideInfoWindow!();
            },
            onCameraMove: (pos) => _customInfoWindowController.onCameraMove!(),
            initialCameraPosition: CameraPosition(
              target: _centroBusca ?? const LatLng(-17.7960, -50.9220),
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 140,
            width: 250,
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

    // Texto da avaliação corrigido
    final textoAvaliacao =
        '${(nota ?? 0.0).toStringAsFixed(1)} (${avaliacoes ?? 0} avaliações)';

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha principal: imagem + conteúdo + avaliação
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem
                Container(
                  width: 50,
                  height: 50,
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
                      ? const Icon(
                          Icons.handyman,
                          color: Colors.deepPurple,
                          size: 24,
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                // Conteúdo principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Linha do título + avaliação
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título
                          Expanded(
                            child: Text(
                              titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Avaliação no canto superior direito - AGORA CLICÁVEL
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisualizarAvaliacoesScreen(
                                    prestadorId: prestadorId,
                                    servicoId: servicoId,
                                    servicoTitulo: titulo,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    textoAvaliacao,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Descrição
                      if (descricao.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          descricao,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Prestador
                      const SizedBox(height: 4),
                      Text(
                        'Prestador: ${prestador.isNotEmpty ? prestador : prestadorId}',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Cidade
                      if (cidade.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cidade,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

            const SizedBox(height: 8),

            // Valores
            Text(
              'Mín: ${formatPreco(e['valorMinimo'])} • '
              'Méd: ${formatPreco(e['valorMedio'])} • '
              'Máx: ${formatPreco(e['valorMaximo'])}'
              '${unidadeAbrev.isNotEmpty ? '/$unidadeAbrev' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Botões
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Perfil',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Solicitar Orçamento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

/// 🔹 Verifica se existe algum prestador com o nome buscado (case-insensitive)
Future<bool> _verificarSeExistePrestadorComNome(String termo) async {
  if (termo.isEmpty) return false;
  
  try {
    // 🔥 BUSCA CASE-INSENSITIVE: Remove acentos e converte para minúsculas
    final termoNormalizado = _normalizarTexto(termo);
    
    final querySnapshot = await db
        .collection(_colUsuarios)
        .where('tipoPerfil', whereIn: ['Prestador', 'Ambos'])
        .where('ativo', isEqualTo: true)
        .get();

    // 🔥 FILTRO LOCAL: Verifica se algum prestador tem o nome normalizado
    for (final doc in querySnapshot.docs) {
      final nomePrestador = (doc.data()['nome'] ?? '').toString();
      final nomeNormalizado = _normalizarTexto(nomePrestador);
      
      if (nomeNormalizado.contains(termoNormalizado)) {
        return true;
      }
    }

    return false;
  } catch (e) {
    debugPrint('Erro ao verificar prestador com nome: $e');
    return false;
  }
}

/// 🔹 Normaliza texto para busca case-insensitive e sem acentos
String _normalizarTexto(String texto) {
  if (texto.isEmpty) return '';
  
  // Converte para minúsculas
  texto = texto.toLowerCase();
  
  // Remove acentos
  texto = texto
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[ñ]'), 'n');
  
  return texto.trim();
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

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha principal: avatar + conteúdo + avaliação
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (fotoUrl.isNotEmpty)
                      ? NetworkImage(fotoUrl)
                      : null,
                  child: (fotoUrl.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 28,
                          color: Colors.deepPurple,
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Conteúdo principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Linha do nome + avaliação
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome
                          Expanded(
                            child: Text(
                              nome,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Avaliação no canto superior direito - COM FUTUREBUILDER
                          FutureBuilder<Map<String, num>>(
                            future: ratingPrestador(
                              id,
                            ), // Busca avaliações em tempo real
                            builder: (context, snapshot) {
                              final data =
                                  snapshot.data ?? {'media': 0.0, 'total': 0};
                              final nota = data['media']?.toDouble() ?? 0.0;
                              final avaliacoes = data['total']?.toInt() ?? 0;
                              final textoAvaliacao =
                                  '${nota.toStringAsFixed(1)} ($avaliacoes avaliações)';
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VisualizarAvaliacoesPrestador(
                                            prestadorId: id,
                                          ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        textoAvaliacao,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color.fromARGB(255, 0, 0, 0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Categoria profissional
                      FutureBuilder<String>(
                        future: nomeCategoriaProf(catProfId),
                        builder: (_, snapCat) {
                          final cat = (snapCat.data ?? '').trim();
                          return Text(
                            cat.isNotEmpty ? cat : 'Categoria não informada',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),

                      const SizedBox(height: 4),

                      // Localização
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cidade,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Experiência
                      Row(
                        children: [
                          const Icon(Icons.work, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              tempoExp.isEmpty
                                  ? 'Experiência não informada'
                                  : tempoExp,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Informações adicionais (se houver)
                      if ((u['especialidades'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Especialidades: ${u['especialidades']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Botões
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ver Perfil',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        showAgendaPrestadorModal(
                          context,
                          prestadorId: id,
                          prestadorNome: nome,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Agenda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  // Método auxiliar para buscar avaliações em tempo real (se necessário)
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
        const SizedBox(height: 10),
        ...childrenList,
      ],
    );
  }

  Widget buildFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        // CORREÇÃO: Filtro de unidades funcionando
        _sectionTitle('Unidade de medida'),
        DropdownButtonFormField<String>(
          initialValue: _unidadeSelecionada,
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            ..._unidades.map(
              (uId) => DropdownMenuItem(
                value: uId,
                child: Text(_unidadesMap[uId] ?? 'Unidade'),
              ),
            ),
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
                controller: maxValueController,
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
                min: 0,
                max: 50,
                divisions: 50,
                label: _raioDistancia == 0
                    ? 'Desativado'
                    : '${_raioDistancia.toStringAsFixed(0)} km',
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                _raioDistancia == 0
                    ? 'Sem filtro'
                    : '${_raioDistancia.toStringAsFixed(0)} km',
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
                ? 'Hoje (${DateFormat('dd/MM/yyyy').format(DateTime.now())})' // 🔥 Mostra "Hoje"
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
        _payTile('Dinheiro'),
        _payTile('Pix'),
        _payTile('Cartão de crédito/débito'),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _payTile(String label) {
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
    if (!mounted) return;

    DateTime? data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (data != null && mounted) {
      setState(() => dataSelecionada = data);
    }
  }

  void limparFiltros() {
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
      _raioDistancia = 0.0;
      pagamentosAceitos = []; // ✅ LIMPA PAGAMENTOS TAMBÉM
      _resultados.clear();
      _marcadores.clear();
      exibirProfissionais = false;
      _filtrosExibidos = true;
    });
  }

  String formatPreco(dynamic v) {
    if (v == null) return 'R\$ --';

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
    if (valor == null) return 'R\$ --';

    return 'R\$${valor.toStringAsFixed(2).replaceAll('.', ',')}';
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
      bottomNavigationBar: const ClienteBottomNav(
        selectedIndex: 1,
      ), // Índice 1 = Buscar
    );
  }
}

// CLASSES AUXILIARES
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
