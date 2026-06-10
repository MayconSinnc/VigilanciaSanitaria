import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'app_storage.dart';

class BaseLegalGrupo {
  const BaseLegalGrupo({required this.id, required this.descricao});

  final String id;
  final String descricao;

  String get codigoDescricao => descricao;

  factory BaseLegalGrupo.fromJson(Map<String, dynamic> json) {
    return BaseLegalGrupo(
      id: (json['id'] ?? '').toString(),
      descricao: (json['descricao'] ?? '').toString(),
    );
  }
}

class BaseLegalSubgrupo {
  const BaseLegalSubgrupo({required this.id, required this.grupoId, required this.descricao});

  final String id;
  final String grupoId;
  final String descricao;

  String get codigoDescricao => descricao;

  factory BaseLegalSubgrupo.fromJson(Map<String, dynamic> json) {
    return BaseLegalSubgrupo(
      id: (json['id'] ?? '').toString(),
      grupoId: (json['grupo_id'] ?? json['grupoId'] ?? '').toString(),
      descricao: (json['descricao'] ?? '').toString(),
    );
  }
}

class BaseLegalEntry {
  const BaseLegalEntry({
    required this.id,
    required this.normaId,
    required this.grupoId,
    required this.grupoDescricao,
    required this.subgrupoId,
    required this.subgrupoDescricao,
    required this.tipoNorma,
    required this.esfera,
    required this.numeroNorma,
    required this.anoNorma,
    required this.situacao,
    required this.ementa,
    required this.observacoes,
    required this.baseLegalHtml,
    required this.artigo,
    required this.complemento,
    required this.inciso,
    required this.paragrafo,
    required this.descricao,
    required this.score,
    this.descricaoItem,
    this.palavrasChave,
    this.sinonimos,
    this.prazoPadraoDias,
    this.aplicaAutoIntimacao,
    this.descricaoIrregularidade,
    this.descricaoProvidencia,
  });

  final String id;
  final String normaId;
  final String? grupoId;
  final String? grupoDescricao;
  final String? subgrupoId;
  final String? subgrupoDescricao;
  final String? tipoNorma;
  final String? esfera;
  final String? numeroNorma;
  final int? anoNorma;
  final String? situacao;
  final String? ementa;
  final String? observacoes;
  final String? baseLegalHtml;
  final String? artigo;
  final String? complemento;
  final String? inciso;
  final String? paragrafo;
  final String? descricao;
  final int? score;
  final String? descricaoItem;
  final List<String>? palavrasChave;
  final List<String>? sinonimos;
  final int? prazoPadraoDias;
  final bool? aplicaAutoIntimacao;
  final String? descricaoIrregularidade;
  final String? descricaoProvidencia;

  String get normaTitulo {
    final parts = <String>[];
    if (tipoNorma != null && tipoNorma!.trim().isNotEmpty) parts.add(tipoNorma!.trim());
    final numeroAno = [
      if (numeroNorma != null && numeroNorma!.trim().isNotEmpty) numeroNorma!.trim(),
      if (anoNorma != null) anoNorma.toString(),
    ].where((e) => e.trim().isNotEmpty).join('/');
    if (numeroAno.isNotEmpty) parts.add(numeroAno);
    if (esfera != null && esfera!.trim().isNotEmpty) parts.add('(${esfera!.trim()})');
    return parts.join(' ');
  }

  String get grupoResumo {
    final g = (grupoDescricao ?? '').trim();
    final s = (subgrupoDescricao ?? '').trim();
    if (g.isEmpty && s.isEmpty) return '';
    if (g.isEmpty) return s;
    if (s.isEmpty) return g;
    return '$g > $s';
  }

