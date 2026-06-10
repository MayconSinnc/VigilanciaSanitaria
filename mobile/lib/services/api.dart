import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_base_url.dart';
import 'app_storage.dart';

const bool _debugEnabled = bool.fromEnvironment('ENABLE_DEBUG_REPORT', defaultValue: false);
const String _debugServerUrl = String.fromEnvironment('DEBUG_SERVER_URL', defaultValue: '');
const String _debugSessionId = String.fromEnvironment('DEBUG_SESSION_ID', defaultValue: '');

Future<void> _reportFrontendDebug({
  required String hypothesisId,
  required String location,
  required String msg,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) async {
  if (!_debugEnabled || _debugServerUrl.trim().isEmpty) return;
  try {
    await Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 800),
        receiveTimeout: const Duration(milliseconds: 800),
        sendTimeout: const Duration(milliseconds: 800),
      ),
    ).post(
      _debugServerUrl,
      data: {
        'sessionId': _debugSessionId.trim().isEmpty ? 'apk-login-http-404' : _debugSessionId.trim(),
        'runId': runId,
        'hypothesisId': hypothesisId,
        'location': location,
        'msg': msg,
        'data': data ?? const <String, dynamic>{},
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
  } catch (_) {}
}

class ApiService {
  static const bool mockMode = bool.fromEnvironment('MOCK_MODE', defaultValue: false);

  final Dio _dio = Dio();

  String _baseUrl = resolveDefaultApiBaseUrl();
  static String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');
  String get baseUrl => _baseUrl;

  static final List<Map<String, dynamic>> _mockEstabelecimentos = [
    {
      'cnpj': '12345678000190',
      'razaoSocial': 'Padaria Central LTDA',
      'razao_social': 'Padaria Central LTDA',
      'nomeFantasia': 'Padaria Central',
      'nome_fantasia': 'Padaria Central',
      'nome': 'Padaria Central',
      'logradouro': 'Av. Brasil',
      'rua': 'Av. Brasil',
      'numero': '100',
      'bairro': 'Centro',
      'cep': '88330000',
      'cidade': 'Balneário Camboriú',
      'municipio': 'Balneário Camboriú',
      'uf': 'SC',
      'estado': 'SC',
      'endereco': 'Av. Brasil, 100 - Centro',
      'telefone': '(47) 99999-0001',
      'email': 'contato@padariacentral.com',
      'responsavel': 'João da Silva',
      'cpf_responsavel': '00000000000',
      'cnae': '4721102',
      'cnaeDescricao': 'Padaria e confeitaria com predominância de revenda',
      'cnae_fiscal_descricao': 'Padaria e confeitaria com predominância de revenda',
      'risco': 'Baixo',
      'status_alvara': 'Regular',
      'status_sanitario': 'Regular',
      'grau_risco': 'Baixo',
      'lat': -26.9900,
      'lng': -48.6350,
      'data_cadastro': '2026-03-10',
    },
    {
      'cnpj': '98765432000100',
      'razaoSocial': 'Restaurante Praia ME',
      'razao_social': 'Restaurante Praia ME',
      'nomeFantasia': 'Restaurante Praia',
      'nome_fantasia': 'Restaurante Praia',
      'nome': 'Restaurante Praia',
      'logradouro': 'Av. Atlântica',
      'rua': 'Av. Atlântica',
      'numero': '2000',
      'bairro': 'Barra Sul',
      'cep': '88330001',
      'cidade': 'Balneário Camboriú',
      'municipio': 'Balneário Camboriú',
      'uf': 'SC',
      'estado': 'SC',
      'endereco': 'Av. Atlântica, 2000 - Barra Sul',
      'telefone': '(47) 99999-0002',
      'email': 'financeiro@restaurantepraia.com',
      'responsavel': 'Maria Oliveira',
      'cpf_responsavel': '11111111111',
      'cnae': '5611201',
      'cnaeDescricao': 'Restaurantes e similares',
      'cnae_fiscal_descricao': 'Restaurantes e similares',
      'risco': 'Médio',
      'status_alvara': 'Regular',
      'status_sanitario': 'Regular',
      'grau_risco': 'Médio',
      'lat': -26.9955,
      'lng': -48.6332,
      'data_cadastro': '2026-03-12',
    },
    {
      'cnpj': '11223344000155',
      'razaoSocial': 'Laticínios BC Indústria',
      'razao_social': 'Laticínios BC Indústria',
      'nomeFantasia': 'Laticínios BC',
      'nome_fantasia': 'Laticínios BC',
      'nome': 'Laticínios BC',
      'logradouro': 'Rua 1500',
      'rua': 'Rua 1500',
      'numero': '50',
      'bairro': 'Nações',
      'cep': '88330002',
      'cidade': 'Balneário Camboriú',
      'municipio': 'Balneário Camboriú',
      'uf': 'SC',
      'estado': 'SC',
      'endereco': 'Rua 1500, 50 - Nações',
      'telefone': '(47) 99999-0003',
      'email': 'suporte@laticiniosbc.com',
      'responsavel': 'Carlos Souza',
      'cpf_responsavel': '22222222222',
      'cnae': '1052000',
      'cnaeDescricao': 'Fabricação de laticínios',
      'cnae_fiscal_descricao': 'Fabricação de laticínios',
      'risco': 'Alto',
      'status_alvara': 'Vencido',
      'status_sanitario': 'Irregular',
      'grau_risco': 'Alto',
      'lat': -27.0042,
      'lng': -48.6401,
      'data_cadastro': '2026-03-08',
    },
  ];

