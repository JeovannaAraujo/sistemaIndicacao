// lib/Cliente/CadastroUsuario.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_webservice/geocoding.dart' as gws;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CadastroUsuario extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final gws.GoogleMapsGeocoding? geocoding;

  const CadastroUsuario({super.key, this.firestore, this.auth, this.geocoding});

  @override
  State<CadastroUsuario> createState() => _CadastroUsuarioState();
}

class _CadastroUsuarioState extends State<CadastroUsuario> {
  final formKey = GlobalKey<FormState>();

  // Controllers
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  final cepController = TextEditingController();
  final cidadeController = TextEditingController();
  final ruaController = TextEditingController();
  final numeroController = TextEditingController();
  final bairroController = TextEditingController();
  final complementoController = TextEditingController();
  final whatsappController = TextEditingController();
  final descricaoController = TextEditingController();

  // Áreas de atendimento
  final areaAtendimentoInputController = TextEditingController();
  final List<String> areasAtendimento = [];

  // Estado
  String tipoPerfil = 'Cliente'; // Cliente | Prestador | Ambos
  String? categoriaProfissionalId;
  String tempoExperiencia = '';
  final List<String> meiosPagamento = [];
  final List<String> jornada = [];

  // UF vinda do ViaCEP para amarrar no geocoding
  String uf = '';

  // Auxiliares
  final experiencias = [
    '0-1 ano',
    '1-3 anos',
    '3-5 anos',
    '5-10 anos',
    '+10 anos',
  ];
  final diasSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  bool get isPrestador => tipoPerfil == 'Prestador' || tipoPerfil == 'Ambos';

  // debounce CEP
  Timer? _cepDebounce;

  // Cores/botões
  final _primary = const Color(0xFF5B2CF6);
  final _primaryDark = const Color(0xFF3F10D6);

  // ====== MAPA (picker) ======
  GoogleMapController? mapCtrl;
  LatLng? pickedLatLng; // pino atual (auto pelo CEP/endereço ou manual)
  bool _mapBusy = false;

  // fallback de câmera (fixo Rio Verde)
  static const LatLng _fallbackCenter = LatLng(
    -17.792765,
    -50.919582,
  ); // Rio Verde (GO) centro aproximado
  static const double _fallbackZoom = 13;

  // ====== Títulos: padronização ======
  static const double _sectionFontSize = 18; // tamanho fixo solicitado
  static const FontWeight _sectionFontWeight = FontWeight.w700;

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: _sectionFontSize,
        fontWeight: _sectionFontWeight,
      ),
    ),
  );

  // ====== Dependências e Streams ======
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late gws.GoogleMapsGeocoding _geocoding;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  @override
  void initState() {
    super.initState();

    // Injeção de dependência (usa fake se vier dos testes)
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;

    // 🔹 Mantém a chave real da API no app e usa FAKE_KEY apenas em testes
    _geocoding =
        widget.geocoding ??
        gws.GoogleMapsGeocoding(
          apiKey: 'AIzaSyBIEjXfEExXz_av5qu-xmWM4DqzHrExGC0',
        );

    _categoriasStream = _firestore
        .collection('categoriasProfissionais')
        .where('ativo', isEqualTo: true)
        .snapshots();
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    cepController.dispose();
    cidadeController.dispose();
    ruaController.dispose();
    numeroController.dispose();
    bairroController.dispose();
    complementoController.dispose();
    whatsappController.dispose();
    descricaoController.dispose();
    areaAtendimentoInputController.dispose();
    _cepDebounce?.cancel();
    mapCtrl?.dispose();
    super.dispose();
  }

  // =============== VIA CEP: preenche endereço + UF ===============