  factory BaseLegalEntry.fromJson(Map<String, dynamic> json) {
    List<String>? parseList(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      return null;
    }

    return BaseLegalEntry(
      id: (json['id'] ?? '').toString(),
      normaId: (json['normaId'] ?? json['norma_id'] ?? '').toString(),
      grupoId: (json['grupoId'] ?? json['grupo_id'])?.toString(),
      grupoDescricao: (json['grupoDescricao'] ?? json['grupo_descricao'])?.toString(),
      subgrupoId: (json['subgrupoId'] ?? json['subgrupo_id'])?.toString(),
      subgrupoDescricao: (json['subgrupoDescricao'] ?? json['subgrupo_descricao'])?.toString(),
      tipoNorma: (json['tipoNorma'] ?? json['tipo'])?.toString(),
      esfera: (json['esfera'])?.toString(),
      numeroNorma: (json['numeroNorma'] ?? json['numero'])?.toString(),
      anoNorma: (json['anoNorma'] as num?)?.toInt() ?? (json['ano'] as num?)?.toInt(),
      situacao: (json['situacao'])?.toString(),
      ementa: (json['ementa'])?.toString(),
      observacoes: (json['observacoes'])?.toString(),
      baseLegalHtml: (json['baseLegalHtml'] ?? json['baseLegalHTML'] ?? json['base_legal_html'])?.toString(),
      artigo: (json['artigo'] ?? json['artigo_numero'])?.toString(),
      complemento: (json['complemento'] ?? json['artigo_complemento'])?.toString(),
      inciso: (json['inciso'] ?? json['artigo_inciso'])?.toString(),
      paragrafo: (json['paragrafo'] ?? json['artigo_paragrafo'])?.toString(),
      descricao: (json['descricao'] ?? json['artigo_descricao'])?.toString(),
      score: (json['score'] as num?)?.toInt(),
      descricaoItem: (json['descricaoItem'] ?? json['descricao_item'])?.toString(),
      palavrasChave: parseList(json['palavrasChave'] ?? json['palavras_chave']),
      sinonimos: parseList(json['sinonimos']),
      prazoPadraoDias: (json['prazoPadraoDias'] as num?)?.toInt() ?? (json['prazo_padrao_dias'] as num?)?.toInt(),
      aplicaAutoIntimacao: (json['aplicaAutoIntimacao'] as bool?) ?? (json['aplica_auto_intimacao'] as bool?),
      descricaoIrregularidade: (json['descricaoIrregularidade'] ?? json['descricao_irregularidade'])?.toString(),
      descricaoProvidencia: (json['descricaoProvidencia'] ?? json['descricao_providencia'])?.toString(),
    );
  }

  Map<String, dynamic> toVinculoJson() {
    return {
      'id': id,
      'norma_id': normaId,
      'grupo_id': grupoId,
      'grupo_descricao': grupoDescricao,
      'subgrupo_id': subgrupoId,
      'subgrupo_descricao': subgrupoDescricao,
      'tipo': tipoNorma,
      'esfera': esfera,
      'numero': numeroNorma,
      'ano': anoNorma,
      'ementa': ementa,
      'observacoes': observacoes,
      'artigo': artigo,
      'complemento': complemento,
      'inciso': inciso,
      'paragrafo': paragrafo,
      'descricao': descricao,
    };
  }
}

