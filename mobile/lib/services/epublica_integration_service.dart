import 'package:dio/dio.dart';

import 'api.dart';

class ImportResult {
  const ImportResult({
    required this.success,
    required this.importados,
    required this.atualizados,
    required this.ignorados,
    required this.erros,
    this.ultimaSincronizacao,
    this.message,
  });

  final bool success;
  final int importados;
  final int atualizados;
  final int ignorados;
  final List<String> erros;
  final String? ultimaSincronizacao;
  final String? message;

  bool get hasErrors => erros.isNotEmpty;

  bool get hasWarnings => success && erros.isNotEmpty;

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    final errosRaw = json['erros'];
    final erros = <String>[];
    if (errosRaw is List) {
      for (final item in errosRaw) {
        if (item is String) {
          erros.add(item);
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final mensagem = (map['mensagem'] ?? map['message'] ?? '').toString().trim();
          final referencia = (map['item'] ?? '').toString().trim();
          if (mensagem.isEmpty) continue;
          erros.add(referencia.isEmpty ? mensagem : '$referencia: $mensagem');
        }
      }
    }

    return ImportResult(
      success: json['success'] == true,
      importados: (json['importados'] as num?)?.toInt() ?? 0,
      atualizados: (json['atualizados'] as num?)?.toInt() ?? 0,
      ignorados: (json['ignorados'] as num?)?.toInt() ?? 0,
      erros: erros,
      ultimaSincronizacao: json['ultima_sincronizacao']?.toString(),
      message: json['message']?.toString(),
    );
  }

  factory ImportResult.failure(String message) {
    return ImportResult(
      success: false,
      importados: 0,
      atualizados: 0,
      ignorados: 0,
      erros: const [],
      message: message,
      ultimaSincronizacao: null,
    );
  }
}

class EpublicaIntegrationService {
  EpublicaIntegrationService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<ImportResult> importarEstabelecimentos() async {
    return _execute(_apiService.importarEstabelecimentosEpublica);
  }

  Future<ImportResult> importarPenalidades() async {
    return _execute(_apiService.importarPenalidadesEpublica);
  }

  Future<ImportResult> importarAutosExternos() async {
    return _execute(_apiService.importarAutosExternosEpublica);
  }

  Future<ImportResult> _execute(Future<Map<String, dynamic>> Function() request) async {
    try {
      final json = await request();
      return ImportResult.fromJson(json);
    } on DioException catch (err) {
      return ImportResult.failure(_mapDioError(err));
    } catch (_) {
      return ImportResult.failure('Não foi possível conectar ao backend.');
    }
  }

  String _mapDioError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return 'Não foi possível conectar ao backend.';
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        final data = err.response?.data;
        String backendMessage = '';
        if (data is Map) {
          backendMessage = ((data['message'] ?? data['error']) ?? '').toString();
        }
        final normalized = backendMessage.toLowerCase();
        if (status == 401 || status == 403 || normalized.contains('autenticação')) {
          return 'Erro de autenticação com a e-Pública.';
        }
        if (status == 404 || normalized.contains('não possui este endpoint')) {
          return 'A API da e-Pública não possui este endpoint.';
        }
        if (normalized.contains('nenhum dado encontrado')) {
          return 'Nenhum dado encontrado para importação.';
        }
        if (backendMessage.isNotEmpty) {
          return backendMessage;
        }
        if (status >= 500) {
          return 'Não foi possível conectar ao backend.';
        }
        return 'Não foi possível concluir a importação.';
      case DioExceptionType.cancel:
        return 'Importação cancelada.';
      case DioExceptionType.badCertificate:
        return 'Não foi possível conectar ao backend.';
    }
  }
}