  Future<void> setBaseUrl(String url) async {
    if (mockMode) return;
    final normalized = normalizeSavedApiBaseUrl(url);
    _baseUrl = normalized;
    _dio.options.baseUrl = _baseUrl;
    await AppStorage.write('base_url', _baseUrl);
  }

  Future<List<int>> baixarPdfBytes(String pathOrUrl) async {
    if (mockMode) return const <int>[];
    await init();
    final res = await _dio.get(
      pathOrUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return data;
    if (data is List) return data.whereType<int>().toList();
    return const <int>[];
  }

  Future<Map<String, dynamic>> sincronizarSinncSaudeViewVsAutoTermo() async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/sinnc-saude/view-vs-auto-termo/sync');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return {};
  }

  Future<Map<String, dynamic>> sincronizarAutoTermoSinncSaude(Map<String, dynamic> body) async {
    if (mockMode) return {};
    await init();
    final sinncToken = await getSinncToken();
    final res = await _dio.post('/api/sinnc/auto-termo/sincronizar',
        data: body, options: sinncToken == null ? null : Options(headers: {'x-sinnc-token': sinncToken}));
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return {};
  }

  Future<Map<String, dynamic>?> criarEstabelecimento({
    required String cnpj,
    required String razaoSocial,
    required String nomeFantasia,
    required String endereco,
    required String cidade,
    String? numero,
    String? cep,
    String? estado,
    String? bairro,
    String? inscricaoMunicipal,
    String? telefone,
    String? email,
    String? responsavel,
    String? cpfResponsavel,
    String? risco,
    String? statusAlvara,
    String? statusSanitario,
    String? grauRisco,
    double? latitude,
    double? longitude,
  }) async {
    if (mockMode) {
      return {
        'cnpj': _digitsOnly(cnpj),
        'razaoSocial': razaoSocial,
        'nomeFantasia': nomeFantasia,
        'endereco': endereco,
        'cidade': cidade,
        'numero': numero,
        'cep': cep,
        'estado': estado,
        'bairro': bairro,
        'inscricaoMunicipal': inscricaoMunicipal,
        'telefone': telefone,
        'email': email,
        'responsavel': responsavel,
        'cpf_responsavel': cpfResponsavel,
        'risco': risco,
        'status_alvara': statusAlvara,
        'status_sanitario': statusSanitario,
        'grau_risco': grauRisco,
        'lat': latitude,
        'lng': longitude,
      };
    }
    await init();
    final res = await _dio.post('/api/estabelecimentos', data: {
      'cnpj': cnpj,
      'razao_social': razaoSocial,
      'nome_fantasia': nomeFantasia,
      'endereco': endereco,
      'numero': numero,
      'cep': cep,
      'cidade': cidade,
      'uf': estado,
      'bairro': bairro,
      'inscricaoMunicipal': inscricaoMunicipal,
      'telefone': telefone,
      'email': email,
      'responsavel': responsavel,
      'cpf_responsavel': cpfResponsavel,
      'risco': risco,
      'status_alvara': statusAlvara,
      'status_sanitario': statusSanitario,
      'grau_risco': grauRisco,
      'lat': latitude,
      'lng': longitude,
    });
    if (res.statusCode == 201) return res.data;
    return null;
  }

  Future<Map<String, dynamic>> dashboardResumo() async {
    if (mockMode) return {};
    await init();
    final res = await _dio.get('/api/dashboard/resumo');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return {};
  }