class BaseLegalRepository {
  BaseLegalRepository({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const _cacheGruposKey = 'base_legal_grupos_cache_v1';
  static const _cacheSubgruposPrefix = 'base_legal_subgrupos_cache_v1_';
  static const _cacheEntriesPrefix = 'base_legal_entries_cache_v1_';
  static const _cacheSmartPrefix = 'base_legal_smart_cache_v1_';
  static const _cacheDetailPrefix = 'base_legal_detail_cache_v1_';
  static const _cacheLastSyncKey = 'base_legal_last_sync_v1';

  final ValueNotifier<bool> offlineMode = ValueNotifier(false);

  String _encodeKeyPart(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'all';
    return base64UrlEncode(utf8.encode(v)).replaceAll('=', '');
  }

  Future<void> _markOnline() async {
    if (offlineMode.value) offlineMode.value = false;
    await AppStorage.write(_cacheLastSyncKey, DateTime.now().toIso8601String());
  }

  void _markOffline() {
    if (!offlineMode.value) offlineMode.value = true;
  }

  bool _shouldMarkOffline(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  Future<List<BaseLegalGrupo>> listarGrupos({bool allowCache = true}) async {
    try {
      final res = await _api.listarBaseLegalGrupos();
      final grupos = res.map((e) => BaseLegalGrupo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      await AppStorage.write(_cacheGruposKey, jsonEncode(res));
      await _markOnline();
      return grupos;
    } on DioException catch (err) {
      if (!allowCache) rethrow;
      final cached = await AppStorage.read(_cacheGruposKey);
      if (cached == null || cached.trim().isEmpty) rethrow;
      final list = jsonDecode(cached);
      if (list is! List) rethrow;
      if (_shouldMarkOffline(err)) _markOffline();
      return list.map((e) => BaseLegalGrupo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
  }

  Future<List<BaseLegalSubgrupo>> listarSubgrupos(String grupoId, {bool allowCache = true}) async {
    final cacheKey = '$_cacheSubgruposPrefix$grupoId';
    try {
      final res = await _api.listarBaseLegalSubgrupos(grupoId);
      final sub = res.map((e) => BaseLegalSubgrupo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      await AppStorage.write(cacheKey, jsonEncode(res));
      await _markOnline();
      return sub;
    } on DioException catch (err) {
      if (!allowCache) rethrow;
      final cached = await AppStorage.read(cacheKey);
      if (cached == null || cached.trim().isEmpty) rethrow;
      final list = jsonDecode(cached);
      if (list is! List) rethrow;
      if (_shouldMarkOffline(err)) _markOffline();
      return list.map((e) => BaseLegalSubgrupo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
  }

  Future<List<BaseLegalEntry>> listarEntriesPorSubgrupo({
    required String subgrupoId,
    String? search,
    int? limit,
    bool allowCache = true,
  }) async {
    final cacheKey = '$_cacheEntriesPrefix${subgrupoId}_${_encodeKeyPart(search)}_${limit ?? 'n'}';
    try {
      final res = await _api.listarBaseLegalEntries(subgrupoId: subgrupoId, search: search, limit: limit);
      await AppStorage.write(cacheKey, jsonEncode(res));
      await _markOnline();
      return res.map((e) => BaseLegalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on DioException catch (err) {
      if (!allowCache) rethrow;
      final cached = await AppStorage.read(cacheKey);
      if (cached == null || cached.trim().isEmpty) rethrow;
      final list = jsonDecode(cached);
      if (list is! List) rethrow;
      if (_shouldMarkOffline(err)) _markOffline();
      return list.map((e) => BaseLegalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
  }

  Future<List<BaseLegalEntry>> buscarInteligente({
    required String query,
    String? grupoId,
    String? subgrupoId,
    int? limit,
    bool allowCache = true,
  }) async {
    final cacheKey =
        '$_cacheSmartPrefix${_encodeKeyPart(query)}_${grupoId ?? 'g'}_${subgrupoId ?? 's'}_${limit ?? 'n'}';
    try {
      final res = await _api.buscarBaseLegal(query: query, grupoId: grupoId, subgrupoId: subgrupoId, limit: limit);
      await AppStorage.write(cacheKey, jsonEncode(res));
      await _markOnline();
      return res.map((e) => BaseLegalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on DioException catch (err) {
      if (!allowCache) rethrow;
      final cached = await AppStorage.read(cacheKey);
      if (cached == null || cached.trim().isEmpty) rethrow;
      final list = jsonDecode(cached);
      if (list is! List) rethrow;
      if (_shouldMarkOffline(err)) _markOffline();
      return list.map((e) => BaseLegalEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
  }

  Future<BaseLegalEntry?> buscarDetalhe(String id, {bool allowCache = true}) async {
    final cacheKey = '$_cacheDetailPrefix$id';
    try {
      final json = await _api.buscarBaseLegalDetalhe(id);
      if (json == null) return null;
      await AppStorage.write(cacheKey, jsonEncode(json));
      await _markOnline();
      return BaseLegalEntry.fromJson(json);
    } on DioException catch (err) {
      if (!allowCache) rethrow;
      final cached = await AppStorage.read(cacheKey);
      if (cached == null || cached.trim().isEmpty) rethrow;
      final data = jsonDecode(cached);
      if (data is! Map) rethrow;
      if (_shouldMarkOffline(err)) _markOffline();
      return BaseLegalEntry.fromJson(Map<String, dynamic>.from(data));
    }
  }

  Future<String?> getUltimaSincronizacao() async {
    return AppStorage.read(_cacheLastSyncKey);
  }
}
