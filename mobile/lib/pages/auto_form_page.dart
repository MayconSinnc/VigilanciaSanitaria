import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../services/api.dart';
import '../widgets/step_header.dart';
import '../widgets/official_form_fields.dart';
import '../widgets/official_components.dart' show CepInputFormatter;

// ============================================================================
// CONSTANTES DE DESIGN
// ============================================================================
const Color _govBlue = Color(0xFF1351B4);
const Color _darkGray = Color(0xFF2C3E50);
const Color _lightBg = Color(0xFFF8FAFC);
const Color _statusRed = Color(0xFFE74C3C);
const Color _statusGreen = Color(0xFF27AE60);
const Color _statusYellow = Color(0xFFF39C12);
const Color _errorRed = Color(0xFFE74C3C);

// TextInputFormatters para máscaras
class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue ne) {
    final text = ne.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return ne.copyWith(text: '');
    if (text.length > 11) return old;
    
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 2 || i == 5) formatted += '.';
      if (i == 8) formatted += '-';
    }
    return ne.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue ne) {
    final text = ne.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return ne.copyWith(text: '');
    if (text.length > 11) return old;
    
    String formatted = '(${text.substring(0, (text.length > 2 ? 2 : text.length))}';
    if (text.length > 2) {
      final hasNine = text.length >= 7 && text[2] == '9';
      final end = hasNine ? 7 : 6;
      formatted += ') ${text.substring(2, (text.length > end ? end : text.length))}';
      if (text.length > end) {
        formatted += '-${text.substring(end)}';
      }
    }
    return ne.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue ne) {
    final text = ne.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return ne.copyWith(text: '');
    if (text.length > 8) return old;
    
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 3) formatted += '/';
    }
    return ne.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AutoFormPage extends StatefulWidget {
  const AutoFormPage({super.key});
  @override
  State<AutoFormPage> createState() => _AutoFormPageState();
}

class _AutoFormPageState extends State<AutoFormPage> {
  String _tipo = 'INT';
  String _numero = '';
  String _nome = '';
  String _cnpj = '';
  bool _saving = false;
  int _step = 0;
  bool _argsLoaded = false;
  Uint8List? _assinaturaFiscal;
  Uint8List? _assinaturaResponsavel;
  int? _estabelecimentoId;
  int? _inspecaoId;

  // GlobalKeys para validação por step
  final _dadosFormKey = GlobalKey<FormState>();
  final _infracaoFormKey = GlobalKey<FormState>();
  final _legalFormKey = GlobalKey<FormState>();
  final _medidasFormKey = GlobalKey<FormState>();
  final _evidenciasFormKey = GlobalKey<FormState>();
  final _assinaturaFormKey = GlobalKey<FormState>();

  // Estado de revisão confirmada
  bool _revisaoConfirmada = false;

  final _api = ApiService();
  final _picker = ImagePicker();

  final _cnpjCtrl = TextEditingController();
  final _razaoCtrl = TextEditingController();
  final _fantasiaCtrl = TextEditingController();
  final _logradouroCtrl = TextEditingController();
  final _numeroEndCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _cnaeCtrl = TextEditingController();
  final _atividadeCtrl = TextEditingController();
  final _statusAlvaraCtrl = TextEditingController();
  bool? _debitoVencido;

  final _respNomeCtrl = TextEditingController();
  final _respCpfCtrl = TextEditingController();
  final _respCargoCtrl = TextEditingController();
  final _respTelefoneCtrl = TextEditingController();

  final _fiscalNomeCtrl = TextEditingController();
  final _fiscalMatriculaCtrl = TextEditingController();
  DateTime _dataInspecao = DateTime.now();
  TimeOfDay _horaInspecao = TimeOfDay.now();
  String _tipoInspecao = 'Rotina';

  String _classificacao = 'Leve';
  bool _apreensao = false;
  bool _interdicao = false;
  bool _destruicao = false;
  String _tipoMedida = 'Advertência';
  final _prazoRegularizacaoCtrl = TextEditingController();
  final _valorMultaCtrl = TextEditingController();

  final List<_EvidenceItem> _evidencias = [];

  String _lei = '';
  String _artigo = '';
  String _inciso = '';
  final _descLegalCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  String _gpsEndereco = '';

  final _descricao = TextEditingController();
  final _fundamentacao = TextEditingController();
  final _observacoes = TextEditingController();

  final Map<String, TextEditingController> _dynamicControllers = {};

  TextEditingController _getController(String key) {
    return _dynamicControllers.putIfAbsent(key, () => TextEditingController());
  }

  TextEditingController get _medidasCtrl => _getController('medidas');
  TextEditingController get _prazoCumprimentoCtrl => _getController('prazo');
  TextEditingController get _advertenciaCtrl => _getController('advertencia');

  String get _tipoAutoApi {
    switch (_tipo) {
      case 'INF':
        return 'INFRACAO';
      case 'COL':
        return 'COLETA';
      default:
        return 'INTIMACAO';
    }
  }

