import 'package:dio/dio.dart';
import 'api_base_url.dart';
import 'app_storage.dart';

class ApiService {
  static const bool mockMode = bool.fromEnvironment('MOCK_MODE', defaultValue: false);

  final Dio _dio = Dio();

  String _baseUrl = resolveDefaultApiBaseUrl();
  static String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

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
    _dio.options.sendTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    if (!_initialized) {
      _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
        final token = await AppStorage.read('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
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
      return cpf.trim().isNotEmpty && senha.trim().isNotEmpty;
    }
    await init();
    try {
      final res = await _dio.post('/auth/login', data: {'cpf': cpf, 'senha': senha});
      final token = res.data['token'] as String?;
      if (token != null) {
        await AppStorage.write('jwt_token', token);
        return true;
      }
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
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

  Future<Map<String, dynamic>> salvarAutoTermo(Map<String, dynamic> payload) async {
    if (mockMode) return payload;
    await init();
    final res = await _dio.post('/api/auto-termo', data: payload);
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return payload;
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
    bool isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty);
    Map<String, dynamic> mergeWithFallback(Map<String, dynamic> primary, Map<String, dynamic> fallback) {
      final merged = Map<String, dynamic>.from(primary);
      final keys = [
        'razaoSocial',
        'razao_social',
        'inscricaoMunicipal',
        'inscricao_municipal',
        'nomeFantasia',
        'nome_fantasia',
        'nome',
        'endereco',
        'logradouro',
        'numero',
        'bairro',
        'cep',
        'cidade',
        'municipio',
        'estado',
        'uf',
        'telefone',
        'email',
        'responsavel',
        'cpf_responsavel',
        'cpfResponsavel',
        'cnae',
        'cnaeDescricao',
        'cnae_fiscal_descricao',
      ];
      for (final k in keys) {
        if (merged.containsKey(k) && !isBlank(merged[k])) continue;
        if (!fallback.containsKey(k)) continue;
        if (isBlank(fallback[k])) continue;
        merged[k] = fallback[k];
      }
      if (!merged.containsKey('cnpj') || isBlank(merged['cnpj'])) merged['cnpj'] = fallback['cnpj'];
      return merged;
    }
    try {
      final res0 = await _dio.get('/api/estabelecimentos/cnpj/$digits');
      final data0 = res0.data;
      if (data0 is Map<String, dynamic>) {
        final shouldEnrich =
            isBlank(data0['razaoSocial']) ||
            isBlank(data0['razao_social']) ||
            isBlank(data0['endereco']) ||
            isBlank(data0['logradouro']) ||
            isBlank(data0['cidade']) ||
            isBlank(data0['municipio']) ||
            isBlank(data0['estado']) ||
            isBlank(data0['uf']);
        if (!shouldEnrich) return data0;
        try {
          final res1 = await _dio.get('/api/cnpj/$digits');
          final data1 = res1.data;
          if (data1 is Map<String, dynamic>) return mergeWithFallback(data0, data1);
        } on DioException {
          return data0;
        }
        return data0;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401) return null;
    }

    try {
      final res = await _dio.get('/api/cnpj/$digits');
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401) return null;
      if (code == 404) {
        try {
          final res2 = await _dio.get('/cnpj/$digits');
          final data2 = res2.data;
          if (data2 is Map<String, dynamic>) return data2;
          return null;
        } on DioException {
          return null;
        }
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> buscarEstabelecimentoDetalhe(String cnpj) async {
    if (mockMode) return buscarEstabelecimentoPorCnpj(cnpj);
    await init();
    final digits = _digitsOnly(cnpj);
    if (digits.isEmpty) return null;
    try {
      final res = await _dio.get('/api/estabelecimentos/cnpj/$digits');
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on DioException {
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