  Future<bool> loginSinnc(String cpf, String senha) async {
    if (mockMode) {
      await AppStorage.write('sinnc_token', 'mock-sinnc-token');
      await AppStorage.write('sinnc_cpf', _digitsOnly(cpf));
      return cpf.trim().isNotEmpty && senha.trim().isNotEmpty;
    }
    await init();
    final res = await _dio.post('/api/sinnc/login', data: {'cpf': cpf, 'senha': senha});
    final token = (res.data is Map ? (res.data['token'] as String?) : null);
    if (token != null && token.trim().isNotEmpty) {
      await AppStorage.write('sinnc_token', token.trim());
      await AppStorage.write('sinnc_cpf', _digitsOnly(cpf));
      return true;
    }
    return false;
  }

  Future<String?> getSinncToken() async {
    final token = await AppStorage.read('sinnc_token');
    if (token == null) return null;
    final trimmed = token.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  bool _initialized = false;

  Future<void> init() async {
    if (mockMode) {
      _initialized = true;
      return;
    }
    final saved = await AppStorage.read('base_url');
    _baseUrl = normalizeSavedApiBaseUrl(saved);
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.sendTimeout = kIsWeb ? null : const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    if (!_initialized) {
      _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
        final token = await AppStorage.read('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final base = (_dio.options.baseUrl).toLowerCase();
        if (base.contains('.ngrok-free.')) {
          options.headers['ngrok-skip-browser-warning'] = 'true';
        }
        handler.next(options);
      }));
    }
    _initialized = true;
  }

  Future<bool> login(String cpf, String senha) async {
    if (mockMode) {
      final token = 'mock-token';
      await AppStorage.write('jwt_token', token);
      await AppStorage.write('usuario_nome', 'Fiscal (Mock)');
      await AppStorage.write('usuario_cpf', _digitsOnly(cpf));
      return cpf.trim().isNotEmpty && senha.trim().isNotEmpty;
    }
    await init();
    try {
      final baseUrl = _dio.options.baseUrl;
      final fullUrl = '${baseUrl.replaceAll(RegExp(r'/*$'), '')}/auth/login';
      // #region debug-point H2:login-request
      unawaited(
        _reportFrontendDebug(
          hypothesisId: 'H2',
          location: 'ApiService.login',
          msg: 'Efetuando login (request)',
          data: {
            'baseUrl': baseUrl,
            'url': fullUrl,
            'path': '/auth/login',
            'cpfLen': _digitsOnly(cpf).length,
          },
        ),
      );
      // #endregion
      final res = await _dio.post('/auth/login', data: {'cpf': cpf, 'senha': senha});
      // #region debug-point H2:login-response
      unawaited(
        _reportFrontendDebug(
          hypothesisId: 'H2',
          location: 'ApiService.login',
          msg: 'Login retornou response',
          data: {
            'status': res.statusCode ?? 0,
            'baseUrl': baseUrl,
            'url': fullUrl,
            'hasToken': (res.data is Map) && ((res.data['token'] ?? '').toString().trim().isNotEmpty),
            'dataType': res.data.runtimeType.toString(),
          },
        ),
      );
      // #endregion
      final token = res.data['token'] as String?;
      if (token != null) {
        await AppStorage.write('jwt_token', token);
        final user = res.data['user'];
        if (user is Map) {
          final nome = (user['nome'] ?? '').toString().trim();
          final cpfUser = (user['cpf'] ?? '').toString().trim();
          final id = (user['id'] ?? '').toString().trim();
          if (nome.isNotEmpty) await AppStorage.write('usuario_nome', nome);
          if (cpfUser.isNotEmpty) await AppStorage.write('usuario_cpf', _digitsOnly(cpfUser));
          if (id.isNotEmpty) await AppStorage.write('usuario_id', id);
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final baseUrl = _dio.options.baseUrl;
      final fullUrl = '${baseUrl.replaceAll(RegExp(r'/*$'), '')}/auth/login';
      final body = e.response?.data;
      final bodyPreview = body == null ? '' : body.toString();
      // #region debug-point H3:login-dio-exception
      unawaited(
        _reportFrontendDebug(
          hypothesisId: status == 404 ? 'H3' : 'H1',
          location: 'ApiService.login',
          msg: 'Login falhou (DioException)',
          data: {
            'status': status,
            'baseUrl': baseUrl,
            'url': fullUrl,
            'dioType': e.type.toString(),
            'error': (e.error ?? '').toString(),
            'bodyPreview': bodyPreview.length > 400 ? bodyPreview.substring(0, 400) : bodyPreview,
          },
        ),
      );
      // #endregion
      if (status == 401 || status == 403) return false;
      rethrow;
    }
  }

  Future<List<dynamic>> listarInspecoes() async {
    if (mockMode) {
      return [
        {'id': 1, 'tipo_auto': 'INT', 'estabelecimento_id': 1, 'data': '2026-03-20', 'hora': '09:30', 'status': 'PENDENTE'},
        {'id': 2, 'tipo_auto': 'INF', 'estabelecimento_id': 2, 'data': '2026-03-18', 'hora': '14:10', 'status': 'CONCLUÍDA'},
        {'id': 3, 'tipo_auto': 'COL', 'estabelecimento_id': 3, 'data': '2026-03-16', 'hora': '11:00', 'status': 'PENDENTE'},
      ];
    }
    await init();
    final res = await _dio.get('/inspecoes');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>?> criarInspecao({
    required String tipoAuto,
    required int estabelecimentoId,
    String? descricao,
  }) async {
    if (mockMode) {
      return {
        'id': 1,
        'tipoAuto': tipoAuto,
        'estabelecimentoId': estabelecimentoId,
        'descricao': descricao,
        'status': 'Pendente',
      };
    }
    await init();
    final payload = <String, dynamic>{
      'tipoAuto': tipoAuto,
      'estabelecimentoId': estabelecimentoId,
    };
    if (descricao != null && descricao.trim().isNotEmpty) {
      payload['descricao'] = descricao.trim();
    }
    final res = await _dio.post('/inspecoes', data: payload);
    if (res.statusCode == 201) return res.data as Map<String, dynamic>;
    return null;
  }

  Future<bool> enviarFotoInspecao({
    required int inspecaoId,
    required String url,
    required String data,
    double? gpsLatitude,
    double? gpsLongitude,
    String? dispositivo,
    String? resolucao,
  }) async {
    if (mockMode) return true;
    await init();
    final payload = <String, dynamic>{
      'url': url,
      'data': data,
    };
    if (gpsLatitude != null) payload['gpsLatitude'] = gpsLatitude;
    if (gpsLongitude != null) payload['gpsLongitude'] = gpsLongitude;
    if (dispositivo != null && dispositivo.trim().isNotEmpty) {
      payload['dispositivo'] = dispositivo.trim();
    }
    if (resolucao != null && resolucao.trim().isNotEmpty) {
      payload['resolucao'] = resolucao.trim();
    }
    final res = await _dio.post('/inspecoes/$inspecaoId/fotos', data: payload);
    return res.statusCode == 201;
  }

  Future<bool> salvarIntimacao({
    required int inspecaoId,
    required String descricaoIrregularidade,
    required String baseLegal,
    required String prazoRegularizacao,
    required String penalidadePrevista,
  }) async {
    if (mockMode) return true;
    await init();
    final payload = <String, dynamic>{
      'descricaoIrregularidade': descricaoIrregularidade,
      'baseLegal': baseLegal,
      'prazoRegularizacao': prazoRegularizacao,
      'penalidadePrevista': penalidadePrevista,
    };
    final res = await _dio.post('/inspecoes/$inspecaoId/intimacao', data: payload);
    return res.statusCode == 201;
  }

  Future<bool> enviarAssinaturaInspecao({
    required int inspecaoId,
    required String assinaturaFiscal,
    String? assinaturaResponsavel,
  }) async {
    if (mockMode) return true;
    await init();
    final payload = <String, dynamic>{
      'assinaturaFiscal': assinaturaFiscal,
    };
    if (assinaturaResponsavel != null && assinaturaResponsavel.trim().isNotEmpty) {
      payload['assinaturaResponsavel'] = assinaturaResponsavel.trim();
    }
    final res = await _dio.post('/inspecoes/$inspecaoId/assinatura', data: payload);
    return res.statusCode == 201;
  }

  Future<Map<String, dynamic>?> finalizarInspecao({
    required int inspecaoId,
  }) async {
    if (mockMode) {
      return {'id': inspecaoId, 'status': 'Enviado', 'pdfUrl': '/inspecoes/$inspecaoId/pdf'};
    }
    await init();
    final res = await _dio.post('/inspecoes/$inspecaoId/finalizar');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>> sincronizarComServidor() async {
    if (mockMode) {
      return {'sincronizados': 3, 'erros': 0};
    }
    await init();
    try {
      final res = await _dio.post('/api/integracoes/epublica/sync');
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return {'sincronizados': 0, 'erros': 1};
    }
  }

  Future<List<dynamic>> buscarEstabelecimentos(String q) async {
    if (mockMode) {
      final query = q.trim().toLowerCase();
      if (query.isEmpty) return List<Map<String, dynamic>>.from(_mockEstabelecimentos);
      final digits = _digitsOnly(query);
      return _mockEstabelecimentos.where((e) {
        final cnpj = (e['cnpj'] ?? '').toString();
        final nome = (e['nomeFantasia'] ?? e['nome_fantasia'] ?? e['nome'] ?? '').toString().toLowerCase();
        final razao = (e['razaoSocial'] ?? e['razao_social'] ?? '').toString().toLowerCase();
        if (digits.isNotEmpty && cnpj.contains(digits)) return true;
        return nome.contains(query) || razao.contains(query);
      }).toList();
    }
    await init();
    try {
      final res = await _dio.get('/api/estabelecimentos', queryParameters: {'search': q});
      final data = res.data;
      if (data is List) return data;
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code >= 500) {
        return [];
      }
      rethrow;
    }
  }

  Future<List<dynamic>> buscarEstabelecimentosEpublica(String q) async {
    if (mockMode) {
      return buscarEstabelecimentos(q);
    }
    await init();
    try {
      final res = await _dio.get('/api/estabelecimentos/epublica', queryParameters: {'search': q});
      final data = res.data;
      if (data is List) return data;
      return [];
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code >= 500) {
        return [];
      }
      rethrow;
    }
  }

  Future<List<dynamic>> listarAutoTermo({
    String? search,
    String? cnpj,
    String? tipoDocumento,
    String? status,
    String? dataInicio,
    String? dataFim,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/auto-termo',
      queryParameters: {
        'search': search,
        'cnpj': cnpj,
        'tipo_documento': tipoDocumento,
        'status': status,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarAutoInfracaoDocumentos({
    String? search,
    String? cnpj,
    String? status,
    String? dataInicio,
    String? dataFim,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/auto-infracao',
      queryParameters: {
        'search': search,
        'cnpj': cnpj,
        'status': status,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> salvarAutoTermo(Map<String, dynamic> payload) async {
    if (mockMode) return payload;
    await init();
    final res = await _dio.post('/api/auto-termo', data: payload);
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return payload;
  }

  Future<String?> proximoNumeroAutoInfracao(int ano) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/auto-infracao/next-numero', queryParameters: {'ano': ano});
    final data = res.data;
    if (data is Map) {
      final numero = (data['numero'] ?? '').toString().trim();
      return numero.isEmpty ? null : numero;
    }
    return null;
  }

  Future<String?> proximoNumeroAutoIntimacao(int ano) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/auto-intimacao/next-numero', queryParameters: {'ano': ano});
    final data = res.data;
    if (data is Map) {
      final numero = (data['numero'] ?? '').toString().trim();
      return numero.isEmpty ? null : numero;
    }
    return null;
  }

  Future<Map<String, dynamic>> salvarAutoInfracao({
    required int ano,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-infracao', data: {
      'ano': ano,
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> atualizarAutoInfracao({
    required int id,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.put('/api/auto-infracao/$id', data: {
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> finalizarAutoInfracao(int id) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-infracao/$id/finalizar');
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> marcarAutoInfracaoSemEfeito({
    required int id,
    required String motivo,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-infracao/$id/sem-efeito', data: {'motivo': motivo, 'dispositivo': dispositivo});
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<dynamic>> listarAutoInfracaoLogs(int id) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/auto-infracao/$id/logs');
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarAutoIntimacaoDocumentos({
    String? search,
    String? cnpj,
    String? status,
    String? dataInicio,
    String? dataFim,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/auto-intimacao',
      queryParameters: {
        'search': search,
        'cnpj': cnpj,
        'status': status,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> salvarAutoIntimacao({
    required int ano,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
    List<Map<String, dynamic>>? logs,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-intimacao', data: {
      'ano': ano,
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
      'logs': logs,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> atualizarAutoIntimacao({
    required int id,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
    List<Map<String, dynamic>>? logs,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.put('/api/auto-intimacao/$id', data: {
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
      'logs': logs,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> finalizarAutoIntimacao(int id) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-intimacao/$id/finalizar');
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> marcarAutoIntimacaoSemEfeito({
    required int id,
    required String motivo,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-intimacao/$id/sem-efeito', data: {'motivo': motivo, 'dispositivo': dispositivo});
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<dynamic>> listarAutoIntimacaoLogs(int id) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/auto-intimacao/$id/logs');
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarImposicaoPenalidadeDocumentos({
    String? search,
    String? cnpj,
    String? status,
    String? dataInicio,
    String? dataFim,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/imposicao-penalidade',
      queryParameters: {
        'search': search,
        'cnpj': cnpj,
        'status': status,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<String?> proximoNumeroImposicaoPenalidade(int ano) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/imposicao-penalidade/next-numero', queryParameters: {'ano': ano});
    final data = res.data;
    if (data is Map) {
      final numero = (data['numero'] ?? '').toString().trim();
      return numero.isEmpty ? null : numero;
    }
    return null;
  }

  Future<String?> proximoPasImposicaoPenalidade(int ano) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/imposicao-penalidade/next-pas', queryParameters: {'ano': ano});
    final data = res.data;
    if (data is Map) {
      final numero = (data['pas_numero'] ?? '').toString().trim();
      return numero.isEmpty ? null : numero;
    }
    return null;
  }

  Future<Map<String, dynamic>> salvarImposicaoPenalidade({
    required int ano,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/imposicao-penalidade', data: {
      'ano': ano,
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> atualizarImposicaoPenalidade({
    required int id,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.put('/api/imposicao-penalidade/$id', data: {
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<dynamic>> listarImposicaoPenalidadeLogs(int id) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/imposicao-penalidade/$id/logs');
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarAutoColetaAmostraDocumentos({
    String? search,
    String? cnpj,
    String? status,
    String? dataInicio,
    String? dataFim,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/auto-coleta',
      queryParameters: {
        'search': search,
        'cnpj': cnpj,
        'status': status,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<String?> proximoNumeroAutoColetaAmostra(int ano) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/auto-coleta/next-numero', queryParameters: {'ano': ano});
    final data = res.data;
    if (data is Map) {
      final numero = (data['numero'] ?? '').toString().trim();
      return numero.isEmpty ? null : numero;
    }
    return null;
  }

  Future<Map<String, dynamic>> salvarAutoColetaAmostra({
    required int ano,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/auto-coleta', data: {
      'ano': ano,
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> atualizarAutoColetaAmostra({
    required int id,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.put('/api/auto-coleta/$id', data: {
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<dynamic>> listarAutoColetaAmostraLogs(int id) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/auto-coleta/$id/logs');
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarRelatorioInspecaoDocumentos({
    String? search,
    String? cnpj,
    String? status,
    String? dataInicio,
    String? dataFim,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/relatorio-inspecao',
      queryParameters: {
        'search': search,
        'cnpj': cnpj,
        'status': status,
        'data_inicio': dataInicio,
        'data_fim': dataFim,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<String?> proximoNumeroRelatorioInspecao(int ano) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/relatorio-inspecao/next-numero', queryParameters: {'ano': ano});
    final data = res.data;
    if (data is Map) {
      final numero = (data['numero'] ?? '').toString().trim();
      return numero.isEmpty ? null : numero;
    }
    return null;
  }

  Future<Map<String, dynamic>> salvarRelatorioInspecao({
    required int ano,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.post('/api/relatorio-inspecao', data: {
      'ano': ano,
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> atualizarRelatorioInspecao({
    required int id,
    required String status,
    required Map<String, dynamic> dados,
    String? dispositivo,
  }) async {
    if (mockMode) return {};
    await init();
    final res = await _dio.put('/api/relatorio-inspecao/$id', data: {
      'status': status,
      'dados': dados,
      'dispositivo': dispositivo,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<List<dynamic>> listarRelatorioInspecaoLogs(int id) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/relatorio-inspecao/$id/logs');
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarBaseLegalGrupos() async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/base-legal/grupos');
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarBaseLegalSubgrupos(String grupoId) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/base-legal/subgrupos', queryParameters: {'grupoId': grupoId});
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> listarBaseLegalEntries({
    required String subgrupoId,
    String? search,
    int? limit,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/base-legal/entries',
      queryParameters: {
        'subgrupoId': subgrupoId,
        'search': search,
        'limit': limit,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<List<dynamic>> buscarBaseLegal({
    required String query,
    String? grupoId,
    String? subgrupoId,
    int? limit,
  }) async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get(
      '/api/base-legal/search',
      queryParameters: {
        'query': query,
        'grupoId': grupoId,
        'subgrupoId': subgrupoId,
        'limit': limit,
      },
    );
    final data = res.data;
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>?> buscarBaseLegalDetalhe(String id) async {
    if (mockMode) return null;
    await init();
    final res = await _dio.get('/api/base-legal/$id');
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> buscarEstabelecimentoPorCnpj(String cnpj) async {
    if (mockMode) {
      final digits = _digitsOnly(cnpj);
      for (final e in _mockEstabelecimentos) {
        if (_digitsOnly((e['cnpj'] ?? '').toString()) == digits) return Map<String, dynamic>.from(e);
      }
      if (digits.length != 14) return null;
      return {
        'cnpj': digits,
        'razaoSocial': 'Estabelecimento $digits',
        'razao_social': 'Estabelecimento $digits',
        'nomeFantasia': 'Novo Estabelecimento',
        'nome_fantasia': 'Novo Estabelecimento',
        'nome': 'Novo Estabelecimento',
        'logradouro': 'Rua Exemplo',
        'rua': 'Rua Exemplo',
        'numero': '0',
        'bairro': 'Centro',
        'cep': '88330000',
        'cidade': 'Balneário Camboriú',
        'municipio': 'Balneário Camboriú',
        'uf': 'SC',
        'estado': 'SC',
        'endereco': 'Rua Exemplo, 0 - Centro',
        'telefone': '(47) 99999-0000',
        'email': 'demo@exemplo.com',
        'responsavel': 'Responsável',
        'cpf_responsavel': '00000000000',
        'cnae': '0000000',
        'cnaeDescricao': 'Atividade não informada',
        'cnae_fiscal_descricao': 'Atividade não informada',
        'risco': 'Médio',
        'status_alvara': 'Regular',
        'status_sanitario': 'Regular',
        'grau_risco': 'Médio',
        'lat': -26.9900,
        'lng': -48.6350,
        'data_cadastro': DateTime.now().toIso8601String().substring(0, 10),
      };
    }
    await init();
    final digits = _digitsOnly(cnpj);
    // #region debug-point A:buscar-estabelecimento
    unawaited(
      _reportFrontendDebug(
        hypothesisId: 'A',
        location: 'api.dart:buscarEstabelecimentoPorCnpj',
        msg: '[DEBUG] Iniciando busca de estabelecimento por CNPJ',
        data: {'cnpj': digits},
      ),
    );
    // #endregion
    try {
      final res = await _dio.get('/api/estabelecimentos/cnpj/$digits');
      final data = res.data;
      // #region debug-point A:buscar-estabelecimento
      unawaited(
        _reportFrontendDebug(
          hypothesisId: 'A',
          location: 'api.dart:buscarEstabelecimentoPorCnpj',
          msg: '[DEBUG] Busca de estabelecimento concluida',
          data: {
            'cnpj': digits,
            'statusCode': res.statusCode,
            'dataTipo': data.runtimeType.toString(),
            'dataKeys': data is Map ? data.keys.take(12).toList() : const <String>[],
          },
        ),
      );
      // #endregion
      if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      // #region debug-point A:buscar-estabelecimento
      unawaited(
        _reportFrontendDebug(
          hypothesisId: 'A',
          location: 'api.dart:buscarEstabelecimentoPorCnpj',
          msg: '[DEBUG] Busca de estabelecimento falhou',
          data: {
            'cnpj': digits,
            'statusCode': code,
            'message': e.message,
          },
        ),
      );
      // #endregion
      if (code == 401) return null;
      return null;
    }
  }

  Future<Map<String, dynamic>?> buscarEstabelecimentoDetalhe(String cnpj) async {
    if (mockMode) return buscarEstabelecimentoPorCnpj(cnpj);
    await init();
    final digits = _digitsOnly(cnpj);
    if (digits.isEmpty) return null;
    // #region debug-point A:buscar-estabelecimento-detalhe
    unawaited(
      _reportFrontendDebug(
        hypothesisId: 'A',
        location: 'api.dart:buscarEstabelecimentoDetalhe',
        msg: '[DEBUG] Iniciando busca de detalhe de estabelecimento',
        data: {'cnpj': digits},
      ),
    );
    // #endregion
    try {
      final res = await _dio.get('/api/estabelecimentos/cnpj/$digits');
      final data = res.data;
      // #region debug-point A:buscar-estabelecimento-detalhe
      unawaited(
        _reportFrontendDebug(
          hypothesisId: 'A',
          location: 'api.dart:buscarEstabelecimentoDetalhe',
          msg: '[DEBUG] Busca de detalhe de estabelecimento concluida',
          data: {
            'cnpj': digits,
            'statusCode': res.statusCode,
            'dataTipo': data.runtimeType.toString(),
            'dataKeys': data is Map ? data.keys.take(12).toList() : const <String>[],
          },
        ),
      );
      // #endregion
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on DioException catch (e) {
      // #region debug-point A:buscar-estabelecimento-detalhe
      unawaited(
        _reportFrontendDebug(
          hypothesisId: 'A',
          location: 'api.dart:buscarEstabelecimentoDetalhe',
          msg: '[DEBUG] Busca de detalhe de estabelecimento falhou',
          data: {
            'cnpj': digits,
            'statusCode': e.response?.statusCode,
            'message': e.message,
          },
        ),
      );
      // #endregion
      return null;
    }
  }

  Future<Map<String, dynamic>?> atualizarEstabelecimentoLocal({
    required int estabelecimentoId,
    String? telefone,
    String? email,
    String? responsavelLocal,
    String? observacoes,
    double? latitude,
    double? longitude,
  }) async {
    if (mockMode) {
      return {
        'id': estabelecimentoId,
        'telefone': telefone,
        'email': email,
        'responsavel': responsavelLocal,
        'observacoes': observacoes,
        'latitude': latitude,
        'longitude': longitude,
      };
    }
    await init();
    final res = await _dio.put('/api/estabelecimentos/$estabelecimentoId', data: {
      'telefone': telefone,
      'email': email,
      'responsavel': responsavelLocal,
      'observacoes': observacoes,
      'latitude': latitude,
      'longitude': longitude,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>> importarDados(String type) async {
    if (mockMode) {
      switch (type) {
        case 'empresas':
          return {
            'success': true,
            'importados': 12,
            'atualizados': 3,
            'ignorados': 0,
            'erros': <String>[],
            'ultima_sincronizacao': DateTime.now().toIso8601String(),
          };
        case 'penalidades':
          return {
            'success': false,
            'message':
                'A API de Gestão de Tributos da e-Pública não possui endpoint específico para penalidades sanitárias. Utilize a base local do módulo Auto/Termo.',
            'importados': 0,
            'atualizados': 0,
            'ignorados': 0,
            'erros': <String>[],
            'ultima_sincronizacao': DateTime.now().toIso8601String(),
          };
        case 'autos':
          return {
            'success': false,
            'message':
                'A API de Gestão de Tributos da e-Pública não possui endpoint específico para autos sanitários externos.',
            'importados': 0,
            'atualizados': 0,
            'ignorados': 0,
            'erros': <String>[],
            'ultima_sincronizacao': DateTime.now().toIso8601String(),
          };
      }
      return {'success': false, 'message': 'Tipo de importação inválido.'};
    }
    await init();
    String endpoint;
    switch (type) {
      case 'empresas':
        endpoint = '/api/integracoes/epublica/importar-estabelecimentos';
        break;
      case 'penalidades':
        endpoint = '/api/integracoes/epublica/importar-penalidades';
        break;
      case 'autos':
        endpoint = '/api/integracoes/epublica/importar-autos-externos';
        break;
      default:
        throw ArgumentError('Tipo de importação inválido: $type');
    }
    final res = await _dio.post(endpoint);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importarEstabelecimentosEpublica() async {
    return importarDados('empresas');
  }

  Future<Map<String, dynamic>> importarPenalidadesEpublica() async {
    return importarDados('penalidades');
  }

  Future<Map<String, dynamic>> importarAutosExternosEpublica() async {
    return importarDados('autos');
  }

  Future<void> savePreference(String key, String value) async {
    await AppStorage.write(key, value);
  }

  Future<String?> readPreference(String key) async {
    return AppStorage.read(key);
  }

  Future<Map<String, dynamic>> buscarMapaSanitario() async {
    if (mockMode) {
      return {'estabelecimentos': _mockEstabelecimentos};
    }
    await init();
    final res = await _dio.get('/api/mapa-sanitario');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> buscarPerfilSanitario() async {
    if (mockMode) return {'perfis': []};
    await init();
    final res = await _dio.get('/api/perfil-sanitario');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<dynamic>> buscarAlvaras() async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/alvaras');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> buscarHabiteSe() async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/habite-se');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> buscarProfissionais() async {
    if (mockMode) return [];
    await init();
    final res = await _dio.get('/api/profissionais');
    return res.data as List<dynamic>;
  }

  Future<Map<String, int>> buscarEstatisticas() async {
    if (mockMode) {
      return {
        'inspecoes': 12,
        'autos': 4,
        'estabelecimentos': _mockEstabelecimentos.length,
        'pendentes': 2,
      };
    }
    await init();
    final res = await _dio.get('/api/estatisticas');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
    return {};
  }

  Future<Map<String, dynamic>> criarHabiteSe(Map<String, dynamic> payload) async {
    if (mockMode) return {'id': 1, ...payload};
    await init();
    final res = await _dio.post('/api/habite-se', data: payload);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> criarProfissional(Map<String, dynamic> payload) async {
    if (mockMode) return {'id': 1, ...payload};
    await init();
    final res = await _dio.post('/api/profissionais', data: payload);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> atualizarProfissional(int id, Map<String, dynamic> payload) async {
    if (mockMode) return {'id': id, ...payload};
    await init();
    final res = await _dio.put('/api/profissionais/$id', data: payload);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