  void _voltarOuDashboard() {
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _cnpjCtrl.dispose();
    _razaoCtrl.dispose();
    _fantasiaCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroEndCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _cepCtrl.dispose();
    _cnaeCtrl.dispose();
    _atividadeCtrl.dispose();
    _statusAlvaraCtrl.dispose();
    _respNomeCtrl.dispose();
    _respCpfCtrl.dispose();
    _respCargoCtrl.dispose();
    _respTelefoneCtrl.dispose();
    _fiscalNomeCtrl.dispose();
    _fiscalMatriculaCtrl.dispose();
    _prazoRegularizacaoCtrl.dispose();
    _valorMultaCtrl.dispose();
    _descricao.dispose();
    _fundamentacao.dispose();
    _observacoes.dispose();
    _descLegalCtrl.dispose();
    for (var c in _dynamicControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _tipo = (args?['tipo'] as String?) ?? 'INT';
    _nome = (args?['nome'] as String?) ?? '';
    _cnpj = (args?['cnpj'] as String?) ?? '';
    _cnpjCtrl.text = _cnpj;
    _estabelecimentoId = args?['estabelecimentoId'] as int?;
    _inspecaoId = args?['inspecaoId'] as int?;
    _generateNumero();
    _loadEstabelecimentoFromArgs(args);
    if (!kIsWeb) {
      _loadLocalEstabelecimentoIfPossible();
    }
    _argsLoaded = true;
  }

  static String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  void _loadEstabelecimentoFromArgs(Map<String, dynamic>? args) {
    final d = args?['estabelecimento'] as Map<String, dynamic>?;
    if (d == null) return;
    _cnpjCtrl.text = '${d['cnpj'] ?? _cnpj}';
    _razaoCtrl.text = '${d['razao_social'] ?? d['razaoSocial'] ?? ''}';
    _fantasiaCtrl.text = '${d['nome_fantasia'] ?? d['nomeFantasia'] ?? ''}';
    _logradouroCtrl.text = '${d['rua'] ?? d['logradouro'] ?? ''}';
    _numeroEndCtrl.text = '${d['numero'] ?? ''}';
    _bairroCtrl.text = '${d['bairro'] ?? ''}';
    _cidadeCtrl.text = '${d['cidade'] ?? d['municipio'] ?? ''}';
    _cepCtrl.text = '${d['cep'] ?? ''}';
    _cnaeCtrl.text = '${d['cnae'] ?? ''}';
    _atividadeCtrl.text = '${d['atividade_principal'] ?? d['cnaeDescricao'] ?? d['cnae_fiscal_descricao'] ?? ''}';
    _statusAlvaraCtrl.text = '${d['status_alvara'] ?? ''}';
    _lat = (d['lat'] as num?)?.toDouble();
    _lng = (d['lng'] as num?)?.toDouble();
  }

  Future<void> _loadLocalEstabelecimentoIfPossible() async {
    if (kIsWeb) return;
    final cnpjDigits = _digitsOnly(_cnpjCtrl.text);
    if (cnpjDigits.isEmpty) return;
    try {
      final db = await LocalDb.instance;
      final rows = await db.query('estabelecimentos', where: 'cnpj = ?', whereArgs: [cnpjDigits], limit: 1);
      if (rows.isEmpty) return;
      final e = rows.first;
      if (!mounted) return;
      setState(() {
        _estabelecimentoId = e['id'] as int?;
        _razaoCtrl.text = '${e['razao_social'] ?? ''}';
        _fantasiaCtrl.text = '${e['nome_fantasia'] ?? ''}';
        _logradouroCtrl.text = '${e['rua'] ?? ''}';
        _numeroEndCtrl.text = '${e['numero'] ?? ''}';
        _bairroCtrl.text = '${e['bairro'] ?? ''}';
        _cidadeCtrl.text = '${e['cidade'] ?? ''}';
        _cepCtrl.text = '${e['cep'] ?? ''}';
        _cnaeCtrl.text = '${e['cnae'] ?? ''}';
        _atividadeCtrl.text = '${e['atividade_principal'] ?? ''}';
        _statusAlvaraCtrl.text = '${e['status_alvara'] ?? ''}';
        _lat = (e['lat'] as num?)?.toDouble();
        _lng = (e['lng'] as num?)?.toDouble();
      });
    } catch (_) {}
  }

  Future<void> _buscarEstabelecimento() async {
    final cnpjDigits = _digitsOnly(_cnpjCtrl.text);
    if (cnpjDigits.length != 14) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um CNPJ válido.')));
      return;
    }
    if (!kIsWeb) {
      await _loadLocalEstabelecimentoIfPossible();
    }
    if (_estabelecimentoId != null) return;
    try {
      await _api.init();
      final d = await _api.buscarEstabelecimentoPorCnpj(cnpjDigits);
      if (!mounted) return;
      if (d == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CNPJ não encontrado.')));
        return;
      }
      setState(() {
        _loadEstabelecimentoFromArgs({'estabelecimento': d});
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao consultar o CNPJ.')));
    }
  }

  Future<void> _generateNumero() async {
    try {
      if (kIsWeb) {
        throw StateError('no_local_db_web');
      }
      _numero = await LocalDb.nextNumeroAuto(_tipo);
    } catch (_) {
      final now = DateTime.now();
      final y = now.year.toString();
      final seq = (now.microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      _numero = '$seq/$y';
    }
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _buildPdfArguments({
    required String dataInspecaoStr,
    required String horaStr,
  }) {
    return {
      'tipo': _tipo,
      'numero': _numero,
      'nome': _fantasiaCtrl.text.isNotEmpty ? _fantasiaCtrl.text : _nome,
      'cnpj': _digitsOnly(_cnpjCtrl.text),
      'razaoSocial': _razaoCtrl.text,
      'endereco':
          '${_logradouroCtrl.text}, ${_numeroEndCtrl.text} - ${_bairroCtrl.text} - ${_cidadeCtrl.text} (${_cepCtrl.text})',
      'cnae': _cnaeCtrl.text,
      'atividade': _atividadeCtrl.text,
      'statusAlvara': _statusAlvaraCtrl.text,
      'debitoVencido': _debitoVencido,
      'responsavelNome': _respNomeCtrl.text,
      'responsavelCpf': _respCpfCtrl.text,
      'responsavelCargo': _respCargoCtrl.text,
      'responsavelTelefone': _respTelefoneCtrl.text,
      'fiscalNome': _fiscalNomeCtrl.text,
      'fiscalMatricula': _fiscalMatriculaCtrl.text,
      'dataInspecao': dataInspecaoStr,
      'horaInspecao': horaStr,
      'tipoInspecao': _tipoInspecao,
      'classificacao': _classificacao,
      'apreensao': _apreensao,
      'interdicao': _interdicao,
      'tipoMedida': _tipoMedida,
      'prazoRegularizacao': _prazoRegularizacaoCtrl.text,
      'valorMulta': _valorMultaCtrl.text,
      'latitude': _lat,
      'longitude': _lng,
      'enderecoGps': _gpsEndereco,
      'lei': _lei,
      'artigo': _artigo,
      'inciso': _inciso,
      'descricaoLegal': _descLegalCtrl.text,
      'descricao': _descricao.text,
      'fundamentacao': _fundamentacao.text,
      'observacoes': _observacoes.text,
      'medidasExigidas': _medidasCtrl.text,
      'prazoCumprimento': _prazoCumprimentoCtrl.text,
      'advertenciaPenalidade': _advertenciaCtrl.text,
      'evidencias': _evidencias.map((e) => {'bytes': e.bytes, 'descricao': e.descricao}).toList(),
      'assinaturaFiscal': _assinaturaFiscal,
      'assinaturaResponsavel': _assinaturaResponsavel,
    };
  }

  Future<void> _saveLocal({
    required String dataInspecaoStr,
    required String horaStr,
  }) async {
    final db = await LocalDb.instance;
    final autoId = await db.insert('autos_sanitarios', {
      'tipo_auto': _tipo,
      'numero_auto': _numero,
      'estabelecimento_id': _estabelecimentoId ?? 0,
      'inspecao_id': _inspecaoId ?? 0,
      'fiscal_id': 0,
      'data': DateTime.now().toIso8601String(),
      'descricao': _descricao.text,
      'fundamentacao_legal': _fundamentacao.text,
      'observacoes': _observacoes.text,
      'status': 'PENDENTE',
      'responsavel_nome': _respNomeCtrl.text,
      'responsavel_cpf': _respCpfCtrl.text,
      'responsavel_cargo': _respCargoCtrl.text,
      'responsavel_telefone': _respTelefoneCtrl.text,
      'fiscal_nome': _fiscalNomeCtrl.text,
      'fiscal_matricula': _fiscalMatriculaCtrl.text,
      'data_inspecao': dataInspecaoStr,
      'hora_inspecao': horaStr,
      'tipo_inspecao': _tipoInspecao,
      'classificacao_infracao': _classificacao,
      'apreensao': _apreensao ? 1 : 0,
      'interdicao': _interdicao ? 1 : 0,
      'tipo_medida': _tipoMedida,
      'prazo_regularizacao': int.tryParse(_prazoRegularizacaoCtrl.text),
      'valor_multa': double.tryParse(_valorMultaCtrl.text.replaceAll(',', '.')),
      'latitude': _lat,
      'longitude': _lng,
      'endereco_gps': _gpsEndereco,
    });

    for (final ev in _evidencias) {
      final b64 = base64Encode(ev.bytes);
      await db.insert('fotos', {
        'inspecao_id': _inspecaoId ?? 0,
        'auto_id': autoId,
        'categoria': 'EVIDENCIA',
        'descricao': ev.descricao,
        'url': b64,
        'data': DateTime.now().toIso8601String(),
        'gps': '${_lat ?? ''},${_lng ?? ''}',
      });
    }
    if (_assinaturaFiscal != null) {
      final b64 = base64Encode(_assinaturaFiscal!);
      await db.insert('fotos', {
        'inspecao_id': _inspecaoId ?? 0,
        'auto_id': autoId,
        'categoria': 'ASSINATURA_FISCAL',
        'descricao': 'Assinatura do fiscal',
        'url': b64,
        'data': DateTime.now().toIso8601String(),
        'gps': '',
      });
    }
    if (_assinaturaResponsavel != null) {
      final b64 = base64Encode(_assinaturaResponsavel!);
      await db.insert('fotos', {
        'inspecao_id': _inspecaoId ?? 0,
        'auto_id': autoId,
        'categoria': 'ASSINATURA_RESPONSAVEL',
        'descricao': 'Assinatura do responsável',
        'url': b64,
        'data': DateTime.now().toIso8601String(),
        'gps': '',
      });
    }
  }

  Future<void> _saveWeb() async {
    await _api.init();
    if (_estabelecimentoId == null) {
      final d = await _api.buscarEstabelecimentoPorCnpj(_digitsOnly(_cnpjCtrl.text));
      _estabelecimentoId = (d?['id'] as num?)?.toInt();
      if (d != null) {
        _loadEstabelecimentoFromArgs({'estabelecimento': d});
      }
    }
    if (_estabelecimentoId == null) {
      throw StateError('missing_estabelecimento');
    }
    if (_inspecaoId == null) {
      final created = await _api.criarInspecao(
        tipoAuto: _tipoAutoApi,
        estabelecimentoId: _estabelecimentoId!,
        descricao: _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
      );
      _inspecaoId = (created?['id'] as num?)?.toInt();
    }
    if (_inspecaoId == null) {
      throw StateError('missing_inspecao');
    }
    if (_tipo == 'INT') {
      final ok = await _api.salvarIntimacao(
        inspecaoId: _inspecaoId!,
        descricaoIrregularidade: _descricao.text.trim(),
        baseLegal: _fundamentacao.text.trim(),
        prazoRegularizacao: _prazoCumprimentoCtrl.text.trim(),
        penalidadePrevista: _advertenciaCtrl.text.trim(),
      );
      if (!ok) throw StateError('save_intimacao_failed');
    }
    for (final ev in _evidencias) {
      final ok = await _api.enviarFotoInspecao(
        inspecaoId: _inspecaoId!,
        url: base64Encode(ev.bytes),
        data: DateTime.now().toIso8601String(),
      );
      if (!ok) throw StateError('save_evidence_failed');
    }
    if (_assinaturaFiscal != null) {
      final ok = await _api.enviarAssinaturaInspecao(
        inspecaoId: _inspecaoId!,
        assinaturaFiscal: base64Encode(_assinaturaFiscal!),
        assinaturaResponsavel: _assinaturaResponsavel == null ? null : base64Encode(_assinaturaResponsavel!),
      );
      if (!ok) throw StateError('save_signature_failed');
    }
    await _api.finalizarInspecao(inspecaoId: _inspecaoId!);
  }

  Future<void> _save() async {
    // Validar todos os dados obrigatórios antes de salvar
    if (!_validateAllData()) {
      return;
    }

    setState(() => _saving = true);
    final horaStr = _horaInspecao.format(context);
    final dataInspecaoStr = _dataInspecao.toIso8601String().substring(0, 10);
    try {
      if (kIsWeb) {
        await _saveWeb();
      } else {
        await _saveLocal(dataInspecaoStr: dataInspecaoStr, horaStr: horaStr);
      }

      if (mounted) {
        final estab = <String, dynamic>{
          'nomeFantasia': _fantasiaCtrl.text.isNotEmpty ? _fantasiaCtrl.text : _nome,
          'razaoSocial': _razaoCtrl.text,
          'cnpj': _digitsOnly(_cnpjCtrl.text),
          'endereco':
              '${_logradouroCtrl.text}${_numeroEndCtrl.text.isNotEmpty ? ', ${_numeroEndCtrl.text}' : ''} - ${_bairroCtrl.text} - ${_cidadeCtrl.text} (${_cepCtrl.text})',
          'telefone': _respTelefoneCtrl.text,
        }..removeWhere((_, v) => (v ?? '').toString().trim().isEmpty);

        final documentoVinculoPayload = <String, dynamic>{
          'tipo_documento': _tipo == 'INF'
              ? 'AUTO_INFRACAO'
              : _tipo == 'COL'
                  ? 'AUTO_COLETA'
                  : 'AUTO_INTIMACAO',
          'numero_ano': _numero,
          'data_inspecao': dataInspecaoStr,
          'hora_inspecao': horaStr,
          if (_inspecaoId != null) 'inspecao_id': _inspecaoId,
        };

        await Navigator.pushNamed(
          context,
          '/auto-pdf',
          arguments: _buildPdfArguments(
            dataInspecaoStr: dataInspecaoStr,
            horaStr: horaStr,
          ),
        );
        if (!mounted) return;

        final abrir = await _perguntarAbrirRelatorioInspecao();
        if (!mounted) return;
        if (abrir) {
          await _abrirRelatorioInspecao(
            estabelecimento: estab,
            documentoVinculoPayload: documentoVinculoPayload,
          );
          if (!mounted) return;
        }
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      debugPrint('Erro ao salvar auto: $e');
      if (mounted) {
        final msg = switch ('$e') {
          'Bad state: missing_estabelecimento' => 'Não foi possível identificar o estabelecimento.',
          'Bad state: missing_inspecao' => 'Não foi possível criar a inspeção.',
          'Bad state: save_intimacao_failed' => 'Não foi possível salvar o Auto de Intimação.',
          'Bad state: save_evidence_failed' => 'Não foi possível enviar as evidências.',
          'Bad state: save_signature_failed' => 'Não foi possível salvar as assinaturas.',
          _ => 'Não foi possível salvar o auto neste ambiente.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Future<void> _abrirRelatorioInspecao({
    required Map<String, dynamic> estabelecimento,
    required Map<String, dynamic> documentoVinculoPayload,
  }) async {
    await Navigator.pushNamed(
      context,
      '/relatorio-inspecao-sanitario',
      arguments: {
        if (estabelecimento.isNotEmpty) 'estabelecimento': estabelecimento,
        'documento_vinculado': {
          'tipo_documento': documentoVinculoPayload['tipo_documento'],
          'numero_ano': documentoVinculoPayload['numero_ano'],
          'payload': documentoVinculoPayload,
        },
      },
    );
  }

  /// Valida todos os dados obrigatórios antes de salvar
  bool _validateAllData() {
    // Validar estabelecimento
    if (_cnpjCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CNPJ do estabelecimento é obrigatório'), backgroundColor: _statusRed),
      );
      return false;
    }

    // Validar fiscal responsável
    if (_fiscalNomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do fiscal responsável é obrigatório'), backgroundColor: _statusRed),
      );
      return false;
    }
    if (_fiscalMatriculaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matrícula do fiscal é obrigatória'), backgroundColor: _statusRed),
      );
      return false;
    }

    // Validar descrição da infração (para Auto de Infração)
    if (_tipo == 'INF') {
      if (_descricao.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descrição detalhada da infração é obrigatória'), backgroundColor: _statusRed),
        );
        return false;
      }
      if (_descricao.text.trim().length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descrição deve ter no mínimo 10 caracteres'), backgroundColor: _statusRed),
        );
        return false;
      }

      // Validar classificação
      if (_classificacao.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classificação da infração é obrigatória'), backgroundColor: _statusRed),
        );
        return false;
      }

      // Validar legislação
      if (_lei.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base legal é obrigatória'), backgroundColor: _statusRed),
        );
        return false;
      }
      if (_descLegalCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descrição legal é obrigatória'), backgroundColor: _statusRed),
        );
        return false;
      }
      if (_descLegalCtrl.text.trim().length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descrição legal deve ter no mínimo 5 caracteres'), backgroundColor: _statusRed),
        );
        return false;
      }

