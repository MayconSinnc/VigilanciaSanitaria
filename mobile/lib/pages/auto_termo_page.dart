import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/api.dart';
import '../services/app_storage.dart';
import '../services/base_legal_repository.dart';
import '../services/pdf_generator_service.dart';
import '../storage/db.dart';
import '../widgets/app_drawer.dart';
import '../widgets/inspection_widgets.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/official_form_fields.dart';
import 'pdf_bytes_preview_page.dart';

const Color _govBlue = Color(0xFF1351B4);
const Color _lightBg = Color(0xFFF8FAFC);
const Color _darkText = Color(0xFF2C3E50);
const Color _statusGreen = Color(0xFF27AE60);
const Color _statusOrange = Color(0xFFF39C12);
const Color _statusRed = Color(0xFFE74C3C);

class AutoTermoPage extends StatefulWidget {
  const AutoTermoPage({
    super.key,
    this.initialBasesLegaisVinculadas,
    this.initialTipoDocumento,
    this.initialEstabelecimento,
    this.autoSyncOnOpen = false,
    this.autoSyncPopOnFinish = false,
  });

  final List<Map<String, dynamic>>? initialBasesLegaisVinculadas;
  final String? initialTipoDocumento;
  final Map<String, dynamic>? initialEstabelecimento;
  final bool autoSyncOnOpen;
  final bool autoSyncPopOnFinish;

  @override
  State<AutoTermoPage> createState() => _AutoTermoPageState();
}

class _AutoTermoPageState extends State<AutoTermoPage> {
  final ApiService _api = ApiService();
  final BaseLegalRepository _baseLegalRepo = BaseLegalRepository();
  static const String _debugServerUrl = 'http://127.0.0.1:7777/event';
  static const String _debugSessionId = 'sync-never-finishes';
  static const bool _debugReportingEnabled = bool.fromEnvironment('DEBUG_REPORT', defaultValue: false);

  final ValueNotifier<int> _formRebuildTick = ValueNotifier<int>(0);
  String _usuarioNomeLogado = '';

  Future<void> _debugReport({
    required String hypothesisId,
    required String location,
    required String msg,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) async {
    if (!_debugReportingEnabled) return;
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
          'sessionId': _debugSessionId,
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

  void _touchFormRebuild() {
    _formRebuildTick.value += 1;
  }

  void _formSetState(VoidCallback fn) {
    setState(fn);
    _touchFormRebuild();
  }

  final _searchCtrl = TextEditingController();
  final _estabSearchCtrl = TextEditingController();
  final _anoCtrl = TextEditingController(text: DateTime.now().year.toString());
  final _dataHoraCtrl = TextEditingController();
  final _tipoDocumentoLabelCtrl = TextEditingController();
  final _nomeFantasiaCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _inscricaoMunicipalCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _responsavelLegalCtrl = TextEditingController();
  final _numeroPastaVisaCtrl = TextEditingController();
  final _responsavelTecnicoCtrl = TextEditingController();
  final _testemunha1Ctrl = TextEditingController();
  final _testemunha2Ctrl = TextEditingController();
  final _profissionalCtrl = TextEditingController();
  final _baseLegalCtrl = TextEditingController();
  final _enquadramentoLegalCtrl = TextEditingController();
  final _artigoCtrl = TextEditingController();
  final _incisoCtrl = TextEditingController();
  final _paragrafoCtrl = TextEditingController();
  final _observacoesLegaisCtrl = TextEditingController();
  final _descricaoIrregularidadesCtrl = TextEditingController();
  final _descricaoProvidenciasCtrl = TextEditingController();
  final _prazoCumprimentoTextoCtrl = TextEditingController();
  final _prazoCumprimentoDataCtrl = TextEditingController();
  final _prazoCumprimentoDiasCtrl = TextEditingController();
  final _vencimentoPrazoCtrl = TextEditingController();
  final _itensReferenciaCtrl = TextEditingController();
  final _prazoExigenciaReferenciaCtrl = TextEditingController();
  final _prazoExigenciaDiasCtrl = TextEditingController();
  final _prazoExigenciaVencimentoCtrl = TextEditingController();
  final _comentarioFiscalizacaoCtrl = TextEditingController();
  final _especificacaoAtoCtrl = TextEditingController();
  final _departamentoCtrl = TextEditingController();
  final _dataLavraturaCtrl = TextEditingController();
  final _telefoneVisaCtrl = TextEditingController();
  final _emailVisaCtrl = TextEditingController();
  final _semEfeitoMotivoCtrl = TextEditingController();
  final _anoRelacionadoCtrl = TextEditingController();
  final _documentoRelacionadoCtrl = TextEditingController();
  final _dataRecebimentoCtrl = TextEditingController();
  final _autuadoNomeCtrl = TextEditingController();
  final _autuadoCpfCnpjCtrl = TextEditingController();
  final _autuadoNomeFantasiaCtrl = TextEditingController();
  final _autuadoEnderecoCompletoCtrl = TextEditingController();
  final _autuadoNumeroCtrl = TextEditingController();
  final _autuadoBairroCtrl = TextEditingController();
  final _autuadoMunicipioCtrl = TextEditingController(text: 'Balneário Camboriú');
  final _autuadoUfCtrl = TextEditingController(text: 'SC');
  final _autuadoProprietarioCtrl = TextEditingController();
  final _autuadoTipoAtividadeCtrl = TextEditingController();
  final _autuadoAlvaraCtrl = TextEditingController();
  final _recebimentoDataCtrl = TextEditingController();
  final _recebimentoHoraCtrl = TextEditingController();
  final _recebimentoResponsavelCtrl = TextEditingController();
  final _testemunha1RecusaCtrl = TextEditingController();
  final _testemunha2RecusaCtrl = TextEditingController();
  final _autoridadeSaudeCtrl = TextEditingController();
  final _autoridadeFuncaoCtrl = TextEditingController();
  final _tipoAmostraCtrl = TextEditingController();
  final _situacaoEncontradaCtrl = TextEditingController();
  final _observacoesInspecaoCtrl = TextEditingController();
  final _profissionalEquipeCtrl = TextEditingController();
  final _funcaoEquipeCtrl = TextEditingController();

  final _dadosFormKey = GlobalKey<FormState>();
  final _baseLegalFormKey = GlobalKey<FormState>();
  final _descricaoFormKey = GlobalKey<FormState>();
  final _autuadoFormKey = GlobalKey<FormState>();
  final _irregularidadesFormKey = GlobalKey<FormState>();
  final _providenciasPrazoFormKey = GlobalKey<FormState>();
  final _recebimentoAssinaturasFormKey = GlobalKey<FormState>();
  final _tipoDocumentoFormKey = GlobalKey<FormState>();
  final _inspecaoFormKey = GlobalKey<FormState>();
  final _profissionaisFormKey = GlobalKey<FormState>();
  final _reviewFormKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _documentos = [];
  List<Map<String, dynamic>> _documentosFiltrados = [];
  List<Map<String, dynamic>> _estabResults = [];
  List<Map<String, dynamic>> _vinculosRelacionados = [];
  List<Map<String, dynamic>> _autosIntimacaoRelacionados = [];
  List<Map<String, dynamic>> _profissionaisEquipe = [];
  List<Map<String, dynamic>> _basesLegaisVinculadas = [];
  List<Map<String, dynamic>> _prazosExigencias = [];
  List<Map<String, dynamic>> _itensReferencia = [];
  List<Map<String, dynamic>> _cnaesAutuado = [];
  List<String> _prazoExigenciaBaseLegalIds = [];
  bool? _infracaoDesejaImportarIntimacao;
  List<Map<String, dynamic>> _infracaoIntimacoesSelecionadas = [];

  String _tipoAtividadeUltimoAuto = '';

  bool _loadingList = true;
  bool _saving = false;
  bool _syncingPendentes = false;
  bool _estabLoading = false;
  bool _maisFiltrosExpandidos = false;
  String? _estabError;
  String? _listError;
  int _currentStep = 0;
  String? _numeroAutoIntimacao;
  String? _numeroAutoInfracao;
  int? _autoIntimacaoIdOnline;
  int? _autoInfracaoIdOnline;
  bool _semEfeito = false;
  bool _responsavelRecusouAssinatura = false;
  String _statusDocumento = 'EM_EDICAO';
  bool _documentoBloqueado = false;
  bool _possuiPastaVisa = false;
  Uint8List? _assinaturaRecebimento;
  Uint8List? _assinaturaTestemunha1;
  Uint8List? _assinaturaTestemunha2;
  Uint8List? _assinaturaAutoridadeSaude;
  List<_AutoridadeSaudeItem> _autoridadesSaude = [];
  final Map<String, String> _auditLastValue = {};
  final List<Map<String, dynamic>> _auditLogs = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime? _filtroDataInicio;
  DateTime? _filtroDataFim;
  int? _estabelecimentoId;
  Map<String, dynamic>? _estabelecimentoSelecionado;
  String _statusFiltro = 'Todos';
  String _tipoFiltro = 'Todos';
  String? _tipoDocumento;
  String _departamento = _departamentos.first;
  String _tipoAmostra = _tiposAmostra.first;
  @override
  void initState() {
    super.initState();
    _tipoDocumentoLabelCtrl.text = _tipoDocumentoLabel;
    final initBases = widget.initialBasesLegaisVinculadas ?? const [];
    if (initBases.isNotEmpty) {
      final seen = <String>{};
      _basesLegaisVinculadas = [
        for (final v in initBases)
          if (seen.add(((v['id'] ?? '').toString().trim())))
            if (((v['id'] ?? '').toString().trim()).isNotEmpty) Map<String, dynamic>.from(v),
      ];
    }
    _syncDateTimeFields();
    _prefillUsuarioLogado();
    _ensureAutoridadeInicial();
    _loadDocumentos();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initTipo = widget.initialTipoDocumento?.trim();
      if (initTipo != null && initTipo.isNotEmpty) {
        unawaited(_onTipoDocumentoChanged(initTipo));
      }
      final estab = widget.initialEstabelecimento;
      if (estab != null && estab.isNotEmpty) {
        _selecionarEstabelecimento(estab);
      }
      if (widget.autoSyncOnOpen) {
        unawaited(() async {
          final outcome = await _sincronizarPendentesSinnc(
            showSnackbar: !widget.autoSyncPopOnFinish,
            reloadAfter: !widget.autoSyncPopOnFinish,
          );
          if (!mounted) return;
          if (widget.autoSyncPopOnFinish) {
            Navigator.of(context).pop(outcome);
          }
        }());
      }
    });
  }

  void _ensureAutoridadeInicial() {
    if (_autoridadesSaude.isNotEmpty) return;
    _autoridadesSaude.add(_AutoridadeSaudeItem());
  }

  Future<void> _prefillUsuarioLogado() async {
    try {
      final nome = (await _api.readPreference('usuario_nome'))?.trim() ?? '';
      if (!mounted) return;
      if (nome.isEmpty) return;
      _usuarioNomeLogado = nome;
      _formSetState(() {
        _responsavelTecnicoCtrl.text = nome;
        if (_profissionalCtrl.text.trim().isEmpty) _profissionalCtrl.text = nome;
      });
    } catch (_) {}
  }

  Future<void> _prefillDadosVisa() async {
    try {
      final setor = (await _api.readPreference('visa_setor'))?.trim() ?? '';
      final telefone = (await _api.readPreference('visa_telefone'))?.trim() ?? '';
      final email = (await _api.readPreference('visa_email'))?.trim() ?? '';
      if (!mounted) return;

      setState(() {
        final normalizedSetor = setor.isNotEmpty ? setor : _departamento;
        if (_departamentos.contains(normalizedSetor)) {
          _departamento = normalizedSetor;
        }
        if (_telefoneVisaCtrl.text.trim().isEmpty) {
          _telefoneVisaCtrl.text = telefone.isNotEmpty ? telefone : '(47) 3261-6256';
        }
        if (_emailVisaCtrl.text.trim().isEmpty) {
          _emailVisaCtrl.text = email.isNotEmpty ? email : 'alimentos.devs@bc.sc.gov.br';
        }
      });
    } catch (_) {}
  }

