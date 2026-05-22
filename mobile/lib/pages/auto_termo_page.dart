import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../storage/db.dart';
import '../widgets/app_drawer.dart';
import '../widgets/inspection_widgets.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/official_form_fields.dart';

const Color _govBlue = Color(0xFF1351B4);
const Color _lightBg = Color(0xFFF8FAFC);
const Color _darkText = Color(0xFF2C3E50);
const Color _statusGreen = Color(0xFF27AE60);
const Color _statusOrange = Color(0xFFF39C12);
const Color _statusRed = Color(0xFFE74C3C);

class AutoTermoPage extends StatefulWidget {
  const AutoTermoPage({super.key});

  @override
  State<AutoTermoPage> createState() => _AutoTermoPageState();
}

class _AutoTermoPageState extends State<AutoTermoPage> {
  final ApiService _api = ApiService();

  // #region debug-point auto-termo-steps-not-updating
  final Dio _dbgDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      sendTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ),
  );
  String? _dbgLastTipoDocumento;
  int? _dbgLastStepsCount;

  Future<void> _dbg(String point, Map<String, dynamic> data) async {
    if (!kIsWeb) return;
    try {
      await _dbgDio.post(
        'http://127.0.0.1:7777/event',
        data: {
          'sessionId': 'auto-termo-steps-not-updating',
          'point': point,
          'ts': DateTime.now().millisecondsSinceEpoch,
          'data': data,
        },
      );
    } catch (_) {}
  }
  // #endregion

  final ValueNotifier<int> _formRebuildTick = ValueNotifier<int>(0);

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
  final _nomeFantasiaCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _inscricaoMunicipalCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _responsavelLegalCtrl = TextEditingController();
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
  final _comentarioFiscalizacaoCtrl = TextEditingController();
  final _especificacaoAtoCtrl = TextEditingController();
  final _departamentoCtrl = TextEditingController();
  final _dataLavraturaCtrl = TextEditingController();
  final _anoRelacionadoCtrl = TextEditingController();
  final _documentoRelacionadoCtrl = TextEditingController();
  final _dataRecebimentoCtrl = TextEditingController();
  final _tipoAmostraCtrl = TextEditingController();
  final _situacaoEncontradaCtrl = TextEditingController();
  final _observacoesInspecaoCtrl = TextEditingController();
  final _profissionalEquipeCtrl = TextEditingController();
  final _funcaoEquipeCtrl = TextEditingController();

  final _dadosFormKey = GlobalKey<FormState>();
  final _baseLegalFormKey = GlobalKey<FormState>();
  final _descricaoFormKey = GlobalKey<FormState>();
  final _tipoDocumentoFormKey = GlobalKey<FormState>();
  final _inspecaoFormKey = GlobalKey<FormState>();
  final _profissionaisFormKey = GlobalKey<FormState>();
  final _reviewFormKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _documentos = [];
  List<Map<String, dynamic>> _documentosFiltrados = [];
  List<Map<String, dynamic>> _estabResults = [];
  List<Map<String, dynamic>> _vinculosRelacionados = [];
  List<Map<String, dynamic>> _profissionaisEquipe = [];

  bool _loadingList = true;
  bool _saving = false;
  bool _estabLoading = false;
  bool _maisFiltrosExpandidos = false;
  String? _estabError;
  String? _listError;
  int _currentStep = 0;
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
    _syncDateTimeFields();
    _loadDocumentos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _estabSearchCtrl.dispose();
    _anoCtrl.dispose();
    _dataHoraCtrl.dispose();
    _nomeFantasiaCtrl.dispose();
    _cnpjCtrl.dispose();
    _inscricaoMunicipalCtrl.dispose();
    _enderecoCtrl.dispose();
    _responsavelLegalCtrl.dispose();
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
    _comentarioFiscalizacaoCtrl.dispose();
    _especificacaoAtoCtrl.dispose();
    _departamentoCtrl.dispose();
    _dataLavraturaCtrl.dispose();
    _anoRelacionadoCtrl.dispose();
    _documentoRelacionadoCtrl.dispose();
    _dataRecebimentoCtrl.dispose();
    _tipoAmostraCtrl.dispose();
    _situacaoEncontradaCtrl.dispose();
    _observacoesInspecaoCtrl.dispose();
    _profissionalEquipeCtrl.dispose();
    _funcaoEquipeCtrl.dispose();
    _formRebuildTick.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentos() async {
    await _buscarDocumentos();
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
      final list = kIsWeb
          ? await _api.listarAutoTermo(
              search: busca.isEmpty ? null : busca,
              cnpj: digits.length == 14 ? digits : null,
              tipoDocumento: _tipoFiltroApiValue,
              status: _statusFiltroApiValue,
              dataInicio: _toApiDate(_filtroDataInicio),
              dataFim: _toApiDate(_filtroDataFim),
            )
          : await LocalDb.listarAutosTermosLocal();
      if (!mounted) return;
      setState(() {
        _documentos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _applyFiltroLista();
        _loadingList = false;
      });
    } on DioException catch (e) {
      await _dbg('listar_auto_termo_error', {
        'status': e.response?.statusCode,
        'message': e.message,
      });
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
    });
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
      _nomeFantasiaCtrl.text =
          (item['nomeFantasia'] ?? item['nome_fantasia'] ?? item['nome'] ?? item['razaoSocial'] ?? item['razao_social'] ?? '')
              .toString();
      _cnpjCtrl.text = _formatCnpj((item['cnpj'] ?? '').toString());
      _inscricaoMunicipalCtrl.text =
          (item['inscricaoMunicipal'] ?? item['inscricao_municipal'] ?? '').toString();
      _enderecoCtrl.text = endereco.isEmpty ? (data['endereco'] ?? '').toString() : endereco;
      _responsavelLegalCtrl.text =
          (item['responsavel'] ?? item['responsavel_legal'] ?? item['responsavelLegal'] ?? '').toString();
      _estabError = null;
    });
  }

  Future<void> _adicionarVinculo() async {
    if (_anoRelacionadoCtrl.text.trim().isEmpty || _documentoRelacionadoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ano e documento relacionado para adicionar.')),
      );
      return;
    }
    setState(() {
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

  void _adicionarProfissionalEquipe() {
    if ((_profissionaisFormKey.currentState?.validate() ?? false) == false) {
      return;
    }
    setState(() {
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
  }

  void _removerProfissionalEquipe(int index) {
    setState(() {
      _profissionaisEquipe = [..._profissionaisEquipe]..removeAt(index);
    });
  }

  List<_StepConfig> get _steps => _buildStepsByTipoDocumento(_tipoDocumento);

  bool get _hasTipoDocumentoSelected => _tipoDocumento != null;

  String get _tipoDocumentoLabel => _tipoDocumento == null
      ? 'Tipo de Documento'
      : (_tiposDocumentoLabel[_tipoDocumento] ?? 'Tipo de Documento');

  List<_StepConfig> _buildStepsByTipoDocumento(String? tipoDocumento) {
    final dados = _StepConfig('Dados', _dadosFormKey, true);
    final baseLegal = _StepConfig('Base legal', _baseLegalFormKey, true);
    final descricao = _StepConfig('Descrição', _descricaoFormKey, true);
    final inspecaoSanitaria = _StepConfig('Inspeção Sanitária', _inspecaoFormKey, true);
    final profissionaisEquipe = _StepConfig('Profissionais da Equipe', _profissionaisFormKey, true);
    final revisao = _StepConfig('Revisão', _reviewFormKey, true);
    const salvar = _StepConfig('Salvar', null, true);

    if (tipoDocumento == null) {
      return [dados];
    }

    switch (tipoDocumento) {
      case _tipoAutoIntimacao:
      case _tipoAutoInfracao:
      case _tipoImposicaoPenalidade:
      case _tipoAutoColeta:
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
    await _dbg('tipo_documento_on_changed_called', {
      'current': _tipoDocumento,
      'next': nextTipo,
      'currentStep': _currentStep,
      'stepsCount': _steps.length,
    });
    if (nextTipo == _tipoDocumento) return;

    if (nextTipo == null) {
      _formSetState(() {
        _tipoDocumento = null;
        _currentStep = 0;
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
      _currentStep = 0;
    });

    final steps = _buildStepsByTipoDocumento(nextTipo);
    await _dbg('tipo_documento_after_setstate', {
      'tipoDocumento': nextTipo,
      'stepsCount': steps.length,
      'steps': steps.map((e) => e.title).toList(),
    });
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
        _comentarioFiscalizacaoCtrl.text.trim().isNotEmpty ||
        _especificacaoAtoCtrl.text.trim().isNotEmpty ||
        _dataLavraturaCtrl.text.trim().isNotEmpty ||
        _anoRelacionadoCtrl.text.trim().isNotEmpty ||
        _documentoRelacionadoCtrl.text.trim().isNotEmpty ||
        _dataRecebimentoCtrl.text.trim().isNotEmpty ||
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
    _descricaoIrregularidadesCtrl.clear();
    _descricaoProvidenciasCtrl.clear();
    _comentarioFiscalizacaoCtrl.clear();
    _especificacaoAtoCtrl.clear();
    _departamento = _departamentos.first;
    _departamentoCtrl.text = _departamento;
    _dataLavraturaCtrl.clear();
    _anoRelacionadoCtrl.clear();
    _documentoRelacionadoCtrl.clear();
    _dataRecebimentoCtrl.clear();
    _vinculosRelacionados = [];
    _tipoAmostra = _tiposAmostra.first;
    _tipoAmostraCtrl.text = _tipoAmostra;
  }

  bool _validateCurrentStep() {
    final config = _steps[_currentStep];
    final form = config.formKey?.currentState;
    if (form != null && !form.validate()) {
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
    if (config.title == _tipoDocumentoLabel && _requiresLinkedDocuments && _vinculosRelacionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um documento relacionado.')),
      );
      return false;
    }
    return true;
  }

  bool get _requiresLinkedDocuments =>
      _tipoDocumento == _tipoAutoInfracao || _tipoDocumento == _tipoImposicaoPenalidade;

  Future<void> _continuar() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _steps.length - 1) {
      _formSetState(() => _currentStep += 1);
      return;
    }
    await _salvarDocumento();
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
    final inspecaoSanitaria = <String, dynamic>{
      'situacao_encontrada': _situacaoEncontradaCtrl.text.trim(),
      'observacoes': _observacoesInspecaoCtrl.text.trim(),
      'estabelecimento_id': (_estabelecimentoId ?? '').toString(),
      'profissional': _profissionalCtrl.text.trim(),
      'data_hora': _formatBackendDateTime(dataHora),
      'tipo_documento': _payloadTipoDocumento[_tipoDocumento],
    };
    final payload = <String, dynamic>{
      'ano': _anoCtrl.text.trim(),
      'data_hora': _formatBackendDateTime(dataHora),
      'estabelecimento_id': (_estabelecimentoId ?? '').toString(),
      'tipo_documento': _payloadTipoDocumento[_tipoDocumento],
      'responsavel_tecnico_id': _responsavelTecnicoCtrl.text.trim(),
      'profissional_id': _profissionalCtrl.text.trim(),
      'testemunha_1': _testemunha1Ctrl.text.trim(),
      'testemunha_2': _testemunha2Ctrl.text.trim(),
      'dados_estabelecimento': dadosEstabelecimento,
      'inspecao_sanitaria': inspecaoSanitaria,
      'profissionais_equipe': _profissionaisEquipe,
      'status': kIsWeb ? 'ENVIADO' : 'PENDENTE_SINCRONIZACAO',
    };
    switch (_tipoDocumento) {
      case _tipoAutoIntimacao:
        payload['auto_intimacao'] = <String, dynamic>{
          'descricao_irregularidades': descricao['descricao_irregularidades'],
          'descricao_providencias': descricao['descricao_providencias'],
          'departamento_vigilancia': _departamento,
          'data_lavratura': _dataLavraturaCtrl.text.trim(),
          'base_legal': baseLegal,
        };
        break;
      case _tipoAutoInfracao:
        payload['auto_infracao'] = <String, dynamic>{
          'especificacao_detalhada_ato_ou_fato': descricao['especificacao_detalhada_ato_ou_fato'],
          'descricao_irregularidades': descricao['descricao_irregularidades'],
          'descricao_providencias': descricao['descricao_providencias'],
          'departamento_vigilancia': _departamento,
          'data_lavratura': _dataLavraturaCtrl.text.trim(),
          'documentos_relacionados': _vinculosRelacionados,
          'base_legal': baseLegal,
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

  Future<void> _salvarDocumento() async {
    if (!_hasTipoDocumentoSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de documento para continuar.')),
      );
      return;
    }
    if (!_steps.where((e) => e.formKey != null).every((e) => e.formKey!.currentState?.validate() ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise os campos obrigatórios antes de salvar.')),
      );
      return;
    }
    if (_estabelecimentoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um estabelecimento antes de salvar.')),
      );
      return;
    }
    final payload = _buildPayload();
    setState(() => _saving = true);
    try {
      if (kIsWeb) {
        try {
          final sendPayload = <String, dynamic>{
            ...payload,
            'numero_ano': _buildNumeroAno(),
          };
          await _api.salvarAutoTermo(sendPayload);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auto/Termo enviado e salvo com sucesso.')),
          );
          _resetForm();
          await _loadDocumentos();
          return;
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao enviar. Verifique a conexão e tente novamente.')),
          );
          return;
        }
      }
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
      await db.insert('autos_sanitarios', {
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
        'status': 'PENDENTE_SINCRONIZACAO',
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
        const SnackBar(content: Text('Auto/Termo salvo como pendente de sincronização.')),
      );
      _resetForm();
      await _loadDocumentos();
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
    _descricaoIrregularidadesCtrl.clear();
    _descricaoProvidenciasCtrl.clear();
    _comentarioFiscalizacaoCtrl.clear();
    _especificacaoAtoCtrl.clear();
    _dataLavraturaCtrl.clear();
    _anoRelacionadoCtrl.clear();
    _documentoRelacionadoCtrl.clear();
    _dataRecebimentoCtrl.clear();
    _situacaoEncontradaCtrl.clear();
    _observacoesInspecaoCtrl.clear();
    _profissionalEquipeCtrl.clear();
    _funcaoEquipeCtrl.clear();
    _estabResults = [];
    _vinculosRelacionados = [];
    _profissionaisEquipe = [];
    _estabelecimentoId = null;
    _estabelecimentoSelecionado = null;
    _currentStep = 0;
    _tipoDocumento = null;
    _departamento = _departamentos.first;
    _tipoAmostra = _tiposAmostra.first;
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _syncDateTimeFields();
  }

  String _buildNumeroAno() {
    final prefix = _tipoNumeroPrefixo[_tipoDocumento] ?? 'DOC';
    return '$prefix/${_anoCtrl.text.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    // #region debug-point auto-termo-steps-not-updating
    final dbgStepsCount = _steps.length;
    if (_dbgLastTipoDocumento != _tipoDocumento || _dbgLastStepsCount != dbgStepsCount) {
      _dbgLastTipoDocumento = _tipoDocumento;
      _dbgLastStepsCount = dbgStepsCount;
      _dbg('ui_state_changed', {
        'tipoDocumento': _tipoDocumento,
        'tipoDocumentoLabel': _tipoDocumentoLabel,
        'currentStep': _currentStep,
        'stepsCount': dbgStepsCount,
        'steps': _steps.map((e) => e.title).toList(),
      });
    }
    // #endregion

    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1200;
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('Auto/Termo'),
        backgroundColor: _govBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadingList ? null : _buscarDocumentos,
            icon: const Icon(Icons.refresh),
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
    final dados = Map<String, dynamic>.from(payload['dados_estabelecimento'] as Map? ?? {});
    setState(() {
      _tipoDocumento = _storedTipoToInternal((item['tipo_auto'] ?? '').toString());
      _anoCtrl.text = (payload?['ano'] ?? '').toString();
      _nomeFantasiaCtrl.text = (dados['nome_fantasia'] ?? '').toString();
      _cnpjCtrl.text = _formatCnpj((dados['cnpj'] ?? '').toString());
      _inscricaoMunicipalCtrl.text = (dados['inscricao_municipal'] ?? '').toString();
      _enderecoCtrl.text = (dados['endereco'] ?? '').toString();
      _responsavelLegalCtrl.text = (dados['responsavel_legal'] ?? '').toString();
      _profissionalCtrl.text = (payload?['profissional_id'] ?? '').toString();
      _responsavelTecnicoCtrl.text = (payload?['responsavel_tecnico_id'] ?? '').toString();
      _testemunha1Ctrl.text = (payload?['testemunha_1'] ?? '').toString();
      _testemunha2Ctrl.text = (payload?['testemunha_2'] ?? '').toString();
      _currentStep = targetStep;
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
    final pdfUrl = (item['pdf_url'] ?? item['pdfUrl'] ?? '').toString().trim();
    final message = pdfUrl.isEmpty
        ? 'PDF indisponivel para este Auto/Termo no momento.'
        : 'PDF disponivel em $pdfUrl';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _compartilharOuImprimir(Map<String, dynamic> item) async {
    final numero = (item['numero_ano'] ?? item['numero_auto'] ?? item['numero'] ?? '').toString();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compartilhamento/Impressao indisponivel para $numero nesta versao.')),
    );
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
            child: _buildStepContent(steps[_currentStep].title),
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
                  onPressed: _saving ? null : _continuar,
                  style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(_currentStep == steps.length - 1 ? 'Salvar' : 'Continuar'),
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
      case 'Base legal':
        return _buildBaseLegalStep();
      case 'Descrição':
        return _buildDescricaoStep();
      case 'Inspeção Sanitária':
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
                _responsiveRow([
                  OfficialTextField(
                    controller: _responsavelTecnicoCtrl,
                    label: 'Responsável Técnico',
                  ),
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
                ]),
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
                _responsiveRow([
                  OfficialTextField(controller: _testemunha1Ctrl, label: '1ª Testemunha'),
                  OfficialTextField(controller: _testemunha2Ctrl, label: '2ª Testemunha'),
                ]),
                const SizedBox(height: 12),
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
          final nome = (item['nomeFantasia'] ?? item['nome_fantasia'] ?? item['nome'] ?? item['razaoSocial'] ?? item['razao_social'] ?? '-')
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

  Widget _buildBaseLegalStep() {
    return Form(
      key: _baseLegalFormKey,
      child: OfficialSectionCard(
        title: 'Base legal',
        icon: Icons.gavel_outlined,
        child: Column(
          children: [
            OfficialTextField(
              controller: _baseLegalCtrl,
              label: 'Base legal',
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
        ),
      ),
    );
  }

  Widget _buildDescricaoStep() {
    return Form(
      key: _descricaoFormKey,
      child: OfficialSectionCard(
        title: 'Descrição',
        icon: Icons.description_outlined,
        child: Column(
          children: [
            if (_showDescricaoIrregularidades)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _descricaoIrregularidadesCtrl,
                  label: 'Descrição das Irregularidades',
                  required: _tipoDocumento == _tipoAutoIntimacao || _tipoDocumento == _tipoAutoInfracao,
                ),
              ),
            if (_showDescricaoProvidencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _descricaoProvidenciasCtrl,
                  label: 'Descrição das Providências / Exigências / Outras Informações',
                  required: _tipoDocumento != null && _tipoDocumento != _tipoInspecaoSanitaria,
                ),
              ),
            if (_showComentarioFiscalizacao)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OfficialMultilineField(
                  controller: _comentarioFiscalizacaoCtrl,
                  label: 'Comentário sobre a Fiscalização',
                ),
              ),
            if (_showEspecificacaoAto)
              OfficialMultilineField(
                controller: _especificacaoAtoCtrl,
                label: _tipoDocumento == _tipoImposicaoPenalidade
                    ? 'Especificação detalhada da penalidade imposta'
                    : 'Especificação Detalhada do Ato ou Fato',
                required: _tipoDocumento == _tipoAutoInfracao || _tipoDocumento == _tipoImposicaoPenalidade,
              ),
          ],
        ),
      ),
    );
  }

  bool get _showDescricaoIrregularidades =>
      _tipoDocumento == _tipoAutoIntimacao || _tipoDocumento == _tipoAutoInfracao;

  bool get _showDescricaoProvidencias => _tipoDocumento != _tipoInspecaoSanitaria;

  bool get _showComentarioFiscalizacao =>
      _tipoDocumento == _tipoImposicaoPenalidade || _tipoDocumento == _tipoInspecaoSanitaria;

  bool get _showEspecificacaoAto =>
      _tipoDocumento == _tipoAutoInfracao || _tipoDocumento == _tipoImposicaoPenalidade;

  Widget _buildTipoDocumentoStep() {
    return Form(
      key: _tipoDocumentoFormKey,
      child: OfficialSectionCard(
        title: _tipoDocumentoLabel,
        icon: Icons.fact_check_outlined,
        child: Column(
          children: [
            if (_tipoDocumento == _tipoAutoIntimacao) ...[
              _buildDepartamentoLavraturaSection(),
            ],
            if (_tipoDocumento == _tipoAutoInfracao) ...[
              _buildDepartamentoLavraturaSection(),
              const SizedBox(height: 12),
              _buildVinculoSection('Auto de Intimação relacionado'),
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

  Widget _buildDepartamentoLavraturaSection({String dataLabel = 'Data da lavratura do Auto de Intimação'}) {
    return Column(
      children: [
        OfficialDropdownField.fromStrings(
          value: _departamento,
          items: _departamentos,
          onChanged: (value) {
            setState(() {
              _departamento = value ?? _departamentos.first;
              _departamentoCtrl.text = _departamento;
            });
          },
          label: 'Departamento da Vigilância Sanitária',
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
              OfficialTextField(controller: TextEditingController(text: _tipoDocumentoLabel), label: 'Tipo de documento', readOnly: true),
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
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cadastro de novo profissional deve usar o módulo existente.')),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Novo'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _adicionarProfissionalEquipe,
                  style: ElevatedButton.styleFrom(backgroundColor: _govBlue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
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
          _reviewRow('Payload', const JsonEncoder.withIndent('  ').convert(payload), multiline: true),
        ],
      ),
    );
  }

  Widget _buildSalvarStep() {
    final payload = _buildPayload();
    return OfficialSectionCard(
      title: 'Salvar',
      icon: Icons.save_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kIsWeb
                ? 'Ao salvar, o documento ficará pronto para envio online.'
                : 'Ao salvar, o documento será armazenado como PENDENTE_SINCRONIZACAO.',
          ),
          const SizedBox(height: 12),
          _reviewRow('Tipo', _tipoDocumentoLabel),
          _reviewRow('Status final', (payload['status'] ?? '').toString()),
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
      case 'Inspeção Sanitária':
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
  _tipoInspecaoSanitaria: 'Inspeção Sanitária',
};

const List<String> _tiposFiltroLista = [
  'Todos',
  'Auto de Intimação',
  'Auto de Infração',
  'Imposição de Penalidade',
  'Auto de Coleta de Amostra',
  'Inspeção Sanitária',
];

const List<String> _statusFiltroOpcoes = [
  'Todos',
  'Rascunho',
  'Emitido',
  'Pendente de sincronizacao',
  'Sincronizado',
  'Cancelado',
];

const Map<String, String> _tipoNumeroPrefixo = {
  _tipoAutoIntimacao: 'AI',
  _tipoAutoInfracao: 'AINF',
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
  'Departamento da Vigilância Sanitária',
  'Vigilância Sanitária Municipal',
];

const List<String> _tiposAmostra = [
  'Amostra Triplicata Fiscalização',
];