      // Validar tipo de medida
      if (_tipoMedida.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipo de medida adotada é obrigatório'), backgroundColor: _statusRed),
        );
        return false;
      }

      // Validar valor da multa se medida for Multa
      if (_tipoMedida == 'Multa' && _valorMultaCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valor da multa é obrigatório quando a medida é Multa'), backgroundColor: _statusRed),
        );
        return false;
      }

      // Validar evidências para infração grave ou gravíssima
      if ((_classificacao == 'Grave' || _classificacao == 'Gravíssima') && _evidencias.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adicione pelo menos uma evidência para infração grave ou gravíssima'), backgroundColor: _statusRed),
        );
        return false;
      }
    }

    // Validar assinatura do fiscal
    if (_assinaturaFiscal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura do fiscal é obrigatória'), backgroundColor: _statusRed),
      );
      return false;
    }

    return true;
  }

  String get _title {
    switch (_tipo) {
      case 'INF':
        return 'AUTO DE INFRAÇÃO';
      case 'PEN':
        return 'IMPOSIÇÃO DE PENALIDADE';
      case 'COL':
        return 'AUTO DE COLETA PARA AMOSTRA';
      default:
        return 'AUTO DE INTIMAÇÃO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          // Stepper moderno
          _buildModernStepper(),
          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepBody(),
            ),
          ),
          // Botões de ação
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: Colors.white,
            child: _buildWizardButtons(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _govBlue,
      foregroundColor: Colors.white,
      title: Text(
        _title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        onPressed: _voltarOuDashboard,
      ),
      actions: [
        if (_numero.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              'Nº $_numero',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildModernStepper() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (idx) {
              final isActive = idx == _step;
              final isDone = idx < _step;
              
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? _govBlue : (isDone ? _statusGreen : Colors.grey[300]),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: _govBlue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  color: isActive || isDone ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ['Preenchimento', 'Revisão', 'Assinatura'][idx],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? _govBlue : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Linha conectora
          Row(
            children: List.generate(3, (idx) {
              final isConnected = idx < _step;
              return Expanded(
                child: idx < 2
                    ? Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isConnected ? _govBlue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildStepPreenchimento();
      case 1:
        return _buildStepRevisao();
      default:
        return _buildStepAssinatura();
    }
  }

  Widget _buildStepPreenchimento() {
    if (_tipo == 'INF') {
      return Form(
        key: _dadosFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGovHeader(),
            const SizedBox(height: 16),
            Text('AUTO DE INFRAÇÃO Nº $_numero', 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _darkGray,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection('Dados do Estabelecimento', _buildEstabelecimentoForm(), icon: Icons.store_outlined),
            _buildSection('Responsável Presente', _buildResponsavelForm(), icon: Icons.person_outline),
            _buildSection('Dados da Inspeção', _buildInspecaoForm(), icon: Icons.assignment_outlined),
            _buildSection('Descrição da Infração', _buildDescricaoForm(), icon: Icons.report_problem_outlined),
            _buildSection('Fundamentação Legal', _buildLegalForm(), icon: Icons.gavel_outlined),
            _buildSection('Evidências', _buildEvidenciasForm(), icon: Icons.image_search_outlined),
            _buildSection('Penalidade / Medidas', _buildMedidasForm(), icon: Icons.assignment_turned_in_outlined),
            _buildSection('Perfil Sanitário', _buildPerfilSanitario(), icon: Icons.show_chart_outlined),
            _buildSection('Geolocalização', _buildGeolocalizacao(), icon: Icons.location_on_outlined),
          ],
        ),
      );
    }

    return Form(
      key: _dadosFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nº $_numero', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _darkGray,
            fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 14),
          _buildEstablishmentCard(),
          const SizedBox(height: 14),
          _buildSection('Responsável Presente', _buildResponsavelForm(), icon: Icons.person_outline),
          _buildSection('Dados da Inspeção', _buildInspecaoForm(), icon: Icons.assignment_outlined),
          _buildSection('Descrição e Fundamentação', _buildBaseFormFields(), icon: Icons.description_outlined),
          _buildSection(_title, _buildConditionalSection(), icon: Icons.fact_check_outlined),
          _buildSection('Evidências', _buildEvidenciasForm(), icon: Icons.image_search_outlined),
          _buildSection('Geolocalização', _buildGeolocalizacao(), icon: Icons.location_on_outlined),
        ],
      ),
    );
  }

  Widget _buildStepRevisao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tipo == 'INF') ...[
          _buildGovHeader(),
          const SizedBox(height: 16),
        ],
        Text(
          'Revisar e Confirmar Auto',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _darkGray,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Verifique se todos os dados estão corretos antes de prosseguir',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        _buildReviewCard(),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _revisaoConfirmada = true),
            icon: Icon(_revisaoConfirmada ? Icons.check_circle : Icons.radio_button_unchecked),
            label: Text(_revisaoConfirmada ? 'Revisão Confirmada' : 'Confirmar Revisão'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _revisaoConfirmada ? _statusGreen : _govBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepAssinatura() {
    return Form(
      key: _assinaturaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tipo == 'INF') ...[
            _buildGovHeader(),
            const SizedBox(height: 16),
          ],
          Text(
            'Assinatura Digital',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _darkGray,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assine digitalmente para validar este auto e concluir o processo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusChip(
                  _assinaturaFiscal != null ? 'Fiscal assinado' : 'Fiscal pendente',
                  _assinaturaFiscal != null ? _statusGreen : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusChip(
                  _assinaturaResponsavel != null ? 'Responsável assinado' : 'Responsável opcional',
                  _assinaturaResponsavel != null ? _statusGreen : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildReviewCard(),
          const SizedBox(height: 16),
          _buildSection('Assinaturas Digitais', _buildAssinaturas(), icon: Icons.security_outlined),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final cnpjDigits = _digitsOnly(_cnpjCtrl.text);
    final estab = _fantasiaCtrl.text.isNotEmpty
        ? _fantasiaCtrl.text
        : (_nome.isNotEmpty ? _nome : 'Estabelecimento');

    final endereco =
        '${_logradouroCtrl.text}${_numeroEndCtrl.text.isNotEmpty ? ', ${_numeroEndCtrl.text}' : ''}'
        '${_bairroCtrl.text.isNotEmpty ? ' - ${_bairroCtrl.text}' : ''}'
        '${_cidadeCtrl.text.isNotEmpty ? ' - ${_cidadeCtrl.text}' : ''}';

    final evidenciasLabel = '${_evidencias.length} foto${_evidencias.length != 1 ? 's' : ''} anexada${_evidencias.length != 1 ? 's' : ''}';
    final gpsLabel = _lat != null && _lng != null ? 'GPS capturado' : 'GPS pendente';
    final assinaturaFiscalLabel = _assinaturaFiscal != null ? 'Fiscal assinado' : 'Fiscal pendente';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _govBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _govBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Resumo do Auto nº $_numero',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _govBlue,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(_title, _govBlue),
                _buildStatusChip(evidenciasLabel, _evidencias.isNotEmpty ? _statusGreen : Colors.orange),
                _buildStatusChip(gpsLabel, _lat != null && _lng != null ? _statusGreen : Colors.orange),
                _buildStatusChip(assinaturaFiscalLabel, _assinaturaFiscal != null ? _statusGreen : Colors.orange),
              ],
            ),
            const SizedBox(height: 14),
            // Seções de informação
            _buildReviewSection('Informações do Auto', [
              _reviewRow('Tipo', _title),
              _reviewRow('Número', _numero.isEmpty ? '-' : _numero),
            ]),
            const SizedBox(height: 12),
            _buildReviewSection('Dados do Estabelecimento', [
              _reviewRow('Estabelecimento', estab),
              _reviewRow('CNPJ', cnpjDigits.isEmpty ? '-' : cnpjDigits),
              _reviewRow('Razão Social', _razaoCtrl.text.isEmpty ? '-' : _razaoCtrl.text),
              if (endereco.trim().isNotEmpty) _reviewRow('Endereço', endereco),
            ]),
            const SizedBox(height: 12),
            _buildReviewSection('Responsável Presente', [
              _reviewRow('Nome', _respNomeCtrl.text.isEmpty ? '-' : _respNomeCtrl.text),
              _reviewRow('CPF', _respCpfCtrl.text.isEmpty ? '-' : _respCpfCtrl.text),
              _reviewRow('Cargo', _respCargoCtrl.text.isEmpty ? '-' : _respCargoCtrl.text),
            ]),
            const SizedBox(height: 12),
            _buildReviewSection('Dados da Inspeção', [
              _reviewRow('Fiscal', _fiscalNomeCtrl.text.isEmpty ? '-' : _fiscalNomeCtrl.text),
              _reviewRow('Data', _dataInspecao.toIso8601String().substring(0, 10)),
              _reviewRow('Hora', _horaInspecao.format(context)),
              _reviewRow('Tipo', _tipoInspecao),
            ]),
            const SizedBox(height: 12),
            _buildReviewSection('Descrição e Fundamentação', [
              _reviewRow('Descrição', _descricao.text.isEmpty ? '-' : _descricao.text, multiline: true),
              _reviewRow('Fundamentação Legal', _fundamentacao.text.isEmpty ? '-' : _fundamentacao.text, multiline: true),
            ]),
            if (_tipo == 'INF') ...[
              const SizedBox(height: 12),
              _buildReviewSection('Infração', [
                _reviewRow('Classificação', _classificacao),
                _reviewRow('Apreensão', _apreensao ? 'Sim' : 'Não'),
                _reviewRow('Interdição', _interdicao ? 'Sim' : 'Não'),
              ]),
            ],
            if (_tipo == 'INT') ...[
              const SizedBox(height: 12),
              _buildReviewSection('Intimação', [
                _reviewRow('Medidas Exigidas', _medidasCtrl.text.isEmpty ? '-' : _medidasCtrl.text, multiline: true),
                _reviewRow('Prazo para Cumprimento', _prazoCumprimentoCtrl.text.isEmpty ? '-' : '${_prazoCumprimentoCtrl.text} dias'),
                _reviewRow('Advertência', _advertenciaCtrl.text.isEmpty ? '-' : _advertenciaCtrl.text, multiline: true),
              ]),
            ],
            if (_tipo == 'PEN') ...[
              const SizedBox(height: 12),
              _buildReviewSection('Penalidade', [
                _reviewRow('Processo', _getController('processo').text.isEmpty ? '-' : _getController('processo').text),
                _reviewRow('Auto Relacionado', _getController('auto_relacionado').text.isEmpty ? '-' : _getController('auto_relacionado').text),
                _reviewRow('Tipo de Penalidade', _tipoMedida),
                _reviewRow('Valor', _getController('valor').text.isEmpty ? '-' : 'R\$ ${_getController('valor').text}'),
                _reviewRow('Prazo de Pagamento', _getController('prazo_pagto').text.isEmpty ? '-' : '${_getController('prazo_pagto').text} dias'),
              ]),
            ],
            if (_tipo == 'COL') ...[
              const SizedBox(height: 12),
              _buildReviewSection('Coleta', [
                _reviewRow('Produto', _getController('produto').text.isEmpty ? '-' : _getController('produto').text),
                _reviewRow('Marca', _getController('marca').text.isEmpty ? '-' : _getController('marca').text),
                _reviewRow('Lote', _getController('lote').text.isEmpty ? '-' : _getController('lote').text),
                _reviewRow('Validade', _getController('validade').text.isEmpty ? '-' : _getController('validade').text),
                _reviewRow('Quantidade', _getController('quantidade').text.isEmpty ? '-' : _getController('quantidade').text),
                _reviewRow('Tipo de Análise', _classificacao),
                _reviewRow('Laboratório', _getController('laboratorio').text.isEmpty ? '-' : _getController('laboratorio').text),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _darkGray,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        ...items.expand((item) => [item, const SizedBox(height: 8)]).toList()..removeLast(),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value, {bool multiline = false}) {
    return Row(
      crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _darkGray,
              fontWeight: FontWeight.w600,
            ),
            maxLines: multiline ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool _validarPreenchimento() {
    final cnpjDigits = _digitsOnly(_cnpjCtrl.text);
    if (cnpjDigits.length != 14) return false;
    if (_fiscalNomeCtrl.text.trim().isEmpty) return false;
    if (_respNomeCtrl.text.trim().isEmpty) return false;
    if (_fundamentacao.text.trim().isEmpty) return false;
    if (_tipo == 'INF') {
      if (_descricao.text.trim().isEmpty) return false;
      return true;
    }
    if (_descricao.text.trim().isEmpty) return false;
    if (_tipo == 'INT') {
      if (_medidasCtrl.text.trim().isEmpty) return false;
      if (_prazoCumprimentoCtrl.text.trim().isEmpty) return false;
      if (_advertenciaCtrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  bool _validarAssinatura() {
    return _assinaturaFiscal != null;
  }

  /// Valida apenas o step atual usando o GlobalKey correspondente
  bool _validateCurrentStep() {
    GlobalKey<FormState>? currentFormKey;

    switch (_step) {
      case 0:
        currentFormKey = _dadosFormKey;
        break;
      case 1:
        // Step de revisão não tem validação de campos
        if (!_revisaoConfirmada) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Confirme a revisão antes de continuar'),
              backgroundColor: _statusRed,
            ),
          );
          return false;
        }
        return true;
      case 2:
        currentFormKey = _assinaturaFormKey;
        break;
      default:
        return true;
    }

    if (currentFormKey != null) {
      final isValid = currentFormKey.currentState?.validate() ?? true;
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corrija os campos destacados antes de continuar'),
            backgroundColor: _statusRed,
          ),
        );
      }
      return isValid;
    }

    return true;
  }

  Widget _buildWizardButtons() {
    final canBack = _step > 0 && !_saving;
    final isLast = _step == 2;
    final canNext = !_saving;
    final primaryLabel = isLast ? 'Assinar e Emitir Auto' : 'Continuar';
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: canBack ? () => setState(() => _step -= 1) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: canBack ? _govBlue : Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Voltar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: canBack ? _govBlue : Colors.grey[400],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: canNext
                ? () async {
                    // Validar step atual antes de avançar
                    if (!_validateCurrentStep()) {
                      return;
                    }
                    
                    if (isLast) {
                      // Validar assinatura antes de salvar
                      if (_assinaturaFiscal == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Adicione a assinatura do fiscal antes de emitir'),
                            backgroundColor: _statusRed,
                          ),
                        );
                        return;
                      }
                      await _save();
                      return;
                    }
                    setState(() => _step += 1);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isLast ? Icons.check_circle_outline : Icons.arrow_forward, size: 18),
                      const SizedBox(width: 8),
                      Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEstablishmentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _govBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store_outlined, size: 20, color: _govBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fantasiaCtrl.text.isNotEmpty ? _fantasiaCtrl.text : _nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _darkGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CNPJ: ${_cnpjCtrl.text.isEmpty ? _cnpj : _cnpjCtrl.text}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_razaoCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Razão Social: ${_razaoCtrl.text}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
          if (_logradouroCtrl.text.trim().isNotEmpty || _cidadeCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Endereço: ${_logradouroCtrl.text}${_numeroEndCtrl.text.isNotEmpty ? ', ${_numeroEndCtrl.text}' : ''}'
              '${_bairroCtrl.text.isNotEmpty ? ' - ${_bairroCtrl.text}' : ''}'
              '${_cidadeCtrl.text.isNotEmpty ? ' - ${_cidadeCtrl.text}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGovHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'public/brasao.png',
              height: 56,
              width: 56,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) => Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _govBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: _govBlue),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREFEITURA MUNICIPAL DE BALNEÁRIO CAMBORIÚ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VIGILÂNCIA SANITÁRIA MUNICIPAL',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _govBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título com ícone
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _govBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: _govBlue),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _darkGray,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Conteúdo
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEstabelecimentoForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OfficialCnpjField(
                controller: _cnpjCtrl,
                label: 'CNPJ',
                required: true,
                enabled: !_argsLoaded,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _buscarEstabelecimento,
              icon: const Icon(Icons.search_outlined, size: 18),
              label: const Text('Buscar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _govBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OfficialTextField(
          controller: _razaoCtrl,
          label: 'Razão Social',
          enabled: !_argsLoaded,
        ),
        const SizedBox(height: 12),
        OfficialTextField(
          controller: _fantasiaCtrl,
          label: 'Nome Fantasia',
          enabled: !_argsLoaded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialTextField(
                controller: _logradouroCtrl,
                label: 'Logradouro',
                enabled: !_argsLoaded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialNumericField(
                controller: _numeroEndCtrl,
                label: 'Número',
                required: false,
                enabled: !_argsLoaded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialTextField(
                controller: _bairroCtrl,
                label: 'Bairro',
                enabled: !_argsLoaded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialTextField(
                controller: _cidadeCtrl,
                label: 'Cidade',
                enabled: !_argsLoaded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialTextField(
                controller: _cepCtrl,
                label: 'CEP',
                enabled: !_argsLoaded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  CepInputFormatter(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialTextField(
                controller: _statusAlvaraCtrl,
                label: 'Situação do Alvará',
                enabled: !_argsLoaded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialTextField(
                controller: _cnaeCtrl,
                label: 'CNAE',
                enabled: !_argsLoaded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialTextField(
                controller: _atividadeCtrl,
                label: 'Atividade Econômica',
                enabled: !_argsLoaded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OfficialDropdownField<bool>(
          value: _debitoVencido,
          items: const [
            DropdownMenuItem(value: false, child: Text('Não')),
            DropdownMenuItem(value: true, child: Text('Sim')),
          ],
          onChanged: (v) => setState(() => _debitoVencido = v),
          label: 'Situação Fiscal',
          required: false,
        ),
      ],
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required List<(String, T)> items,
    required Function(T?) onChanged,
    required String label,
    bool isRequired = false,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item.$2, child: Text(item.$1))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _govBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildResponsavelForm() {
    return Column(
      children: [
        OfficialTextField(
          controller: _respNomeCtrl,
          label: 'Nome do Responsável',
          required: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialCpfField(
                controller: _respCpfCtrl,
                label: 'CPF',
                required: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialTextField(
                controller: _respCargoCtrl,
                label: 'Cargo/Função',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OfficialPhoneField(
          controller: _respTelefoneCtrl,
          label: 'Telefone',
          required: false,
        ),
      ],
    );
  }

  Widget _buildInspecaoForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OfficialTextField(
                controller: _fiscalNomeCtrl,
                label: 'Fiscal Responsável',
                required: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialNumericField(
                controller: _fiscalMatriculaCtrl,
                label: 'Matrícula',
                required: true,
                minValue: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialDateField(
                value: _dataInspecao,
                label: 'Data da Inspeção',
                required: true,
                onChanged: (picked) {
                  if (picked != null) setState(() => _dataInspecao = picked);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialTimeField(
                value: _horaInspecao,
                label: 'Hora',
                required: true,
                onChanged: (picked) {
                  if (picked != null) setState(() => _horaInspecao = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OfficialDropdownField<String>(
          value: _tipoInspecao,
          items: const [
            DropdownMenuItem(value: 'Rotina', child: Text('Rotina')),
            DropdownMenuItem(value: 'Denúncia', child: Text('Denúncia')),
            DropdownMenuItem(value: 'Retorno', child: Text('Retorno')),
            DropdownMenuItem(value: 'Licenciamento', child: Text('Licenciamento')),
          ],
          onChanged: (v) => setState(() => _tipoInspecao = v ?? 'Rotina'),
          label: 'Tipo de Inspeção',
          required: true,
        ),
      ],
    );
  }

  Widget _buildDescricaoForm() {
    final templates = const [
      'Foi constatada ausência de higiene adequada no ambiente de manipulação de alimentos, presença de resíduos acumulados e armazenamento inadequado de produtos perecíveis.',
      'Foi verificada a inexistência de controle de temperatura e ausência de registros obrigatórios.',
      'Foram encontradas condições inadequadas de armazenamento e falta de proteção contra pragas.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Templates Rápidos',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: templates.asMap().entries.map((entry) {
            return ActionChip(
              onPressed: () {
                _descricao.text = entry.value;
                setState(() {});
              },
              label: Text('Template ${entry.key + 1}'),
              side: const BorderSide(color: _govBlue),
              labelStyle: const TextStyle(color: _govBlue, fontSize: 12),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        OfficialMultilineField(
          controller: _descricao,
          label: 'Descrição Detalhada da Irregularidade',
          required: true,
          hint: 'Descreva com detalhes o que foi encontrado...',
          minLines: 4,
          maxLines: 8,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Campo obrigatório';
            }
            if (value.trim().length < 10) {
              return 'Mínimo de 10 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        OfficialDropdownField<String>(
          value: _classificacao,
          items: const [
            DropdownMenuItem(value: 'Leve', child: Text('Leve')),
            DropdownMenuItem(value: 'Grave', child: Text('Grave')),
            DropdownMenuItem(value: 'Gravíssima', child: Text('Gravíssima')),
          ],
          onChanged: (v) => setState(() => _classificacao = v ?? 'Leve'),
          label: 'Classificação da Infração',
          required: true,
        ),
      ],
    );
  }

  static const _legalItems = <Map<String, String>>[
    {'lei': 'Lei 6.437/77', 'artigo': '10', 'inciso': '', 'descricao': 'Infrações à legislação sanitária federal'},
    {'lei': 'RDC 216/2004', 'artigo': '', 'inciso': '', 'descricao': 'Boas práticas para serviços de alimentação'},
    {'lei': 'Código Sanitário Municipal', 'artigo': '', 'inciso': '', 'descricao': 'Normas sanitárias municipais'},
  ];

  Widget _buildLegalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecionar Legislação',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        _buildModernTextField(
          controller: TextEditingController(),
          label: 'Pesquisar Legislação',
          hint: 'Digite lei, artigo ou palavra-chave...',
          onChanged: (v) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.white,
          ),
          child: Column(
            children: List.generate(
              (_legalItems.length > 5 ? 5 : _legalItems.length),
              (idx) {
                final item = _legalItems[idx];
                final isSelected = _lei == (item['lei'] ?? '');
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  onTap: () => setState(() {
                    _lei = item['lei'] ?? '';
                    _artigo = item['artigo'] ?? '';
                    _inciso = item['inciso'] ?? '';
                    _descLegalCtrl.text = item['descricao'] ?? '';
                    _fundamentacao.text = _lei;
                  }),
                  selected: isSelected,
                  selectedTileColor: _govBlue.withOpacity(0.08),
                  title: Text(
                    item['lei'] ?? 'N/A',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? _govBlue : _darkGray,
                    ),
                  ),
                  subtitle: Text(
                    '${item['artigo'] != null && item['artigo']!.isNotEmpty ? 'Art. ${item['artigo']!}' : ''} ${item['descricao'] ?? ''}',
                    style: TextStyle(fontSize: 11, color: isSelected ? _govBlue.withOpacity(0.7) : Colors.black54),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: _statusGreen) : null,
                );
              },
            ),
          ),
        ),
        if (_lei.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _govBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _govBlue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Legislação Selecionada',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _govBlue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRow([
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lei',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_lei, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (_artigo.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Artigo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_artigo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                ]),
                if (_inciso.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Inciso: $_inciso',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          OfficialMultilineField(
            controller: _descLegalCtrl,
            label: 'Descrição Legal',
            required: true,
            hint: 'Justifique como a lei se aplica ao caso',
            minLines: 2,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo obrigatório';
              }
              if (value.trim().length < 5) {
                return 'Mínimo de 5 caracteres';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Future<void> _addEvidence(ImageSource source) async {
    final x = await _picker.pickImage(source: source, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _evidencias.add(_EvidenceItem(bytes: bytes, descricao: ''));
    });
  }

  Widget _buildEvidenciasForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botões para adicionar evidências
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _addEvidence(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Tirar Foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _addEvidence(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Galeria'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Contador de evidências
        if (_evidencias.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _statusGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: _statusGreen, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_evidencias.length} foto${_evidencias.length != 1 ? 's' : ''} anexada${_evidencias.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: _statusGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Nenhuma evidência adicionada ainda',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        // Grid de evidências
        if (_evidencias.isNotEmpty) ...[
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _evidencias.length,
            itemBuilder: (ctx, idx) {
              final ev = _evidencias[idx];
              return Stack(
                children: [
                  // Preview da imagem
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(ev.bytes, fit: BoxFit.cover),
                    ),
                  ),
                  // Botão para remover
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _evidencias.removeAt(idx)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _statusRed,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // Descrição das evidências
          Column(
            children: List.generate(_evidencias.length, (idx) {
              final ev = _evidencias[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildModernTextField(
                  controller: TextEditingController(text: ev.descricao),
                  label: 'Descrição da foto ${idx + 1}',
                  maxLines: 2,
                  onChanged: (v) => _evidencias[idx] = _EvidenceItem(bytes: ev.bytes, descricao: v ?? ''),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildMedidasForm() {
    return Column(
      children: [
        Text(
          'Medidas Recomendadas',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _lightBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _apreensao,
                onChanged: (v) => setState(() => _apreensao = v),
                title: const Text(
                  'Apreensão de Produtos',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text('Produtos impróprios para consumo', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 12, indent: 0, endIndent: 0),
              SwitchListTile(
                value: _interdicao,
                onChanged: (v) => setState(() => _interdicao = v),
                title: const Text(
                  'Interdição do Estabelecimento',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text('Fechamento total ou parcial', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 12, indent: 0, endIndent: 0),
              SwitchListTile(
                value: _destruicao,
                onChanged: (v) => setState(() => _destruicao = v),
                title: const Text(
                  'Destruição de Produtos',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: const Text('Produto com risco iminente à saúde', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OfficialDropdownField<String>(
          value: _tipoMedida,
          items: const [
            DropdownMenuItem(value: 'Advertência', child: Text('Advertência')),
            DropdownMenuItem(value: 'Multa', child: Text('Multa')),
            DropdownMenuItem(value: 'Interdição', child: Text('Interdição')),
            DropdownMenuItem(value: 'Apreensão', child: Text('Apreensão')),
            DropdownMenuItem(value: 'Descarte', child: Text('Descarte')),
          ],
          onChanged: (v) => setState(() => _tipoMedida = v ?? 'Advertência'),
          label: 'Tipo de Medida Adotada',
          required: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OfficialNumericField(
                controller: _prazoRegularizacaoCtrl,
                label: 'Prazo (dias)',
                required: false,
                minValue: 1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OfficialMoneyField(
                controller: _valorMultaCtrl,
                label: 'Valor da Multa',
                required: _tipoMedida == 'Multa',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<int> _countInfracoesAnteriores() async {
    if (kIsWeb) return 0;
    if (_estabelecimentoId == null) return 0;
    try {
      final db = await LocalDb.instance;
      final res = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM autos_sanitarios WHERE tipo_auto = ? AND estabelecimento_id = ?',
        ['INF', _estabelecimentoId],
      );
      return (res.first['c'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildPerfilSanitario() {
    return FutureBuilder<int>(
      future: _countInfracoesAnteriores(),
      builder: (context, snap) {
        final prev = snap.data ?? 0;
        final riscoTxt = (() {
          final r = _statusAlvaraCtrl.text;
          if (r.toLowerCase().contains('venc')) return 'ALTO';
          return 'MÉDIO';
        })();
        final base = riscoTxt == 'ALTO' ? 75 : (riscoTxt == 'MÉDIO' ? 45 : 20);
        final score = (base + prev * 5).clamp(0, 100);
        final color = score >= 75 ? _statusRed : (score >= 45 ? Colors.orange : _statusGreen);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart_outlined, color: color, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Risco Sanitário',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _darkGray,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      riscoTxt,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Score de Risco',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: score / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$score/100',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _darkGray,
                    ),
                  ),
                  Text(
                    'Infrações anteriores: $prev',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _capturarLocalizacao() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _gpsEndereco = '';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível capturar a localização.')));
    }
  }

  Widget _buildGeolocalizacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status da localização
        if (_lat != null && _lng != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: _statusGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Localização Capturada',
                        style: TextStyle(
                          color: _statusGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_lat?.toStringAsFixed(6) ?? '-'}, ${_lng?.toStringAsFixed(6) ?? '-'}',
                        style: TextStyle(
                          color: _statusGreen.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_off_outlined, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Localização não capturada',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Clique em "Capturar" para obter coordenadas GPS',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        // Botão de captura
        ElevatedButton.icon(
          onPressed: _saving ? null : _capturarLocalizacao,
          icon: const Icon(Icons.my_location_outlined, size: 18),
          label: const Text('Capturar Localização'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _govBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        if (_gpsEndereco.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildModernTextField(
            controller: TextEditingController(text: _gpsEndereco),
            label: 'Endereço GPS',
            readOnly: true,
            suffixIcon: const Icon(Icons.place_outlined, color: _govBlue, size: 18),
          ),
        ],
      ],
    );
  }

  Widget _buildAssinaturas() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final res = await Navigator.pushNamed(context, '/assinatura');
                  if (res is Uint8List) setState(() => _assinaturaFiscal = res);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Assinar como Fiscal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final res = await Navigator.pushNamed(context, '/assinatura');
                  if (res is Uint8List) setState(() => _assinaturaResponsavel = res);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Assinar como Responsável'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _assinaturaFiscal == null ? Colors.orange : _statusGreen,
                    width: 2,
                  ),
                  color: _assinaturaFiscal == null ? Colors.orange.withOpacity(0.05) : _statusGreen.withOpacity(0.05),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _assinaturaFiscal == null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_outlined, size: 40, color: Colors.orange.withOpacity(0.6)),
                              const SizedBox(height: 8),
                              const Text(
                                'Fiscal',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Pressione o botão para assinar',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Image.memory(_assinaturaFiscal!, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _assinaturaResponsavel == null ? Colors.grey[400]! : _statusGreen,
                    width: 2,
                  ),
                  color: _assinaturaResponsavel == null ? Colors.grey[100] : _statusGreen.withOpacity(0.05),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _assinaturaResponsavel == null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_outlined, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              const Text(
                                'Responsável',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Opcional',
                                style: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Image.memory(_assinaturaResponsavel!, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBaseFormFields() {
    return Column(
      children: [
        _buildModernTextField(
          controller: _descricao,
          label: 'Descrição',
          isRequired: true,
          maxLines: 4,
          minLines: 3,
          hint: 'Descreva os problemas encontrados...',
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _fundamentacao,
          label: 'Fundamentação Legal',
          isRequired: true,
          maxLines: 3,
          minLines: 2,
          hint: 'Cite a lei ou resolução aplicável...',
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _observacoes,
          label: 'Observações Adicionais',
          maxLines: 3,
          minLines: 2,
          hint: 'Informações complementares...',
        ),
      ],
    );
  }

  Widget _buildConditionalSection() {
    switch (_tipo) {
      case 'INT':
        return _buildIntimacaoSection();
      case 'INF':
        return _buildInfracaoSection();
      case 'PEN':
        return _buildPenalidadeSection();
      case 'COL':
        return _buildColetaSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIntimacaoSection() {
    return Column(
      children: [
        _buildModernTextField(
          controller: _medidasCtrl,
          label: 'Medidas Exigidas',
          isRequired: true,
          maxLines: 4,
          minLines: 3,
          hint: 'Descreva quais são as medidas corretivas necessárias...',
        ),
        const SizedBox(height: 12),
        _buildNumericField(
          _prazoCumprimentoCtrl,
          'Prazo para Cumprimento (dias)',
          isRequired: true,
          maxLength: 4,
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _advertenciaCtrl,
          label: 'Advertência de Penalidade',
          isRequired: true,
          maxLines: 3,
          minLines: 2,
          hint: 'Informar quais penalidades incidirão caso não haja cumprimento...',
        ),
      ],
    );
  }

  Widget _buildInfracaoSection() {
    return Column(
      children: [
        _buildModernDropdown<String>(
          value: _classificacao,
          items: const [
            ('Leve', 'Leve'),
            ('Grave', 'Grave'),
            ('Gravíssima', 'Gravíssima'),
          ],
          onChanged: (v) => setState(() => _classificacao = v ?? 'Leve'),
          label: 'Classificação da Infração',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _lightBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _apreensao,
                onChanged: (v) => setState(() => _apreensao = v),
                title: const Text(
                  'Apreensão de Produtos',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 12),
              SwitchListTile(
                value: _interdicao,
                onChanged: (v) => setState(() => _interdicao = v),
                title: const Text(
                  'Interdição do Estabelecimento',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPenalidadeSection() {
    return Column(
      children: [
        _buildModernTextField(
          controller: _getController('processo'),
          label: 'Número do Processo Administrativo',
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _getController('auto_relacionado'),
          label: 'Auto de Infração Relacionado',
        ),
        const SizedBox(height: 12),
        _buildModernDropdown<String>(
          value: _tipoMedida,
          items: const [
            ('Advertência', 'Advertência'),
            ('Multa', 'Multa'),
            ('Interdição', 'Interdição'),
            ('Cancelamento de Licença', 'Cancelamento de Licença'),
          ],
          onChanged: (v) => setState(() => _tipoMedida = v ?? 'Advertência'),
          label: 'Tipo de Penalidade',
        ),
        const SizedBox(height: 12),
        _buildNumericField(_getController('valor'), 'Valor da Multa', maxLength: 10),
        const SizedBox(height: 12),
        _buildNumericField(_getController('prazo_pagto'), 'Prazo para Pagamento (dias)', maxLength: 3),
      ],
    );
  }

  Widget _buildColetaSection() {
    return Column(
      children: [
        _buildModernTextField(
          controller: _getController('produto'),
          label: 'Produto Coletado',
        ),
        const SizedBox(height: 12),
        _buildRow([
          _buildModernTextField(controller: _getController('marca'), label: 'Marca'),
          _buildModernTextField(controller: _getController('lote'), label: 'Lote'),
        ]),
        const SizedBox(height: 12),
        _buildRow([
          _buildModernTextField(controller: _getController('validade'), label: 'Validade'),
          _buildNumericField(_getController('quantidade'), 'Quantidade', maxLength: 5),
        ]),
        const SizedBox(height: 12),
        _buildModernDropdown<String>(
          value: _classificacao,
          items: const [
            ('Microbiológica', 'Microbiológica'),
            ('Físico-química', 'Físico-química'),
            ('Toxicológica', 'Toxicológica'),
          ],
          onChanged: (v) => setState(() => _classificacao = v ?? 'Microbiológica'),
          label: 'Tipo de Análise',
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _getController('laboratorio'),
          label: 'Local de Envio (Laboratório)',
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _getController('condicoes'),
          label: 'Condições da Coleta',
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _getController('lacre'),
          label: 'Lacre da Amostra',
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return _buildModernTextField(
      controller: controller,
      label: label,
      maxLines: maxLines,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    bool isRequired = false,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    int? maxLength,
    Widget? suffixIcon,
    int? minLines,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? [],
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _govBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildCpfField(TextEditingController controller, String label, {bool isRequired = false}) {
    return _buildModernTextField(
      controller: controller,
      label: label,
      isRequired: isRequired,
      keyboardType: TextInputType.number,
      inputFormatters: [_CpfFormatter()],
      hint: '000.000.000-00',
    );
  }

  Widget _buildPhoneField(TextEditingController controller, String label, {bool isRequired = false}) {
    return _buildModernTextField(
      controller: controller,
      label: label,
      isRequired: isRequired,
      keyboardType: TextInputType.phone,
      inputFormatters: [_PhoneFormatter()],
      hint: '(00) 00000-0000',
    );
  }

  Widget _buildNumericField(TextEditingController controller, String label, {bool isRequired = false, int? maxLength}) {
    return _buildModernTextField(
      controller: controller,
      label: label,
      isRequired: isRequired,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: maxLength,
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _EvidenceItem {
  final Uint8List bytes;
  final String descricao;
  const _EvidenceItem({required this.bytes, required this.descricao});
}