  Future<void> _prefillBasesPadraoAutoInfracao() async {
    if (_tipoDocumento != _tipoAutoInfracao) return;
    try {
      final id1 = (await _api.readPreference('infracao_base_padrao_1_id'))?.trim() ?? '';
      final id2 = (await _api.readPreference('infracao_base_padrao_2_id'))?.trim() ?? '';
      final ids = [id1, id2].where((e) => e.isNotEmpty).toList();
      if (ids.isEmpty) return;

      final bases = <Map<String, dynamic>>[];
      for (final id in ids) {
        final detalhe = await _api.buscarBaseLegalDetalhe(id);
        if (detalhe == null) continue;
        final m = Map<String, dynamic>.from(detalhe);
        m['origem_tipo'] = 'PADRAO';
        bases.add(m);
      }
      if (!mounted || bases.isEmpty) return;
      _formSetState(() {
        for (final b in bases) {
          _mergeBaseLegalInfracao(b);
        }
      });
    } catch (_) {}
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Campo obrigatório';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'E-mail inválido';
    return null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _estabSearchCtrl.dispose();
    _anoCtrl.dispose();
    _dataHoraCtrl.dispose();
    _tipoDocumentoLabelCtrl.dispose();
    _nomeFantasiaCtrl.dispose();
    _cnpjCtrl.dispose();
    _inscricaoMunicipalCtrl.dispose();
    _enderecoCtrl.dispose();
    _responsavelLegalCtrl.dispose();
    _numeroPastaVisaCtrl.dispose();
    _responsavelTecnicoCtrl.dispose();
    _testemunha1Ctrl.dispose();
    _testemunha2Ctrl.dispose();
    _profissionalCtrl.dispose();
    _baseLegalCtrl.dispose();
    _enquadramentoLegalCtrl.dispose();
    _artigoCtrl.dispose();
    _incisoCtrl.dispose();
    _paragrafoCtrl.dispose();
    _observacoesLegaisCtrl.dispose();
    _descricaoIrregularidadesCtrl.dispose();
    _descricaoProvidenciasCtrl.dispose();
    _prazoCumprimentoTextoCtrl.dispose();
    _prazoCumprimentoDataCtrl.dispose();
    _prazoCumprimentoDiasCtrl.dispose();
    _vencimentoPrazoCtrl.dispose();
    _itensReferenciaCtrl.dispose();
    _prazoExigenciaReferenciaCtrl.dispose();
    _prazoExigenciaDiasCtrl.dispose();
    _prazoExigenciaVencimentoCtrl.dispose();
    _comentarioFiscalizacaoCtrl.dispose();
    _especificacaoAtoCtrl.dispose();
    _departamentoCtrl.dispose();
    _dataLavraturaCtrl.dispose();
    _telefoneVisaCtrl.dispose();
    _emailVisaCtrl.dispose();
    _semEfeitoMotivoCtrl.dispose();
    _anoRelacionadoCtrl.dispose();
    _documentoRelacionadoCtrl.dispose();
    _dataRecebimentoCtrl.dispose();
    _autuadoNomeCtrl.dispose();
    _autuadoCpfCnpjCtrl.dispose();
    _autuadoNomeFantasiaCtrl.dispose();
    _autuadoEnderecoCompletoCtrl.dispose();
    _autuadoNumeroCtrl.dispose();
    _autuadoBairroCtrl.dispose();
    _autuadoMunicipioCtrl.dispose();
    _autuadoUfCtrl.dispose();
    _autuadoProprietarioCtrl.dispose();
    _autuadoTipoAtividadeCtrl.dispose();
    _autuadoAlvaraCtrl.dispose();
    _recebimentoDataCtrl.dispose();
    _recebimentoHoraCtrl.dispose();
    _recebimentoResponsavelCtrl.dispose();
    _testemunha1RecusaCtrl.dispose();
    _testemunha2RecusaCtrl.dispose();
    _autoridadeSaudeCtrl.dispose();
    _autoridadeFuncaoCtrl.dispose();
    _tipoAmostraCtrl.dispose();
    _situacaoEncontradaCtrl.dispose();
    _observacoesInspecaoCtrl.dispose();
    _profissionalEquipeCtrl.dispose();
    _funcaoEquipeCtrl.dispose();
    for (final a in _autoridadesSaude) {
      a.dispose();
    }
    _formRebuildTick.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentos() async {
    await _buscarDocumentos();
  }

  Future<void> _sincronizarPendentes() async {
    await _sincronizarPendentesSinnc();
  }

  Future<Map<String, dynamic>> _sincronizarPendentesSinnc({
    bool showSnackbar = true,
    bool reloadAfter = true,
  }) async {
    if (_syncingPendentes) {
      return <String, dynamic>{'skipped': true, 'reason': 'already_syncing'};
    }
    setState(() => _syncingPendentes = true);
    try {
      final swTotal = Stopwatch()..start();
      // #region debug-point S:sync
      unawaited(
        _debugReport(
          hypothesisId: 'S',
          location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
          msg: '[DEBUG] Inicio sincronizacao pendentes',
          data: {'isWeb': kIsWeb},
        ),
      );
      // #endregion
      final hasToken = (await _api.getSinncToken()) != null;
      if (!mounted) return <String, dynamic>{'skipped': true, 'reason': 'unmounted'};
      if (!hasToken) {
        // #region debug-point S:sync
        unawaited(
          _debugReport(
            hypothesisId: 'S',
            location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
            msg: '[DEBUG] Token SINNC ausente, abrindo dialog de login',
          ),
        );
        // #endregion
        final okLogin = await _dialogLoginSinnc();
        if (!okLogin) {
          return <String, dynamic>{'skipped': true, 'reason': 'login_cancelled'};
        }
      }

      var ok = 0;
      var erro = 0;
      String? firstError;

      final pendentes = await LocalDb.listarAutosSanitariosPendentesSync();
      final docs = pendentes.isNotEmpty ? pendentes : await LocalDb.listarAutosTermosLocal();
      if (!mounted) return <String, dynamic>{'skipped': true, 'reason': 'unmounted'};
      // #region debug-point S:sync
      unawaited(
        _debugReport(
          hypothesisId: 'S',
          location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
          msg: '[DEBUG] Documentos carregados para sincronizar',
          data: {'pendentesCount': pendentes.length, 'docsCount': docs.length},
        ),
      );
      // #endregion

      if (docs.isEmpty) {
        if (showSnackbar) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum documento pendente de sincronização.')),
          );
        }
        return <String, dynamic>{
          'ok': 0,
          'erro': 0,
          'firstError': null,
          'ms': swTotal.elapsedMilliseconds,
          'docsCount': 0,
        };
      }

      for (final row in docs) {
        final id = (row['id'] as int?) ?? 0;
        if (id <= 0) continue;

        final payloadRaw = (row['payload_json'] ?? '').toString().trim();
        if (payloadRaw.isEmpty) continue;

        Map<String, dynamic>? payload;
        try {
          final decoded = jsonDecode(payloadRaw);
          if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
        } catch (_) {
          payload = null;
        }
        if (payload == null) continue;

        final tipoDocumento = (payload['tipo_documento'] ??
                payload['tipoDocumento'] ??
                row['tipo_documento'] ??
                row['tipo_auto'] ??
                '')
            .toString()
            .trim();

        final numero = (row['numero_ano'] ??
                row['numero_auto'] ??
                payload['numero_ano'] ??
                payload['numero'] ??
                payload['numeroAuto'] ??
                '')
            .toString()
            .trim();

        final ano = int.tryParse((payload['ano'] ?? row['ano'] ?? '').toString()) ?? DateTime.now().year;

        final statusRaw = (row['status'] ?? payload['status'] ?? payload['situacao'] ?? 'FINALIZADO').toString().trim();
        final situacao = statusRaw.toUpperCase();

        final dadosEstab = payload['dados_estabelecimento'];
        final estab = dadosEstab is Map ? Map<String, dynamic>.from(dadosEstab) : <String, dynamic>{};
        final estabNome = (row['estabelecimento_nome'] ?? estab['nome_fantasia'] ?? estab['razao_social'] ?? '').toString().trim();
        final estabCnpj = _onlyDigits((row['estabelecimento_cnpj'] ?? estab['cnpj'] ?? '').toString());

        final fiscalNome = (row['profissional_nome'] ?? payload['profissional_id'] ?? payload['profissional'] ?? '').toString().trim();

        final semEfeitoMotivo = (payload['sem_efeito_motivo'] ??
                payload['semEfeitoMotivo'] ??
                (payload['auto_infracao'] is Map ? (payload['auto_infracao'] as Map)['sem_efeito_motivo'] : null) ??
                (payload['auto_intimacao'] is Map ? (payload['auto_intimacao'] as Map)['sem_efeito_motivo'] : null) ??
                (payload['imposicao_penalidade'] is Map ? (payload['imposicao_penalidade'] as Map)['sem_efeito_motivo'] : null))
            ?.toString()
            .trim();

        final documento = <String, dynamic>{
          'tipo_documento': tipoDocumento,
          'numero': numero,
          'ano': ano,
          'situacao': situacao,
          'status_sincronizacao': 'SINCRONIZADO',
          'origem': 'MOBILE',
          'dispositivo': kIsWeb ? 'web' : 'mobile',
          'estabelecimento_nome': estabNome,
          'estabelecimento_cnpj_cpf': estabCnpj,
          'fiscal_nome': fiscalNome,
          'conteudo': payload,
          'assinaturas': payload['assinaturas'] ?? payload['assinatura'] ?? <String, dynamic>{},
          'base_legal_ids': payload['base_legal_ids'] ?? payload['baseLegalIds'] ?? <dynamic>[],
          'timeline_eventos': payload['timeline_eventos'] ?? <dynamic>[],
          if (situacao.contains('SEM') && semEfeitoMotivo != null && semEfeitoMotivo.isNotEmpty)
            'sem_efeito_justificativa': semEfeitoMotivo,
        };

        final envelope = <String, dynamic>{
          'chave_origem': 'sqlite:autos_sanitarios:$id',
          'hash_sync': payload['hash_sync'] ?? payload['hashSync'],
          'documento': documento,
        };

        try {
          final sw = Stopwatch()..start();
          // #region debug-point S:sync
          unawaited(
            _debugReport(
              hypothesisId: 'S',
              location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
              msg: '[DEBUG] Enviando documento para SINNC',
              data: {'id': id, 'tipo_documento': tipoDocumento, 'numero': numero, 'ano': ano, 'situacao': situacao},
            ),
          );
          // #endregion
          await _api.sincronizarAutoTermoSinncSaude(envelope);
          await LocalDb.atualizarAutoSanitario(id, {'status_sincronizacao': 'SINCRONIZADO'});
          ok += 1;
          // #region debug-point S:sync
          unawaited(
            _debugReport(
              hypothesisId: 'S',
              location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
              msg: '[DEBUG] Documento sincronizado com sucesso',
              data: {'id': id, 'ms': sw.elapsedMilliseconds},
            ),
          );
          // #endregion
        } on DioException catch (e) {
          await LocalDb.atualizarAutoSanitario(id, {'status_sincronizacao': 'ERRO'});
          erro += 1;
          if (firstError == null) {
            final status = e.response?.statusCode;
            final data = e.response?.data;
            final msg = data is Map ? (data['error'] ?? data['message'] ?? '').toString().trim() : '';
            firstError = status == null ? (e.message ?? 'Falha') : 'HTTP $status${msg.isEmpty ? '' : ' — $msg'}';
          }
          // #region debug-point S:sync
          unawaited(
            _debugReport(
              hypothesisId: 'S',
              location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
              msg: '[DEBUG] Erro Dio ao sincronizar documento',
              data: {'id': id, 'status': e.response?.statusCode, 'message': e.message},
            ),
          );
          // #endregion
        } catch (_) {
          await LocalDb.atualizarAutoSanitario(id, {'status_sincronizacao': 'ERRO'});
          erro += 1;
          // #region debug-point S:sync
          unawaited(
            _debugReport(
              hypothesisId: 'S',
              location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
              msg: '[DEBUG] Erro generico ao sincronizar documento',
              data: {'id': id},
            ),
          );
          // #endregion
        }
      }

      if (!mounted) return <String, dynamic>{'skipped': true, 'reason': 'unmounted'};
      // #region debug-point S:sync
      unawaited(
        _debugReport(
          hypothesisId: 'S',
          location: 'auto_termo_page.dart:_sincronizarPendentesSinnc',
          msg: '[DEBUG] Fim sincronizacao pendentes (antes do snackbar)',
          data: {'ok': ok, 'erro': erro, 'firstError': firstError, 'ms': swTotal.elapsedMilliseconds},
        ),
      );
      // #endregion
      final outcome = <String, dynamic>{
        'ok': ok,
        'erro': erro,
        'firstError': firstError,
        'ms': swTotal.elapsedMilliseconds,
        'docsCount': docs.length,
      };
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              firstError == null
                  ? 'Sincronização concluída: $ok ok, $erro erro(s).'
                  : 'Sincronização concluída: $ok ok, $erro erro(s). Primeiro erro: $firstError',
            ),
          ),
        );
      }
      if (reloadAfter) await _loadDocumentos();
      return outcome;
    } finally {
      if (mounted) setState(() => _syncingPendentes = false);
    }
  }

  Future<void> _sincronizarPendentesWeb() async {
    await _sincronizarPendentesSinnc();
  }

  Future<bool> _dialogLoginSinnc() async {
    final dialogContext = context;
    final savedCpf = (await AppStorage.read('sinnc_cpf')) ?? (await AppStorage.read('usuario_cpf')) ?? '';
    if (!dialogContext.mounted) return false;
    final cpfCtrl = TextEditingController(text: savedCpf);
    final senhaCtrl = TextEditingController();
    bool loading = false;
    String? error;

    final result = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Login SINNC'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: cpfCtrl,
                      decoration: const InputDecoration(labelText: 'CPF'),
                      keyboardType: TextInputType.number,
                      enabled: !loading,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senhaCtrl,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      enabled: !loading,
                    ),
                    if (error != null && error!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setLocal(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final ok = await _api.loginSinnc(cpfCtrl.text, senhaCtrl.text);
                            if (ok) {
                              if (ctx.mounted) Navigator.of(ctx).pop(true);
                              return;
                            }
                            setLocal(() {
                              loading = false;
                              error = 'CPF ou senha inválidos no SINNC.';
                            });
                          } on DioException catch (e) {
                            final status = e.response?.statusCode;
                            final data = e.response?.data;
                            final msg = data is Map ? (data['error'] ?? data['message'] ?? '').toString().trim() : '';
                            setLocal(() {
                              loading = false;
                              error = status == null ? (e.message ?? 'Falha ao conectar') : 'HTTP $status${msg.isEmpty ? '' : ' — $msg'}';
                            });
                          } catch (e) {
                            setLocal(() {
                              loading = false;
                              error = 'Erro ao autenticar no SINNC: $e';
                            });
                          }
                        },
                  child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar'),
                ),
              ],
            );
          },
        );
      },
    );

    cpfCtrl.dispose();
    senhaCtrl.dispose();
    return result ?? false;
  }

  Future<void> _buscarDocumentos() async {
    if (!_validarPeriodoFiltro()) return;
    final busca = _searchCtrl.text.trim();
    final digits = _onlyDigits(busca);
    if (digits.length == 14 && busca == digits) {
      _searchCtrl.value = TextEditingValue(
        text: _formatCnpj(digits),
        selection: TextSelection.collapsed(offset: _formatCnpj(digits).length),
      );
    }

    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      late final List<dynamic> list;
      if (kIsWeb) {
        final tipoFiltro = _tipoFiltroApiValue;
        final search = busca.isEmpty ? null : busca;
        final cnpj = digits.length == 14 ? digits : null;
        final status = _statusFiltroApiValue;
        final dataInicio = _toApiDate(_filtroDataInicio);
        final dataFim = _toApiDate(_filtroDataFim);

        final autoTermo = await _api.listarAutoTermo(
          search: search,
          cnpj: cnpj,
          tipoDocumento: tipoFiltro,
          status: status,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );

        final shouldFetchInfracao = tipoFiltro == null || tipoFiltro == _tipoAutoInfracao;
        final shouldFetchIntimacao = tipoFiltro == null || tipoFiltro == _tipoAutoIntimacao;
        final infracoes = shouldFetchInfracao
            ? await _api.listarAutoInfracaoDocumentos(
                search: search,
                cnpj: cnpj,
                status: status,
                dataInicio: dataInicio,
                dataFim: dataFim,
              )
            : const <dynamic>[];
        final intimacoes = shouldFetchIntimacao
            ? await _api.listarAutoIntimacaoDocumentos(
                search: search,
                cnpj: cnpj,
                status: status,
                dataInicio: dataInicio,
                dataFim: dataFim,
              )
            : const <dynamic>[];
        list = [...autoTermo, ...infracoes, ...intimacoes];
      } else {
        list = await LocalDb.listarAutosTermosLocal();
      }
      if (!mounted) return;
      setState(() {
        _documentos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _applyFiltroLista();
        _loadingList = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _documentos = [];
        _documentosFiltrados = [];
        _listError = e.response?.statusCode == 401
            ? 'Sessão expirada. Faça login novamente.'
            : 'Nao foi possivel carregar os Autos/Termos. Tente novamente.';
        _loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _documentos = [];
        _documentosFiltrados = [];
        _listError = 'Nao foi possivel carregar os Autos/Termos. Tente novamente.';
        _loadingList = false;
      });
    }
  }

  void _applyFiltroLista() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final qDigits = _onlyDigits(_searchCtrl.text);
    final filtered = _documentos.where((item) {
      final numeroAno = (item['numero_ano'] ?? item['numero_auto'] ?? item['numero'] ?? '').toString();
      final tipo = _tipoDocumentoFromStored(item);
      final estabelecimento = (item['estabelecimento_nome'] ?? item['estabelecimento'] ?? '').toString();
      final cnpjDigits = _onlyDigits((item['estabelecimento_cnpj'] ?? item['cnpj'] ?? '').toString());
      final cnpj = _formatCnpj(cnpjDigits);
      final fiscal = (item['profissional_nome'] ?? item['profissional'] ?? item['fiscal_nome'] ?? '').toString();
      final status = _statusLabelFromValue((item['status'] ?? '').toString());
      final buscaBase = <String>[
        numeroAno,
        tipo,
        estabelecimento,
        cnpj,
        fiscal,
        (item['ano'] ?? '').toString(),
      ].join(' ').toLowerCase();
      final matchBusca = q.isEmpty || buscaBase.contains(q) || (qDigits.isNotEmpty && cnpjDigits.contains(qDigits));
      final matchStatus = _statusFiltro == 'Todos' || status == _statusFiltro;
      final matchTipo = _tipoFiltro == 'Todos' || tipo == _tipoFiltro;
      final matchPeriodo = _matchesPeriodo(_extractItemDate(item));
      return matchBusca && matchStatus && matchTipo && matchPeriodo;
    }).toList()
      ..sort((a, b) {
        final ad = _extractItemDate(a);
        final bd = _extractItemDate(b);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    _documentosFiltrados = filtered;
  }

  void _syncDateTimeFields() {
    _anoCtrl.text = _selectedDate.year.toString();
    _dataHoraCtrl.text = '${_formatDate(_selectedDate)} ${_formatTime(_selectedTime)}';
    _dataLavraturaCtrl.text = _formatDate(_selectedDate);
    _tipoAmostraCtrl.text = _tipoAmostra;
    _departamentoCtrl.text = _departamento;
    _recalcularVencimentoPrazo();
  }

  Future<void> _pickDataHora() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (!mounted || pickedTime == null) return;
    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
      _syncDateTimeFields();
    });
  }

  Future<void> _pickDateOnly(TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || pickedDate == null) return;
    setState(() {
      controller.text = _formatDate(pickedDate);
      _recalcularVencimentoPrazo();
    });
    if (identical(controller, _dataLavraturaCtrl) && _tipoDocumento == _tipoAutoIntimacao) {
      _recalcularVencimentosItensReferencia(showSnack: true);
    }
  }

  Future<void> _pickTimeOnly(TextEditingController controller) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (!mounted || pickedTime == null) return;
    setState(() {
      controller.text = _formatTime(pickedTime);
    });
  }

  Future<Uint8List?> _abrirAssinatura() async {
    final result = await Navigator.pushNamed(context, '/assinatura');
    if (!mounted) return null;
    if (result is Uint8List) return result;
    return null;
  }

  Widget _buildAssinaturaRow({
    required String label,
    required bool required,
    required bool hasValue,
    required VoidCallback onPressed,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GovColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GovColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.edit_outlined),
                label: Text(hasValue ? 'Refazer assinatura' : 'Capturar assinatura'),
              ),
            ),
            if (hasValue) ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Limpar',
              ),
            ],
          ],
        ),
        if (hasValue) ...[
          const SizedBox(height: 6),
          const Text('Assinatura capturada', style: TextStyle(color: Colors.black54)),
        ],
      ],
    );
  }

  bool _validarPeriodoFiltro() {
    if (_filtroDataInicio != null && _filtroDataFim != null && _filtroDataInicio!.isAfter(_filtroDataFim!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O periodo inicial nao pode ser maior que o periodo final.')),
      );
      return false;
    }
    return true;
  }

  bool _matchesPeriodo(DateTime? value) {
    if (_filtroDataInicio == null && _filtroDataFim == null) return true;
    if (value == null) return false;
    final current = DateTime(value.year, value.month, value.day);
    final inicio = _filtroDataInicio == null
        ? null
        : DateTime(_filtroDataInicio!.year, _filtroDataInicio!.month, _filtroDataInicio!.day);
    final fim = _filtroDataFim == null
        ? null
        : DateTime(_filtroDataFim!.year, _filtroDataFim!.month, _filtroDataFim!.day);
    if (inicio != null && current.isBefore(inicio)) return false;
    if (fim != null && current.isAfter(fim)) return false;
    return true;
  }

  Future<void> _limparFiltros() async {
    setState(() {
      _searchCtrl.clear();
      _tipoFiltro = 'Todos';
      _statusFiltro = 'Todos';
      _filtroDataInicio = null;
      _filtroDataFim = null;
      _listError = null;
    });
    await _buscarDocumentos();
  }

  Future<void> _buscarEstabelecimento() async {
    final query = _estabSearchCtrl.text.trim();
    final digits = _onlyDigits(query);
    if (digits.isEmpty && query.length < 2) {
      setState(() {
        _estabError = 'Digite pelo menos 2 caracteres para buscar.';
        _estabResults = [];
      });
      return;
    }
    if (digits.isNotEmpty && digits.length != 14 && query == digits) {
      setState(() {
        _estabError = 'CNPJ incompleto. Digite 14 dígitos.';
        _estabResults = [];
      });
      return;
    }
    setState(() {
      _estabLoading = true;
      _estabError = null;
      _estabResults = [];
    });
    try {
      await _api.init();
      if (digits.length == 14) {
        final data = await _api.buscarEstabelecimentoPorCnpj(digits);
        if (!mounted) return;
        if (data == null) {
          setState(() {
            _estabLoading = false;
            _estabError = 'Estabelecimento não encontrado.';
          });
          return;
        }
        _selecionarEstabelecimento(data);
        setState(() {
          _estabLoading = false;
          _estabResults = [Map<String, dynamic>.from(data)];
        });
        return;
      }
      final data = await _api.buscarEstabelecimentosEpublica(query);
      if (!mounted) return;
      setState(() {
        _estabLoading = false;
        _estabResults = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _estabError = _estabResults.isEmpty ? 'Nenhum estabelecimento encontrado.' : null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _estabLoading = false;
        _estabError = e.response?.statusCode == 401
            ? 'Sessão expirada. Faça login novamente.'
            : 'Erro ao buscar estabelecimento.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estabLoading = false;
        _estabError = 'Erro ao buscar estabelecimento.';
      });
    }
  }

  void _selecionarEstabelecimento(Map<String, dynamic> item) {
    final data = normalizeEstablishmentForInspection(item);
    final endereco = (item['endereco'] ?? data['endereco'] ?? '').toString();
    setState(() {
      _estabelecimentoSelecionado = Map<String, dynamic>.from(item);
      _estabelecimentoId = (item['id'] as num?)?.toInt();
      _nomeFantasiaCtrl.text = (item['razaoSocial'] ??
              item['razao_social'] ??
              item['nomeRazaoSocial'] ??
              item['nome_razao_social'] ??
              item['nomeFantasia'] ??
              item['nome_fantasia'] ??
              item['nome'] ??
              '')
          .toString();
      _cnpjCtrl.text = _formatCnpj((item['cnpj'] ?? '').toString());
      _inscricaoMunicipalCtrl.text =
          (item['inscricaoMunicipal'] ?? item['inscricao_municipal'] ?? '').toString();
      _enderecoCtrl.text = endereco.isEmpty ? (data['endereco'] ?? '').toString() : endereco;
      _responsavelLegalCtrl.text =
          (item['responsavel'] ?? item['responsavel_legal'] ?? item['responsavelLegal'] ?? '').toString();
      _estabError = null;
    });
    _prefillAutuadoFromEstabelecimento(item);
    _seedAuditValuesForIntimacao();
    unawaited(_hidratarEstabelecimentoDetalheSeNecessario(item));
  }

  Future<void> _hidratarEstabelecimentoDetalheSeNecessario(Map<String, dynamic> raw) async {
    if (ApiService.mockMode) return;
    final digits = _onlyDigits((raw['cnpj'] ?? '').toString());
    if (digits.length != 14) return;

    final cnaes = _extractCnaesFromEstabelecimento(raw);
    final atividadeAtual = _autuadoTipoAtividadeCtrl.text.trim();
    // #region debug-point A:cnae-hydration
    unawaited(
      _debugReport(
        hypothesisId: 'A',
        location: 'auto_termo_page.dart:_hidratarEstabelecimentoDetalheSeNecessario',
        msg: '[DEBUG] Avaliando necessidade de hidratar detalhe do estabelecimento',
        data: {
          'cnpj': digits,
          'rawCnaesCount': cnaes.length,
          'atividadeAtual': atividadeAtual,
        },
      ),
    );
    // #endregion
    if (cnaes.isNotEmpty && atividadeAtual.isNotEmpty) {
      // #region debug-point A:cnae-hydration
      unawaited(
        _debugReport(
          hypothesisId: 'A',
          location: 'auto_termo_page.dart:_hidratarEstabelecimentoDetalheSeNecessario',
          msg: '[DEBUG] Hidratacao complementar ignorada porque o payload inicial ja contem atividade',
          data: {
            'cnpj': digits,
            'rawCnaesCount': cnaes.length,
            'atividadeAtual': atividadeAtual,
          },
        ),
      );
      // #endregion
      return;
    }

    final atividadeFallback = (raw['cnaeDescricao'] ??
            raw['cnae_descricao'] ??
            raw['cnae_fiscal_descricao'] ??
            raw['cnaeFiscalDescricao'] ??
            raw['atividade_principal'] ??
            raw['atividadePrincipal'] ??
            raw['atividade_principal_descricao'] ??
            raw['atividadePrincipalDescricao'] ??
            raw['atividade'] ??
            raw['ramo_atividade'] ??
            raw['ramoAtividade'] ??
            '')
        .toString()
        .trim();
    if (atividadeFallback.isNotEmpty) {
      // #region debug-point A:cnae-hydration
      unawaited(
        _debugReport(
          hypothesisId: 'A',
          location: 'auto_termo_page.dart:_hidratarEstabelecimentoDetalheSeNecessario',
          msg: '[DEBUG] Hidratacao complementar ignorada por fallback de atividade no payload inicial',
          data: {
            'cnpj': digits,
            'atividadeFallback': atividadeFallback,
          },
        ),
      );
      // #endregion
      return;
    }

    final detail = await _api.buscarEstabelecimentoDetalhe(digits);
    // #region debug-point A:cnae-hydration
    unawaited(
      _debugReport(
        hypothesisId: 'A',
        location: 'auto_termo_page.dart:_hidratarEstabelecimentoDetalheSeNecessario',
        msg: '[DEBUG] Resultado da busca de detalhe do estabelecimento',
        data: {
          'cnpj': digits,
          'detailEncontrado': detail != null,
          'detailKeys': detail == null ? const <String>[] : detail.keys.take(12).toList(),
        },
      ),
    );
    // #endregion
    if (!mounted || detail == null) return;
    _prefillAutuadoFromEstabelecimento(Map<String, dynamic>.from(detail));
  }

  void _prefillAutuadoFromEstabelecimento(Map raw) {
    final item = raw.cast<String, dynamic>();
    final data = normalizeEstablishmentForInspection(item);
    final endereco = (item['endereco'] ?? data['endereco'] ?? '').toString().trim();
    final razaoSocial = (item['razaoSocial'] ?? item['razao_social'] ?? item['nomeRazaoSocial'] ?? item['nome_razao_social'] ?? '')
        .toString()
        .trim();
    final nomeFantasia = (item['nomeFantasia'] ?? item['nome_fantasia'] ?? item['nome'] ?? '').toString().trim();
    final cnpj = (item['cnpj'] ?? '').toString().trim();

    if (_autuadoNomeCtrl.text.trim().isEmpty) _autuadoNomeCtrl.text = razaoSocial.isEmpty ? nomeFantasia : razaoSocial;
    if (_autuadoCpfCnpjCtrl.text.trim().isEmpty) _autuadoCpfCnpjCtrl.text = _formatCpfCnpj(cnpj);
    if (_autuadoNomeFantasiaCtrl.text.trim().isEmpty) _autuadoNomeFantasiaCtrl.text = nomeFantasia;
    {
      final cnaes = _extractCnaesFromEstabelecimento(item);
      _formSetState(() => _cnaesAutuado = cnaes);

      String atividade = '';
      if (cnaes.isNotEmpty) {
        final principal = cnaes.firstWhere((e) => e['principal'] == true, orElse: () => cnaes.first);
        atividade = _formatCnaeItem(principal);
      } else {
        atividade = (item['cnaeDescricao'] ??
                item['cnae_descricao'] ??
                item['cnae_fiscal_descricao'] ??
                item['cnaeFiscalDescricao'] ??
                '')
            .toString()
            .trim();
      }
      if (atividade.isEmpty) {
        atividade = (item['atividade_principal'] ??
                item['atividadePrincipal'] ??
                item['atividade_principal_descricao'] ??
                item['atividadePrincipalDescricao'] ??
                item['atividade'] ??
                item['ramo_atividade'] ??
                item['ramoAtividade'] ??
                '')
            .toString()
            .trim();
      }
      final atual = _autuadoTipoAtividadeCtrl.text.trim();
      // #region debug-point B:atividade-prefill
      unawaited(
        _debugReport(
          hypothesisId: 'B',
          location: 'auto_termo_page.dart:_prefillAutuadoFromEstabelecimento',
          msg: '[DEBUG] Avaliando prefill do campo tipo de atividade',
          data: {
            'cnpj': cnpj,
            'cnaesCount': cnaes.length,
            'atividadeCalculada': atividade,
            'atividadeAtual': atual,
            'ultimoAuto': _tipoAtividadeUltimoAuto,
          },
        ),
      );
      // #endregion
      if (atividade.isNotEmpty && (atual.isEmpty || atual == _tipoAtividadeUltimoAuto)) {
        _autuadoTipoAtividadeCtrl.text = atividade;
        _tipoAtividadeUltimoAuto = atividade;
        _revalidarAutuadoSeAtivo();
        // #region debug-point B:atividade-prefill
        unawaited(
          _debugReport(
            hypothesisId: 'B',
            location: 'auto_termo_page.dart:_prefillAutuadoFromEstabelecimento',
            msg: '[DEBUG] Campo tipo de atividade atualizado',
            data: {
              'cnpj': cnpj,
              'atividadeAplicada': atividade,
            },
          ),
        );
        // #endregion
      }
    }
    if (_autuadoEnderecoCompletoCtrl.text.trim().isEmpty) {
      _autuadoEnderecoCompletoCtrl.text = endereco.isEmpty ? (data['endereco'] ?? '').toString() : endereco;
    }
    if (_autuadoNumeroCtrl.text.trim().isEmpty) {
      _autuadoNumeroCtrl.text = (item['numero'] ?? item['enderecoNumero'] ?? item['endereco_numero'] ?? '').toString();
    }
    if (_autuadoBairroCtrl.text.trim().isEmpty) {
      _autuadoBairroCtrl.text = (item['bairro'] ?? item['enderecoBairro'] ?? item['endereco_bairro'] ?? '').toString();
    }
    if (_autuadoMunicipioCtrl.text.trim().isEmpty) {
      _autuadoMunicipioCtrl.text = (item['cidade'] ?? item['municipio'] ?? item['cidadeDescricao'] ?? 'Balneário Camboriú').toString();
    }
    if (_autuadoUfCtrl.text.trim().isEmpty) {
      _autuadoUfCtrl.text = (item['uf'] ?? item['estado'] ?? 'SC').toString();
    }
    if (_autuadoProprietarioCtrl.text.trim().isEmpty) _autuadoProprietarioCtrl.text = _responsavelLegalCtrl.text;
  }

  List<Map<String, dynamic>> _extractCnaesFromEstabelecimento(Map<String, dynamic> item) {
    String pickFrom(Map m, List<String> keys) {
      for (final k in keys) {
        final v = (m[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    bool pickBoolFrom(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        final s = (v ?? '').toString().trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'sim') return true;
        if (s == 'false' || s == '0' || s == 'nao' || s == 'não') return false;
      }
      return false;
    }

    final out = <Map<String, dynamic>>[];
    final rawList = item['cnaes'];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final codigo = pickFrom(m, ['cnae', 'codigo', 'codigo_cnae', 'code']);
        final descricao = pickFrom(m, ['cnaeDescricao', 'descricao', 'cnae_descricao', 'cnae_fiscal_descricao']);
        final principal = pickBoolFrom(m, ['principal', 'is_principal', 'isPrincipal']);
        if (codigo.isEmpty && descricao.isEmpty) continue;
        out.add({
          'codigo': codigo,
          'descricao': descricao,
          'principal': principal,
        });
      }
    }

    void addIfNotExists({
      required String codigo,
      required String descricao,
      required bool principal,
    }) {
      final c = codigo.trim();
      final d = descricao.trim();
      if (c.isEmpty && d.isEmpty) return;
      final exists = out.any((e) => (e['codigo'] ?? '').toString().trim() == c && (e['descricao'] ?? '').toString().trim() == d);
      if (exists) return;
      out.add({'codigo': c, 'descricao': d, 'principal': principal});
    }

    final atividadePrincipal = item['atividade_principal'];
    if (atividadePrincipal is List) {
      for (final e in atividadePrincipal) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final codigo = pickFrom(m, ['code', 'cnae', 'codigo']);
        final descricao = pickFrom(m, ['text', 'descricao', 'cnaeDescricao']);
        addIfNotExists(codigo: codigo, descricao: descricao, principal: true);
      }
    }

    final atividadesSec = item['atividades_secundarias'];
    if (atividadesSec is List) {
      for (final e in atividadesSec) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final codigo = pickFrom(m, ['code', 'cnae', 'codigo']);
        final descricao = pickFrom(m, ['text', 'descricao', 'cnaeDescricao']);
        addIfNotExists(codigo: codigo, descricao: descricao, principal: false);
      }
    }

    if (out.isEmpty) {
      final codigo = pickFrom(item, ['cnae', 'cnae_principal', 'cnaePrincipal']);
      final descricao = pickFrom(item, ['cnaeDescricao', 'cnae_descricao', 'cnae_fiscal_descricao', 'cnaeFiscalDescricao']);
      if (codigo.isNotEmpty || descricao.isNotEmpty) {
        out.add({'codigo': codigo, 'descricao': descricao, 'principal': true});
      }
    }

    final hasPrincipal = out.any((e) => e['principal'] == true);
    if (!hasPrincipal && out.isNotEmpty) {
      out[0] = {...out[0], 'principal': true};
    }
    return out;
  }

  String _formatCnaeItem(Map<String, dynamic> item) {
    final codigo = (item['codigo'] ?? '').toString().trim();
    final descricao = (item['descricao'] ?? '').toString().trim();
    if (codigo.isNotEmpty && descricao.isNotEmpty) return '$codigo - $descricao';
    return descricao.isNotEmpty ? descricao : codigo;
  }

  void _revalidarAutuadoSeAtivo() {
    final steps = _steps;
    if (_currentStep < 0 || _currentStep >= steps.length) return;
    if (steps[_currentStep].title != 'Autuado') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autuadoFormKey.currentState?.validate();
    });
  }

  Future<void> _selecionarCnaeAutuado() async {
    if (_cnaesAutuado.isEmpty) return;
    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecionar CNAE'),
        content: SizedBox(
          width: 520,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cnaesAutuado.length,
            itemBuilder: (ctx, index) {
              final it = _cnaesAutuado[index];
              final label = _formatCnaeItem(it);
              final isPrincipal = it['principal'] == true;
              return ListTile(
                title: Text(label.isEmpty ? 'CNAE' : label),
                subtitle: isPrincipal ? const Text('CNAE principal') : null,
                onTap: () => Navigator.of(ctx).pop(it),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
        ],
      ),
    );
    if (selected == null) return;
    final text = _formatCnaeItem(selected);
    if (text.isEmpty) return;
    _autuadoTipoAtividadeCtrl.text = text;
    _tipoAtividadeUltimoAuto = text;
    _revalidarAutuadoSeAtivo();
  }

  Future<void> _adicionarVinculo() async {
    if (_tipoDocumento == _tipoAutoInfracao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use a seção Auto de Intimação para vincular autos anteriores.')),
      );
      return;
    }
    if (_anoRelacionadoCtrl.text.trim().isEmpty || _documentoRelacionadoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ano e documento relacionado para adicionar.')),
      );
      return;
    }
    final exists = _vinculosRelacionados.any((e) {
      final numero = (e['numero'] ?? '').toString().trim();
      final ano = (e['ano'] ?? '').toString().trim();
      return numero == _documentoRelacionadoCtrl.text.trim() && ano == _anoRelacionadoCtrl.text.trim();
    });
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vínculo já adicionado.')),
      );
      return;
    }
    _formSetState(() {
      _vinculosRelacionados = [
        ..._vinculosRelacionados,
        {
          'numero': _documentoRelacionadoCtrl.text.trim(),
          'ano': _anoRelacionadoCtrl.text.trim(),
          'data_recebimento': _dataRecebimentoCtrl.text.trim(),
        },
      ];
      _anoRelacionadoCtrl.clear();
      _documentoRelacionadoCtrl.clear();
      _dataRecebimentoCtrl.clear();
    });
  }

  void _adicionarAutoIntimacaoRelacionado() {
    () async {
      if (_estabelecimentoSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o estabelecimento no step Dados.')),
        );
        return;
      }

      final numeroAno = _documentoRelacionadoCtrl.text.trim();
      final dataRecebBr = _dataRecebimentoCtrl.text.trim();

      if (numeroAno.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o Número/Ano do Auto de Intimação.')),
        );
        return;
      }
      if (dataRecebBr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe a data de recebimento.')),
        );
        return;
      }
      if (_autosIntimacaoRelacionados.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limite de 10 autos de intimação relacionados.')),
        );
        return;
      }

      final dtReceb = _tryParseBrDate(dataRecebBr);
      if (dtReceb == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data de recebimento inválida. Use o seletor de data.')),
        );
        return;
      }

      final key = numeroAno.toLowerCase().replaceAll(' ', '');
      final exists = _autosIntimacaoRelacionados.any((e) {
        final oldKey = ((e['numero_ano'] ?? '').toString().toLowerCase().replaceAll(' ', ''));
        return oldKey == key;
      });
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto de intimação já adicionado. Informe outro número ou continue.')),
        );
        _documentoRelacionadoCtrl.clear();
        _dataRecebimentoCtrl.clear();
        return;
      }

      final cnpj = _onlyDigits(_cnpjCtrl.text);
      int? autoId;
      try {
        final raw = await _api.listarAutoIntimacaoDocumentos(search: numeroAno, cnpj: cnpj, status: 'TODOS');
        for (final e in raw) {
          if (e is! Map) continue;
          final doc = Map<String, dynamic>.from(e);
          final docNumero = _autoIntimacaoNumeroAnoFromDoc(doc).toLowerCase().replaceAll(' ', '');
          if (docNumero != key) continue;
          final id = doc['id'];
          if (id is int) autoId = id;
          break;
        }
      } catch (_) {}

      if (autoId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível validar este Auto de Intimação para o CNPJ selecionado.')),
        );
        return;
      }

      _formSetState(() {
        _autosIntimacaoRelacionados = [
          ..._autosIntimacaoRelacionados,
          {
            'auto_intimacao_id': autoId,
            'numero_ano': numeroAno,
            'data_recebimento': _formatIsoDate(dtReceb),
            'data_recebimento_br': dataRecebBr,
          },
        ];
        _documentoRelacionadoCtrl.clear();
        _dataRecebimentoCtrl.clear();
      });
    }();
  }

  void _removerAutoIntimacaoRelacionado(int index) {
    _formSetState(() {
      _autosIntimacaoRelacionados = [..._autosIntimacaoRelacionados]..removeAt(index);
    });
  }

  Future<List<Map<String, dynamic>>> _listarIntimacoesDoEstabelecimento() async {
    final cnpj = _onlyDigits(_cnpjCtrl.text);
    if (cnpj.isEmpty) return [];
    try {
      final raw = await _api.listarAutoIntimacaoDocumentos(cnpj: cnpj, status: 'TODOS');
      final out = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  String _autoIntimacaoNumeroAnoFromDoc(Map<String, dynamic> doc) {
    final numeroAno = (doc['numero_ano'] ?? doc['numero_auto'] ?? '').toString().trim();
    return numeroAno;
  }

  String _autoIntimacaoDataRecebimentoBrFromDoc(Map<String, dynamic> doc) {
    final payload = (doc['payload'] is Map) ? (doc['payload'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final ai = (payload['auto_intimacao'] is Map) ? (payload['auto_intimacao'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final receb = (ai['recebimento'] is Map) ? (ai['recebimento'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final data = (receb['data'] ?? '').toString().trim();
    return data;
  }

  String? _autoIntimacaoDataRecebimentoIsoFromDoc(Map<String, dynamic> doc) {
    final br = _autoIntimacaoDataRecebimentoBrFromDoc(doc);
    final dt = _tryParseBrDate(br);
    if (dt == null) return null;
    return _formatIsoDate(dt);
  }

  Future<List<Map<String, dynamic>>> _abrirSeletorIntimacoes() async {
    if (_estabelecimentoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o estabelecimento no step Dados.')));
      return [];
    }
    final items = await _listarIntimacoesDoEstabelecimento();
    if (!mounted) return [];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum Auto de Intimação encontrado para este CNPJ.')));
      return [];
    }

    final preSelected = <String>{
      for (final e in _infracaoIntimacoesSelecionadas) (e['id'] ?? '').toString(),
    };

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final checked = <String>{...preSelected};
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Selecionar Autos de Intimação'),
              content: SizedBox(
                width: 520,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (ctx, index) {
                    final doc = items[index];
                    final id = (doc['id'] ?? '').toString();
                    final numeroAno = _autoIntimacaoNumeroAnoFromDoc(doc);
                    final dataReceb = _autoIntimacaoDataRecebimentoBrFromDoc(doc);
                    final status = (doc['status'] ?? '').toString();
                    final subtitleParts = [
                      if (dataReceb.isNotEmpty) 'Recebido em $dataReceb',
                      if (status.isNotEmpty) status,
                    ].join(' • ');
                    return CheckboxListTile(
                      value: checked.contains(id),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            checked.add(id);
                          } else {
                            checked.remove(id);
                          }
                        });
                      },
                      title: Text(numeroAno.isEmpty ? 'Auto de Intimação' : numeroAno),
                      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(checked), child: const Text('Selecionar')),
              ],
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return [];
    final chosen = <Map<String, dynamic>>[];
    for (final doc in items) {
      final id = (doc['id'] ?? '').toString();
      if (!selected.contains(id)) continue;
      chosen.add(doc);
    }
    return chosen;
  }

  void _mergeBaseLegalInfracao(Map<String, dynamic> base) {
    final id = (base['id'] ?? base['base_legal_id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    final origemTipo = (base['origem_tipo'] ?? '').toString().trim();
    final origem = (base['origem'] ?? '').toString().trim();
    final idx = _basesLegaisVinculadas.indexWhere(
      (e) => (e['id'] ?? e['base_legal_id'] ?? '').toString().trim() == id,
    );
    if (idx >= 0) {
      if (origemTipo == 'AUTO_INTIMACAO' && origem.isNotEmpty) {
        final current = Map<String, dynamic>.from(_basesLegaisVinculadas[idx]);
        final origens = <String>[
          ...((current['origens'] is List) ? (current['origens'] as List).map((e) => e.toString()).toList() : const <String>[]),
        ];
        final origemAtual = (current['origem'] ?? '').toString().trim();
        if (origemAtual.isNotEmpty) origens.add(origemAtual);
        origens.add(origem);
        final unique = <String>{};
        final merged = <String>[];
        for (final o in origens) {
          final v = o.trim();
          if (v.isEmpty) continue;
          if (unique.add(v)) merged.add(v);
        }
        current['origens'] = merged;
        current['origem'] = merged.join(', ');
        _basesLegaisVinculadas = [..._basesLegaisVinculadas]..[idx] = current;
      }
      return;
    }
    final next = Map<String, dynamic>.from(base);
    if (origemTipo == 'AUTO_INTIMACAO' && origem.isNotEmpty) {
      next['origens'] = [origem];
    }
    _basesLegaisVinculadas = [..._basesLegaisVinculadas, next];
  }

  Future<void> _importarDadosDasIntimacoesSelecionadas() async {
    if (_tipoDocumento != _tipoAutoInfracao) return;
    if (_infracaoIntimacoesSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ao menos uma intimação para importar.')));
      return;
    }

    final novasBases = <Map<String, dynamic>>[];
    final sb = StringBuffer();

    for (final doc in _infracaoIntimacoesSelecionadas) {
      final numeroAno = _autoIntimacaoNumeroAnoFromDoc(doc);
      final dataRecebBr = _autoIntimacaoDataRecebimentoBrFromDoc(doc);
      final payload = (doc['payload'] is Map) ? (doc['payload'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
      final ai = (payload['auto_intimacao'] is Map) ? (payload['auto_intimacao'] as Map).cast<String, dynamic>() : const <String, dynamic>{};

      final irreg = (ai['descricao_irregularidades'] ?? '').toString().trim();
      final prov = (ai['descricao_providencias'] ?? '').toString().trim();

      sb.writeln('Auto de Intimação nº ${numeroAno.isEmpty ? '-' : numeroAno}${dataRecebBr.isEmpty ? '' : ' — recebido em $dataRecebBr'}:');
      if (irreg.isNotEmpty) sb.writeln(irreg);
      if (prov.isNotEmpty) sb.writeln(prov);
      sb.writeln();

      final basesRaw = ai['bases_legais'];
      var basesList = basesRaw is List ? basesRaw : null;
      if (basesList == null) {
        final baseLegal = (ai['base_legal'] is Map) ? (ai['base_legal'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
        final legacy = baseLegal['bases_legais_vinculadas'] ?? baseLegal['bases_legais'];
        if (legacy is List) basesList = legacy;
      }
      if (basesList == null) {
        final root = payload['bases_legais_vinculadas'];
        if (root is List) basesList = root;
      }
      if (basesList != null) {
        for (final b in basesList) {
          if (b is! Map) continue;
          final m = Map<String, dynamic>.from(b);
          final baseId = (m['base_legal_id'] ?? m['id'] ?? '').toString().trim();
          if (baseId.isEmpty) continue;
          novasBases.add({
            'id': baseId,
            'grupo_id': m['grupo_id'],
            'grupo_descricao': m['grupo'] ?? m['grupo_descricao'],
            'subgrupo_id': m['subgrupo_id'],
            'subgrupo_descricao': m['subgrupo'] ?? m['subgrupo_descricao'],
            'tipo': m['tipo'],
            'numero': m['numero'],
            'ano': m['ano'],
            'esfera': m['esfera'],
            'artigo': m['artigo'],
            'descricao': m['descricao'] ?? m['ementa'],
            'ementa': m['ementa'],
            'observacoes': m['observacoes'],
            'origem_tipo': 'AUTO_INTIMACAO',
            'origem': numeroAno,
            'auto_intimacao_id': doc['id'],
          });
        }
      }
    }

    var basesAdicionadas = 0;
    _formSetState(() {
      final before = [..._basesLegaisVinculadas];
      _basesLegaisVinculadas = before;
      for (final b in novasBases) {
        final len0 = _basesLegaisVinculadas.length;
        _mergeBaseLegalInfracao(b);
        if (_basesLegaisVinculadas.length > len0) basesAdicionadas += 1;
      }

      for (final doc in _infracaoIntimacoesSelecionadas) {
        final numeroAno = _autoIntimacaoNumeroAnoFromDoc(doc);
        final iso = _autoIntimacaoDataRecebimentoIsoFromDoc(doc);
        final exists = _autosIntimacaoRelacionados.any((e) => (e['auto_intimacao_id'] ?? '').toString() == (doc['id'] ?? '').toString());
        if (exists) continue;
        _autosIntimacaoRelacionados = [
          ..._autosIntimacaoRelacionados,
          {
            'auto_intimacao_id': doc['id'],
            'numero_ano': numeroAno,
            'data_recebimento': iso ?? _autoIntimacaoDataRecebimentoBrFromDoc(doc),
          },
        ];
      }

      final textoImportado = sb.toString().trim();
      if (textoImportado.isNotEmpty) {
        if (_especificacaoAtoCtrl.text.trim().isEmpty) {
          _especificacaoAtoCtrl.text = textoImportado;
        } else {
          _especificacaoAtoCtrl.text = '${_especificacaoAtoCtrl.text.trim()}\n\n$textoImportado';
        }
      }
    });

    if (!mounted) return;
    final msg = basesAdicionadas > 0
        ? 'Importação concluída. Bases legais importadas: $basesAdicionadas. Você pode editar antes de salvar.'
        : 'Importação concluída, mas não encontrei bases legais na intimação selecionada. Use "Inserir Base Legal".';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _adicionarProfissionalEquipe() {
    if ((_profissionaisFormKey.currentState?.validate() ?? false) == false) {
      return;
    }
    _formSetState(() {
      _profissionaisEquipe = [
        ..._profissionaisEquipe,
        {
          'codigo_profissional': '${_profissionaisEquipe.length + 1}',
          'nome_profissional': _profissionalEquipeCtrl.text.trim(),
          'codigo_especialidade': _funcaoEquipeCtrl.text.trim(),
          'funcao': _funcaoEquipeCtrl.text.trim(),
        },
      ];
      _profissionalEquipeCtrl.clear();
      _funcaoEquipeCtrl.clear();
    });
    _profissionaisFormKey.currentState?.reset();
  }

  void _removerProfissionalEquipe(int index) {
    _formSetState(() {
      _profissionaisEquipe = [..._profissionaisEquipe]..removeAt(index);
    });
  }

  List<_StepConfig> get _steps => _buildStepsByTipoDocumento(_tipoDocumento);

  bool get _hasTipoDocumentoSelected => _tipoDocumento != null;

  String get _tipoDocumentoLabel => _tipoDocumento == null
      ? 'Tipo de Documento'
      : (_tiposDocumentoLabel[_tipoDocumento] ?? 'Tipo de Documento');

  void _syncTipoDocumentoLabelCtrl() {
    final next = _tipoDocumentoLabel;
    if (_tipoDocumentoLabelCtrl.text != next) {
      _tipoDocumentoLabelCtrl.text = next;
    }
  }

  List<_StepConfig> _buildStepsByTipoDocumento(String? tipoDocumento) {
    final dados = _StepConfig('Dados', _dadosFormKey, true);
    final baseLegal = _StepConfig('Base legal', _baseLegalFormKey, true);
    final descricao = _StepConfig('Descrição', _descricaoFormKey, true);
    final autuado = _StepConfig('Autuado', _autuadoFormKey, true);
    final irregularidades = _StepConfig('Irregularidades', _irregularidadesFormKey, true);
    final providenciasPrazo = _StepConfig('Providências/Prazo', _providenciasPrazoFormKey, true);
    final recebimentoAssinaturas = _StepConfig('Recebimento/Assinaturas', _recebimentoAssinaturasFormKey, true);
    final inspecaoSanitaria = _StepConfig('Relatório Inspeção Sanitária', _inspecaoFormKey, true);
    final profissionaisEquipe = _StepConfig('Profissionais da Equipe', _profissionaisFormKey, true);
    final revisao = _StepConfig('Revisão', _reviewFormKey, true);
    const salvar = _StepConfig('Salvar', null, true);

    if (tipoDocumento == null) {
      return [dados];
    }
    if (tipoDocumento == _tipoImposicaoPenalidade) {
      return [dados];
    }
    if (tipoDocumento == _tipoAutoColeta) {
      return [dados];
    }
    if (tipoDocumento == _tipoInspecaoSanitaria) {
      return [dados];
    }

    switch (tipoDocumento) {
      case _tipoAutoIntimacao:
        return [
          dados,
          autuado,
          baseLegal,
          irregularidades,
          providenciasPrazo,
          recebimentoAssinaturas,
          revisao,
          salvar,
        ];
      case _tipoAutoInfracao:
        return [
          dados,
          baseLegal,
          descricao,
          _StepConfig(_tipoDocumentoLabel, _tipoDocumentoFormKey, true),
          inspecaoSanitaria,
          profissionaisEquipe,
          revisao,
          salvar,
        ];
      case _tipoInspecaoSanitaria:
        return [
          dados,
          baseLegal,
          descricao,
          inspecaoSanitaria,
          profissionaisEquipe,
          revisao,
          salvar,
        ];
      default:
        return [dados];
    }
  }

  Future<void> _onTipoDocumentoChanged(String? nextTipo) async {
    if (nextTipo == _tipoDocumento) return;

    if (nextTipo == null) {
      _formSetState(() {
        _tipoDocumento = null;
        _currentStep = 0;
        _syncTipoDocumentoLabelCtrl();
      });
      return;
    }

    if (_tipoDocumento != null && _hasSpecificTipoData()) {
      final confirmed = await _confirmarTrocaTipoDocumento();
      if (!mounted || !confirmed) return;
    }

    _formSetState(() {
      _clearTipoSpecificData();
      _tipoDocumento = nextTipo;
      _numeroAutoIntimacao = nextTipo == _tipoAutoIntimacao ? (_numeroAutoIntimacao ?? _autoIntimacaoNumeroFallback()) : null;
      _numeroAutoInfracao = nextTipo == _tipoAutoInfracao ? (_numeroAutoInfracao ?? _autoInfracaoNumeroFallback()) : null;
      _currentStep = 0;
      _syncTipoDocumentoLabelCtrl();
    });

    if (mounted && nextTipo == _tipoImposicaoPenalidade) {
      if (_estabelecimentoSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um estabelecimento para abrir a Imposição de Penalidade.')),
        );
        _formSetState(() {
          _tipoDocumento = null;
          _currentStep = 0;
          _syncTipoDocumentoLabelCtrl();
        });
        return;
      }
      final estab = Map<String, dynamic>.from(_estabelecimentoSelecionado as Map);
      await Navigator.pushNamed(
        context,
        '/auto-imposicao-penalidade',
        arguments: {
          'estabelecimento': estab,
        },
      );
      if (!mounted) return;
      _formSetState(() {
        _tipoDocumento = null;
        _currentStep = 0;
        _syncTipoDocumentoLabelCtrl();
      });
      return;
    }

    if (mounted && nextTipo == _tipoAutoColeta) {
      if (_estabelecimentoSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um estabelecimento para abrir o Auto de Coleta.')),
        );
        _formSetState(() {
          _tipoDocumento = null;
          _currentStep = 0;
          _syncTipoDocumentoLabelCtrl();
        });
        return;
      }
      final estab = Map<String, dynamic>.from(_estabelecimentoSelecionado as Map);
      await Navigator.pushNamed(
        context,
        '/auto-coleta-amostra',
        arguments: {
          'estabelecimento': estab,
        },
      );
      if (!mounted) return;
      _formSetState(() {
        _tipoDocumento = null;
        _currentStep = 0;
        _syncTipoDocumentoLabelCtrl();
      });
      return;
    }

    if (mounted && nextTipo == _tipoInspecaoSanitaria) {
      if (_estabelecimentoSelecionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um estabelecimento para abrir o Relatório de Inspeção.')),
        );
        _formSetState(() {
          _tipoDocumento = null;
          _currentStep = 0;
          _syncTipoDocumentoLabelCtrl();
        });
        return;
      }
      final estab = Map<String, dynamic>.from(_estabelecimentoSelecionado as Map);
      await Navigator.pushNamed(
        context,
        '/relatorio-inspecao-sanitario',
        arguments: {
          'estabelecimento': estab,
        },
      );
      if (!mounted) return;
      _formSetState(() {
        _tipoDocumento = null;
        _currentStep = 0;
        _syncTipoDocumentoLabelCtrl();
      });
      return;
    }

    if (mounted && nextTipo == _tipoAutoIntimacao) {
      if (_dataLavraturaCtrl.text.trim().isEmpty) {
        _dataLavraturaCtrl.text = _formatDate(DateTime.now());
      }
      if (_recebimentoDataCtrl.text.trim().isEmpty) {
        _recebimentoDataCtrl.text = _formatDate(DateTime.now());
      }
      if (_recebimentoHoraCtrl.text.trim().isEmpty) {
        _recebimentoHoraCtrl.text = _formatTime(TimeOfDay.now());
      }
      await _prefillDadosVisa();
      if (_estabelecimentoSelecionado != null) {
        _prefillAutuadoFromEstabelecimento(_estabelecimentoSelecionado as Map);
      }
      _recalcularVencimentoPrazo();
      _seedAuditValuesForIntimacao();
    }

    if (mounted && nextTipo == _tipoAutoInfracao) {
      if (_dataLavraturaCtrl.text.trim().isEmpty) {
        _dataLavraturaCtrl.text = _formatDate(DateTime.now());
      }
      await _prefillDadosVisa();
      await _prefillBasesPadraoAutoInfracao();

      if (!mounted || !kIsWeb) return;
      final ano = int.tryParse(_anoCtrl.text.trim()) ?? DateTime.now().year;
      try {
        final numero = await _api.proximoNumeroAutoInfracao(ano);
        if (!mounted) return;
        if (numero != null && numero.trim().isNotEmpty) {
          setState(() => _numeroAutoInfracao = numero);
        }
      } catch (_) {}
    }
  }

  bool _hasSpecificTipoData() {
    return _baseLegalCtrl.text.trim().isNotEmpty ||
        _enquadramentoLegalCtrl.text.trim().isNotEmpty ||
        _artigoCtrl.text.trim().isNotEmpty ||
        _incisoCtrl.text.trim().isNotEmpty ||
        _paragrafoCtrl.text.trim().isNotEmpty ||
        _observacoesLegaisCtrl.text.trim().isNotEmpty ||
        _descricaoIrregularidadesCtrl.text.trim().isNotEmpty ||
        _descricaoProvidenciasCtrl.text.trim().isNotEmpty ||
        _prazoCumprimentoTextoCtrl.text.trim().isNotEmpty ||
        _prazoCumprimentoDataCtrl.text.trim().isNotEmpty ||
        _comentarioFiscalizacaoCtrl.text.trim().isNotEmpty ||
        _especificacaoAtoCtrl.text.trim().isNotEmpty ||
        _dataLavraturaCtrl.text.trim().isNotEmpty ||
        _telefoneVisaCtrl.text.trim().isNotEmpty ||
        _emailVisaCtrl.text.trim().isNotEmpty ||
        _anoRelacionadoCtrl.text.trim().isNotEmpty ||
        _documentoRelacionadoCtrl.text.trim().isNotEmpty ||
        _dataRecebimentoCtrl.text.trim().isNotEmpty ||
        _autuadoNomeCtrl.text.trim().isNotEmpty ||
        _autuadoCpfCnpjCtrl.text.trim().isNotEmpty ||
        _autuadoNomeFantasiaCtrl.text.trim().isNotEmpty ||
        _autuadoEnderecoCompletoCtrl.text.trim().isNotEmpty ||
        _autuadoNumeroCtrl.text.trim().isNotEmpty ||
        _autuadoBairroCtrl.text.trim().isNotEmpty ||
        _autuadoMunicipioCtrl.text.trim().isNotEmpty ||
        _autuadoUfCtrl.text.trim().isNotEmpty ||
        _autuadoProprietarioCtrl.text.trim().isNotEmpty ||
        _autuadoTipoAtividadeCtrl.text.trim().isNotEmpty ||
        _autuadoAlvaraCtrl.text.trim().isNotEmpty ||
        _recebimentoDataCtrl.text.trim().isNotEmpty ||
        _recebimentoHoraCtrl.text.trim().isNotEmpty ||
        _recebimentoResponsavelCtrl.text.trim().isNotEmpty ||
        _responsavelRecusouAssinatura ||
        _testemunha1RecusaCtrl.text.trim().isNotEmpty ||
        _testemunha2RecusaCtrl.text.trim().isNotEmpty ||
        _autoridadeSaudeCtrl.text.trim().isNotEmpty ||
        _autoridadeFuncaoCtrl.text.trim().isNotEmpty ||
        _vinculosRelacionados.isNotEmpty ||
        _tipoAmostra != _tiposAmostra.first;
  }

  Future<bool> _confirmarTrocaTipoDocumento() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trocar tipo de documento'),
        content: const Text(
          'Ao trocar o tipo de documento, os dados específicos do tipo anterior serão limpos. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _govBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _clearTipoSpecificData() {
    _baseLegalCtrl.clear();
    _enquadramentoLegalCtrl.clear();
    _artigoCtrl.clear();
    _incisoCtrl.clear();
    _paragrafoCtrl.clear();
    _observacoesLegaisCtrl.clear();
    _basesLegaisVinculadas = [];
    _autosIntimacaoRelacionados = [];
    _infracaoDesejaImportarIntimacao = null;
    _infracaoIntimacoesSelecionadas = [];
    _descricaoIrregularidadesCtrl.clear();
    _descricaoProvidenciasCtrl.clear();
    _prazoCumprimentoTextoCtrl.clear();
    _prazoCumprimentoDataCtrl.clear();
    _comentarioFiscalizacaoCtrl.clear();
    _especificacaoAtoCtrl.clear();
    _departamento = _departamentos.first;
    _departamentoCtrl.text = _departamento;
    _dataLavraturaCtrl.clear();
    _telefoneVisaCtrl.clear();
    _emailVisaCtrl.clear();
    _semEfeito = false;
    _semEfeitoMotivoCtrl.clear();
    _autuadoNomeCtrl.clear();
    _autuadoCpfCnpjCtrl.clear();
    _autuadoNomeFantasiaCtrl.clear();
    _autuadoEnderecoCompletoCtrl.clear();
    _autuadoNumeroCtrl.clear();
    _autuadoBairroCtrl.clear();
    _autuadoMunicipioCtrl.text = 'Balneário Camboriú';
    _autuadoUfCtrl.text = 'SC';
    _autuadoProprietarioCtrl.clear();
    _autuadoTipoAtividadeCtrl.clear();
    _autuadoAlvaraCtrl.clear();
    _recebimentoDataCtrl.clear();
    _recebimentoHoraCtrl.clear();
    _recebimentoResponsavelCtrl.clear();
    _responsavelRecusouAssinatura = false;
    _testemunha1RecusaCtrl.clear();
    _testemunha2RecusaCtrl.clear();
    _autoridadeSaudeCtrl.clear();
    _autoridadeFuncaoCtrl.clear();
    _assinaturaRecebimento = null;
    _assinaturaTestemunha1 = null;
    _assinaturaTestemunha2 = null;
    _assinaturaAutoridadeSaude = null;
    _auditLastValue.clear();
    _auditLogs.clear();
    _anoRelacionadoCtrl.clear();
    _documentoRelacionadoCtrl.clear();
    _dataRecebimentoCtrl.clear();
    _autuadoNomeCtrl.clear();
    _autuadoCpfCnpjCtrl.clear();
    _autuadoNomeFantasiaCtrl.clear();
    _autuadoEnderecoCompletoCtrl.clear();
    _autuadoNumeroCtrl.clear();
    _autuadoBairroCtrl.clear();
    _autuadoMunicipioCtrl.text = 'Balneário Camboriú';
    _autuadoUfCtrl.text = 'SC';
    _autuadoProprietarioCtrl.clear();
    _autuadoTipoAtividadeCtrl.clear();
    _autuadoAlvaraCtrl.clear();
    _recebimentoDataCtrl.clear();
    _recebimentoHoraCtrl.clear();
    _recebimentoResponsavelCtrl.clear();
    _responsavelRecusouAssinatura = false;
    _testemunha1RecusaCtrl.clear();
    _testemunha2RecusaCtrl.clear();
    _autoridadeSaudeCtrl.clear();
    _autoridadeFuncaoCtrl.clear();
    _assinaturaRecebimento = null;
    _assinaturaTestemunha1 = null;
    _assinaturaTestemunha2 = null;
    _assinaturaAutoridadeSaude = null;
    _auditLastValue.clear();
    _auditLogs.clear();
    _vinculosRelacionados = [];
    _autosIntimacaoRelacionados = [];
    _numeroAutoIntimacao = null;
    _numeroAutoInfracao = null;
    _autoIntimacaoIdOnline = null;
    _autoInfracaoIdOnline = null;
    _semEfeito = false;
    _semEfeitoMotivoCtrl.clear();
    _statusDocumento = 'EM_EDICAO';
    _documentoBloqueado = false;
    _tipoAmostra = _tiposAmostra.first;
    _tipoAmostraCtrl.text = _tipoAmostra;
  }

  bool _validateCurrentStep() {
    final config = _steps[_currentStep];
    final form = config.formKey?.currentState;
    final skipFormValidation = config.title == 'Profissionais da Equipe' && _profissionaisEquipe.isNotEmpty;
    if (form != null && !skipFormValidation && !form.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Há campos obrigatórios pendentes neste step.')),
      );
      return false;
    }
    if (config.title == 'Dados' && _estabelecimentoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um estabelecimento para continuar.')),
      );
      return false;
    }
    if (config.title == 'Dados' && !_hasTipoDocumentoSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de documento para continuar.')),
      );
      return false;
    }
    if (config.title == 'Profissionais da Equipe' && _profissionaisEquipe.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um profissional da equipe.')),
      );
      return false;
    }
    if (config.title == 'Providências/Prazo' && _tipoDocumento == _tipoAutoIntimacao) {
      final erroItens = _validarItensReferenciaPreenchidos();
      if (erroItens != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erroItens)));
        return false;
      }
    }
    if (config.title == _tipoDocumentoLabel && _requiresLinkedDocuments && _vinculosRelacionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um documento relacionado.')),
      );
      return false;
    }
    return true;
  }

  bool get _requiresLinkedDocuments => _tipoDocumento == _tipoImposicaoPenalidade;

  Future<void> _continuar() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _steps.length - 1) {
      _formSetState(() => _currentStep += 1);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Use os botões do step Salvar para concluir.')),
    );
  }

  void _goToStepTitle(String title) {
    final idx = _steps.indexWhere((s) => s.title == title);
    if (idx < 0) return;
    _formSetState(() => _currentStep = idx);
  }

  Map<String, dynamic> _buildPayload() {
    final dataHora = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
      25,
    );
    final dadosEstabelecimento = <String, dynamic>{
      'nome_fantasia': _nomeFantasiaCtrl.text.trim(),
      'cnpj': _onlyDigits(_cnpjCtrl.text),
      'inscricao_municipal': _inscricaoMunicipalCtrl.text.trim(),
      'endereco': _enderecoCtrl.text.trim(),
      'responsavel_legal': _responsavelLegalCtrl.text.trim(),
      'possui_pasta_visa': _possuiPastaVisa,
      'numero_pasta_visa': _possuiPastaVisa ? _numeroPastaVisaCtrl.text.trim() : '',
    };
    final baseLegal = <String, dynamic>{
      'base_legal': _baseLegalCtrl.text.trim(),
      'enquadramento_legal': _enquadramentoLegalCtrl.text.trim(),
      'artigo': _artigoCtrl.text.trim(),
      'inciso': _incisoCtrl.text.trim(),
      'paragrafo': _paragrafoCtrl.text.trim(),
      'observacoes_legais': _observacoesLegaisCtrl.text.trim(),
    };
    final descricao = <String, dynamic>{
      'descricao_irregularidades': _descricaoIrregularidadesCtrl.text.trim(),
      'descricao_providencias': _descricaoProvidenciasCtrl.text.trim(),
      'comentario_fiscalizacao': _comentarioFiscalizacaoCtrl.text.trim(),
      'especificacao_detalhada_ato_ou_fato': _especificacaoAtoCtrl.text.trim(),
    };
    final profissionalLogado = _usuarioNomeLogado.trim().isNotEmpty ? _usuarioNomeLogado.trim() : _profissionalCtrl.text.trim();
    final inspecaoSanitaria = <String, dynamic>{
      'situacao_encontrada': _situacaoEncontradaCtrl.text.trim(),
      'observacoes': _observacoesInspecaoCtrl.text.trim(),
      'estabelecimento_id': (_estabelecimentoId ?? '').toString(),
      'profissional': profissionalLogado,
      'data_hora': _formatBackendDateTime(dataHora),
      'tipo_documento': _payloadTipoDocumento[_tipoDocumento],
    };
    final payload = <String, dynamic>{
      'ano': _anoCtrl.text.trim(),
      'data_hora': _formatBackendDateTime(dataHora),
      'estabelecimento_id': (_estabelecimentoId ?? '').toString(),
      'tipo_documento': _payloadTipoDocumento[_tipoDocumento],
      'responsavel_tecnico_id': _usuarioNomeLogado.trim().isNotEmpty ? _usuarioNomeLogado.trim() : _responsavelTecnicoCtrl.text.trim(),
      'profissional_id': profissionalLogado,
      'testemunha_1': null,
      'testemunha_2': null,
      'dados_estabelecimento': dadosEstabelecimento,
      'inspecao_sanitaria': inspecaoSanitaria,
      'profissionais_equipe': _profissionaisEquipe,
      'bases_legais_vinculadas': _basesLegaisVinculadas,
      'status': _statusDocumento,
      'status_documento': _statusDocumento,
      'status_sincronizacao': kIsWeb ? 'ENVIADO' : 'PENDENTE_SINCRONIZACAO',
    };
    if (_tipoDocumento == _tipoAutoIntimacao) {
      payload.remove('inspecao_sanitaria');
    }
    switch (_tipoDocumento) {
      case _tipoAutoIntimacao:
        final autuado = <String, dynamic>{
          'nome': _autuadoNomeCtrl.text.trim(),
          'cnpj_cpf': _onlyDigits(_autuadoCpfCnpjCtrl.text),
          'cnpj_cpf_formatado': _autuadoCpfCnpjCtrl.text.trim(),
          'nome_fantasia': _autuadoNomeFantasiaCtrl.text.trim(),
          'endereco_completo': _autuadoEnderecoCompletoCtrl.text.trim(),
          'numero': _autuadoNumeroCtrl.text.trim(),
          'bairro': _autuadoBairroCtrl.text.trim(),
          'municipio': _autuadoMunicipioCtrl.text.trim(),
          'uf': _autuadoUfCtrl.text.trim(),
          'proprietario_responsavel': _autuadoProprietarioCtrl.text.trim(),
          'tipo_atividade': _autuadoTipoAtividadeCtrl.text.trim(),
          'alvara_pasta_visa': _autuadoAlvaraCtrl.text.trim(),
        };
        final recebimento = <String, dynamic>{
          'data': _recebimentoDataCtrl.text.trim(),
          'hora': _recebimentoHoraCtrl.text.trim(),
          'responsavel': _recebimentoResponsavelCtrl.text.trim(),
          'assinatura_base64': _assinaturaRecebimento == null ? null : base64Encode(_assinaturaRecebimento!),
        };
        final recusa = <String, dynamic>{
          'responsavel_recusou_assinatura': _responsavelRecusouAssinatura,
          'testemunha_1': _testemunha1RecusaCtrl.text.trim(),
          'assinatura_testemunha_1_base64': _assinaturaTestemunha1 == null ? null : base64Encode(_assinaturaTestemunha1!),
          'testemunha_2': _testemunha2RecusaCtrl.text.trim(),
          'assinatura_testemunha_2_base64': _assinaturaTestemunha2 == null ? null : base64Encode(_assinaturaTestemunha2!),
        };
        final prazoDias = int.tryParse(_prazoCumprimentoDiasCtrl.text.trim());
        final dataLavratura = _tryParseBrDate(_dataLavraturaCtrl.text) ?? _selectedDate;
        final vencimento = (prazoDias == null || prazoDias <= 0) ? null : (_tryParseBrDate(_vencimentoPrazoCtrl.text) ?? dataLavratura);

        final itensReferencia = _itensReferencia.map((it) {
          final m = Map<String, dynamic>.from(it);
          final id = (m['item_referencia_id'] ?? m['base_legal_id'] ?? '').toString().trim();
          return {
            'item_referencia_id': id,
            'descricao': (m['descricao'] ?? '').toString().trim(),
            'base_legal_id': (m['base_legal_id'] ?? id).toString().trim(),
            'descricao_irregularidade': (m['descricao_irregularidade'] ?? '').toString().trim(),
            'descricao_providencia': (m['descricao_providencia'] ?? '').toString().trim(),
            'prazo_dias': m['prazo_dias'],
            'data_vencimento': (m['data_vencimento'] ?? '').toString().trim(),
            'prazo_alterado_manual': m['prazo_alterado_manual'] == true,
          };
        }).where((e) => (e['item_referencia_id'] ?? '').toString().trim().isNotEmpty).toList();

        final prazosExigencias = (_itensReferencia.isNotEmpty ? _itensReferencia : _prazosExigencias).map((p) {
          final m = Map<String, dynamic>.from(p);
          final ref = (m['descricao'] ?? m['referencia'] ?? '').toString().trim();
          return {
            'referencia': ref,
            'prazo_dias': m['prazo_dias'],
            'data_vencimento': (m['data_vencimento'] ?? '').toString().trim(),
          };
        }).where((e) => (e['referencia'] ?? '').toString().trim().isNotEmpty).toList();

        final basesLegais = <Map<String, dynamic>>[];
        final seenBaseLegalIds = <String>{};
        for (final v in _basesLegaisVinculadas) {
          final m = Map<String, dynamic>.from(v);
          final tipo = (m['tipo'] ?? '').toString().trim();
          final numero = (m['numero'] ?? '').toString().trim();
          final ano = (m['ano'] ?? '').toString().trim();
          final esfera = (m['esfera'] ?? '').toString().trim();
          final baseLegalManual = (m['base_legal'] ?? '').toString().trim();
          final baseLegalTitulo = [tipo, [numero, ano].where((e) => e.isNotEmpty).join('/'), esfera.isEmpty ? '' : '($esfera)']
              .where((e) => e.trim().isNotEmpty)
              .join(' ')
              .trim();
          final baseLegalId = (m['id'] ?? m['base_legal_id'] ?? '').toString().trim();
          if (baseLegalId.isEmpty) continue;
          if (!seenBaseLegalIds.add(baseLegalId)) continue;
          basesLegais.add({
            'grupo_id': (m['grupo_id'] ?? '').toString(),
            'grupo': (m['grupo_descricao'] ?? '').toString(),
            'subgrupo_id': (m['subgrupo_id'] ?? '').toString(),
            'subgrupo': (m['subgrupo_descricao'] ?? '').toString(),
            'base_legal_id': baseLegalId,
            'base_legal': baseLegalManual.isNotEmpty ? baseLegalManual : baseLegalTitulo,
            'artigo': (m['artigo'] ?? '').toString(),
            'inciso': (m['inciso'] ?? '').toString(),
            'paragrafo': (m['paragrafo'] ?? '').toString(),
            'descricao': (m['descricao'] ?? '').toString(),
            'ementa': (m['ementa'] ?? '').toString(),
            'observacoes': (m['observacoes'] ?? '').toString(),
            'origem': (m['origem'] ?? 'MANUAL').toString(),
          });
        }
        final autoridades = _autoridadesSaude.map((a) {
          return {
            'nome': a.nomeCtrl.text.trim(),
            'funcao': a.funcaoCtrl.text.trim(),
            'assinatura_base64': a.assinatura == null ? null : base64Encode(a.assinatura!),
          };
        }).toList();
        payload['auto_intimacao'] = <String, dynamic>{
          'numero_auto': (_numeroAutoIntimacao ?? '').trim().isEmpty ? _autoIntimacaoNumeroFallback() : _numeroAutoIntimacao,
          'tipo_documento': 'AUTO_INTIMACAO',
          'data_lavratura': _formatIsoDate(dataLavratura),
          'prazo_dias': _itensReferencia.isNotEmpty ? null : prazoDias,
          'data_vencimento': _itensReferencia.isNotEmpty ? null : (vencimento == null ? null : _formatIsoDate(vencimento)),
          'prazos_exigencias': prazosExigencias,
          'itens_referencia': itensReferencia,
          'dados_visa': {
            'setor': _departamento,
            'telefone': _telefoneVisaCtrl.text.trim(),
            'email': _emailVisaCtrl.text.trim(),
          },
          'bases_legais': basesLegais,
          'descricao_irregularidades': descricao['descricao_irregularidades'],
          'descricao_providencias': descricao['descricao_providencias'],
          'comentario_relatorio_interno': _comentarioFiscalizacaoCtrl.text.trim(),
          'departamento_vigilancia': _departamento,
          'telefone_visa': _telefoneVisaCtrl.text.trim(),
          'email_visa': _emailVisaCtrl.text.trim(),
          'sem_efeito': _semEfeito,
          'sem_efeito_motivo': _semEfeitoMotivoCtrl.text.trim(),
          'base_legal': baseLegal,
          'autuado': autuado,
          'recebimento': recebimento,
          'recusa': recusa,
          'autoridades_saude': autoridades,
          'logs': _auditLogs,
        };
        break;
      case _tipoAutoInfracao:
        final basesLegaisInfracao = _basesLegaisVinculadas.map((v) {
          final m = Map<String, dynamic>.from(v);
          final id = (m['id'] ?? m['base_legal_id'] ?? '').toString().trim();
          final origemTipo = (m['origem_tipo'] ?? 'MANUAL').toString().trim().toUpperCase();
          final origem = origemTipo == 'AUTO_INTIMACAO' ? 'AUTO_INTIMACAO' : (origemTipo == 'PADRAO' ? 'PADRAO' : 'MANUAL');
          final out = <String, dynamic>{
            'base_legal_id': id,
            'origem': origem,
          };
          if (origem == 'AUTO_INTIMACAO') out['auto_intimacao_id'] = m['auto_intimacao_id'];
          return out;
        }).where((e) => (e['base_legal_id'] ?? '').toString().trim().isNotEmpty).toList();

        final intimacoesRelacionadas = _autosIntimacaoRelacionados.map((e) {
          final m = Map<String, dynamic>.from(e);
          return {
            'auto_intimacao_id': m['auto_intimacao_id'],
            'numero_ano': (m['numero_ano'] ?? '').toString().trim(),
            'data_recebimento': (m['data_recebimento'] ?? '').toString().trim(),
          };
        }).where((e) => (e['numero_ano'] ?? '').toString().trim().isNotEmpty).toList();

        payload['auto_infracao'] = <String, dynamic>{
          'numero_auto': (_numeroAutoInfracao ?? '').trim().isEmpty ? _autoInfracaoNumeroFallback() : _numeroAutoInfracao,
          'tipo_documento': 'AUTO_INFRACAO',
          'estabelecimento_id': _estabelecimentoId,
          'intimacoes_relacionadas': intimacoesRelacionadas,
          'bases_legais': basesLegaisInfracao,
          'especificacao_detalhada': _especificacaoAtoCtrl.text.trim(),
          'departamento_vigilancia': _departamento,
          'data_lavratura': _dataLavraturaCtrl.text.trim(),
          'telefone_visa': _telefoneVisaCtrl.text.trim(),
          'email_visa': _emailVisaCtrl.text.trim(),
          'sem_efeito': _semEfeito,
          'sem_efeito_motivo': _semEfeitoMotivoCtrl.text.trim(),
          'base_legal': baseLegal,
          'especificacao_detalhada_ato_ou_fato': _especificacaoAtoCtrl.text.trim(),
          'autos_intimacao_relacionados': _autosIntimacaoRelacionados,
        };
        break;
      case _tipoImposicaoPenalidade:
        payload['imposicao_penalidade'] = <String, dynamic>{
          'enquadramento_legal': baseLegal['enquadramento_legal'],
          'especificacao_detalhada_penalidade': descricao['especificacao_detalhada_ato_ou_fato'],
          'comentario_fiscalizacao': descricao['comentario_fiscalizacao'],
          'descricao_providencias': descricao['descricao_providencias'],
          'departamento_vigilancia': _departamento,
          'data_lavratura': _dataLavraturaCtrl.text.trim(),
          'documentos_relacionados': _vinculosRelacionados,
          'base_legal': baseLegal,
        };
        break;
      case _tipoAutoColeta:
        payload['auto_coleta_amostra'] = <String, dynamic>{
          'tipo_amostra': _tipoAmostra,
          'departamento_vigilancia': _departamento,
          'data_lavratura': _dataLavraturaCtrl.text.trim(),
        };
        break;
      case _tipoInspecaoSanitaria:
        break;
    }
    return payload;
  }

  Future<bool> _perguntarAbrirRelatorioInspecao() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Relatório de Inspeção Sanitária'),
        content: const Text('Deseja abrir um Relatório de Inspeção Sanitária para complementar este registro?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não, finalizar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sim, abrir relatório')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _abrirRelatorioInspecaoAposFinalizar(Map<String, dynamic> payload) async {
    final estab = _estabelecimentoSelecionado == null ? null : Map<String, dynamic>.from(_estabelecimentoSelecionado as Map);
    final vinculo = <String, dynamic>{
      'tipo_documento': _payloadTipoDocumento[_tipoDocumento],
      'numero_ano': payload['numero_ano'] ?? payload['numero_auto'] ?? payload['numero'] ?? _buildNumeroAno(),
      'auto_id_online': _tipoDocumento == _tipoAutoIntimacao ? _autoIntimacaoIdOnline : (_tipoDocumento == _tipoAutoInfracao ? _autoInfracaoIdOnline : null),
      'payload': payload,
    };
    await Navigator.pushNamed(
      context,
      '/relatorio-inspecao-sanitario',
      arguments: {
        if (estab != null) 'estabelecimento': estab,
        'documento_vinculado': vinculo,
      },
    );
  }

  Future<void> _salvarDocumento({required String statusDocumento}) async {
    // #region debug-point D:salvar-documento
    unawaited(
      _debugReport(
        hypothesisId: 'D',
        location: 'auto_termo_page.dart:_salvarDocumento',
        msg: '[DEBUG] Inicio do fluxo de salvar documento',
        data: {
          'tipoDocumento': _tipoDocumento,
          'statusDocumento': statusDocumento,
          'estabelecimentoSelecionado': _estabelecimentoSelecionado != null,
          'itensReferenciaCount': _itensReferencia.length,
        },
      ),
    );
    // #endregion
    if (!_hasTipoDocumentoSelected) {
      // #region debug-point D:salvar-documento
      unawaited(
        _debugReport(
          hypothesisId: 'D',
          location: 'auto_termo_page.dart:_salvarDocumento',
          msg: '[DEBUG] Salvar bloqueado por tipo de documento ausente',
          data: {'statusDocumento': statusDocumento},
        ),
      );
      // #endregion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de documento para continuar.')),
      );
      return;
    }
    if ((_tipoDocumento == _tipoAutoInfracao || _tipoDocumento == _tipoAutoIntimacao) &&
        statusDocumento == 'SEM_EFEITO' &&
        _semEfeitoMotivoCtrl.text.trim().isEmpty) {
      // #region debug-point D:salvar-documento
      unawaited(
        _debugReport(
          hypothesisId: 'D',
          location: 'auto_termo_page.dart:_salvarDocumento',
          msg: '[DEBUG] Salvar bloqueado por justificativa de sem efeito ausente',
          data: {'tipoDocumento': _tipoDocumento},
        ),
      );
      // #endregion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a justificativa para "Não Emitido / Sem Efeito".')),
      );
      return;
    }
    if (!_steps.where((e) => e.formKey != null).every((e) => e.formKey!.currentState?.validate() ?? true)) {
      // #region debug-point D:salvar-documento
      unawaited(
        _debugReport(
          hypothesisId: 'D',
          location: 'auto_termo_page.dart:_salvarDocumento',
          msg: '[DEBUG] Salvar bloqueado por validacao de formulario',
          data: {
            'tipoDocumento': _tipoDocumento,
            'stepsComFormulario': _steps.where((e) => e.formKey != null).length,
          },
        ),
      );
      // #endregion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise os campos obrigatórios antes de salvar.')),
      );
      return;
    }
    if (_tipoDocumento == _tipoAutoIntimacao) {
      final erroItens = _validarItensReferenciaPreenchidos();
      if (erroItens != null) {
        // #region debug-point D:salvar-documento
        unawaited(
          _debugReport(
            hypothesisId: 'D',
            location: 'auto_termo_page.dart:_salvarDocumento',
            msg: '[DEBUG] Salvar bloqueado por itens de referencia incompletos',
            data: {
              'erroItens': erroItens,
              'itensReferenciaCount': _itensReferencia.length,
            },
          ),
        );
        // #endregion
        _goToStepTitle('Providências/Prazo');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erroItens)));
        return;
      }
    }
    if (_tipoDocumento == _tipoAutoIntimacao) {
      if (_assinaturaRecebimento == null) {
        _goToStepTitle('Recebimento/Assinaturas');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assinatura do recebimento é obrigatória.')),
        );
        return;
      }
      if (_autoridadesSaude.isEmpty || _autoridadesSaude.any((a) => a.assinatura == null)) {
        _goToStepTitle('Recebimento/Assinaturas');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assinatura da Autoridade de Saúde é obrigatória.')),
        );
        return;
      }
      if (_responsavelRecusouAssinatura) {
        if (_assinaturaTestemunha1 == null || _assinaturaTestemunha2 == null) {
          _goToStepTitle('Recebimento/Assinaturas');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assinaturas das testemunhas são obrigatórias em caso de recusa.')),
          );
          return;
        }
      }
    }
    if (_estabelecimentoSelecionado == null) {
      // #region debug-point D:salvar-documento
      unawaited(
        _debugReport(
          hypothesisId: 'D',
          location: 'auto_termo_page.dart:_salvarDocumento',
          msg: '[DEBUG] Salvar bloqueado por estabelecimento ausente',
          data: {'tipoDocumento': _tipoDocumento},
        ),
      );
      // #endregion
      _goToStepTitle('Dados');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um estabelecimento antes de salvar.')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _statusDocumento = statusDocumento;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final payload = _buildPayload();
    // #region debug-point D:salvar-documento
    unawaited(
      _debugReport(
        hypothesisId: 'D',
        location: 'auto_termo_page.dart:_salvarDocumento',
        msg: '[DEBUG] Payload gerado para salvar documento',
        data: {
          'tipoDocumento': _tipoDocumento,
          'statusDocumento': statusDocumento,
          'payloadKeys': payload.keys.take(16).toList(),
        },
      ),
    );
    // #endregion
    try {
      if (kIsWeb) {
        try {
          if (_tipoDocumento == _tipoAutoInfracao) {
            final ano = int.tryParse(payload['ano']?.toString() ?? '') ?? DateTime.now().year;
            Map<String, dynamic> saved;
            if (_autoInfracaoIdOnline == null) {
              saved = await _api.salvarAutoInfracao(
                ano: ano,
                status: statusDocumento,
                dados: payload,
                dispositivo: 'Flutter Web',
              );
              final id = int.tryParse((saved['id'] ?? '').toString());
              if (id != null) _autoInfracaoIdOnline = id;
            } else {
              saved = await _api.atualizarAutoInfracao(
                id: _autoInfracaoIdOnline!,
                status: statusDocumento,
                dados: payload,
                dispositivo: 'Flutter Web',
              );
            }
            final numero = (saved['numero'] ?? '').toString().trim();
            if (numero.isNotEmpty) {
              _numeroAutoInfracao = numero;
            }
            if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
              _documentoBloqueado = true;
            }
          } else if (_tipoDocumento == _tipoAutoIntimacao) {
            final ano = int.tryParse(payload['ano']?.toString() ?? '') ?? DateTime.now().year;
            Map<String, dynamic> saved;
            final logs = _auditLogs.map((e) => Map<String, dynamic>.from(e)).toList();
            if (_autoIntimacaoIdOnline == null) {
              saved = await _api.salvarAutoIntimacao(
                ano: ano,
                status: statusDocumento,
                dados: payload,
                dispositivo: 'Flutter Web',
                logs: logs,
              );
              final id = int.tryParse((saved['id'] ?? '').toString());
              if (id != null) _autoIntimacaoIdOnline = id;
            } else {
              saved = await _api.atualizarAutoIntimacao(
                id: _autoIntimacaoIdOnline!,
                status: statusDocumento,
                dados: payload,
                dispositivo: 'Flutter Web',
                logs: logs,
              );
            }
            final numero = (saved['numero'] ?? '').toString().trim();
            if (numero.isNotEmpty) {
              _numeroAutoIntimacao = numero;
              payload['numero_ano'] = numero;
              final ai = payload['auto_intimacao'];
              if (ai is Map) {
                final updatedAi = Map<String, dynamic>.from(ai);
                updatedAi['numero_auto'] = numero;
                payload['auto_intimacao'] = updatedAi;
              }
            }
            if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
              _documentoBloqueado = true;
            }
          } else {
            final sendPayload = <String, dynamic>{
              ...payload,
              'numero_ano': _buildNumeroAno(),
            };
            await _api.salvarAutoTermo(sendPayload);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                statusDocumento == 'FINALIZADO'
                    ? 'Documento salvo e finalizado.'
                    : statusDocumento == 'SEM_EFEITO'
                        ? 'Documento salvo como Sem Efeito.'
                        : 'Documento salvo como rascunho.',
              ),
            ),
          );
          if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
            await _loadDocumentos();
          } else {
            await _loadDocumentos();
          }
          if (!mounted) return;
          if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
            final abrir = _tipoDocumento == _tipoAutoInfracao ? true : await _perguntarAbrirRelatorioInspecao();
            if (!mounted) return;
            if (abrir) {
              await _abrirRelatorioInspecaoAposFinalizar(payload);
              if (!mounted) return;
            }
            _resetForm();
            _prefillUsuarioLogado();
          }
          return;
        } on DioException catch (e) {
          if (!mounted) return;
          final code = e.response?.statusCode;
          final data = e.response?.data;
          final msg = data is Map
              ? (data['error'] ?? data['message'] ?? '').toString().trim()
              : data?.toString().trim() ?? '';
          final suffix = [
            if (code != null) 'HTTP $code',
            if (msg.isNotEmpty) msg,
          ].join(' • ');
          debugPrint('Falha ao enviar: $suffix');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(suffix.isEmpty ? 'Falha ao enviar. Verifique a conexão e tente novamente.' : 'Falha ao enviar. $suffix')),
          );
          return;
        } catch (e) {
          if (!mounted) return;
          debugPrint('Falha ao enviar: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao enviar. Verifique a conexão e tente novamente.')),
          );
          return;
        }
      }
      try {
        final baseLegalJson = jsonEncode({
          'base_legal': _baseLegalCtrl.text.trim(),
          'enquadramento_legal': _enquadramentoLegalCtrl.text.trim(),
          'artigo': _artigoCtrl.text.trim(),
          'inciso': _incisoCtrl.text.trim(),
          'paragrafo': _paragrafoCtrl.text.trim(),
          'observacoes_legais': _observacoesLegaisCtrl.text.trim(),
        });
        final descricaoJson = jsonEncode({
          'descricao_irregularidades': _descricaoIrregularidadesCtrl.text.trim(),
          'descricao_providencias': _descricaoProvidenciasCtrl.text.trim(),
          'comentario_fiscalizacao': _comentarioFiscalizacaoCtrl.text.trim(),
          'especificacao_detalhada_ato_ou_fato': _especificacaoAtoCtrl.text.trim(),
        });
        final autoIntimacaoJson = _tipoDocumento == _tipoAutoIntimacao ? jsonEncode(payload['auto_intimacao']) : null;
        final autoInfracaoJson = _tipoDocumento == _tipoAutoInfracao ? jsonEncode(payload['auto_infracao']) : null;
        final imposicaoPenalidadeJson =
            _tipoDocumento == _tipoImposicaoPenalidade ? jsonEncode(payload['imposicao_penalidade']) : null;
        final autoColetaJson = _tipoDocumento == _tipoAutoColeta ? jsonEncode(payload['auto_coleta_amostra']) : null;

        final db = await LocalDb.instance;
        final insertedId = await db.insert('autos_sanitarios', {
          'tipo_auto': _tipoDocumento,
          'numero_auto': _buildNumeroAno(),
          'numero_ano': _buildNumeroAno(),
          'estabelecimento_id': _estabelecimentoId ?? 0,
          'fiscal_id': 0,
          'data': _formatBackendDate(_selectedDate),
          'data_hora': payload['data_hora'],
          'descricao': _descricaoIrregularidadesCtrl.text.trim(),
          'fundamentacao_legal': _baseLegalCtrl.text.trim(),
          'observacoes': _observacoesInspecaoCtrl.text.trim(),
          'status': statusDocumento,
          'ano': payload['ano'],
          'tipo_documento': payload['tipo_documento'],
          'responsavel_tecnico_id': payload['responsavel_tecnico_id'],
          'profissional_id': payload['profissional_id'],
          'testemunha_1': payload['testemunha_1'],
          'testemunha_2': payload['testemunha_2'],
          'dados_estabelecimento': jsonEncode(payload['dados_estabelecimento']),
          'base_legal_json': baseLegalJson,
          'descricao_json': descricaoJson,
          'auto_intimacao_json': autoIntimacaoJson,
          'auto_infracao_json': autoInfracaoJson,
          'imposicao_penalidade_json': imposicaoPenalidadeJson,
          'auto_coleta_amostra_json': autoColetaJson,
          'inspecao_sanitaria_json': jsonEncode(payload['inspecao_sanitaria']),
          'profissionais_equipe_json': jsonEncode(payload['profissionais_equipe']),
          'payload_json': jsonEncode(payload),
          'data_documento': _formatDate(_selectedDate),
          'profissional_nome': _profissionalCtrl.text.trim(),
          'estabelecimento_nome': _nomeFantasiaCtrl.text.trim(),
          'estabelecimento_cnpj': _onlyDigits(_cnpjCtrl.text),
          'status_sincronizacao': 'PENDENTE_SINCRONIZACAO',
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              statusDocumento == 'FINALIZADO'
                  ? 'Documento salvo e finalizado (pendente de sincronização).'
                  : statusDocumento == 'SEM_EFEITO'
                      ? 'Documento salvo como Sem Efeito (pendente de sincronização).'
                      : 'Documento salvo como rascunho (pendente de sincronização).',
            ),
          ),
        );
        if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
          setState(() => _documentoBloqueado = true);
          final abrir = _tipoDocumento == _tipoAutoInfracao ? true : await _perguntarAbrirRelatorioInspecao();
          if (!mounted) return;
          if (abrir) {
            await _abrirRelatorioInspecaoAposFinalizar(payload);
            if (!mounted) return;
          }
          if (!mounted) return;
          _resetForm();
          _prefillUsuarioLogado();
        } else {
          _resetForm();
        }
        await _loadDocumentos();
      } catch (e, st) {
        debugPrint('Falha ao salvar offline: $e');
        unawaited(
          _debugReport(
            hypothesisId: 'D',
            location: 'auto_termo_page.dart:_salvarDocumento',
            msg: '[DEBUG] Excecao ao salvar offline',
            data: {
              'error': e.toString(),
              'stack': st.toString().split('\n').take(16).join('\n'),
              'tipoDocumento': _tipoDocumento,
              'statusDocumento': statusDocumento,
            },
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao salvar offline. Tente novamente.')),
        );
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _resetForm() {
    _estabSearchCtrl.clear();
    _nomeFantasiaCtrl.clear();
    _cnpjCtrl.clear();
    _inscricaoMunicipalCtrl.clear();
    _enderecoCtrl.clear();
    _responsavelLegalCtrl.clear();
    _responsavelTecnicoCtrl.clear();
    _testemunha1Ctrl.clear();
    _testemunha2Ctrl.clear();
    _profissionalCtrl.clear();
    _baseLegalCtrl.clear();
    _enquadramentoLegalCtrl.clear();
    _artigoCtrl.clear();
    _incisoCtrl.clear();
    _paragrafoCtrl.clear();
    _observacoesLegaisCtrl.clear();
    _basesLegaisVinculadas = [];
    _descricaoIrregularidadesCtrl.clear();
    _descricaoProvidenciasCtrl.clear();
    _prazoCumprimentoTextoCtrl.clear();
    _prazoCumprimentoDataCtrl.clear();
    _prazoCumprimentoDiasCtrl.clear();
    _vencimentoPrazoCtrl.clear();
    _prazoExigenciaReferenciaCtrl.clear();
    _prazoExigenciaDiasCtrl.clear();
    _prazoExigenciaVencimentoCtrl.clear();
    _prazoExigenciaBaseLegalIds = [];
    _prazosExigencias = [];
    _itensReferencia = [];
    _itensReferenciaCtrl.clear();
    _cnaesAutuado = [];
    _comentarioFiscalizacaoCtrl.clear();
    _especificacaoAtoCtrl.clear();
    _dataLavraturaCtrl.clear();
    _telefoneVisaCtrl.clear();
    _emailVisaCtrl.clear();
    _anoRelacionadoCtrl.clear();
    _documentoRelacionadoCtrl.clear();
    _dataRecebimentoCtrl.clear();
    _situacaoEncontradaCtrl.clear();
    _observacoesInspecaoCtrl.clear();
    _profissionalEquipeCtrl.clear();
    _funcaoEquipeCtrl.clear();
    _estabResults = [];
    _vinculosRelacionados = [];
    _autosIntimacaoRelacionados = [];
    _profissionaisEquipe = [];
    _estabelecimentoId = null;
    _estabelecimentoSelecionado = null;
    _currentStep = 0;
    _tipoDocumento = null;
    _numeroAutoIntimacao = null;
    _numeroAutoInfracao = null;
    _autoIntimacaoIdOnline = null;
    _autoInfracaoIdOnline = null;
    _statusDocumento = 'EM_EDICAO';
    _documentoBloqueado = false;
    _responsavelRecusouAssinatura = false;
    _semEfeito = false;
    _assinaturaRecebimento = null;
    _assinaturaTestemunha1 = null;
    _assinaturaTestemunha2 = null;
    _assinaturaAutoridadeSaude = null;
    _departamento = _departamentos.first;
    _tipoAmostra = _tiposAmostra.first;
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _syncDateTimeFields();
    for (final a in _autoridadesSaude) {
      a.dispose();
    }
    _autoridadesSaude
      ..clear()
      ..add(_AutoridadeSaudeItem());
  }

  String _buildNumeroAno() {
    if (_tipoDocumento == _tipoAutoIntimacao) {
      final numero = (_numeroAutoIntimacao ?? '').trim();
      if (numero.isNotEmpty) return numero;
    }
    if (_tipoDocumento == _tipoAutoInfracao) {
      final numero = (_numeroAutoInfracao ?? '').trim();
      if (numero.isNotEmpty) return numero;
    }
    final prefix = _tipoNumeroPrefixo[_tipoDocumento] ?? 'DOC';
    return '$prefix/${_anoCtrl.text.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1200;
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('Auto de Intimação'),
        backgroundColor: _govBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadingList ? null : _buscarDocumentos,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sincronizar pendentes',
            onPressed: _syncingPendentes ? null : (kIsWeb ? _sincronizarPendentesWeb : _sincronizarPendentes),
            icon: Icon(_syncingPendentes ? Icons.sync : Icons.cloud_upload_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Limpar filtros',
            onPressed: _limparFiltros,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirNovoCadastro,
        backgroundColor: _govBlue,
        foregroundColor: Colors.white,
        tooltip: 'Novo Auto/Termo',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: desktop ? 10 : 12,
              child: _buildHomeContent(desktop: desktop),
            ),
            if (desktop)
              Expanded(
                flex: 11,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: _buildFormPanel(),
                ),
              ),
          ],
        ),
      ),
      bottomSheet: null,
    );
  }

  Widget _buildHomeContent({required bool desktop}) {
    return RefreshIndicator(
      onRefresh: _buscarDocumentos,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, desktop ? 16 : 96),
        children: [
          _buildFilterCard(desktop: desktop),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildLista(),
        ],
      ),
    );
  }

  void _abrirNovoCadastro() {
    _resetForm();
    _formSetState(() {});
    _openFormIfMobile();
  }

  void _openFormIfMobile() {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1200;
    if (desktop) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: _lightBg,
          appBar: AppBar(
            title: const Text('Dados'),
            backgroundColor: _govBlue,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: ValueListenableBuilder<int>(
              valueListenable: _formRebuildTick,
              builder: (context, tick, _) => _buildFormPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard({required bool desktop}) {
    final compact = !desktop;
    return OfficialSectionCard(
      title: 'Consulta de Autos/Termos',
      icon: Icons.filter_alt_outlined,
      child: Column(
        children: [
          _responsiveRow([
            OfficialTextField(
              controller: _searchCtrl,
              label: 'Busca geral',
              hint: 'Busque por CNPJ, empresa, numero, ano ou tipo',
              suffixIcon: const Icon(Icons.search),
            ),
            OfficialDropdownField.fromStrings(
              value: _tipoFiltro,
              items: _tiposFiltroLista,
              onChanged: (value) => setState(() => _tipoFiltro = value ?? 'Todos'),
              label: 'Tipo de Documento',
            ),
          ]),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: _maisFiltrosExpandidos,
              onExpansionChanged: (value) => setState(() => _maisFiltrosExpandidos = value),
              leading: const Icon(Icons.tune_outlined, color: _govBlue),
              title: const Text(
                'Mais filtros',
                style: TextStyle(fontWeight: FontWeight.w700, color: _darkText),
              ),
              subtitle: const Text('Status e período'),
              children: [
                const SizedBox(height: 8),
                _responsiveRow([
                  OfficialDropdownField.fromStrings(
                    value: _statusFiltro,
                    items: _statusFiltroOpcoes,
                    onChanged: (value) => setState(() => _statusFiltro = value ?? 'Todos'),
                    label: 'Status',
                  ),
                  OfficialDateField(
                    value: _filtroDataInicio,
                    label: 'Periodo inicial',
                    hint: 'Selecione a data',
                    onChanged: (value) => setState(() => _filtroDataInicio = value),
                  ),
                ]),
                const SizedBox(height: 12),
                _responsiveRow([
                  OfficialDateField(
                    value: _filtroDataFim,
                    label: 'Periodo final',
                    hint: 'Selecione a data',
                    onChanged: (value) => setState(() => _filtroDataFim = value),
                  ),
                  const SizedBox.shrink(),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _limparFiltros,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Limpar filtros'),
              ),
              ElevatedButton.icon(
                onPressed: _loadingList ? null : _buscarDocumentos,
                style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.search),
                label: Text(_loadingList && compact ? 'Buscando...' : 'Buscar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final total = _documentosFiltrados.length;
    final emitidos = _countByStatus('Emitido') + _countByStatus('Sincronizado');
    final pendentes = _countByStatus('Pendente de sincronizacao');
    final rascunhos = _countByStatus('Rascunho');
    final cancelados = _countByStatus('Cancelado');
    final cards = [
      ('Total', total, _govBlue),
      ('Emitidos', emitidos, const Color(0xFF2563EB)),
      ('Pendentes', pendentes, _statusOrange),
      ('Rascunhos', rascunhos, Colors.blueGrey),
      ('Cancelados', cancelados, _statusRed),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (entry) => Container(
              width: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.$1, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${entry.$2}', style: TextStyle(fontSize: 24, color: entry.$3, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLista() {
    if (_loadingList) {
      return OfficialSectionCard(
        title: 'Documentos emitidos',
        icon: Icons.list_alt_outlined,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_listError != null) {
      return OfficialSectionCard(
        title: 'Documentos emitidos',
        icon: Icons.list_alt_outlined,
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.black45),
            const SizedBox(height: 12),
            Text(_listError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _buscarDocumentos,
              style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_documentosFiltrados.isEmpty) {
      return _buildEmptyState();
    }
    return OfficialSectionCard(
      title: 'Documentos emitidos',
      icon: Icons.list_alt_outlined,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_documentosFiltrados.length} documento(s) encontrado(s)',
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            _documentosFiltrados.length,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == _documentosFiltrados.length - 1 ? 0 : 12),
              child: _buildDocumentoCard(_documentosFiltrados[index]),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirDocumento(Map<String, dynamic> item, {int targetStep = 0}) {
    Map<String, dynamic>? payload;
    final raw = item['payload'];
    if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else {
      final payloadRaw = (item['payload_json'] ?? '').toString();
      if (payloadRaw.isNotEmpty) {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      }
    }
    if (payload == null) return;
    final nextTipo = _storedTipoToInternal((item['tipo_auto'] ?? '').toString());
    final steps = _buildStepsByTipoDocumento(nextTipo);
    final boundedStep = targetStep < 0
        ? 0
        : targetStep >= steps.length
            ? steps.length - 1
            : targetStep;
    final dados = Map<String, dynamic>.from(payload['dados_estabelecimento'] as Map? ?? {});
    final status = (item['status'] ?? payload['status'] ?? payload['status_documento'] ?? '').toString().trim().toUpperCase();
    final bloqueado = status == 'FINALIZADO' || status == 'SEM_EFEITO';
    final numero = (item['numero_ano'] ?? item['numero_auto'] ?? item['numero'] ?? payload['numero_ano'] ?? '').toString().trim();
    final estabIdRaw = (payload['estabelecimento_id'] ?? item['estabelecimento_id'] ?? '').toString().trim();
    final estabId = int.tryParse(estabIdRaw) ?? int.tryParse(_onlyDigits(estabIdRaw));
    final estabSelecionado = {
      ...?(estabId == null ? null : {'id': estabId}),
      ...dados,
    };
    final ai = (payload['auto_intimacao'] is Map) ? (payload['auto_intimacao'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final autuadoAi = (ai['autuado'] is Map) ? (ai['autuado'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final basesVinculadas = <Map<String, dynamic>>[];
    final basesRawRoot = payload['bases_legais_vinculadas'];
    if (basesRawRoot is List) {
      for (final b in basesRawRoot) {
        if (b is Map) basesVinculadas.add(b.cast<String, dynamic>());
      }
    }
    if (basesVinculadas.isEmpty) {
      final basesRawAi = ai['bases_legais'];
      if (basesRawAi is List) {
        for (final b in basesRawAi) {
          if (b is! Map) continue;
          final m = b.cast<String, dynamic>();
          final baseId = (m['base_legal_id'] ?? m['id'] ?? '').toString().trim();
          if (baseId.isEmpty) continue;
          basesVinculadas.add({
            'id': baseId,
            'grupo_id': m['grupo_id'],
            'grupo_descricao': m['grupo'] ?? m['grupo_descricao'],
            'subgrupo_id': m['subgrupo_id'],
            'subgrupo_descricao': m['subgrupo'] ?? m['subgrupo_descricao'],
            'tipo': m['tipo'],
            'numero': m['numero'],
            'ano': m['ano'],
            'esfera': m['esfera'],
            'artigo': m['artigo'],
            'inciso': m['inciso'],
            'paragrafo': m['paragrafo'],
            'descricao': m['descricao'],
            'ementa': m['ementa'],
            'observacoes': m['observacoes'],
            'origem': m['origem'],
          });
        }
      }
    }
    final seenBases = <String>{};
    final basesVinculadasDedup = <Map<String, dynamic>>[];
    for (final b in basesVinculadas) {
      final id = (b['id'] ?? b['base_legal_id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (!seenBases.add(id)) continue;
      basesVinculadasDedup.add(b);
    }
    final resumoBaseById = <String, String>{
      for (final b in basesVinculadasDedup) ((b['id'] ?? b['base_legal_id'] ?? '').toString().trim()): _formatBaseLegalResumo(b),
    };

    final prazosItens = <Map<String, dynamic>>[];
    final prazosRaw = ai['prazos_exigencias'];
    if (prazosRaw is List) {
      for (final p in prazosRaw) {
        if (p is Map) prazosItens.add(p.cast<String, dynamic>());
      }
    }
    final itensReferenciaRawList = <Map<String, dynamic>>[];
    final itensRaw = ai['itens_referencia'];
    if (itensRaw is List) {
      for (final it in itensRaw) {
        if (it is Map) itensReferenciaRawList.add(it.cast<String, dynamic>());
      }
    }
    setState(() {
      _tipoDocumento = nextTipo;
      _anoCtrl.text = (payload?['ano'] ?? '').toString();
      _nomeFantasiaCtrl.text = (dados['nome_fantasia'] ?? '').toString();
      _cnpjCtrl.text = _formatCnpj((dados['cnpj'] ?? '').toString());
      _inscricaoMunicipalCtrl.text = (dados['inscricao_municipal'] ?? '').toString();
      _enderecoCtrl.text = (dados['endereco'] ?? '').toString();
      _responsavelLegalCtrl.text = (dados['responsavel_legal'] ?? '').toString();
      _profissionalCtrl.text = (payload?['profissional_id'] ?? '').toString();
      _responsavelTecnicoCtrl.text =
          _usuarioNomeLogado.trim().isNotEmpty ? _usuarioNomeLogado.trim() : (payload?['responsavel_tecnico_id'] ?? '').toString();
      _testemunha1Ctrl.clear();
      _testemunha2Ctrl.clear();
      _statusDocumento = status.isEmpty ? 'EM_EDICAO' : status;
      _documentoBloqueado = bloqueado;
      _estabelecimentoId = estabId;
      _estabelecimentoSelecionado = estabSelecionado;
      _basesLegaisVinculadas = basesVinculadasDedup;
      if (nextTipo == _tipoAutoInfracao) _numeroAutoInfracao = numero.isEmpty ? null : numero;
      if (nextTipo == _tipoAutoIntimacao) _numeroAutoIntimacao = numero.isEmpty ? null : numero;
      if (nextTipo == _tipoAutoIntimacao) {
        final dataLav = (ai['data_lavratura'] ?? '').toString().trim();
        final dtLav = DateTime.tryParse(dataLav);
        _dataLavraturaCtrl.text = dtLav == null ? '' : _formatDate(dtLav);
        _descricaoIrregularidadesCtrl.text = (ai['descricao_irregularidades'] ?? '').toString();
        _descricaoProvidenciasCtrl.text = (ai['descricao_providencias'] ?? '').toString();
        _comentarioFiscalizacaoCtrl.text = (ai['comentario_relatorio_interno'] ?? ai['comentario_fiscalizacao'] ?? '').toString();

        _autuadoNomeCtrl.text = (autuadoAi['nome'] ?? '').toString();
        _autuadoCpfCnpjCtrl.text = (autuadoAi['cnpj_cpf_formatado'] ?? autuadoAi['cnpj_cpf'] ?? '').toString();
        _autuadoNomeFantasiaCtrl.text = (autuadoAi['nome_fantasia'] ?? '').toString();
        _autuadoEnderecoCompletoCtrl.text = (autuadoAi['endereco_completo'] ?? '').toString();
        _autuadoNumeroCtrl.text = (autuadoAi['numero'] ?? '').toString();
        _autuadoBairroCtrl.text = (autuadoAi['bairro'] ?? '').toString();
        _autuadoMunicipioCtrl.text = (autuadoAi['municipio'] ?? '').toString();
        _autuadoUfCtrl.text = (autuadoAi['uf'] ?? '').toString();
        _autuadoProprietarioCtrl.text = (autuadoAi['proprietario_responsavel'] ?? '').toString();
        _autuadoTipoAtividadeCtrl.text = (autuadoAi['tipo_atividade'] ?? '').toString();
        _autuadoAlvaraCtrl.text = (autuadoAi['alvara_pasta_visa'] ?? '').toString();

        _prazosExigencias = [];
        _itensReferencia = (itensReferenciaRawList.isNotEmpty ? itensReferenciaRawList : prazosItens).map((p) {
          final ref = (p['descricao'] ?? p['referencia'] ?? '').toString().trim();
          final itemRefId = (p['item_referencia_id'] ?? p['base_legal_id'] ?? '').toString().trim();
          final baseId = (p['base_legal_id'] ?? itemRefId).toString().trim();
          final dias = p['prazo_dias'];
          final vencIso = (p['data_vencimento'] ?? '').toString().trim();
          final dtVenc = DateTime.tryParse(vencIso);
          return <String, dynamic>{
            'id': 'ITEM_${DateTime.now().millisecondsSinceEpoch}_${(itensReferenciaRawList.isNotEmpty ? itensReferenciaRawList : prazosItens).indexOf(p)}',
            'item_referencia_id': itemRefId,
            'descricao': ref,
            'base_legal_id': baseId,
            'base_legal_resumo': resumoBaseById[baseId] ?? '',
            'descricao_irregularidade': (p['descricao_irregularidade'] ?? '').toString(),
            'descricao_providencia': (p['descricao_providencia'] ?? '').toString(),
            'prazo_dias': dias,
            'data_vencimento': vencIso,
            'data_vencimento_br': dtVenc == null ? '' : _formatDate(dtVenc),
            'prazo_alterado_manual': p['prazo_alterado_manual'] == true,
          };
        }).toList();
        _syncItensReferenciaResumo();

        if (_itensReferencia.isEmpty) {
          _prazoCumprimentoDiasCtrl.text = (ai['prazo_dias'] ?? '').toString();
          final vencIso = (ai['data_vencimento'] ?? '').toString().trim();
          final dtVenc = DateTime.tryParse(vencIso);
          _vencimentoPrazoCtrl.text = dtVenc == null ? '' : _formatDate(dtVenc);
        } else {
          _prazoCumprimentoDiasCtrl.clear();
          _vencimentoPrazoCtrl.clear();
        }
      }
      _currentStep = boundedStep;
    });
    _openFormIfMobile();
  }

  Widget _buildEmptyState() {
    return OfficialSectionCard(
      title: 'Documentos emitidos',
      icon: Icons.list_alt_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.description_outlined, size: 56, color: _govBlue),
            const SizedBox(height: 16),
            const Text(
              'Nenhum Auto/Termo encontrado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _darkText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Voce pode criar um novo Auto/Termo ou ajustar os filtros de busca.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _abrirNovoCadastro,
                  style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Novo Auto/Termo'),
                ),
                OutlinedButton.icon(
                  onPressed: _limparFiltros,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpar filtros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentoCard(Map<String, dynamic> item) {
    final tipoLabel = _tipoDocumentoFromStored(item);
    final tipoColor = _tipoColorFromLabel(tipoLabel);
    final statusLabel = _statusLabelFromValue((item['status'] ?? '').toString());
    final statusColor = _statusColorFromLabel(statusLabel);
    final syncIcon = statusLabel == 'Sincronizado'
        ? Icons.cloud_done_outlined
        : statusLabel == 'Pendente de sincronizacao'
            ? Icons.cloud_upload_outlined
            : Icons.description_outlined;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildBadge(tipoLabel, tipoColor),
              _buildBadge(statusLabel, statusColor),
              _buildSyncIndicator(syncIcon, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            (item['numero_ano'] ?? item['numero_auto'] ?? item['numero'] ?? '-').toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _darkText),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _infoItem(Icons.storefront_outlined, 'Estabelecimento', (item['estabelecimento_nome'] ?? item['estabelecimento'] ?? '-').toString()),
              _infoItem(Icons.badge_outlined, 'CNPJ', _formatCnpj((item['estabelecimento_cnpj'] ?? item['cnpj'] ?? '').toString())),
              _infoItem(Icons.event_outlined, 'Data de emissao', _formatDisplayDateTime(item['data_hora'] ?? item['data_emissao'] ?? item['data'])),
              _infoItem(Icons.person_outline, 'Profissional/Fiscal', (item['profissional_nome'] ?? item['profissional'] ?? item['fiscal_nome'] ?? '-').toString()),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _abrirDocumento(item, targetStep: _reviewStepIndex),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver detalhes'),
              ),
              OutlinedButton.icon(
                onPressed: () => _abrirDocumento(item),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _gerarPdf(item),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Gerar PDF'),
              ),
              OutlinedButton.icon(
                onPressed: () => _compartilharOuImprimir(item),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Compartilhar/Imprimir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildSyncIndicator(IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text('Sincronizacao', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _govBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _gerarPdf(Map<String, dynamic> item) async {
    // #region debug-point P:gerar-pdf
    unawaited(
      _debugReport(
        hypothesisId: 'P',
        location: 'auto_termo_page.dart:_gerarPdf',
        msg: '[DEBUG] Clique em Gerar PDF',
        data: {
          'tipo_auto': (item['tipo_auto'] ?? item['tipo_documento'] ?? '').toString(),
          'has_payload_json': (item['payload_json'] ?? '').toString().trim().isNotEmpty,
          'payload_json_len': (item['payload_json'] ?? '').toString().length,
          'has_payload_map': item['payload'] is Map,
        },
      ),
    );
    // #endregion
    final tipo = _storedTipoToInternal((item['tipo_auto'] ?? item['tipo_documento'] ?? '').toString());
    if (tipo == _tipoAutoIntimacao) {
      Map<String, dynamic>? payload;
      final p = item['payload'];
      if (p is Map) {
        payload = Map<String, dynamic>.from(p);
      } else {
        final raw = (item['payload_json'] ?? '').toString().trim();
        if (raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
          } catch (_) {
            payload = null;
          }
        }
      }
      // #region debug-point P:gerar-pdf
      unawaited(
        _debugReport(
          hypothesisId: 'P',
          location: 'auto_termo_page.dart:_gerarPdf',
          msg: '[DEBUG] Payload resolvido para PDF',
          data: {
            'payload_null': payload == null,
            'payload_keys': payload == null ? [] : payload.keys.take(30).toList(),
          },
        ),
      );
      // #endregion
      if (!mounted) return;
      if (payload == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar os dados do documento para gerar o PDF.')),
        );
        return;
      }
      await Navigator.pushNamed(context, '/auto-intimacao-pdf', arguments: {'payload': payload});
      return;
    }

    final numero = (item['numero_ano'] ?? item['numero_auto'] ?? item['numero'] ?? '').toString().trim();
    final pdfUrl = (item['pdf_url'] ?? item['pdfUrl'] ?? '').toString().trim();
    final id = int.tryParse((item['id'] ?? '').toString());
    final fallback = tipo == _tipoAutoInfracao && id != null ? '/api/auto-infracao/$id/pdf' : '';
    final path = pdfUrl.isNotEmpty ? pdfUrl : fallback;
    if (path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF indisponível para este documento.')),
      );
      return;
    }
    try {
      final bytes = await _api.baixarPdfBytes(path);
      if (!mounted) return;
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar PDF. O servidor retornou um PDF vazio.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfBytesPreviewPage(
            title: numero.isEmpty ? 'PDF' : 'PDF — $numero',
            bytes: Uint8List.fromList(bytes),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao gerar PDF.')),
      );
    }
  }

  Future<void> _compartilharOuImprimir(Map<String, dynamic> item) async {
    final numero = (item['numero_ano'] ?? item['numero_auto'] ?? item['numero'] ?? '').toString();
    final tipo = _storedTipoToInternal((item['tipo_auto'] ?? item['tipo_documento'] ?? '').toString());
    final pdfUrl = (item['pdf_url'] ?? item['pdfUrl'] ?? '').toString().trim();
    final id = int.tryParse((item['id'] ?? '').toString());
    final fallback = tipo == _tipoAutoInfracao && id != null ? '/api/auto-infracao/$id/pdf' : '';
    final path = pdfUrl.isNotEmpty ? pdfUrl : fallback;
    if (path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF indisponível para compartilhar/imprimir.')),
      );
      return;
    }
    try {
      final bytes = await _api.baixarPdfBytes(path);
      if (!mounted) return;
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao compartilhar ou imprimir. O PDF veio vazio.')),
        );
        return;
      }
      final data = Uint8List.fromList(bytes);
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => data);
      } else {
        await Printing.sharePdf(bytes: data, filename: numero.isEmpty ? 'documento.pdf' : '$numero.pdf');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao compartilhar ou imprimir.')),
      );
    }
  }

  Widget _buildFormPanel() {
    final steps = _steps;
    return Column(
      children: [
        OfficialStepper(
          currentStep: _currentStep,
          steps: steps.map((e) => e.title).toList(),
          onStepTapped: (step) {
            if (step <= _currentStep) {
              _formSetState(() => _currentStep = step);
            }
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _documentoBloqueado
                ? AbsorbPointer(child: _buildStepContent(steps[_currentStep].title))
                : _buildStepContent(steps[_currentStep].title),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _currentStep > 0 ? () => _formSetState(() => _currentStep -= 1) : null,
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_saving || _currentStep == steps.length - 1) ? null : _continuar,
                  style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(String stepTitle) {
    switch (stepTitle) {
      case 'Dados':
        return _buildDadosStep();
      case 'Autuado':
        return _buildAutuadoStep();
      case 'Base legal':
        return _buildBaseLegalStep();
      case 'Irregularidades':
        return _buildIrregularidadesStep();
      case 'Providências/Prazo':
        return _buildProvidenciasPrazoStep();
      case 'Recebimento/Assinaturas':
        return _buildRecebimentoAssinaturasStep();
      case 'Descrição':
        return _buildDescricaoStep();
      case 'Relatório Inspeção Sanitária':
        return _buildInspecaoStep();
      case 'Profissionais da Equipe':
        return _buildProfissionaisStep();
      case 'Revisão':
        return _buildReviewStep();
      case 'Salvar':
        return _buildSalvarStep();
      default:
        return _buildTipoDocumentoStep();
    }
  }

  Widget _buildDadosStep() {
    return Form(
      key: _dadosFormKey,
      child: Column(
        children: [
          OfficialSectionCard(
            title: 'Dados',
            icon: Icons.badge_outlined,
            child: Column(
              children: [
                _responsiveRow([
                  OfficialNumericField(
                    controller: _anoCtrl,
                    label: 'Ano',
                    required: true,
                    minValue: 2000,
                    maxValue: 2100,
                    validator: (value) {
                      if (value == null || value.trim().length != 4) return 'Informe 4 dígitos';
                      return null;
                    },
                  ),
                  OfficialTextField(
                    controller: _dataHoraCtrl,
                    label: 'Data e hora',
                    required: true,
                    readOnly: true,
                    onTap: _pickDataHora,
                    suffixIcon: const Icon(Icons.event_outlined),
                  ),
                ]),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _estabSearchCtrl,
                  label: 'Estabelecimento',
                  required: true,
                  suffixIcon: _estabLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          onPressed: _buscarEstabelecimento,
                          icon: const Icon(Icons.search),
                        ),
                  helperText: 'Buscar por Nome Fantasia, Razão Social ou CNPJ',
                ),
                if (_estabError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_estabError!, style: const TextStyle(color: _statusRed)),
                  ),
                ],
                if (_estabResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildEstabResults(),
                ],
                const SizedBox(height: 12),
                _responsiveRow([
                  OfficialTextField(
                    controller: _nomeFantasiaCtrl,
                    label: 'Nome Fantasia',
                    readOnly: true,
                    required: true,
                  ),
                  OfficialCnpjField(
                    controller: _cnpjCtrl,
                    label: 'CNPJ',
                    required: true,
                    enabled: false,
                  ),
                ]),
                const SizedBox(height: 12),
                _responsiveRow([
                  OfficialTextField(
                    controller: _inscricaoMunicipalCtrl,
                    label: 'Inscrição municipal',
                    readOnly: true,
                  ),
                  OfficialTextField(
                    controller: _responsavelLegalCtrl,
                    label: 'Responsável legal',
                    readOnly: true,
                  ),
                ]),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: _enderecoCtrl,
                  label: 'Endereço',
                  minLines: 2,
                  maxLines: 3,
                  enabled: false,
                ),
                const SizedBox(height: 12),
                OfficialDropdownField<String>(
                  value: _tipoDocumento,
                  items: _tiposDocumentoOrdem
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(_tiposDocumentoLabel[e] ?? e),
                        ),
                      )
                      .toList(),
                  onChanged: _onTipoDocumentoChanged,
                  label: 'Tipo de documento',
                  required: true,
                  hint: 'Selecione o tipo de documento',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Selecione o tipo de documento para continuar.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Possui Pasta VISA?'),
                  value: _possuiPastaVisa,
                  onChanged: _documentoBloqueado
                      ? null
                      : (v) {
                          _formSetState(() {
                            _possuiPastaVisa = v;
                            if (!v) _numeroPastaVisaCtrl.clear();
                          });
                        },
                ),
                if (_possuiPastaVisa) ...[
                  const SizedBox(height: 12),
                  OfficialTextField(
                    controller: _numeroPastaVisaCtrl,
                    label: 'Número da Pasta VISA',
                    required: true,
                    validator: (v) {
                      if (!_possuiPastaVisa) return null;
                      if ((v ?? '').trim().isEmpty) return 'Campo obrigatório';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _hasTipoDocumentoSelected
                        ? 'Tipo selecionado: $_tipoDocumentoLabel'
                        : 'Selecione o tipo de documento para liberar as próximas etapas.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _hasTipoDocumentoSelected ? FontWeight.w700 : FontWeight.w500,
                      color: _hasTipoDocumentoSelected ? _govBlue : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_usuarioNomeLogado.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Fiscal responsável (logado): ${_usuarioNomeLogado.trim()}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  OfficialTextField(
                    controller: _profissionalCtrl,
                    label: 'Profissional',
                    required: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutuadoStep() {
    return Form(
      key: _autuadoFormKey,
      child: OfficialSectionCard(
        title: 'Autuado',
        icon: Icons.storefront_outlined,
        child: Column(
          children: [
            _responsiveRow([
              OfficialTextField(
                controller: _autuadoNomeCtrl,
                label: 'Nome da Pessoa Física/Jurídica',
                required: true,
                onChanged: (v) => _auditChange('autuado.nome', v),
              ),
              OfficialTextField(
                controller: _autuadoCpfCnpjCtrl,
                label: 'CNPJ/CPF',
                required: true,
                keyboardType: TextInputType.number,
                inputFormatters: [_CpfCnpjInputFormatter()],
                onChanged: (v) => _auditChange('autuado.cnpj_cpf', v),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return 'Campo obrigatório';
                  if (digits.length != 11 && digits.length != 14) return 'CNPJ/CPF inválido';
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 12),
            _responsiveRow([
              OfficialTextField(
                controller: _autuadoNomeFantasiaCtrl,
                label: 'Denominação Comercial / Nome Fantasia',
                required: true,
                onChanged: (v) => _auditChange('autuado.nome_fantasia', v),
              ),
              OfficialTextField(
                controller: _autuadoTipoAtividadeCtrl,
                label: 'Tipo de Estabelecimento / Negócio / Atividade',
                required: true,
                onChanged: (v) => _auditChange('autuado.tipo_atividade', v),
                helperText: _cnaesAutuado.isEmpty ? null : 'Preenchido pelo CNAE do CNPJ. Você pode selecionar outro CNAE.',
                suffixIcon: _documentoBloqueado || _cnaesAutuado.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _selecionarCnaeAutuado,
                        icon: const Icon(Icons.search_outlined),
                        tooltip: 'Selecionar CNAE',
                      ),
              ),
            ]),
            const SizedBox(height: 12),
            OfficialMultilineField(
              controller: _autuadoEnderecoCompletoCtrl,
              label: 'Endereço Completo',
              required: true,
              minLines: 2,
              maxLines: 3,
              onChanged: (v) => _auditChange('autuado.endereco_completo', v),
            ),
            const SizedBox(height: 12),
            _responsiveRow([
              OfficialTextField(
                controller: _autuadoNumeroCtrl,
                label: 'Número',
                required: true,
                onChanged: (v) => _auditChange('autuado.numero', v),
              ),
              OfficialTextField(
                controller: _autuadoBairroCtrl,
                label: 'Bairro',
                required: true,
                onChanged: (v) => _auditChange('autuado.bairro', v),
              ),
            ]),
            const SizedBox(height: 12),
            _responsiveRow([
              OfficialTextField(
                controller: _autuadoMunicipioCtrl,
                label: 'Município',
                required: true,
                onChanged: (v) => _auditChange('autuado.municipio', v),
              ),
              OfficialTextField(
                controller: _autuadoUfCtrl,
                label: 'UF',
                required: true,
                onChanged: (v) => _auditChange('autuado.uf', v),
                validator: (v) {
                  final val = (v ?? '').trim();
                  if (val.isEmpty) return 'Campo obrigatório';
                  if (val.length != 2) return 'UF inválida';
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 12),
            _responsiveRow([
              OfficialTextField(
                controller: _autuadoProprietarioCtrl,
                label: 'Proprietário e/ou Responsável',
                required: true,
                onChanged: (v) => _auditChange('autuado.proprietario_responsavel', v),
              ),
              OfficialTextField(
                controller: _autuadoAlvaraCtrl,
                label: 'Pasta VISA',
                required: true,
                onChanged: (v) => _auditChange('autuado.alvara_pasta', v),
              ),
            ]),
            if (_tipoDocumento == _tipoAutoIntimacao) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _responsiveRow([
                OfficialDropdownField.fromStrings(
                  value: _departamento,
                  items: _departamentos,
                  onChanged: _documentoBloqueado ? null : (v) => setState(() => _departamento = v ?? _departamentos.first),
                  label: 'Nome do setor da Vigilância Sanitária',
                  required: true,
                ),
              ]),
              const SizedBox(height: 12),
              _responsiveRow([
                OfficialTextField(
                  controller: _dataLavraturaCtrl,
                  label: 'Data da lavratura do Auto de Intimação',
                  required: true,
                  readOnly: true,
                  onTap: _documentoBloqueado ? null : () => _pickDateOnly(_dataLavraturaCtrl),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                OfficialPhoneField(
                  controller: _telefoneVisaCtrl,
                  label: 'Telefone da VISA',
                  required: true,
                  enabled: !_documentoBloqueado,
                ),
              ]),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _emailVisaCtrl,
                label: 'E-mail da VISA',
                required: true,
                enabled: !_documentoBloqueado,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIrregularidadesStep() {
    String? validator(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return 'Campo obrigatório';
      if (v.length < 20) return 'Mínimo de 20 caracteres';
      return null;
    }

    return Form(
      key: _irregularidadesFormKey,
      child: OfficialSectionCard(
        title: 'Irregularidades',
        icon: Icons.report_problem_outlined,
        child: OfficialMultilineField(
          controller: _descricaoIrregularidadesCtrl,
          label: 'Descrição das Irregularidades:',
          required: true,
          validator: validator,
        ),
      ),
    );
  }

  DateTime? _tryParseBrDate(String value) {
    final v = value.trim();
    final m = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(v);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    try {
      return DateTime(y, mo, d);
    } catch (_) {
      return null;
    }
  }

  String _formatBrDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _recalcularVencimentoPrazo() {
    if (_tipoDocumento != _tipoAutoIntimacao) return;
    final prazo = int.tryParse(_prazoCumprimentoDiasCtrl.text.trim());
    final dataLav = _tryParseBrDate(_dataLavraturaCtrl.text);
    if (prazo == null || prazo <= 0 || dataLav == null) {
      if (_vencimentoPrazoCtrl.text.trim().isNotEmpty) {
        _vencimentoPrazoCtrl.text = '';
      }
      return;
    }
    final venc = dataLav.add(Duration(days: prazo));
    final formatted = _formatBrDate(venc);
    if (_vencimentoPrazoCtrl.text != formatted) {
      _vencimentoPrazoCtrl.text = formatted;
    }
  }

  void _recalcularVencimentoPrazoExigencia() {
    if (_tipoDocumento != _tipoAutoIntimacao) return;
    final prazo = int.tryParse(_prazoExigenciaDiasCtrl.text.trim());
    final dataLav = _tryParseBrDate(_dataLavraturaCtrl.text);
    if (prazo == null || prazo <= 0 || dataLav == null) {
      if (_prazoExigenciaVencimentoCtrl.text.trim().isNotEmpty) {
        _prazoExigenciaVencimentoCtrl.text = '';
      }
      return;
    }
    final venc = dataLav.add(Duration(days: prazo));
    final formatted = _formatBrDate(venc);
    if (_prazoExigenciaVencimentoCtrl.text != formatted) {
      _prazoExigenciaVencimentoCtrl.text = formatted;
    }
  }

  String _formatBaseLegalResumo(Map<String, dynamic> v) {
    final tipo = (v['tipo'] ?? '').toString().trim();
    final numero = (v['numero'] ?? '').toString().trim();
    final ano = (v['ano'] ?? '').toString().trim();
    final esfera = (v['esfera'] ?? '').toString().trim();
    final artigo = (v['artigo'] ?? '').toString().trim();
    final inciso = (v['inciso'] ?? '').toString().trim();
    final paragrafo = (v['paragrafo'] ?? '').toString().trim();
    final norma = [tipo, [numero, ano].where((e) => e.isNotEmpty).join('/'), esfera.isEmpty ? '' : '($esfera)']
        .where((e) => e.trim().isNotEmpty)
        .join(' ')
        .trim();
    final art = [
      if (artigo.isNotEmpty) 'Art. $artigo',
      if (inciso.isNotEmpty) 'Inciso $inciso',
      if (paragrafo.isNotEmpty) '§ $paragrafo',
    ].join(' ').trim();
    return [norma, art].where((e) => e.trim().isNotEmpty).join(' - ');
  }

  Future<void> _selecionarItensReferenciaBaseLegal() async {
    if (_documentoBloqueado) return;
    if (_basesLegaisVinculadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos uma Base Legal antes de selecionar Itens/Referência.')),
      );
      return;
    }

    final selected = Set<String>.from(_prazoExigenciaBaseLegalIds);
    final result = await showDialog<Set<String>?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Selecionar Itens/Referência'),
              content: SizedBox(
                width: 560,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _basesLegaisVinculadas.length,
                  itemBuilder: (ctx, i) {
                    final v = _basesLegaisVinculadas[i];
                    final id = (v['id'] ?? '').toString().trim();
                    final title = _formatBaseLegalResumo(v);
                    final checked = id.isNotEmpty && selected.contains(id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: id.isEmpty
                          ? null
                          : (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                      title: Text(title.isEmpty ? 'Base legal' : title),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(selected), child: const Text('Aplicar')),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    final ids = result.where((e) => e.trim().isNotEmpty).toList();
    final labels = _basesLegaisVinculadas
        .where((e) => ids.contains((e['id'] ?? '').toString().trim()))
        .map(_formatBaseLegalResumo)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    _formSetState(() => _prazoExigenciaBaseLegalIds = ids);
    _prazoExigenciaReferenciaCtrl.text = labels.join('; ');
  }

  void _adicionarPrazoExigencia() {
    if (_documentoBloqueado) return;
    final ref = _prazoExigenciaReferenciaCtrl.text.trim();
    final dias = int.tryParse(_prazoExigenciaDiasCtrl.text.trim());
    final vencBr = _prazoExigenciaVencimentoCtrl.text.trim();
    final venc = _tryParseBrDate(vencBr);
    if (ref.isEmpty || dias == null || dias <= 0 || venc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe Itens/Referência, Prazo (dias) e Vencimento.')),
      );
      return;
    }
    _formSetState(() {
      _prazosExigencias = [
        ..._prazosExigencias,
        {
          'id': 'PRAZO_${DateTime.now().millisecondsSinceEpoch}',
          'referencia': ref,
          'base_legal_ids': List<String>.from(_prazoExigenciaBaseLegalIds),
          'prazo_dias': dias,
          'data_vencimento': _formatIsoDate(venc),
          'data_vencimento_br': vencBr,
        },
      ];
      _prazoExigenciaReferenciaCtrl.clear();
      _prazoExigenciaDiasCtrl.clear();
      _prazoExigenciaVencimentoCtrl.clear();
      _prazoExigenciaBaseLegalIds = [];
    });
  }

  void _removerPrazoExigencia(String id) {
    _formSetState(() {
      _prazosExigencias = _prazosExigencias.where((e) => (e['id'] ?? '').toString() != id).toList();
    });
  }

  void _syncItensReferenciaResumo() {
    final labels = _itensReferencia
        .map((e) => (e['descricao'] ?? e['descricao_item'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (labels.isEmpty) {
      if (_itensReferenciaCtrl.text.isNotEmpty) _itensReferenciaCtrl.text = '';
      return;
    }
    final preview = labels.length <= 3 ? labels.join('; ') : '${labels.take(3).join('; ')} (+${labels.length - 3})';
    if (_itensReferenciaCtrl.text != preview) _itensReferenciaCtrl.text = preview;
  }

  DateTime _dataLavraturaEfetiva() {
    return _tryParseBrDate(_dataLavraturaCtrl.text) ?? _selectedDate;
  }

  DateTime _calcularVencimento(DateTime dataLavratura, int prazoDias) {
    final base = DateTime(dataLavratura.year, dataLavratura.month, dataLavratura.day);
    return base.add(Duration(days: prazoDias));
  }

  void _recalcularVencimentosItensReferencia({bool showSnack = false}) {
    if (_itensReferencia.isEmpty) return;
    final dataLav = _dataLavraturaEfetiva();
    bool changed = false;
    final updated = _itensReferencia.map((it) {
      final m = Map<String, dynamic>.from(it);
      final dias = int.tryParse((m['prazo_dias'] ?? '').toString()) ?? 0;
      if (dias <= 0) return m;
      final venc = _calcularVencimento(dataLav, dias);
      final vencIso = _formatIsoDate(venc);
      final vencBr = _formatDate(venc);
      if (m['data_vencimento'] != vencIso || m['data_vencimento_br'] != vencBr) {
        m['data_vencimento'] = vencIso;
        m['data_vencimento_br'] = vencBr;
        changed = true;
      }
      return m;
    }).toList();
    if (changed) {
      _formSetState(() => _itensReferencia = updated);
    } else {
      _syncItensReferenciaResumo();
      _touchFormRebuild();
    }
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Os vencimentos dos itens foram recalculados com base na nova data de lavratura.')),
      );
    }
  }

  void _autoAttachBaseLegalFromEntry(BaseLegalEntry entry) {
    final exists = _basesLegaisVinculadas.any((b) => (b['id'] ?? '').toString() == entry.id);
    if (exists) return;
    final vinculo = entry.toVinculoJson();
    vinculo['origem'] = 'ITEM_REFERENCIA';
    _formSetState(() => _basesLegaisVinculadas = [..._basesLegaisVinculadas, vinculo]);
  }

  String? _validarItemReferencia(Map<String, dynamic> item) {
    final descricao = (item['descricao'] ?? item['descricao_item'] ?? 'Item').toString().trim();
    if ((item['base_legal_id'] ?? '').toString().trim().isEmpty) {
      return 'O item "$descricao" está sem Base Legal vinculada.';
    }
    if ((item['descricao_irregularidade'] ?? '').toString().trim().isEmpty) {
      return 'Preencha a descrição da irregularidade do item "$descricao".';
    }
    if ((item['descricao_providencia'] ?? '').toString().trim().isEmpty) {
      return 'Preencha a providência/exigência do item "$descricao".';
    }
    final prazo = int.tryParse((item['prazo_dias'] ?? '').toString()) ?? 0;
    if (prazo <= 0) {
      return 'Informe um prazo maior que zero para o item "$descricao".';
    }
    if ((item['data_vencimento'] ?? '').toString().trim().isEmpty) {
      return 'O item "$descricao" está sem data de vencimento.';
    }
    return null;
  }

  String? _validarItensReferenciaPreenchidos() {
    if (_itensReferencia.isEmpty) return 'Selecione pelo menos 1 item';
    for (final item in _itensReferencia) {
      final erro = _validarItemReferencia(item);
      if (erro != null) return erro;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _abrirDialogoItemReferencia(
    Map<String, dynamic> item, {
    required String titulo,
    required String textoSalvar,
  }) async {
    final working = Map<String, dynamic>.from(item);
    final irregularidadeCtrl = TextEditingController(text: (working['descricao_irregularidade'] ?? '').toString());
    final providenciaCtrl = TextEditingController(text: (working['descricao_providencia'] ?? '').toString());
    final prazoCtrl = TextEditingController(text: (working['prazo_dias'] ?? '').toString());
    final vencimentoCtrl = TextEditingController();

    void syncVencimento() {
      final dias = int.tryParse(prazoCtrl.text.trim()) ?? 0;
      if (dias <= 0) {
        vencimentoCtrl.text = '';
        return;
      }
      vencimentoCtrl.text = _formatDate(_calcularVencimento(_dataLavraturaEfetiva(), dias));
    }

    syncVencimento();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? irregularidadeError;
        String? providenciaError;
        String? prazoError;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(titulo),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OfficialTextField(
                      label: 'Item/Referência',
                      readOnly: true,
                      enabled: false,
                      initialValue: (working['descricao'] ?? working['descricao_item'] ?? '').toString(),
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      label: 'Base Legal / Artigo',
                      readOnly: true,
                      enabled: false,
                      initialValue: (working['base_legal_resumo'] ?? '').toString(),
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: irregularidadeCtrl,
                      label: 'Descrição da irregularidade',
                      enabled: true,
                      multiline: true,
                      minLines: 2,
                      maxLines: 4,
                      required: true,
                      errorText: irregularidadeError,
                      onChanged: (_) {
                        if (irregularidadeError != null) {
                          setLocal(() => irregularidadeError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: providenciaCtrl,
                      label: 'Providência/Exigência',
                      enabled: true,
                      multiline: true,
                      minLines: 2,
                      maxLines: 4,
                      required: true,
                      errorText: providenciaError,
                      onChanged: (_) {
                        if (providenciaError != null) {
                          setLocal(() => providenciaError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: prazoCtrl,
                      label: 'Prazo para cumprimento (dias)',
                      required: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      errorText: prazoError,
                      onChanged: (_) {
                        syncVencimento();
                        setLocal(() => prazoError = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: vencimentoCtrl,
                      label: 'Data de vencimento',
                      readOnly: true,
                      enabled: false,
                      required: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    final irregularidade = irregularidadeCtrl.text.trim();
                    final providencia = providenciaCtrl.text.trim();
                    final dias = int.tryParse(prazoCtrl.text.trim()) ?? 0;
                    setLocal(() {
                      irregularidadeError = irregularidade.isEmpty ? 'Campo obrigatório' : null;
                      providenciaError = providencia.isEmpty ? 'Campo obrigatório' : null;
                      prazoError = dias <= 0 ? 'Informe um número inteiro positivo' : null;
                    });
                    if (irregularidade.isEmpty || providencia.isEmpty || dias <= 0) {
                      // #region debug-point C:item-referencia-dialog
                      unawaited(
                        _debugReport(
                          hypothesisId: 'C',
                          location: 'auto_termo_page.dart:_abrirDialogoItemReferencia',
                          msg: '[DEBUG] Dialogo de item bloqueado por campos obrigatorios',
                          data: {
                            'itemReferenciaId': (working['item_referencia_id'] ?? '').toString(),
                            'irregularidadePreenchida': irregularidade.isNotEmpty,
                            'providenciaPreenchida': providencia.isNotEmpty,
                            'prazoDias': dias,
                          },
                        ),
                      );
                      // #endregion
                      return;
                    }

                    final venc = _calcularVencimento(_dataLavraturaEfetiva(), dias);
                    final updated = Map<String, dynamic>.from(working);
                    updated['descricao_irregularidade'] = irregularidade;
                    updated['descricao_providencia'] = providencia;
                    updated['prazo_dias'] = dias;
                    updated['data_vencimento'] = _formatIsoDate(venc);
                    updated['data_vencimento_br'] = _formatDate(venc);
                    final prazoPadrao = int.tryParse((updated['prazo_padrao_dias'] ?? '').toString()) ?? 0;
                    updated['prazo_alterado_manual'] = prazoPadrao <= 0 || dias != prazoPadrao;
                    // #region debug-point C:item-referencia-dialog
                    unawaited(
                      _debugReport(
                        hypothesisId: 'C',
                        location: 'auto_termo_page.dart:_abrirDialogoItemReferencia',
                        msg: '[DEBUG] Dialogo de item persistiu dados obrigatorios',
                        data: {
                          'itemReferenciaId': (updated['item_referencia_id'] ?? '').toString(),
                          'prazoDias': dias,
                          'dataVencimento': (updated['data_vencimento'] ?? '').toString(),
                          'prazoAlteradoManual': updated['prazo_alterado_manual'] == true,
                        },
                      ),
                    );
                    // #endregion
                    Navigator.of(ctx).pop(updated);
                  },
                  child: Text(textoSalvar),
                ),
              ],
            );
          },
        );
      },
    );

    irregularidadeCtrl.dispose();
    providenciaCtrl.dispose();
    prazoCtrl.dispose();
    vencimentoCtrl.dispose();
    return result;
  }

  Future<void> _adicionarItemReferencia(BaseLegalEntry entry) async {
    if (_documentoBloqueado) return;
    if (_itensReferencia.any((e) => (e['item_referencia_id'] ?? '').toString() == entry.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item já selecionado.')));
      return;
    }
    final prazoPadrao = (entry.prazoPadraoDias ?? 0) > 0 ? entry.prazoPadraoDias! : 1;
    final dataLav = _dataLavraturaEfetiva();
    final venc = _calcularVencimento(dataLav, prazoPadrao);
    final descItem = (entry.descricaoItem ?? '').trim();
    final irregularidade = (entry.descricaoIrregularidade ?? descItem).trim();
    final providencia = (entry.descricaoProvidencia ?? '').trim();
    final resumoBase = _formatBaseLegalResumo(entry.toVinculoJson());

    final novoItem = await _abrirDialogoItemReferencia(
      {
        'id': 'ITEM_${DateTime.now().millisecondsSinceEpoch}',
        'item_referencia_id': entry.id,
        'descricao': descItem.isNotEmpty ? descItem : (entry.descricao ?? entry.ementa ?? '').toString().trim(),
        'base_legal_id': entry.id,
        'base_legal_resumo': resumoBase,
        'artigo': (entry.artigo ?? '').toString(),
        'descricao_irregularidade': irregularidade,
        'descricao_providencia': providencia,
        'prazo_dias': prazoPadrao,
        'prazo_padrao_dias': entry.prazoPadraoDias,
        'data_vencimento': _formatIsoDate(venc),
        'data_vencimento_br': _formatDate(venc),
        'prazo_alterado_manual': entry.prazoPadraoDias == null,
      },
      titulo: 'Detalhar item selecionado',
      textoSalvar: 'Adicionar item',
    );
    if (novoItem == null) return;

    _formSetState(() {
      _itensReferencia = [..._itensReferencia, novoItem];
      _syncItensReferenciaResumo();
    });
    _autoAttachBaseLegalFromEntry(entry);
    if (entry.prazoPadraoDias == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item sem prazo padrão configurado. Ajuste o prazo antes de finalizar.')),
      );
    }
    _atualizarSugestaoProvidencias();
  }

  Future<void> _verBaseLegalDetalhe(String baseLegalId) async {
    if (baseLegalId.trim().isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.85;
        return SizedBox(
          height: height,
          child: FutureBuilder<BaseLegalEntry?>(
            future: _baseLegalRepo.buscarDetalhe(baseLegalId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final e = snap.data;
              if (e == null) {
                return const Center(child: Text('Não foi possível carregar a Base Legal.'));
              }
              final artigoLabel = [
                if ((e.artigo ?? '').trim().isNotEmpty) 'Art. ${e.artigo}',
                if ((e.complemento ?? '').trim().isNotEmpty) e.complemento!,
              ].join(' ').trim();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Base Legal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(e.normaTitulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (artigoLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(artigoLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if ((e.descricao ?? e.ementa ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text((e.descricao ?? e.ementa ?? '').toString().trim()),
                        ),
                      ),
                    ] else
                      const Expanded(child: Center(child: Text('Sem descrição.'))),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _editarItemReferencia(String id) async {
    if (_documentoBloqueado) return;
    final idx = _itensReferencia.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (idx < 0) return;
    final item = Map<String, dynamic>.from(_itensReferencia[idx]);
    final atualizado = await _abrirDialogoItemReferencia(
      item,
      titulo: 'Editar item',
      textoSalvar: 'Salvar',
    );
    if (atualizado == null) return;

    _formSetState(() {
      final next = [..._itensReferencia];
      next[idx] = atualizado;
      _itensReferencia = next;
      _syncItensReferenciaResumo();
    });
    _atualizarSugestaoProvidencias();
  }

  void _removerItemReferencia(String id) {
    if (_documentoBloqueado) return;
    _formSetState(() {
      _itensReferencia = _itensReferencia.where((e) => (e['id'] ?? '').toString() != id).toList();
      final remainingBaseIds = _itensReferencia
          .map((e) => (e['base_legal_id'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      _basesLegaisVinculadas = _basesLegaisVinculadas.where((b) {
        final m = Map<String, dynamic>.from(b);
        final origem = (m['origem'] ?? '').toString().trim().toUpperCase();
        if (origem != 'ITEM_REFERENCIA') return true;
        final baseId = (m['id'] ?? m['base_legal_id'] ?? '').toString().trim();
        if (baseId.isEmpty) return true;
        return remainingBaseIds.contains(baseId);
      }).toList();
      _syncItensReferenciaResumo();
    });
    _atualizarSugestaoProvidencias();
  }

  String _gerarSugestaoProvidenciasPorPrazo() {
    if (_itensReferencia.isEmpty) return '';
    final groups = <int, List<Map<String, dynamic>>>{};
    for (final it in _itensReferencia) {
      final dias = int.tryParse((it['prazo_dias'] ?? '').toString()) ?? 0;
      if (dias <= 0) continue;
      groups.putIfAbsent(dias, () => []).add(it);
    }
    final prazos = groups.keys.toList()..sort();
    final out = StringBuffer();
    out.writeln('O autuado deverá cumprir as seguintes exigências:');
    for (final dias in prazos) {
      out.writeln();
      out.writeln('Prazo de $dias dias:');
      int n = 1;
      for (final it in groups[dias]!) {
        final prov = (it['descricao_providencia'] ?? '').toString().trim();
        final fallback = (it['descricao'] ?? '').toString().trim();
        final line = (prov.isNotEmpty ? prov : fallback).trim();
        if (line.isEmpty) continue;
        out.writeln('${n.toString()}. $line');
        n += 1;
      }
    }
    return out.toString().trim();
  }

  Future<void> _atualizarSugestaoProvidencias() async {
    if (_tipoDocumento != _tipoAutoIntimacao) return;
    final sugestao = _gerarSugestaoProvidenciasPorPrazo();
    if (sugestao.isEmpty) return;
    final atual = _descricaoProvidenciasCtrl.text.trim();
    if (atual.isEmpty) {
      _formSetState(() => _descricaoProvidenciasCtrl.text = sugestao);
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atualizar texto das providências?'),
        content: const Text('Há uma sugestão atualizada com base nos itens selecionados. Deseja substituir o texto atual?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Manter')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Substituir')),
        ],
      ),
    );
    if (result == true) {
      _formSetState(() => _descricaoProvidenciasCtrl.text = sugestao);
    }
  }

  Future<void> _abrirSelecaoItensReferencia() async {
    if (_documentoBloqueado) return;
    final searchCtrl = TextEditingController();
    List<BaseLegalEntry> results = const [];
    bool loading = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.85;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> doSearch() async {
              final q = searchCtrl.text.trim();
              if (q.length < 3) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Digite pelo menos 3 caracteres para buscar.')));
                return;
              }
              if (!ctx.mounted) return;
              setModalState(() {
                loading = true;
                error = null;
              });
              try {
                final items = await _baseLegalRepo.buscarInteligente(query: q, limit: 60);
                final filtered = items.where((e) => e.aplicaAutoIntimacao != false).toList();
                if (!ctx.mounted) return;
                setModalState(() {
                  results = filtered;
                  loading = false;
                });
              } catch (_) {
                if (!ctx.mounted) return;
                setModalState(() {
                  loading = false;
                  error = 'Não foi possível buscar itens na Base Legal.';
                });
              }
            }

            return SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Buscar Itens/Referência', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Itens/Referência',
                        hintText: 'Ex: cozinha suja, produto vencido, teto irregular, construção...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => doSearch(),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: loading ? null : doSearch,
                      icon: loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search),
                      label: Text(loading ? 'Buscando...' : 'Buscar'),
                      style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text('Nenhum item encontrado.'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, i) {
                                final e = results[i];
                                final added = _itensReferencia.any((it) => (it['item_referencia_id'] ?? '').toString() == e.id);
                                final artigoLabel = [
                                  if ((e.artigo ?? '').trim().isNotEmpty) 'Art. ${e.artigo}',
                                  if ((e.complemento ?? '').trim().isNotEmpty) e.complemento!,
                                ].join(' ').trim();
                                final title = (e.descricaoItem ?? '').trim().isNotEmpty ? e.descricaoItem!.trim() : e.normaTitulo;
                                final subtitleParts = <String>[
                                  if (artigoLabel.isNotEmpty) artigoLabel,
                                  if ((e.normaTitulo).trim().isNotEmpty && title != e.normaTitulo) e.normaTitulo,
                                  if (e.prazoPadraoDias != null) 'Prazo padrão: ${e.prazoPadraoDias} dias',
                                ];
                                return Card(
                                  elevation: 0,
                                  color: Colors.black.withValues(alpha: 0.03),
                                  child: ListTile(
                                    title: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      subtitleParts.where((x) => x.trim().isNotEmpty).join(' • '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: added
                                        ? null
                                        : () async {
                                            await _adicionarItemReferencia(e);
                                          },
                                    trailing: SizedBox(
                                      width: 164,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            onPressed: () => _verBaseLegalDetalhe(e.id),
                                            icon: const Icon(Icons.gavel_outlined),
                                            tooltip: 'Ver Base Legal',
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: added
                                                  ? null
                                                  : () async {
                                                      await _adicionarItemReferencia(e);
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _govBlue,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(added ? 'Adicionado' : 'Adicionar'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
  }

  Widget _buildItensReferenciaAgrupadosPorPrazo() {
    if (_itensReferencia.isEmpty) return const SizedBox.shrink();
    final items = [..._itensReferencia];
    items.sort((a, b) {
      final pa = int.tryParse((a['prazo_dias'] ?? '').toString()) ?? 0;
      final pb = int.tryParse((b['prazo_dias'] ?? '').toString()) ?? 0;
      if (pa != pb) return pa.compareTo(pb);
      final va = (a['data_vencimento_br'] ?? '').toString();
      final vb = (b['data_vencimento_br'] ?? '').toString();
      return va.compareTo(vb);
    });

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final dias = int.tryParse((it['prazo_dias'] ?? '').toString()) ?? 0;
      final venc = (it['data_vencimento_br'] ?? '').toString().trim();
      final key = '$dias|$venc';
      groups.putIfAbsent(key, () => []).add(it);
    }

    return Column(
      children: groups.entries.map((e) {
        final parts = e.key.split('|');
        final dias = parts.isNotEmpty ? parts[0] : '';
        final venc = parts.length > 1 ? parts[1] : '';
        return Card(
          elevation: 0,
          color: Colors.black.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ['Prazo: $dias dias', venc.isEmpty ? '' : 'Vencimento: $venc'].where((x) => x.trim().isNotEmpty).join(' — '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...e.value.map((it) {
                  final id = (it['id'] ?? '').toString();
                  final desc = (it['descricao'] ?? '').toString().trim();
                  final base = (it['base_legal_resumo'] ?? '').toString().trim();
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      title: Text(desc.isEmpty ? 'Item' : desc),
                      subtitle: base.isEmpty ? null : Text(base),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _verBaseLegalDetalhe((it['base_legal_id'] ?? '').toString()),
                            icon: const Icon(Icons.gavel_outlined),
                            tooltip: 'Ver Base Legal',
                          ),
                          IconButton(
                            onPressed: _documentoBloqueado ? null : () => _editarItemReferencia(id),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            onPressed: _documentoBloqueado ? null : () => _removerItemReferencia(id),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remover',
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProvidenciasPrazoStep() {
    String? itensReferenciaValidator(String? _) {
      if (_tipoDocumento != _tipoAutoIntimacao) return null;
      return _validarItensReferenciaPreenchidos();
    }

    String? prazoValidator(String? _) {
      if (_tipoDocumento == _tipoAutoIntimacao) return null;
      final prazo = int.tryParse(_prazoCumprimentoDiasCtrl.text.trim());
      if (prazo == null || prazo <= 0) return 'Informe um número inteiro positivo';
      return null;
    }

    String? vencimentoValidator(String? _) {
      if (_tipoDocumento == _tipoAutoIntimacao) return null;
      if (_vencimentoPrazoCtrl.text.trim().isEmpty) return 'Vencimento obrigatório';
      return null;
    }

    return Form(
      key: _providenciasPrazoFormKey,
      child: OfficialSectionCard(
        title: 'Providências/Prazo',
        icon: Icons.rule_folder_outlined,
        child: Column(
          children: [
            OfficialMultilineField(
              controller: _descricaoProvidenciasCtrl,
              label: 'Descrição das Providências / Exigências / Outras Informações:',
              required: true,
            ),
            const SizedBox(height: 12),
            if (_tipoDocumento == _tipoAutoIntimacao) ...[
              OfficialSectionCard(
                title: 'Itens/Referência',
                icon: Icons.schedule_outlined,
                child: Column(
                  children: [
                    OfficialTextField(
                      controller: _itensReferenciaCtrl,
                      label: 'Itens/Referência',
                      required: true,
                      enabled: !_documentoBloqueado,
                      readOnly: true,
                      hint: 'Ex: cozinha suja, produto vencido, teto irregular, construção...',
                      helperText: 'Selecione um ou mais itens da Base Legal. Cada item terá prazo e vencimento próprios.',
                      suffixIcon: _documentoBloqueado
                          ? null
                          : IconButton(
                              onPressed: _abrirSelecaoItensReferencia,
                              icon: const Icon(Icons.search),
                              tooltip: 'Buscar itens',
                            ),
                      onTap: _documentoBloqueado ? null : _abrirSelecaoItensReferencia,
                      validator: itensReferenciaValidator,
                    ),
                    if (_itensReferencia.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildItensReferenciaAgrupadosPorPrazo(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_tipoDocumento != _tipoAutoIntimacao) ...[
              _responsiveRow([
                OfficialTextField(
                  controller: _prazoCumprimentoDiasCtrl,
                  label: 'Prazo para cumprimento das exigências (dias)',
                  required: true,
                  enabled: !_documentoBloqueado,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: prazoValidator,
                  onChanged: (_) => _recalcularVencimentoPrazo(),
                ),
                OfficialTextField(
                  controller: _vencimentoPrazoCtrl,
                  label: 'Data de vencimento do prazo',
                  required: true,
                  readOnly: true,
                  enabled: false,
                  validator: vencimentoValidator,
                ),
              ]),
              const SizedBox(height: 12),
            ],
            _buildCienciaCard(),
            const SizedBox(height: 12),
            OfficialMultilineField(
              controller: _comentarioFiscalizacaoCtrl,
              label: 'Comentário/Relatório Interno',
              minLines: 3,
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecebimentoAssinaturasStep() {
    String? requiredValidator(String? v) {
      if ((v ?? '').trim().isEmpty) return 'Campo obrigatório';
      return null;
    }

    String? assinaturaRecebValidator(bool? _) {
      if (_assinaturaRecebimento == null) return 'Assinatura obrigatória';
      return null;
    }

    String? autoridadesValidator(bool? _) {
      if (_autoridadesSaude.isEmpty) return 'Adicione ao menos uma autoridade';
      for (final a in _autoridadesSaude) {
        if (a.nomeCtrl.text.trim().isEmpty) return 'Informe a autoridade de saúde';
        if (a.funcaoCtrl.text.trim().isEmpty) return 'Informe a função da autoridade';
        if (a.assinatura == null) return 'Assinatura da autoridade é obrigatória';
      }
      return null;
    }

    return Form(
      key: _recebimentoAssinaturasFormKey,
      child: Column(
        children: [
          OfficialSectionCard(
            title: 'Recebimento',
            icon: Icons.how_to_reg_outlined,
            child: Column(
              children: [
                _responsiveRow([
                  OfficialTextField(
                    controller: _recebimentoDataCtrl,
                    label: 'Recebido em',
                    required: true,
                    readOnly: true,
                    onTap: _documentoBloqueado ? null : () => _pickDateOnly(_recebimentoDataCtrl),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    validator: requiredValidator,
                  ),
                  OfficialTextField(
                    controller: _recebimentoHoraCtrl,
                    label: 'Horário',
                    required: true,
                    readOnly: true,
                    onTap: _documentoBloqueado ? null : () => _pickTimeOnly(_recebimentoHoraCtrl),
                    suffixIcon: const Icon(Icons.schedule_outlined),
                    validator: requiredValidator,
                  ),
                ]),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _recebimentoResponsavelCtrl,
                  label: 'Responsável',
                  required: true,
                  enabled: !_documentoBloqueado,
                  validator: requiredValidator,
                ),
                const SizedBox(height: 12),
                _buildAssinaturaRow(
                  label: 'Assinatura',
                  required: true,
                  hasValue: _assinaturaRecebimento != null,
                  onPressed: () {
                    if (_documentoBloqueado) return;
                    () async {
                      final bytes = await _abrirAssinatura();
                      if (!mounted) return;
                      if (bytes != null) _formSetState(() => _assinaturaRecebimento = bytes);
                    }();
                  },
                  onClear: () {
                    if (_documentoBloqueado) return;
                    _formSetState(() => _assinaturaRecebimento = null);
                  },
                ),
                FormField<bool>(
                  validator: assinaturaRecebValidator,
                  builder: (state) {
                    if (state.errorText == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(state.errorText!, style: const TextStyle(color: _statusRed)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OfficialSectionCard(
            title: 'Em caso de recusa do responsável',
            icon: Icons.person_off_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Responsável recusou assinatura'),
                  value: _responsavelRecusouAssinatura,
                  onChanged: _documentoBloqueado ? null : (v) => _formSetState(() => _responsavelRecusouAssinatura = v),
                ),
                if (_responsavelRecusouAssinatura) ...[
                  const SizedBox(height: 12),
                  _responsiveRow([
                    OfficialTextField(
                      controller: _testemunha1RecusaCtrl,
                      label: '1ª testemunha',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: requiredValidator,
                    ),
                    OfficialTextField(
                      controller: _testemunha2RecusaCtrl,
                      label: '2ª testemunha',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: requiredValidator,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _responsiveRow([
                    _buildAssinaturaRow(
                      label: 'Assinatura (1ª testemunha)',
                      required: true,
                      hasValue: _assinaturaTestemunha1 != null,
                      onPressed: () {
                        if (_documentoBloqueado) return;
                        () async {
                          final bytes = await _abrirAssinatura();
                          if (!mounted) return;
                          if (bytes != null) _formSetState(() => _assinaturaTestemunha1 = bytes);
                        }();
                      },
                      onClear: () {
                        if (_documentoBloqueado) return;
                        _formSetState(() => _assinaturaTestemunha1 = null);
                      },
                    ),
                    _buildAssinaturaRow(
                      label: 'Assinatura (2ª testemunha)',
                      required: true,
                      hasValue: _assinaturaTestemunha2 != null,
                      onPressed: () {
                        if (_documentoBloqueado) return;
                        () async {
                          final bytes = await _abrirAssinatura();
                          if (!mounted) return;
                          if (bytes != null) _formSetState(() => _assinaturaTestemunha2 = bytes);
                        }();
                      },
                      onClear: () {
                        if (_documentoBloqueado) return;
                        _formSetState(() => _assinaturaTestemunha2 = null);
                      },
                    ),
                  ]),
                  FormField<bool>(
                    validator: (_) {
                      if (!_responsavelRecusouAssinatura) return null;
                      if (_assinaturaTestemunha1 == null || _assinaturaTestemunha2 == null) return 'Assinaturas das testemunhas são obrigatórias';
                      return null;
                    },
                    builder: (state) {
                      if (state.errorText == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(state.errorText!, style: const TextStyle(color: _statusRed)),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          OfficialSectionCard(
            title: 'Autoridade de Saúde',
            icon: Icons.verified_user_outlined,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _documentoBloqueado
                        ? null
                        : () {
                            _formSetState(() => _autoridadesSaude = [..._autoridadesSaude, _AutoridadeSaudeItem()]);
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Autoridade'),
                  ),
                ),
                const SizedBox(height: 12),
                ..._autoridadesSaude.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final a = entry.value;
                  return Card(
                    elevation: 0,
                    color: Colors.black.withValues(alpha: 0.03),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Autoridade ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (_autoridadesSaude.length > 1)
                                IconButton(
                                  onPressed: _documentoBloqueado
                                      ? null
                                      : () {
                                          setState(() {
                                            final next = [..._autoridadesSaude];
                                            final removed = next.removeAt(idx);
                                            removed.dispose();
                                            _autoridadesSaude = next;
                                          });
                                        },
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Remover',
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _responsiveRow([
                            OfficialTextField(
                              controller: a.nomeCtrl,
                              label: 'Autoridade de Saúde',
                              required: true,
                              enabled: !_documentoBloqueado,
                            ),
                            OfficialTextField(
                              controller: a.funcaoCtrl,
                              label: 'Função',
                              required: true,
                              enabled: !_documentoBloqueado,
                            ),
                          ]),
                          const SizedBox(height: 12),
                          _buildAssinaturaRow(
                            label: 'Assinatura',
                            required: true,
                            hasValue: a.assinatura != null,
                            onPressed: () {
                              if (_documentoBloqueado) return;
                              () async {
                                final bytes = await _abrirAssinatura();
                                if (!mounted) return;
                                if (bytes != null) _formSetState(() => a.assinatura = bytes);
                              }();
                            },
                            onClear: () {
                              if (_documentoBloqueado) return;
                              _formSetState(() => a.assinatura = null);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                FormField<bool>(
                  validator: autoridadesValidator,
                  builder: (state) {
                    if (state.errorText == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(state.errorText!, style: const TextStyle(color: _statusRed)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstabResults() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _estabResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _estabResults[index];
          final nome = (item['razaoSocial'] ??
                  item['razao_social'] ??
                  item['nomeRazaoSocial'] ??
                  item['nome_razao_social'] ??
                  item['nomeFantasia'] ??
                  item['nome_fantasia'] ??
                  item['nome'] ??
                  '-')
              .toString();
          return ListTile(
            title: Text(nome),
            subtitle: Text(_formatCnpj((item['cnpj'] ?? '').toString())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selecionarEstabelecimento(item),
          );
        },
      ),
    );
  }

  Future<void> _buscarBaseLegalSinnc() async {
    final result = await Navigator.pushNamed(
      context,
      '/base-legal',
      arguments: {'selectionMode': true},
    );
    if (!mounted) return;
    final selecionados = <Map<String, dynamic>>[];
    if (result is List) {
      for (final e in result) {
        if (e is Map) selecionados.add(Map<String, dynamic>.from(e));
      }
    } else if (result is Map) {
      selecionados.add(Map<String, dynamic>.from(result));
    }
    if (selecionados.isEmpty) return;

    final novos = <Map<String, dynamic>>[];
    for (final vinculo in selecionados) {
      final id = (vinculo['id'] ?? vinculo['base_legal_id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (_basesLegaisVinculadas.any((e) => (e['id'] ?? e['base_legal_id'] ?? '').toString().trim() == id)) {
        continue;
      }
      final m = Map<String, dynamic>.from(vinculo);
      if (_tipoDocumento == _tipoAutoInfracao) {
        m.putIfAbsent('origem_tipo', () => 'MANUAL');
      }
      novos.add(m);
    }
    if (novos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base legal já adicionada.')),
      );
      return;
    }

    _formSetState(() => _basesLegaisVinculadas = [..._basesLegaisVinculadas, ...novos]);

    if (_baseLegalCtrl.text.trim().isEmpty &&
        _tipoDocumento != _tipoAutoIntimacao &&
        _tipoDocumento != _tipoAutoInfracao) {
      final vinculo = novos.first;
      final tipo = (vinculo['tipo'] ?? '').toString().trim();
      final numero = (vinculo['numero'] ?? '').toString().trim();
      final ano = (vinculo['ano'] ?? '').toString().trim();
      final esfera = (vinculo['esfera'] ?? '').toString().trim();
      final artigo = (vinculo['artigo'] ?? '').toString().trim();
      final inciso = (vinculo['inciso'] ?? '').toString().trim();
      final paragrafo = (vinculo['paragrafo'] ?? '').toString().trim();
      final descricao = (vinculo['descricao'] ?? '').toString().trim();
      final observacoes = (vinculo['observacoes'] ?? '').toString().trim();
      _baseLegalCtrl.text = [tipo, [numero, ano].where((e) => e.isNotEmpty).join('/'), esfera.isEmpty ? '' : '($esfera)']
          .where((e) => e.trim().isNotEmpty)
          .join(' ')
          .trim();
      if (_artigoCtrl.text.trim().isEmpty && artigo.isNotEmpty) _artigoCtrl.text = artigo;
      if (_incisoCtrl.text.trim().isEmpty && inciso.isNotEmpty) _incisoCtrl.text = inciso;
      if (_paragrafoCtrl.text.trim().isEmpty && paragrafo.isNotEmpty) _paragrafoCtrl.text = paragrafo;
      if (_enquadramentoLegalCtrl.text.trim().isEmpty && descricao.isNotEmpty) _enquadramentoLegalCtrl.text = descricao;
      if (_observacoesLegaisCtrl.text.trim().isEmpty && observacoes.isNotEmpty) _observacoesLegaisCtrl.text = observacoes;
    }
  }

  void _removerBaseLegalVinculada(String id) {
    _formSetState(() {
      _basesLegaisVinculadas = _basesLegaisVinculadas.where((e) => (e['id'] ?? e['base_legal_id'] ?? '').toString() != id).toList();
    });
  }

  Future<void> _adicionarBaseLegalManual() async {
    final baseCtrl = TextEditingController();
    final artigoCtrl = TextEditingController();
    final incisoCtrl = TextEditingController();
    final paragrafoCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();

    final added = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Base Legal (manual)'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OfficialTextField(controller: baseCtrl, label: 'Base legal', required: true),
                const SizedBox(height: 12),
                _responsiveRow([
                  OfficialTextField(controller: artigoCtrl, label: 'Artigo'),
                  OfficialTextField(controller: incisoCtrl, label: 'Inciso'),
                  OfficialTextField(controller: paragrafoCtrl, label: 'Parágrafo'),
                ]),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: descricaoCtrl,
                  label: 'Descrição / Observações',
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (baseCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(<String, dynamic>{
                'id': 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
                'origem_tipo': 'MANUAL',
                'base_legal': baseCtrl.text.trim(),
                'artigo': artigoCtrl.text.trim(),
                'inciso': incisoCtrl.text.trim(),
                'paragrafo': paragrafoCtrl.text.trim(),
                'descricao': descricaoCtrl.text.trim(),
              });
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    baseCtrl.dispose();
    artigoCtrl.dispose();
    incisoCtrl.dispose();
    paragrafoCtrl.dispose();
    descricaoCtrl.dispose();

    if (added == null) return;
    _formSetState(() => _basesLegaisVinculadas = [..._basesLegaisVinculadas, added]);
  }

  Widget _buildBaseLegalStep() {
    return Form(
      key: _baseLegalFormKey,
      child: OfficialSectionCard(
        title: 'Base legal',
        icon: Icons.gavel_outlined,
        child: Column(
          children: [
            if (_tipoDocumento == _tipoAutoInfracao) ...[
              OfficialSectionCard(
                title: 'Importar dados de Auto de Intimação anterior',
                icon: Icons.download_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Você pode importar bases legais e descrições já lançadas em uma ou mais intimações deste estabelecimento.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (_infracaoDesejaImportarIntimacao == null)
                      _responsiveRow([
                        ElevatedButton.icon(
                          onPressed: _documentoBloqueado
                              ? null
                              : () => _formSetState(() => _infracaoDesejaImportarIntimacao = true),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Importar Intimação'),
                          style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                        ),
                        OutlinedButton(
                          onPressed: _documentoBloqueado
                              ? null
                              : () => _formSetState(() => _infracaoDesejaImportarIntimacao = false),
                          child: const Text('Preencher Manualmente'),
                        ),
                      ])
                    else if (_infracaoDesejaImportarIntimacao == false)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Preenchimento manual selecionado.'),
                      )
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _documentoBloqueado
                              ? null
                              : () async {
                                  final chosen = await _abrirSeletorIntimacoes();
                                  if (!mounted) return;
                                  if (chosen.isEmpty) return;
                                  _formSetState(() => _infracaoIntimacoesSelecionadas = chosen);
                                },
                          icon: const Icon(Icons.search_outlined),
                          label: const Text('Selecionar Intimações da Empresa'),
                        ),
                      ),
                      if (_infracaoIntimacoesSelecionadas.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._infracaoIntimacoesSelecionadas.map((doc) {
                          final numeroAno = _autoIntimacaoNumeroAnoFromDoc(doc);
                          final dataReceb = _autoIntimacaoDataRecebimentoBrFromDoc(doc);
                          return Card(
                            elevation: 0,
                            color: Colors.black.withValues(alpha: 0.03),
                            child: ListTile(
                              title: Text(numeroAno.isEmpty ? 'Auto de Intimação' : numeroAno),
                              subtitle: dataReceb.isEmpty ? null : Text('Recebido em $dataReceb'),
                              trailing: IconButton(
                                onPressed: _documentoBloqueado
                                    ? null
                                    : () {
                                        final id = (doc['id'] ?? '').toString();
                                        _formSetState(() {
                                          _infracaoIntimacoesSelecionadas =
                                              _infracaoIntimacoesSelecionadas.where((e) => (e['id'] ?? '').toString() != id).toList();
                                        });
                                      },
                                icon: const Icon(Icons.close),
                                tooltip: 'Remover',
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _documentoBloqueado ? null : _importarDadosDasIntimacoesSelecionadas,
                            icon: const Icon(Icons.check),
                            label: const Text('Importar dados'),
                            style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'As informações foram importadas, mas podem ser editadas antes de salvar.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OfficialSectionCard(
                title: 'Auto de Intimação relacionado',
                icon: Icons.link_outlined,
                child: _buildAutoIntimacaoRelacionadaSection(),
              ),
              const SizedBox(height: 12),
            ],
            if (_tipoDocumento == _tipoAutoIntimacao || _tipoDocumento == _tipoAutoInfracao) ...[
              _responsiveRow([
                OutlinedButton.icon(
                  onPressed: _documentoBloqueado ? null : _buscarBaseLegalSinnc,
                  icon: const Icon(Icons.add),
                  label: const Text('Inserir Base Legal'),
                ),
                OutlinedButton.icon(
                  onPressed: _documentoBloqueado ? null : _adicionarBaseLegalManual,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Adicionar Manual'),
                ),
              ]),
              FormField<bool>(
                validator: (_) {
                  if (_tipoDocumento != _tipoAutoIntimacao && _tipoDocumento != _tipoAutoInfracao) return null;
                  if (_basesLegaisVinculadas.isEmpty) return 'Vincule ao menos 1 base legal';
                  return null;
                },
                builder: (state) {
                  if (state.errorText == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(state.errorText!, style: const TextStyle(color: _statusRed, fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
              if (_basesLegaisVinculadas.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._basesLegaisVinculadas.map((v) {
                  final id = (v['id'] ?? '').toString();
                  final grupo = (v['grupo_descricao'] ?? '').toString().trim();
                  final subgrupo = (v['subgrupo_descricao'] ?? '').toString().trim();
                  final tipo = (v['tipo'] ?? '').toString().trim();
                  final numero = (v['numero'] ?? '').toString().trim();
                  final ano = (v['ano'] ?? '').toString().trim();
                  final baseLegalManual = (v['base_legal'] ?? '').toString().trim();
                  final artigo = (v['artigo'] ?? '').toString().trim();
                  final descricao = (v['descricao'] ?? '').toString().trim();
                  final ementa = (v['ementa'] ?? '').toString().trim();
                  final origemTipo = (v['origem_tipo'] ?? '').toString().trim();
                  final origem = (v['origem'] ?? '').toString().trim();
                  final isPadrao = origemTipo == 'PADRAO';
                  final titulo = [
                    if (grupo.isNotEmpty && subgrupo.isNotEmpty) '$grupo > $subgrupo',
                    baseLegalManual.isNotEmpty
                        ? baseLegalManual
                        : [tipo, [numero, ano].where((e) => e.isNotEmpty).join('/')].where((e) => e.trim().isNotEmpty).join(' ').trim(),
                    if (artigo.isNotEmpty) 'Art. $artigo',
                  ].where((e) => e.trim().isNotEmpty).join(' • ');
                  final details = [ementa, descricao].where((e) => e.trim().isNotEmpty).join('\n\n');
                  final origensRaw = v['origens'];
                  final origens = <String>[
                    ...((origensRaw is List) ? origensRaw.map((e) => e.toString()) : const Iterable<String>.empty()),
                  ];
                  if (origens.isEmpty && origem.isNotEmpty) origens.add(origem);
                  final chipText = origemTipo == 'AUTO_INTIMACAO' && origens.isNotEmpty
                      ? (origens.length == 1 ? 'Importado de ${origens.first}' : 'Importado de ${origens.first} +${origens.length - 1}')
                      : null;
                  final subtitleParts = [
                    if (descricao.isNotEmpty) descricao,
                    if (_tipoDocumento == _tipoAutoInfracao && origemTipo.isNotEmpty)
                      origemTipo == 'AUTO_INTIMACAO'
                          ? 'Origem: ${origens.join(', ')}'
                          : (origemTipo == 'PADRAO' ? 'Base legal padrão' : 'Origem: manual'),
                  ].where((e) => e.trim().isNotEmpty).toList();
                  return Card(
                    elevation: 0,
                    color: Colors.black.withValues(alpha: 0.03),
                    child: InkWell(
                      onTap: () async {
                        if (details.isEmpty) return;
                        await showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Base Legal'),
                            content: SingleChildScrollView(child: Text(details)),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
                            ],
                          ),
                        );
                      },
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(titulo)),
                            if (chipText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F1FF),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFB6D4FE)),
                                ),
                                child: Text(
                                  chipText,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _govBlue),
                                ),
                              ),
                          ],
                        ),
                        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join('\n'), maxLines: 3, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          onPressed: (_tipoDocumento == _tipoAutoInfracao && isPadrao) ? null : () => _removerBaseLegalVinculada(id),
                          icon: const Icon(Icons.close),
                          tooltip: 'Remover',
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ] else ...[
              OfficialTextField(
                controller: _baseLegalCtrl,
                label: 'Enquadramento Legal (Legislação sanitária infringida que autoriza a medida):',
                required: _tipoDocumento != null && _tipoDocumento != _tipoInspecaoSanitaria,
              ),
              const SizedBox(height: 12),
              OfficialTextField(controller: _enquadramentoLegalCtrl, label: 'Enquadramento legal'),
              const SizedBox(height: 12),
              _responsiveRow([
                OfficialTextField(controller: _artigoCtrl, label: 'Artigo'),
                OfficialTextField(controller: _incisoCtrl, label: 'Inciso'),
                OfficialTextField(controller: _paragrafoCtrl, label: 'Parágrafo'),
              ]),
              const SizedBox(height: 12),
              OfficialMultilineField(
                controller: _observacoesLegaisCtrl,
                label: 'Observações legais',
                minLines: 4,
                maxLines: 6,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescricaoStep() {
    String? irregularidadesValidator(String? value) {
      if (_tipoDocumento != _tipoAutoIntimacao) return null;
      final v = (value ?? '').trim();
      if (v.isEmpty) return 'Campo obrigatório';
      if (v.length < 20) return 'Mínimo de 20 caracteres';
      return null;
    }

    String? especificacaoValidator(String? value) {
      if (_tipoDocumento != _tipoAutoInfracao) return null;
      final v = (value ?? '').trim();
      if (v.isEmpty) return 'Campo obrigatório';
      if (v.length < 20) return 'Mínimo de 20 caracteres';
      return null;
    }

    String? prazoValidator(String? value) {
      if (_tipoDocumento != _tipoAutoIntimacao) return null;
      final texto = _prazoCumprimentoTextoCtrl.text.trim();
      final data = _prazoCumprimentoDataCtrl.text.trim();
      if (texto.isEmpty && data.isEmpty) return 'Informe o prazo (texto ou data)';
      return null;
    }

    return Form(
      key: _descricaoFormKey,
      child: OfficialSectionCard(
        title: 'Descrição',
        icon: Icons.description_outlined,
        child: Column(
          children: [
            if (_tipoDocumento == _tipoAutoInfracao)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _especificacaoAtoCtrl,
                  label: 'Especificação Detalhada do Ato ou Fato (Constitutivo da Infração Sanitária Cometida):',
                  required: true,
                  minLines: 4,
                  maxLines: 10,
                  validator: especificacaoValidator,
                ),
              ),
            if (_showDescricaoIrregularidades)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _descricaoIrregularidadesCtrl,
                  label: 'Descrição das Irregularidades:',
                  required: _tipoDocumento == _tipoAutoIntimacao,
                  validator: irregularidadesValidator,
                ),
              ),
            if (_showDescricaoProvidencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _descricaoProvidenciasCtrl,
                  label: 'Descrição das Providências / Exigências / Outras Informações:',
                  required: _tipoDocumento != null && _tipoDocumento != _tipoInspecaoSanitaria,
                ),
              ),
            if (_tipoDocumento == _tipoAutoIntimacao)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _responsiveRow([
                  OfficialTextField(
                    controller: _prazoCumprimentoTextoCtrl,
                    label: 'Prazo para Cumprimento das Exigências:',
                    required: true,
                    validator: prazoValidator,
                    onChanged: (_) {
                      if (_prazoCumprimentoDataCtrl.text.trim().isNotEmpty) {
                        _prazoCumprimentoDataCtrl.clear();
                      }
                    },
                  ),
                  OfficialTextField(
                    controller: _prazoCumprimentoDataCtrl,
                    label: 'Vencimento do prazo',
                    readOnly: true,
                    required: true,
                    validator: prazoValidator,
                    onTap: () => _pickDateOnly(_prazoCumprimentoDataCtrl),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    onChanged: (_) {
                      if (_prazoCumprimentoTextoCtrl.text.trim().isNotEmpty) {
                        _prazoCumprimentoTextoCtrl.clear();
                      }
                    },
                  ),
                ]),
              ),
            if (_showComentarioFiscalizacao)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _comentarioFiscalizacaoCtrl,
                  label: 'Comentário sobre a Fiscalização:',
                ),
              ),
            if (_showEspecificacaoAto)
              OfficialMultilineField(
                controller: _especificacaoAtoCtrl,
                label: _tipoDocumento == _tipoImposicaoPenalidade
                    ? 'Especificação detalhada da penalidade imposta'
                    : 'Especificação Detalhada do Ato ou Fato (Constitutivo da Infração Sanitária Cometida):',
                required: _tipoDocumento == _tipoAutoInfracao || _tipoDocumento == _tipoImposicaoPenalidade,
              ),
            if (_tipoDocumento == _tipoAutoIntimacao || _tipoDocumento == _tipoAutoInfracao) ...[
              const SizedBox(height: 12),
              _buildCienciaCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCienciaCard() {
    final texto = _tipoDocumento == _tipoAutoIntimacao
        ? 'ESTOU CIENTE DE QUE O DESCUMPRIMENTO DAS EXIGÊNCIAS CONTIDAS NESTE AUTO PERMITIRÁ A APLICAÇÃO DAS SANÇÕES PREVISTAS PELO ART. 4º DA LEI COMPLEMENTAR Nº 40/19, SEM PREJUÍZO DE OUTRAS MEDIDAS LEGAIS E REGULAMENTARES. ESTOU CIENTE, AINDA, DE QUE PODEREI SOLICITAR PRORROGAÇÃO DO PRAZO AQUI ESTABELECIDO, UMA ÚNICA VEZ, JUSTIFICADAMENTE, À DIRETORIA DE VIGILÂNCIA SANITÁRIA DO MUNICÍPIO DE BALNEÁRIO CAMBORIÚ, NOS TERMOS DO §3º DO ART. 125 DA REFERIDA LEI.'
        : 'ESTOU CIENTE DE QUE, EM VIRTUDE DA INFRAÇÃO CARACTERIZADA NESTE AUTO, RESPONDEREI A PROCESSO ADMINISTRATIVO, FICANDO SUJEITO ÀS PENALIDADES PREVISTAS NOS INCISOS DO ART. 158 DA LEI COMPLEMENTAR Nº 40/19. ESTOU CIENTE, AINDA, QUE PODEREI APRESENTAR DEFESA POR ESCRITO, NO PRAZO DE 15 (QUINZE) DIAS A CONTAR DESTA NOTIFICAÇÃO, AO DIRETOR-GERAL DA DIVISÃO DE VIGILÂNCIA SANITÁRIA DO MUNICÍPIO DE BALNEÁRIO CAMBORIÚ.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFF664D03)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CIÊNCIA', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF664D03))),
                const SizedBox(height: 6),
                Text(texto, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF664D03))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _showDescricaoIrregularidades => _tipoDocumento == _tipoAutoIntimacao;

  bool get _showDescricaoProvidencias =>
      _tipoDocumento != _tipoInspecaoSanitaria && _tipoDocumento != _tipoAutoInfracao;

  bool get _showComentarioFiscalizacao =>
      _tipoDocumento == _tipoImposicaoPenalidade ||
      _tipoDocumento == _tipoInspecaoSanitaria ||
      _tipoDocumento == _tipoAutoInfracao ||
      _tipoDocumento == _tipoAutoIntimacao;

  bool get _showEspecificacaoAto => _tipoDocumento == _tipoImposicaoPenalidade;

  Widget _buildTipoDocumentoStep() {
    return Form(
      key: _tipoDocumentoFormKey,
      child: OfficialSectionCard(
        title: _tipoDocumentoLabel,
        icon: Icons.fact_check_outlined,
        child: Column(
          children: [
            if (_tipoDocumento == _tipoAutoIntimacao) ...[
              _buildCabecalhoAutoIntimacaoSection(),
              const SizedBox(height: 12),
              _buildDepartamentoLavraturaSection(
                dataLabel: 'Data da lavratura do Auto de Intimação',
                departamentoLabel: 'Nome do setor da Vigilância Sanitária',
              ),
              const SizedBox(height: 12),
              _buildContatoVisaSection(),
              const SizedBox(height: 12),
              OfficialSectionCard(
                title: 'Recebimento',
                icon: Icons.how_to_reg_outlined,
                child: Column(
                  children: [
                    _responsiveRow([
                      OfficialTextField(
                        controller: _recebimentoDataCtrl,
                        label: 'Recebido em',
                        required: true,
                        readOnly: true,
                        onTap: () => _pickDateOnly(_recebimentoDataCtrl),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                        onChanged: (v) => _auditChange('recebimento.data', v),
                      ),
                      OfficialTextField(
                        controller: _recebimentoHoraCtrl,
                        label: 'Horário',
                        required: true,
                        readOnly: true,
                        onTap: () => _pickTimeOnly(_recebimentoHoraCtrl),
                        suffixIcon: const Icon(Icons.schedule_outlined),
                        onChanged: (v) => _auditChange('recebimento.hora', v),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _recebimentoResponsavelCtrl,
                      label: 'Responsável',
                      required: true,
                      onChanged: (v) => _auditChange('recebimento.responsavel', v),
                    ),
                    const SizedBox(height: 12),
                    _buildAssinaturaRow(
                      label: 'Assinatura',
                      required: true,
                      hasValue: _assinaturaRecebimento != null,
                      onPressed: () async {
                        final bytes = await _abrirAssinatura();
                        if (!mounted) return;
                        if (bytes != null) setState(() => _assinaturaRecebimento = bytes);
                      },
                      onClear: () => setState(() => _assinaturaRecebimento = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OfficialSectionCard(
                title: 'Em caso de recusa do responsável',
                icon: Icons.person_off_outlined,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Responsável recusou assinatura'),
                      value: _responsavelRecusouAssinatura,
                      onChanged: (v) => setState(() => _responsavelRecusouAssinatura = v),
                    ),
                    if (_responsavelRecusouAssinatura) ...[
                      const SizedBox(height: 12),
                      _responsiveRow([
                        OfficialTextField(
                          controller: _testemunha1RecusaCtrl,
                          label: '1ª testemunha',
                          required: true,
                        ),
                        OfficialTextField(
                          controller: _testemunha2RecusaCtrl,
                          label: '2ª testemunha',
                          required: true,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _responsiveRow([
                        _buildAssinaturaRow(
                          label: 'Assinatura (1ª testemunha)',
                          required: true,
                          hasValue: _assinaturaTestemunha1 != null,
                          onPressed: () async {
                            final bytes = await _abrirAssinatura();
                            if (!mounted) return;
                            if (bytes != null) setState(() => _assinaturaTestemunha1 = bytes);
                          },
                          onClear: () => setState(() => _assinaturaTestemunha1 = null),
                        ),
                        _buildAssinaturaRow(
                          label: 'Assinatura (2ª testemunha)',
                          required: true,
                          hasValue: _assinaturaTestemunha2 != null,
                          onPressed: () async {
                            final bytes = await _abrirAssinatura();
                            if (!mounted) return;
                            if (bytes != null) setState(() => _assinaturaTestemunha2 = bytes);
                          },
                          onClear: () => setState(() => _assinaturaTestemunha2 = null),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OfficialSectionCard(
                title: 'Autoridade de Saúde',
                icon: Icons.verified_user_outlined,
                child: Column(
                  children: [
                    _responsiveRow([
                      OfficialTextField(
                        controller: _autoridadeSaudeCtrl,
                        label: 'Autoridade de Saúde',
                        required: true,
                        onChanged: (v) => _auditChange('autoridade.nome', v),
                      ),
                      OfficialTextField(
                        controller: _autoridadeFuncaoCtrl,
                        label: 'Função',
                        required: true,
                        onChanged: (v) => _auditChange('autoridade.funcao', v),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildAssinaturaRow(
                      label: 'Assinatura',
                      required: true,
                      hasValue: _assinaturaAutoridadeSaude != null,
                      onPressed: () async {
                        final bytes = await _abrirAssinatura();
                        if (!mounted) return;
                        if (bytes != null) setState(() => _assinaturaAutoridadeSaude = bytes);
                      },
                      onClear: () => setState(() => _assinaturaAutoridadeSaude = null),
                    ),
                  ],
                ),
              ),
            ],
            if (_tipoDocumento == _tipoAutoInfracao) ...[
              _buildCabecalhoAutoInfracaoSection(),
              const SizedBox(height: 12),
              _buildDepartamentoLavraturaSection(
                dataLabel: 'Data da lavratura do Auto de Infração',
                departamentoLabel: 'Nome do setor da Vigilância Sanitária',
              ),
              const SizedBox(height: 12),
              _buildContatoVisaSection(),
            ],
            if (_tipoDocumento == _tipoImposicaoPenalidade) ...[
              _buildDepartamentoLavraturaSection(
                dataLabel: 'Data da lavratura da Imposição de Penalidade',
              ),
              const SizedBox(height: 12),
              _buildVinculoSection('Imposição de Penalidade relacionada'),
            ],
            if (_tipoDocumento == _tipoAutoColeta) ...[
              OfficialDropdownField.fromStrings(
                value: _tipoAmostra,
                items: _tiposAmostra,
                onChanged: (value) {
                  setState(() {
                    _tipoAmostra = value ?? _tiposAmostra.first;
                    _tipoAmostraCtrl.text = _tipoAmostra;
                  });
                },
                label: 'Tipo de Amostra',
                required: true,
              ),
              const SizedBox(height: 12),
              _buildDepartamentoLavraturaSection(dataLabel: 'Data da lavratura do Auto de Coleta'),
            ],
          ],
        ),
      ),
    );
  }

  String _autoInfracaoNumeroFallback() {
    final year = DateTime.now().year;
    final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    return 'INF-$year-$seq';
  }

  String _autoIntimacaoNumeroFallback() {
    final year = DateTime.now().year;
    final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    return 'INT-$year-$seq';
  }

  String _setorAutoIntimacaoLabel() {
    switch (_departamento) {
      case 'Departamento de Fiscalização de Alimentos':
        return 'SETOR DE FISCALIZAÇÃO DE ALIMENTOS';
      case 'Departamento de Fiscalização de Serviços de Saúde e de Interesse à Saúde':
        return 'SETOR DE FISCALIZAÇÃO DE SERVIÇOS DE SAÚDE E DE INTERESSE À SAÚDE';
      case 'Centro de Controle de Pragas Urbanas':
        return 'CENTRO DE CONTROLE DE PRAGAS URBANAS';
      case 'Programa Municipal de Controle da Dengue':
        return 'PROGRAMA MUNICIPAL DE CONTROLE DA DENGUE';
      default:
        return _departamento.toUpperCase();
    }
  }

  Widget _buildCabecalhoAutoIntimacaoSection() {
    final numero = (_numeroAutoIntimacao ?? '').trim().isEmpty ? _autoIntimacaoNumeroFallback() : _numeroAutoIntimacao!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ESTADO DE SANTA CATARINA',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'PREFEITURA DE BALNEÁRIO CAMBORIÚ',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'SECRETARIA MUNICIPAL DE SAÚDE',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'DIVISÃO DE VIGILÂNCIA SANITÁRIA',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _setorAutoIntimacaoLabel(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AUTO DE INTIMAÇÃO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  numero,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalhoAutoInfracaoSection() {
    final numero = (_numeroAutoInfracao ?? '').trim().isEmpty ? _autoInfracaoNumeroFallback() : _numeroAutoInfracao!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ESTADO DE SANTA CATARINA',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'PREFEITURA DE BALNEÁRIO CAMBORIÚ',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'SECRETARIA DE SAÚDE E SANEAMENTO',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'DIVISÃO DE VIGILÂNCIA SANITÁRIA',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _departamento.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'ENDEREÇO: Rua 1500, nº 1100, Centro – Balneário Camboriú / SC',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AUTO DE INFRAÇÃO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  numero,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContatoVisaSection() {
    String? emailValidator(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return 'Campo obrigatório';
      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
      return ok ? null : 'E-mail inválido';
    }

    return Column(
      children: [
        _responsiveRow([
          OfficialPhoneField(
            controller: _telefoneVisaCtrl,
            label: 'Telefone da VISA',
            required: true,
          ),
          OfficialTextField(
            controller: _emailVisaCtrl,
            label: 'E-mail da VISA',
            required: true,
            keyboardType: TextInputType.emailAddress,
            validator: emailValidator,
          ),
        ]),
      ],
    );
  }

  Widget _buildDepartamentoLavraturaSection({
    String dataLabel = 'Data da lavratura do Auto de Intimação',
    String departamentoLabel = 'Departamento da Vigilância Sanitária',
  }) {
    return Column(
      children: [
        OfficialDropdownField.fromStrings(
          value: _departamento,
          items: _departamentos,
          onChanged: (value) {
            _formSetState(() {
              _departamento = value ?? _departamentos.first;
              _departamentoCtrl.text = _departamento;
            });
          },
          label: departamentoLabel,
          required: true,
        ),
        const SizedBox(height: 12),
        OfficialTextField(
          controller: _dataLavraturaCtrl,
          label: dataLabel,
          required: true,
          readOnly: true,
          onTap: () => _pickDateOnly(_dataLavraturaCtrl),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    );
  }

  Widget _buildAutoIntimacaoRelacionadaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveRow([
          OfficialTextField(
            controller: _documentoRelacionadoCtrl,
            label: 'Número/Ano do Auto de Intimação',
            required: false,
          ),
          OfficialTextField(
            controller: _dataRecebimentoCtrl,
            label: 'Data de recebimento',
            required: false,
            readOnly: true,
            onTap: () => _pickDateOnly(_dataRecebimentoCtrl),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _adicionarAutoIntimacaoRelacionado,
            style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Intimação'),
          ),
        ),
        const SizedBox(height: 12),
        if (_autosIntimacaoRelacionados.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Nenhum auto de intimação relacionado.'),
          )
        else
          Column(
            children: List.generate(_autosIntimacaoRelacionados.length, (index) {
              final item = _autosIntimacaoRelacionados[index];
              final numeroAno = (item['numero_ano'] ?? '').toString();
              final dataReceb = (item['data_recebimento_br'] ?? item['data_recebimento'] ?? '').toString();
              return Card(
                elevation: 0,
                color: Colors.black.withValues(alpha: 0.03),
                child: ListTile(
                  title: Text(numeroAno),
                  subtitle: Text(dataReceb),
                  trailing: IconButton(
                    onPressed: () => _removerAutoIntimacaoRelacionado(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remover',
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildVinculoSection(String label) {
    return Column(
      children: [
        _responsiveRow([
          OfficialNumericField(
            controller: _anoRelacionadoCtrl,
            label: 'Ano',
            minValue: 2000,
            maxValue: 2100,
          ),
          OfficialTextField(
            controller: _documentoRelacionadoCtrl,
            label: label,
            required: true,
          ),
          OfficialTextField(
            controller: _dataRecebimentoCtrl,
            label: 'Data do recebimento',
            readOnly: true,
            onTap: () => _pickDateOnly(_dataRecebimentoCtrl),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _adicionarVinculo,
            style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
        ),
        const SizedBox(height: 12),
        _buildVinculosTable(),
      ],
    );
  }

  Widget _buildVinculosTable() {
    if (_vinculosRelacionados.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Nenhum vínculo adicionado.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Número')),
          DataColumn(label: Text('Ano')),
          DataColumn(label: Text('Data do recebimento')),
        ],
        rows: _vinculosRelacionados
            .map(
              (item) => DataRow(cells: [
                DataCell(Text((item['numero'] ?? '').toString())),
                DataCell(Text((item['ano'] ?? '').toString())),
                DataCell(Text((item['data_recebimento'] ?? '').toString())),
              ]),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInspecaoStep() {
    return Form(
      key: _inspecaoFormKey,
      child: OfficialSectionCard(
        title: 'Inspeção sanitária',
        icon: Icons.health_and_safety_outlined,
        child: Column(
          children: [
            OfficialMultilineField(
              controller: _situacaoEncontradaCtrl,
              label: 'Situação encontrada',
              required: true,
            ),
            const SizedBox(height: 12),
            OfficialMultilineField(
              controller: _observacoesInspecaoCtrl,
              label: 'Observações',
            ),
            const SizedBox(height: 12),
            _responsiveRow([
              OfficialTextField(
                controller: _nomeFantasiaCtrl,
                label: 'Vínculo com estabelecimento',
                readOnly: true,
              ),
              OfficialTextField(
                controller: _profissionalCtrl,
                label: 'Vínculo com profissional/fiscal',
                readOnly: true,
              ),
            ]),
            const SizedBox(height: 12),
            _responsiveRow([
              OfficialTextField(controller: _dataHoraCtrl, label: 'Data e hora', readOnly: true),
              OfficialTextField(controller: _tipoDocumentoLabelCtrl, label: 'Tipo de documento', readOnly: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildProfissionaisStep() {
    return Form(
      key: _profissionaisFormKey,
      child: OfficialSectionCard(
        title: 'Profissionais da Equipe',
        icon: Icons.groups_outlined,
        child: Column(
          children: [
            _responsiveRow([
              OfficialTextField(
                controller: _profissionalEquipeCtrl,
                label: 'Profissionais da equipe',
                required: true,
                validator: (value) => value == null || value.trim().isEmpty ? 'Campo obrigatório' : null,
              ),
              OfficialTextField(
                controller: _funcaoEquipeCtrl,
                label: 'Função',
                required: true,
                validator: (value) => value == null || value.trim().isEmpty ? 'Campo obrigatório' : null,
              ),
            ]),
            const SizedBox(height: 12),
            _responsiveRow([
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cadastro de novo profissional deve usar o módulo existente.')),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Novo'),
              ),
              ElevatedButton.icon(
                onPressed: _adicionarProfissionalEquipe,
                style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ]),
            const SizedBox(height: 12),
            _buildProfissionaisTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfissionaisTable() {
    if (_profissionaisEquipe.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Nenhum profissional adicionado.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Código do profissional')),
          DataColumn(label: Text('Nome do profissional')),
          DataColumn(label: Text('Código da especialidade')),
          DataColumn(label: Text('Função')),
          DataColumn(label: Text('Remover')),
        ],
        rows: List.generate(_profissionaisEquipe.length, (index) {
          final item = _profissionaisEquipe[index];
          return DataRow(cells: [
            DataCell(Text((item['codigo_profissional'] ?? '').toString())),
            DataCell(Text((item['nome_profissional'] ?? '').toString())),
            DataCell(Text((item['codigo_especialidade'] ?? '').toString())),
            DataCell(Text((item['funcao'] ?? '').toString())),
            DataCell(
              IconButton(
                onPressed: () => _removerProfissionalEquipe(index),
                icon: const Icon(Icons.delete_outline, color: _statusRed),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _buildReviewStep() {
    final payload = _buildPayload();
    final dados = (payload['dados_estabelecimento'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final baseLegal = (() {
      if (_tipoDocumento == _tipoAutoIntimacao) {
        final ai = (payload['auto_intimacao'] as Map?)?.cast<String, dynamic>();
        return (ai?['base_legal'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      }
      if (_tipoDocumento == _tipoAutoInfracao) {
        final ai = (payload['auto_infracao'] as Map?)?.cast<String, dynamic>();
        return (ai?['base_legal'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      }
      if (_tipoDocumento == _tipoImposicaoPenalidade) {
        final ip = (payload['imposicao_penalidade'] as Map?)?.cast<String, dynamic>();
        return (ip?['base_legal'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      }
      return const <String, dynamic>{};
    })();
    final ai = (payload['auto_intimacao'] as Map?)?.cast<String, dynamic>();
    final aiBasesLegais = (ai?['bases_legais'] as List?)?.cast<dynamic>() ?? const [];
    final prazoSource = _itensReferencia.isNotEmpty ? _itensReferencia : _prazosExigencias;
    final prazosLabel = prazoSource.isNotEmpty
        ? prazoSource
            .map((p) {
              final m = Map<String, dynamic>.from(p);
              final ref = (m['referencia'] ?? m['descricao'] ?? '').toString().trim();
              final dias = (m['prazo_dias'] ?? '').toString().trim();
              final venc = (m['data_vencimento_br'] ?? m['data_vencimento'] ?? '').toString().trim();
              return [ref.isEmpty ? '' : 'Itens $ref', dias.isEmpty ? '' : '$dias dias', venc.isEmpty ? '' : 'vencimento $venc']
                  .where((e) => e.isNotEmpty)
                  .join(' — ');
            })
            .where((e) => e.trim().isNotEmpty)
            .join('\n')
        : [
            _prazoCumprimentoDiasCtrl.text.trim().isEmpty ? '' : '${_prazoCumprimentoDiasCtrl.text.trim()} dias',
            _vencimentoPrazoCtrl.text.trim().isEmpty ? '' : 'vencimento ${_vencimentoPrazoCtrl.text.trim()}',
          ].where((e) => e.isNotEmpty).join(' — ');
    return OfficialSectionCard(
      title: 'Revisão',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewRow('Número/Ano', _buildNumeroAno()),
          _reviewRow('Tipo de documento', _tipoDocumentoLabel),
          _reviewRow('Estabelecimento', _nomeFantasiaCtrl.text),
          _reviewRow('CNPJ', _cnpjCtrl.text),
          _reviewRow('Data e hora', _dataHoraCtrl.text),
          _reviewRow('Profissional/Fiscal', _profissionalCtrl.text),
          _reviewRow('Status', (payload['status'] ?? '').toString()),
          const Divider(height: 24),
          _reviewSectionTitle('Prévia do documento'),
          _reviewRow('Inscrição Municipal', (dados['inscricao_municipal'] ?? '').toString()),
          _reviewRow('Endereço', (dados['endereco'] ?? '').toString(), multiline: true),
          _reviewRow('Responsável legal', (dados['responsavel_legal'] ?? '').toString()),
          const SizedBox(height: 8),
          _reviewSectionTitle('Base legal'),
          _reviewRow('Enquadramento legal', (baseLegal['enquadramento_legal'] ?? baseLegal['base_legal'] ?? '').toString(), multiline: true),
          if (_tipoDocumento == _tipoAutoIntimacao)
            _reviewRow(
              'Bases vinculadas',
              aiBasesLegais
                  .map((e) {
                    final m = e is Map ? Map<String, dynamic>.from(e) : const <String, dynamic>{};
                    final base = (m['base_legal'] ?? '').toString().trim();
                    final artigo = (m['artigo'] ?? '').toString().trim();
                    final inciso = (m['inciso'] ?? '').toString().trim();
                    final paragrafo = (m['paragrafo'] ?? '').toString().trim();
                    final parts = [
                      base,
                      artigo.isEmpty ? '' : 'Art. $artigo',
                      inciso.isEmpty ? '' : 'Inc. $inciso',
                      paragrafo.isEmpty ? '' : '§ $paragrafo',
                    ].where((p) => p.trim().isNotEmpty).join(' — ');
                    return parts;
                  })
                  .where((e) => e.trim().isNotEmpty)
                  .join('\n'),
              multiline: true,
            ),
          _reviewRow('Artigo', (baseLegal['artigo'] ?? '').toString()),
          _reviewRow('Inciso', (baseLegal['inciso'] ?? '').toString()),
          _reviewRow('Parágrafo', (baseLegal['paragrafo'] ?? '').toString()),
          _reviewRow('Observações legais', (baseLegal['observacoes_legais'] ?? '').toString(), multiline: true),
          const SizedBox(height: 8),
          _reviewSectionTitle('Conteúdo'),
          if (_tipoDocumento == _tipoAutoIntimacao) ...[
            _reviewRow('Irregularidades', _descricaoIrregularidadesCtrl.text.trim(), multiline: true),
            _reviewRow('Providências', _descricaoProvidenciasCtrl.text.trim(), multiline: true),
            _reviewRow(
              'Prazo(s)',
              prazosLabel,
              multiline: true,
            ),
            _reviewRow('Comentário fiscalização', _comentarioFiscalizacaoCtrl.text.trim(), multiline: true),
            _reviewRow('Telefone VISA', _telefoneVisaCtrl.text.trim()),
            _reviewRow('E-mail VISA', _emailVisaCtrl.text.trim()),
          ] else if (_tipoDocumento == _tipoAutoInfracao) ...[
            _reviewRow('Especificação do ato/fato', _especificacaoAtoCtrl.text.trim(), multiline: true),
            _reviewRow('Irregularidades', _descricaoIrregularidadesCtrl.text.trim(), multiline: true),
            _reviewRow('Providências', _descricaoProvidenciasCtrl.text.trim(), multiline: true),
            _reviewRow('Comentário fiscalização', _comentarioFiscalizacaoCtrl.text.trim(), multiline: true),
          ] else if (_tipoDocumento == _tipoImposicaoPenalidade) ...[
            _reviewRow('Penalidade', _especificacaoAtoCtrl.text.trim(), multiline: true),
            _reviewRow('Providências', _descricaoProvidenciasCtrl.text.trim(), multiline: true),
            _reviewRow('Comentário fiscalização', _comentarioFiscalizacaoCtrl.text.trim(), multiline: true),
          ],
          const SizedBox(height: 8),
          _reviewJson('Payload (técnico)', _formatPayloadForReview(payload)),
        ],
      ),
    );
  }

  String _formatPayloadForReview(Map<String, dynamic> payload) {
    final sanitized = _sanitizeJsonValue(payload, null);
    return const JsonEncoder.withIndent('  ').convert(sanitized);
  }

  dynamic _sanitizeJsonValue(dynamic value, String? key) {
    if (value == null) return null;
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final k = entry.key.toString();
        out[k] = _sanitizeJsonValue(entry.value, k);
      }
      return out;
    }
    if (value is List) {
      return value.map((e) => _sanitizeJsonValue(e, key)).toList();
    }
    if (value is String) {
      final k = (key ?? '').toLowerCase();
      final isBinary = k.contains('assinatura') || k.contains('pdf') || k.endsWith('_base64') || k.endsWith('_bytes') || k == 'pdf_local';
      if (isBinary) {
        if (value.trim().isEmpty) return value;
        return '[conteúdo omitido]';
      }
      if (value.length > 800) {
        return '${value.substring(0, 160)}… (${value.length} chars)';
      }
      return value;
    }
    return value;
  }

  Widget _reviewSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: _darkText,
        ),
      ),
    );
  }

  Widget _reviewJson(String label, String jsonValue) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _darkText),
          ),
          subtitle: const Text('Toque para expandir'),
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: jsonValue));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payload copiado.')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(label),
                        content: SizedBox(
                          width: 720,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 520),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                jsonValue.isEmpty ? '-' : jsonValue,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Abrir'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      jsonValue.isEmpty ? '-' : jsonValue,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalvarStep() {
    final statusFinal = _semEfeito ? 'SEM_EFEITO' : _statusDocumento;
    return OfficialSectionCard(
      title: 'Salvar',
      icon: Icons.save_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kIsWeb ? 'Use os botões abaixo para salvar o documento.' : 'Use os botões abaixo para salvar o documento offline.'),
          const SizedBox(height: 12),
          _reviewRow('Tipo', _tipoDocumentoLabel),
          _reviewRow('Status final', statusFinal),
          if (_saving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          if (_tipoDocumento == _tipoAutoInfracao || _tipoDocumento == _tipoAutoIntimacao) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Não Emitido / Sem Efeito'),
              value: _semEfeito,
              onChanged: _documentoBloqueado
                  ? null
                  : (v) {
                      setState(() {
                        _semEfeito = v;
                        if (!v) _semEfeitoMotivoCtrl.clear();
                      });
                    },
            ),
            if (_semEfeito)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _semEfeitoMotivoCtrl,
                  label: 'Justificativa do Fiscal',
                  required: true,
                ),
              ),
          ],
          const SizedBox(height: 16),
          if (_documentoBloqueado)
            const Text(
              'Documento finalizado/bloqueado. Edição não permitida.',
              style: TextStyle(fontWeight: FontWeight.w700),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _salvarDocumento(statusDocumento: 'RASCUNHO'),
                    child: const Text('Salvar e Editar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () => _salvarDocumento(statusDocumento: _semEfeito ? 'SEM_EFEITO' : 'FINALIZADO'),
                    style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                    child: Text(_semEfeito ? 'Salvar (Sem Efeito)' : 'Salvar (Finalizar)'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _responsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: List.generate(children.length, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: index == children.length - 1 ? 0 : 12),
                child: children[index],
              );
            }),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(children.length, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == children.length - 1 ? 0 : 12),
                child: children[index],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _reviewRow(String label, String value, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: _darkText),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              maxLines: multiline ? null : 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatBackendDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatBackendDateTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute:$second';
  }

  String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  String _formatDisplayDateTime(Object? value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '-';
    DateTime? dt;
    try {
      if (s.contains('T')) {
        dt = DateTime.tryParse(s);
      } else if (s.length >= 19 && s[4] == '-' && s[7] == '-' && s[10] == ' ') {
        final iso = s.replaceFirst(' ', 'T');
        dt = DateTime.tryParse(iso);
      } else if (s.length == 10 && s[4] == '-' && s[7] == '-') {
        dt = DateTime.tryParse(s);
      }
    } catch (_) {
      dt = null;
    }
    if (dt == null) return s;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }

  String _formatCnpj(String value) {
    final digits = _onlyDigits(value);
    if (digits.length != 14) return value;
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12, 14)}';
  }

  String _formatCpfCnpj(String value) {
    final digits = _onlyDigits(value);
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9, 11)}';
    }
    if (digits.length == 14) {
      return _formatCnpj(digits);
    }
    return value;
  }

  void _seedAuditValuesForIntimacao() {
    if (_tipoDocumento != _tipoAutoIntimacao) return;
    final seed = <String, String>{
      'autuado.nome': _autuadoNomeCtrl.text,
      'autuado.cnpj_cpf': _autuadoCpfCnpjCtrl.text,
      'autuado.nome_fantasia': _autuadoNomeFantasiaCtrl.text,
      'autuado.endereco_completo': _autuadoEnderecoCompletoCtrl.text,
      'autuado.numero': _autuadoNumeroCtrl.text,
      'autuado.bairro': _autuadoBairroCtrl.text,
      'autuado.municipio': _autuadoMunicipioCtrl.text,
      'autuado.uf': _autuadoUfCtrl.text,
      'autuado.proprietario_responsavel': _autuadoProprietarioCtrl.text,
      'autuado.tipo_atividade': _autuadoTipoAtividadeCtrl.text,
      'autuado.alvara_pasta': _autuadoAlvaraCtrl.text,
      'recebimento.data': _recebimentoDataCtrl.text,
      'recebimento.hora': _recebimentoHoraCtrl.text,
      'recebimento.responsavel': _recebimentoResponsavelCtrl.text,
      'autoridade.nome': _autoridadeSaudeCtrl.text,
      'autoridade.funcao': _autoridadeFuncaoCtrl.text,
    };
    for (final e in seed.entries) {
      _auditLastValue.putIfAbsent(e.key, () => e.value);
    }
  }

  void _auditChange(String campo, String novoValor) {
    if (_tipoDocumento != _tipoAutoIntimacao) return;
    final novo = novoValor;
    final anterior = _auditLastValue[campo];
    if (anterior == null) {
      _auditLastValue[campo] = novo;
      return;
    }
    if (anterior == novo) return;
    _auditLogs.add({
      'campo': campo,
      'valorAnterior': anterior,
      'valorNovo': novo,
      'acao': 'ALTERAR',
      'dataHora': DateTime.now().toIso8601String(),
    });
    _auditLastValue[campo] = novo;
  }

  DateTime? _extractItemDate(Map<String, dynamic> item) {
    final value = (item['data_hora'] ?? item['data_emissao'] ?? item['data'] ?? '').toString().trim();
    if (value.isEmpty) return null;
    if (value.contains('T')) return DateTime.tryParse(value);
    if (value.length >= 19 && value[4] == '-' && value[7] == '-') {
      return DateTime.tryParse(value.replaceFirst(' ', 'T'));
    }
    if (value.length == 10 && value[4] == '-' && value[7] == '-') {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _toApiDate(DateTime? value) => value == null ? null : _formatBackendDate(value);

  int get _reviewStepIndex {
    final index = _steps.indexWhere((e) => e.title == 'Revisão');
    return index < 0 ? 0 : index;
  }

  int _countByStatus(String label) {
    return _documentosFiltrados.where((item) => _statusLabelFromValue((item['status'] ?? '').toString()) == label).length;
  }

  String _statusLabelFromValue(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'RASCUNHO':
        return 'Rascunho';
      case 'EM_EDICAO':
        return 'Em edição';
      case 'FINALIZADO':
        return 'Finalizado';
      case 'SEM_EFEITO':
        return 'Sem efeito';
      case 'ENVIADO':
      case 'EMITIDO':
        return 'Emitido';
      case 'SINCRONIZADO':
        return 'Sincronizado';
      case 'CANCELADO':
        return 'Cancelado';
      case 'PENDENTE':
      case 'PENDENTE_SINCRONIZACAO':
      default:
        return 'Pendente de sincronizacao';
    }
  }

  String? get _statusFiltroApiValue {
    switch (_statusFiltro) {
      case 'Rascunho':
        return 'RASCUNHO';
      case 'Em edição':
        return 'EM_EDICAO';
      case 'Finalizado':
        return 'FINALIZADO';
      case 'Sem efeito':
        return 'SEM_EFEITO';
      case 'Emitido':
        return 'ENVIADO';
      case 'Sincronizado':
        return 'SINCRONIZADO';
      case 'Cancelado':
        return 'CANCELADO';
      case 'Pendente de sincronizacao':
        return 'PENDENTE_SINCRONIZACAO';
      default:
        return null;
    }
  }

  String? get _tipoFiltroApiValue {
    if (_tipoFiltro == 'Todos') return null;
    for (final entry in _tiposDocumentoLabel.entries) {
      if (entry.value == _tipoFiltro) return entry.key;
    }
    return null;
  }

  Color _statusColorFromLabel(String label) {
    switch (label) {
      case 'Rascunho':
        return Colors.blueGrey;
      case 'Em edição':
        return const Color(0xFF0EA5E9);
      case 'Finalizado':
        return const Color(0xFF1D4ED8);
      case 'Sem efeito':
        return const Color(0xFF991B1B);
      case 'Emitido':
        return const Color(0xFF2563EB);
      case 'Sincronizado':
        return _statusGreen;
      case 'Cancelado':
        return _statusRed;
      case 'Pendente de sincronizacao':
      default:
        return _statusOrange;
    }
  }

  Color _tipoColorFromLabel(String label) {
    switch (label) {
      case 'Auto de Intimação':
        return _govBlue;
      case 'Auto de Infração':
        return _statusRed;
      case 'Imposição de Penalidade':
        return _statusOrange;
      case 'Auto de Coleta de Amostra':
        return _statusGreen;
      case 'Relatório Inspeção Sanitária':
      default:
        return const Color(0xFF5B3CC4);
    }
  }

  String _tipoDocumentoFromStored(Map<String, dynamic> item) {
    final tipo = _storedTipoToInternal((item['tipo_auto'] ?? item['tipo_documento'] ?? '').toString());
    return _tiposDocumentoLabel[tipo] ?? '-';
  }

  String _storedTipoToInternal(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'INF':
      case 'AUTO_DE_INFRACAO':
        return _tipoAutoInfracao;
      case 'PEN':
      case 'IMPOSICAO_DE_PENALIDADE':
        return _tipoImposicaoPenalidade;
      case 'COL':
      case 'AUTO_DE_COLETA_DE_AMOSTRA':
        return _tipoAutoColeta;
      case 'INSPECAO_SANITARIA':
        return _tipoInspecaoSanitaria;
      default:
        return _tipoAutoIntimacao;
    }
  }
}

class _StepConfig {
  const _StepConfig(this.title, this.formKey, this.visible);

  final String title;
  final GlobalKey<FormState>? formKey;
  final bool visible;
}

class _CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String out = digits;

    if (digits.length <= 11) {
      if (digits.length >= 4) out = '${digits.substring(0, 3)}.${digits.substring(3)}';
      if (digits.length >= 7) out = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
      if (digits.length >= 10) out = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
    } else {
      if (digits.length >= 3) out = '${digits.substring(0, 2)}.${digits.substring(2)}';
      if (digits.length >= 6) out = '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5)}';
      if (digits.length >= 9) out = '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8)}';
      if (digits.length >= 13) {
        final base = '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
        out = base;
      }
    }

    out = out.length > 18 ? out.substring(0, 18) : out;
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

class _AutoridadeSaudeItem {
  final TextEditingController nomeCtrl = TextEditingController();
  final TextEditingController funcaoCtrl = TextEditingController();
  Uint8List? assinatura;

  void dispose() {
    nomeCtrl.dispose();
    funcaoCtrl.dispose();
  }
}

const String _tipoAutoIntimacao = 'AUTO_DE_INTIMACAO';
const String _tipoAutoInfracao = 'AUTO_DE_INFRACAO';
const String _tipoImposicaoPenalidade = 'IMPOSICAO_DE_PENALIDADE';
const String _tipoAutoColeta = 'AUTO_DE_COLETA_DE_AMOSTRA';
const String _tipoInspecaoSanitaria = 'INSPECAO_SANITARIA';

const List<String> _tiposDocumentoOrdem = [
  _tipoAutoIntimacao,
  _tipoAutoInfracao,
  _tipoImposicaoPenalidade,
  _tipoAutoColeta,
  _tipoInspecaoSanitaria,
];

const Map<String, String> _tiposDocumentoLabel = {
  _tipoAutoIntimacao: 'Auto de Intimação',
  _tipoAutoInfracao: 'Auto de Infração',
  _tipoImposicaoPenalidade: 'Imposição de Penalidade',
  _tipoAutoColeta: 'Auto de Coleta de Amostra',
  _tipoInspecaoSanitaria: 'Relatório Inspeção Sanitária',
};

const List<String> _tiposFiltroLista = [
  'Todos',
  'Auto de Intimação',
  'Auto de Infração',
  'Imposição de Penalidade',
  'Auto de Coleta de Amostra',
  'Relatório Inspeção Sanitária',
];

const List<String> _statusFiltroOpcoes = [
  'Todos',
  'Rascunho',
  'Em edição',
  'Finalizado',
  'Sem efeito',
  'Emitido',
  'Pendente de sincronizacao',
  'Sincronizado',
  'Cancelado',
];

const Map<String, String> _tipoNumeroPrefixo = {
  _tipoAutoIntimacao: 'AI',
  _tipoAutoInfracao: 'INF',
  _tipoImposicaoPenalidade: 'IP',
  _tipoAutoColeta: 'AC',
  _tipoInspecaoSanitaria: 'IS',
};

const Map<String, String> _payloadTipoDocumento = {
  _tipoAutoIntimacao: 'AUTO_DE_INTIMACAO',
  _tipoAutoInfracao: 'AUTO_DE_INFRACAO',
  _tipoImposicaoPenalidade: 'IMPOSICAO_DE_PENALIDADE',
  _tipoAutoColeta: 'AUTO_DE_COLETA_DE_AMOSTRA',
  _tipoInspecaoSanitaria: 'INSPECAO_SANITARIA',
};

const List<String> _departamentos = [
  'Departamento de Fiscalização de Alimentos',
  'Departamento de Fiscalização de Serviços de Saúde e de Interesse à Saúde',
  'Centro de Controle de Pragas Urbanas',
  'Programa Municipal de Controle da Dengue',
];

const List<String> _tiposAmostra = [
  'Amostra Triplicata Fiscalização',
];