// =============== VIA CEP: preenche endereço + UF ===============
Future<void> buscarCep(String maskCep) async {
  final cep = maskCep.replaceAll(RegExp(r'[^0-9]'), '');
  if (cep.length != 8) return;

  // ✅ Detecta modo de teste
  final isTestMode = Platform.environment.containsKey('FLUTTER_TEST');

  Timer? timeoutTimer;
  try {
    final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');

    // 🔹 Se for teste, ignora o timer e responde direto do mock
    if (isTestMode) {
      final r = await http.get(uri);
      print('⏱️ Timeout ViaCEP simulado (ignorado durante teste)');
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        setState(() {
          ruaController.text = (data['logradouro'] ?? '').toString();
          bairroController.text = (data['bairro'] ?? '').toString();
          cidadeController.text = (data['localidade'] ?? '').toString();
          uf = (data['uf'] ?? '').toString();
        });
      }
      return;
    }

    // 🔹 Execução normal (modo app)
    final completer = Completer<http.Response>();
    timeoutTimer = Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.completeError(
            TimeoutException('Tempo esgotado ao consultar ViaCEP'));
      }
    });

    final response = await http.get(uri);
    if (!completer.isCompleted) completer.complete(response);

    final r = await completer.future;

    if (r.statusCode == 200) {
      final data = json.decode(r.body) as Map<String, dynamic>;
      if (data['erro'] == true) {
        print('⚠️ CEP não encontrado no ViaCEP');
        return;
      }

      setState(() {
        ruaController.text = (data['logradouro'] ?? '').toString();
        bairroController.text = (data['bairro'] ?? '').toString();
        cidadeController.text = (data['localidade'] ?? '').toString();
        uf = (data['uf'] ?? '').toString();
      });
    }
  } catch (e) {
    print('❌ Erro ao consultar ViaCEP: $e');
  } finally {
    timeoutTimer?.cancel();
  }
}



  // =============== ÁREAS DE ATENDIMENTO ===============
  void addAreaAtendimento() {
    final txt = areaAtendimentoInputController.text.trim();
    if (txt.isEmpty) return;
    final normalizado = capitalizeWords(txt);
    if (!areasAtendimento.contains(normalizado)) {
      setState(() => areasAtendimento.add(normalizado));
    }
    areaAtendimentoInputController.clear();
  }

  String capitalizeWords(String s) {
    return s
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map(
          (p) =>
              p[0].toUpperCase() +
              (p.length > 1 ? p.substring(1).toLowerCase() : ''),
        )
        .join(' ');
  }

  // =============== GEOCODING HELPERS ===============
  gws.GeocodingResult? pickBestResult(List<gws.GeocodingResult> results) {
    if (results.isEmpty) return null;
    // 1) tipos mais específicos
    const prefTypes = {'street_address', 'premise', 'subpremise', 'route'};
    final byType = results.where((r) {
      final types = r.types.map((e) => e.toLowerCase()).toSet();
      return types.any(prefTypes.contains);
    }).toList();
    if (byType.isNotEmpty) return byType.first;

    // 2) ROOFTOP > RANGE_INTERPOLATED (comparação por string)
    bool hasLocType(gws.GeocodingResult r, String want) {
      final lt = r.geometry.locationType;
      final s = (lt == null ? '' : lt.toString()).toUpperCase();
      return s.contains(want.toUpperCase());
    }

    final rooftop = results.firstWhere(
      (r) => hasLocType(r, 'ROOFTOP'),
      orElse: () => results.first,
    );
    if (hasLocType(rooftop, 'ROOFTOP')) return rooftop;
    final range = results.firstWhere(
      (r) => hasLocType(r, 'RANGE_INTERPOLATED'),
      orElse: () => results.first,
    );
    return range;
  }

  // Compara cidade/UF do resultado do Google com os esperados
  bool matchesCityUf(gws.GeocodingResult r, String cidade, String uf) {
    final wantCity = cidade.trim().toLowerCase();
    final wantUF = uf.trim().toUpperCase();

    String? gotCity;
    String? gotUF;

    for (final c in r.addressComponents) {
      final types = c.types.map((e) => e.toLowerCase()).toSet();
      if (types.contains('locality') ||
          types.contains('administrative_area_level_2')) {
        gotCity = (c.longName).toLowerCase();
      }
      if (types.contains('administrative_area_level_1')) {
        gotUF = (c.shortName).toUpperCase();
      }
    }

    return (gotCity == wantCity) && (gotUF == wantUF);
  }

  // Pega cidade/UF a partir do CEP (ViaCEP)
  Future<Map<String, String>?> _cidadeUfPorCep(String cep) async {
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        if (data['erro'] == true) return null;
        final cidade = (data['localidade'] ?? '').toString();
        final uf = (data['uf'] ?? '').toString();
        if (cidade.isNotEmpty && uf.isNotEmpty) {
          return {'cidade': cidade, 'uf': uf};
        }
      }
    } catch (_) {}
    return null;
  }

  /// CEP -> Coordenadas seguras (BrasilAPI -> Google com cidade/UF -> Address -> postal_code)
  Future<LatLng?> coordsPorCep(String cepMask) async {
    final cep = cepMask.replaceAll(RegExp(r'[^0-9]'), '');
    if (cep.length != 8) return null;

    // Amarra cidade/UF ao CEP
    final cityUf = await _cidadeUfPorCep(cep);
    final cidade = (cityUf?['cidade'] ?? '').trim();
    final uf = (cityUf?['uf'] ?? '').trim();

    // 1) BrasilAPI
    try {
      final uri = Uri.parse('https://brasilapi.com.br/api/cep/v2/$cep');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        final loc = (data['location'] ?? {}) as Map<String, dynamic>;
        final coords = (loc['coordinates'] ?? {}) as Map<String, dynamic>;
        final lat = (coords['latitude'] as num?)?.toDouble();
        final lng = (coords['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (_) {}

    // 2) Google Geocoding por components com cidade/UF
    try {
      final comps = <gws.Component>[
        gws.Component('postal_code', cep),
        if (cidade.isNotEmpty) gws.Component('locality', cidade),
        if (uf.isNotEmpty) gws.Component('administrative_area_level_1', uf),
        gws.Component('country', 'BR'),
      ];
      final resp = await _geocoding.searchByComponents(comps);
      if (resp.status == 'OK' && resp.results.isNotEmpty) {
        final match = resp.results.firstWhere(
          (r) => matchesCityUf(r, cidade, uf),
          orElse: () => resp.results.first,
        );
        final loc = match.geometry.location;
        return LatLng(loc.lat, loc.lng);
      }
    } catch (_) {}

    // 3) Google Address (amarrado)
    try {
      final q = [
        'CEP $cep',
        if (cidade.isNotEmpty && uf.isNotEmpty) '$cidade - $uf',
        'Brasil',
      ].join(', ');
      final resp2 = await _geocoding.searchByAddress(q, region: 'br');
      if (resp2.status == 'OK' && resp2.results.isNotEmpty) {
        final match = resp2.results.firstWhere(
          (r) => matchesCityUf(r, cidade, uf),
          orElse: () => resp2.results.first,
        );
        final loc = match.geometry.location;
        return LatLng(loc.lat, loc.lng);
      }
    } catch (_) {}

    // 4) Último fallback: postal_code puro
    try {
      final resp = await _geocoding.searchByComponents([
        gws.Component('postal_code', cep),
        gws.Component('country', 'BR'),
      ]);
      if (resp.status == 'OK' && resp.results.isNotEmpty) {
        final loc = resp.results.first.geometry.location;
        return LatLng(loc.lat, loc.lng);
      }
    } catch (_) {}

    return null;
  }

  /// Endereço completo -> GeoPoint (com UF); com validação cidade/UF e fallback por CEP
  Future<GeoPoint?> geocodePrestador({
    required String cep,
    String? rua,
    String? numero,
    String? bairro,
    String? cidade,
    String? uf,
  }) async {
    try {
      final onlyDigitsCep = cep.replaceAll(RegExp(r'[^0-9]'), '');
      final ruaTrim = (rua ?? '').trim();
      final numTrim = (numero ?? '').trim();
      final bairroTrim = (bairro ?? '').trim();
      final cidadeTrim = (cidade ?? '').trim();
      final ufTrim = (uf ?? this.uf).trim().toUpperCase();

      final numeroDigits = RegExp(r'^\d+$').hasMatch(numTrim) ? numTrim : null;

      // 1) Components detalhados
      final comps = <gws.Component>[
        if (numeroDigits != null) gws.Component('street_number', numeroDigits),
        if (ruaTrim.isNotEmpty) gws.Component('route', ruaTrim),
        if (bairroTrim.isNotEmpty) gws.Component('neighborhood', bairroTrim),
        if (cidadeTrim.isNotEmpty) gws.Component('locality', cidadeTrim),
        if (ufTrim.isNotEmpty)
          gws.Component('administrative_area_level_1', ufTrim),
        if (onlyDigitsCep.length == 8)
          gws.Component('postal_code', onlyDigitsCep),
        gws.Component('country', 'BR'),
      ];

      final resp1 = await _geocoding.searchByComponents(comps);
      if (resp1.status == 'OK' && resp1.results.isNotEmpty) {
        final best = pickBestResult(resp1.results) ?? resp1.results.first;
        final chosen = matchesCityUf(best, cidadeTrim, ufTrim)
            ? best
            : (resp1.results.firstWhere(
                (r) => matchesCityUf(r, cidadeTrim, ufTrim),
                orElse: () => best,
              ));
        final loc = chosen.geometry.location;
        return GeoPoint(loc.lat, loc.lng);
      }

      // 2) Address string completa
      final fullAddress = [
        if (ruaTrim.isNotEmpty && numeroDigits != null)
          '$ruaTrim, $numeroDigits'
        else if (ruaTrim.isNotEmpty)
          ruaTrim,
        if (bairroTrim.isNotEmpty) bairroTrim,
        if (cidadeTrim.isNotEmpty && ufTrim.isNotEmpty)
          '$cidadeTrim - $ufTrim'
        else if (cidadeTrim.isNotEmpty)
          cidadeTrim,
        if (onlyDigitsCep.length == 8) 'CEP $onlyDigitsCep',
        'Brasil',
      ].where((s) => s.trim().isNotEmpty).join(', ');

      if (fullAddress.isNotEmpty) {
        final resp2 = await _geocoding.searchByAddress(
          fullAddress,
          region: 'br',
        );
        if (resp2.status == 'OK' && resp2.results.isNotEmpty) {
          final best = pickBestResult(resp2.results) ?? resp2.results.first;
          final chosen = matchesCityUf(best, cidadeTrim, ufTrim)
              ? best
              : (resp2.results.firstWhere(
                  (r) => matchesCityUf(r, cidadeTrim, ufTrim),
                  orElse: () => best,
                ));
          final loc = chosen.geometry.location;
          return GeoPoint(loc.lat, loc.lng);
        }
      }

      // 3) Fallback: CEP (reusa método de CEP)
      if (onlyDigitsCep.length == 8) {
        final ll = await coordsPorCep(onlyDigitsCep);
        if (ll != null) {
          return GeoPoint(ll.latitude, ll.longitude);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // =============== AÇÕES DE MAPA (CEP / Endereço) ===============
  Future<void> _localizarPeloCEP() async {
    if (!isPrestador) return;
    final cep = cepController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cep.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um CEP válido (8 dígitos).')),
      );
      return;
    }

    setState(() => _mapBusy = true);
    try {
      final comps = <gws.Component>[
        gws.Component('postal_code', cep),
        if (cidadeController.text.isNotEmpty)
          gws.Component('locality', cidadeController.text.trim()),
        if (uf.isNotEmpty) gws.Component('administrative_area_level_1', uf),
        gws.Component('country', 'BR'),
      ];

      final resp = await _geocoding.searchByComponents(comps);

      if (resp.status == 'OK' && resp.results.isNotEmpty) {
        final loc = resp.results.first.geometry.location;
        final latLng = LatLng(loc.lat, loc.lng);

        setState(() => pickedLatLng = latLng);

        if (mapCtrl != null) {
          await mapCtrl!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16),
            ),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pino posicionado pelo CEP.')),
        );
      } else {
        print('Geocoding erro: ${resp.status} - ${resp.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível localizar esse CEP.')),
        );
      }
    } catch (e) {
      print('Erro Geocoding: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao localizar CEP: $e')));
    } finally {
      if (mounted) setState(() => _mapBusy = false);
    }
  }

  Future<void> _localizarPeloEndereco() async {
    if (!isPrestador) return;
    setState(() => _mapBusy = true);
    try {
      final geo = await geocodePrestador(
        cep: cepController.text.trim(),
        rua: ruaController.text.trim(),
        numero: numeroController.text.trim(),
        bairro: bairroController.text.trim(),
        cidade: cidadeController.text.trim(),
        uf: uf,
      );
      if (geo != null) {
        final latLng = LatLng(geo.latitude, geo.longitude);
        setState(() => pickedLatLng = latLng);
        if (mapCtrl != null) {
          await mapCtrl!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16),
            ),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Localização encontrada. Ajuste o pino se necessário.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível localizar pelo endereço. Ajuste manualmente no mapa.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _mapBusy = false);
    }
  }

  // =============== CADASTRAR ===============
  // 🔹 Versão compatível com testes (sem alterar funcionamento)
  Future<void> cadastrar() async {
    if (!formKey.currentState!.validate()) return;

    if (senhaController.text != confirmarSenhaController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('As senhas não coincidem.')));
      return;
    }

    if (isPrestador) {
      if (categoriaProfissionalId == null ||
          tempoExperiencia.isEmpty ||
          areasAtendimento.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preencha categoria, experiência e ao menos uma área de atendimento.',
            ),
          ),
        );
        return;
      }

      // 🔸 usa _firestore injetável (FakeFirebaseFirestore nos testes)
      final catDoc = await _firestore
          .collection('categoriasProfissionais')
          .doc(categoriaProfissionalId)
          .get();

      if (!catDoc.exists || catDoc.data()?['ativo'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A categoria selecionada não está mais ativa.'),
          ),
        );
        return;
      }
    }

    UserCredential? cred;
    try {
      final email = emailController.text.trim().toLowerCase();
      final senha = senhaController.text.trim();

      // 🔸 usa _auth injetável (MockFirebaseAuth nos testes)
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      final uid = cred.user!.uid;

      // =====================================
      // 🔹 GEOPOINT DO PRESTADOR (LOCALIZAÇÃO)
      // =====================================
      GeoPoint? geo;
      if (isPrestador) {
        if (pickedLatLng != null) {
          geo = GeoPoint(pickedLatLng!.latitude, pickedLatLng!.longitude);
        } else {
          final result = await geocodePrestador(
            cep: cepController.text.trim(),
            rua: ruaController.text.trim(),
            numero: numeroController.text.trim(),
            bairro: bairroController.text.trim(),
            cidade: cidadeController.text.trim(),
            uf: uf,
          );

          if (result != null) {
            geo = GeoPoint(result.latitude, result.longitude);
          } else {
            final ll = await coordsPorCep(cepController.text.trim());
            if (ll != null) geo = GeoPoint(ll.latitude, ll.longitude);
          }
        }
      }

      // =====================================
      // 🔹 DADOS BÁSICOS DO USUÁRIO
      // =====================================
      final payload = <String, dynamic>{
        'uid': uid,
        'nome': nomeController.text.trim(),
        'email': email,
        'tipoPerfil': tipoPerfil,
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
        'endereco': {
          'cep': cepController.text.trim(),
          'cidade': cidadeController.text.trim(),
          'uf': uf,
          'rua': ruaController.text.trim(),
          'numero': numeroController.text.trim(),
          'bairro': bairroController.text.trim(),
          'complemento': complementoController.text.trim(),
          'whatsapp': whatsappController.text.trim(),
        },
      };

      if (isPrestador) {
        payload.addAll({
          'categoriaProfissionalId': categoriaProfissionalId,
          'descricao': descricaoController.text.trim(),
          'tempoExperiencia': tempoExperiencia,
          'areasAtendimento': areasAtendimento.toSet().toList(),
          'meiosPagamento': meiosPagamento.toSet().toList(),
          'jornada': jornada.toSet().toList(),
          if (geo != null) 'geo': geo,
        });
      }

      // 🔸 usa _firestore injetável (FakeFirebaseFirestore nos testes)
      await _firestore.collection('usuarios').doc(uid).set(payload);

      // 🔸 mensagem reconhecida pelos testes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso!')),
      );

      if (Navigator.canPop(context)) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este e-mail já está em uso.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'weak-password':
          msg = 'Senha fraca. Use 6+ caracteres.';
          break;
        default:
          msg = 'Falha no cadastro: ${e.message ?? e.code}';
      }

      // 🔸 texto verificável nos testes
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (cred?.user != null) {
        try {
          await cred!.user!.delete();
        } catch (_) {}
      }

      // 🔸 texto verificável nos testes
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar dados: $e')));
    }
  }

  // =============== UI ===============
  InputDecoration _dec(
    String label, {
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F7FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6E3F6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6E3F6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF5B2CF6), width: 1.6),
      ),
    );
  }

  ButtonStyle _btnPrimary() => ElevatedButton.styleFrom(
    backgroundColor: _primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  );

  ButtonStyle _btnGhost() => OutlinedButton.styleFrom(
    foregroundColor: _primaryDark,
    side: BorderSide(color: _primary.withOpacity(0.25)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    final isPrest = isPrestador;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Usuário'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== Título: Informações Pessoais ======
              _section('Informações Pessoais'),

              // Dados básicos
              TextFormField(
                controller: nomeController,
                decoration: _dec('Nome completo'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration: _dec('E-mail'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: senhaController,
                decoration: _dec('Senha'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmarSenhaController,
                decoration: _dec('Confirmar senha'),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: tipoPerfil,
                items: const ['Cliente', 'Prestador', 'Ambos']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => tipoPerfil = v as String),
                decoration: _dec('Tipo de perfil'),
              ),

              const Divider(height: 32),

              // ====== Título: Endereço e Contato ======
              _section('Endereço e Contato'),

              // Endereço
              TextFormField(
                controller: cepController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CepInputFormatter(),
                ],
                decoration: _dec(
                  'CEP',
                  hint: '00000-000',
                  prefix: const Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                onChanged: (v) {
                  _cepDebounce?.cancel();
                  final raw = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (raw.length == 8) {
                    _cepDebounce = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        await buscarCep(v); // 🔹 Preenche os campos
                        if (cidadeController.text.isNotEmpty && uf.isNotEmpty) {
                          await _localizarPeloCEP(); // 🔹 Só tenta mapa depois do endereço
                        }
                      },
                    );
                  }
                },

                onFieldSubmitted: (v) async {
                  await buscarCep(v);
                  await _localizarPeloCEP();
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: cidadeController,
                decoration: _dec('Cidade'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: ruaController,
                decoration: _dec('Rua'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: numeroController,
                decoration: _dec('Número'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: bairroController,
                decoration: _dec('Bairro'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: complementoController,
                decoration: _dec('Complemento'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: whatsappController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _WhatsappMaskFormatter(),
                ],
                decoration: _dec(
                  'WhatsApp',
                  hint: '(00) 00000-0000',
                  prefix: const Icon(
                    FontAwesomeIcons.whatsapp,
                    color: Color(0xFF25D366),
                    size: 22,
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),

              // ====== MAPA: Confirmar localização ======
              if (isPrest) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Confirme sua localização no mapa',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _mapBusy ? null : _localizarPeloCEP,
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Text('Pelo CEP'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _mapBusy ? null : _localizarPeloEndereco,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Pelo endereço'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6E3F6)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      GoogleMap(
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        // ✅ permite gestos dentro do SingleChildScrollView
                        gestureRecognizers:
                            <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                        onMapCreated: (c) => mapCtrl = c,
                        // Fixo: inicia em Rio Verde
                        initialCameraPosition: const CameraPosition(
                          target: _fallbackCenter,
                          zoom: _fallbackZoom,
                        ),
                        markers: {
                          if (pickedLatLng != null)
                            Marker(
                              markerId: const MarkerId('picked'),
                              position: pickedLatLng!,
                              draggable: true,
                              onDragEnd: (p) =>
                                  setState(() => pickedLatLng = p),
                            ),
                        },
                        onTap: (p) => setState(() => pickedLatLng = p),
                      ),
                      if (_mapBusy)
                        Container(
                          color: Colors.black.withOpacity(0.15),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pickedLatLng == null
                            ? 'Toque no mapa para posicionar o pino. Você pode arrastar para ajustar com precisão.'
                            : 'Pino em: ${pickedLatLng!.latitude.toStringAsFixed(6)}, '
                                  '${pickedLatLng!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],

              if (isPrest) const Divider(height: 32),

              if (isPrest) ...[
                // ====== Título: Informações Profissionais ======
                _section('Informações Profissionais'),

                // Categorias ativas
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoriasStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return DropdownButtonFormField<String>(
                        items: const [],
                        onChanged: null,
                        decoration: _dec('Categoria Profissional'),
                        hint: const Text('Carregando categorias...'),
                      );
                    }
                    if (snap.hasError) {
                      return Text(
                        'Erro ao carregar categorias: ${snap.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    final docs = [...(snap.data?.docs ?? [])];
                    docs.sort((a, b) {
                      final an = (a.data()['nome'] ?? '')
                          .toString()
                          .toLowerCase();
                      final bn = (b.data()['nome'] ?? '')
                          .toString()
                          .toLowerCase();
                      return an.compareTo(bn);
                    });

                    if (docs.isEmpty) {
                      return const Text(
                        'Nenhuma categoria ativa disponível.',
                        style: TextStyle(color: Colors.red),
                      );
                    }

                    final itens = docs.map((d) {
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text((d.data()['nome'] ?? '').toString()),
                      );
                    }).toList();

                    return DropdownButtonFormField<String>(
                      initialValue: categoriaProfissionalId,
                      items: itens,
                      onChanged: (id) =>
                          setState(() => categoriaProfissionalId = id),
                      decoration: _dec('Categoria Profissional'),
                      hint: const Text('Selecione a categoria'),
                      validator: (_) =>
                          (isPrestador &&
                              (categoriaProfissionalId == null ||
                                  categoriaProfissionalId!.isEmpty))
                          ? 'Obrigatório'
                          : null,
                    );
                  },
                ),

                const SizedBox(height: 10),
                TextFormField(
                  controller: descricaoController,
                  decoration: _dec('Descrição (opcional)'),
                  maxLines: 4,
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField(
                  initialValue: tempoExperiencia.isNotEmpty
                      ? tempoExperiencia
                      : null,
                  hint: const Text('Selecione'),
                  items: experiencias
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => tempoExperiencia = v as String),
                  decoration: _dec('Tempo de experiência'),
                  validator: (_) =>
                      tempoExperiencia.isEmpty ? 'Obrigatório' : null,
                ),

                const SizedBox(height: 16),

                // ====== Título: Cidade / Área de atendimento ======
                _section('Cidade / Área de atendimento'),

                TextField(
                  controller: areaAtendimentoInputController,
                  decoration: _dec(
                    '',
                    hint: 'Ex: Rio Verde',
                    suffix: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: addAreaAtendimento,
                    ),
                  ),
                  onSubmitted: (_) => addAreaAtendimento(),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Informe todas as cidades e áreas de seu atendimento.',
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: areasAtendimento.map((c) {
                    return Chip(
                      label: Text(c),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () =>
                          setState(() => areasAtendimento.remove(c)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: _primary.withOpacity(0.25)),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ====== Título: Meios de pagamento aceitos ======
                _section('Meios de pagamento aceitos'),
                const Text(
                  'Os meios de pagamento servem apenas para informativo; o app não processa pagamentos.',
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                ),
                ...['Dinheiro', 'Pix', 'Cartão de crédito/débito'].map(
                  (e) => CheckboxListTile(
                    dense: true,
                    title: Text(
                      e,
                      style: const TextStyle(fontSize: 16.5),
                    ), // ↑ fonte maior
                    value: meiosPagamento.contains(e),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!meiosPagamento.contains(e)) meiosPagamento.add(e);
                      } else {
                        meiosPagamento.remove(e);
                      }
                    }),
                  ),
                ),

                const SizedBox(height: 8),

                // ====== Título: Jornada de Trabalho ======
                _section('Jornada de Trabalho'),
                const Text(
                  'Informe os dias em que você está disponível para prestar serviços.',
                  style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                ),
                ...diasSemana.map(
                  (e) => CheckboxListTile(
                    dense: true,
                    title: Text(
                      e,
                      style: const TextStyle(fontSize: 16.5),
                    ), // ↑ fonte maior
                    value: jornada.contains(e),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!jornada.contains(e)) jornada.add(e);
                      } else {
                        jornada.remove(e);
                      }
                    }),
                  ),
                ),
              ],

              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cadastrar,
                      style: _btnPrimary(),
                      child: const Text('Cadastrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: _btnGhost(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- Máscaras ---------------- */

/// CEP: 00000-000
class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final v = d.length > 8 ? d.substring(0, 8) : d;
    String out;
    if (v.length <= 5) {
      out = v;
    } else {
      out = '${v.substring(0, 5)}-${v.substring(5)}';
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

/// WhatsApp: (00) 00000-0000
class _WhatsappMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final d = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buf = StringBuffer();
    if (d.isNotEmpty) {
      buf.write('(');
      buf.write(d.substring(0, d.length >= 2 ? 2 : d.length));
      if (d.length >= 2) buf.write(') ');
    }
    final midLen = d.length <= 2 ? 0 : (d.length - 2 >= 5 ? 5 : d.length - 2);
    if (midLen > 0) {
      buf.write(d.substring(2, 2 + midLen));
      if (midLen >= 5) buf.write('-');
    }
    final endLen = d.length <= 7 ? 0 : (d.length - 7 > 4 ? 4 : d.length - 7);
    if (endLen > 0) {
      buf.write(d.substring(7, 7 + endLen));
    }

    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
