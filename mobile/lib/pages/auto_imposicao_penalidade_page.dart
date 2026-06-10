import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/pdf_generator_service.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/official_form_fields.dart';

class AutoImposicaoPenalidadePage extends StatefulWidget {
  const AutoImposicaoPenalidadePage({super.key});

  @override
  State<AutoImposicaoPenalidadePage> createState() => _AutoImposicaoPenalidadePageState();
}

class _AutoImposicaoPenalidadePageState extends State<AutoImposicaoPenalidadePage> {
  static const _setores = [
    'Departamento de Fiscalização de Alimentos',
    'Departamento de Fiscalização de Serviços de Saúde e de Interesse à Saúde',
    'Centro de Controle de Pragas Urbanas',
    'Programa Municipal de Controle da Dengue',
  ];

  static const _cienciaTexto =
      'ESTOU CIENTE DE QUE PODEREI INTERPOR RECURSO POR ESCRITO NO PRAZO DE 15 (QUINZE) DIAS, A PARTIR DESTA NOTIFICAÇÃO, AO SECRETÁRIO MUNICIPAL DE SAÚDE, NOS TERMOS DO INCISO VI DO ART. 141 DA LEI COMPLEMENTAR Nº 40/19. ESGOTADOS OS PRAZOS LEGAIS, O DÉBITO SERÁ ENCAMINHADO À SECRETARIA DA FAZENDA PARA INSCRIÇÃO EM DÍVIDA ATIVA, COBRANÇA EM INSTITUIÇÃO BANCÁRIA E, SE FOR O CASO, PROTESTO EXTRAJUDICIAL E POSTERIOR PROVOCAÇÃO DO PODER JUDICIÁRIO PARA COBRANÇA COERCITIVA.';

  static const _observacaoTexto =
      'NA PENALIDADE DE MULTA O AUTUADO TEM PRAZO DE 30 (TRINTA) DIAS PARA PAGAMENTO, A CONTAR DESTA NOTIFICAÇÃO, SOB PENA DE COBRANÇA JUDICIAL, NOS TERMOS DO INCISO III DO ART. 142 DA LEI COMPLEMENTAR Nº 40/19. SE O PAGAMENTO DA MULTA FOR EFETUADO EM 10 (DEZ) DIAS CONTADOS DESTA NOTIFICAÇÃO, COM DESISTÊNCIA TÁCITA DO RECURSO, O AUTUADO GOZARÁ DA REDUÇÃO DE 20% (VINTE POR CENTO) NO VALOR DA MULTA, CONFORME O INCISO IV DO ART. 142 DA REFERIDA LEI. O RECOLHIMENTO DA MULTA DEVERÁ SER FEITO, OBRIGATORIAMENTE, ATRAVÉS DE INSTITUIÇÃO BANCÁRIA. O NÃO PAGAMENTO DA MULTA, DEPOIS DE ESGOTADOS OS RECURSOS NO PRAZO LEGAL, IMPEDIRÁ QUE A DIVISÃO DE VIGILÂNCIA SANITÁRIA CONCEDA ALVARÁ DE QUALQUER NATUREZA AO AUTUADO, NOS TERMOS DO INCISO V DO ART. 52 DO DECRETO ESTADUAL Nº 23.663/84.';

  final ApiService _api = ApiService();

  // #region debug-point imposicao-penalidade-blank
  static const String _dbgUrl = String.fromEnvironment('DEBUG_SERVER_URL', defaultValue: '');
  static const String _dbgSessionId = String.fromEnvironment('DEBUG_SESSION_ID', defaultValue: 'imposicao-penalidade-blank');
  final Dio _dbgDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2), receiveTimeout: const Duration(seconds: 2)));
  int _dbgSeq = 0;

  void _dbg(String msg, {String hypothesisId = 'A', String runId = 'pre'}) {
    if (!kIsWeb) return;
    if (_dbgUrl.trim().isEmpty) return;
    if (_dbgSeq > 40) return;
    _dbgSeq += 1;
    unawaited(_dbgDio.post(_dbgUrl, data: {
      'sessionId': _dbgSessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'msg': msg,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'seq': _dbgSeq,
    }).catchError((_) => Response(requestOptions: RequestOptions(path: _dbgUrl))));
  }
  // #endregion debug-point imposicao-penalidade-blank

  int _currentStep = 0;
  bool _saving = false;
  bool _documentoBloqueado = false;
  String _statusDocumento = 'EM_EDICAO';
  int? _docIdOnline;
  bool _possuiPastaVisa = false;

  String? _numeroAuto;
  String _setor = _setores.first;

  final _dadosFormKey = GlobalKey<FormState>();
  final _autuadoFormKey = GlobalKey<FormState>();
  final _enquadramentoFormKey = GlobalKey<FormState>();
  final _autosRelacionadosFormKey = GlobalKey<FormState>();
  final _penalidadeFormKey = GlobalKey<FormState>();
  final _recebimentoFormKey = GlobalKey<FormState>();
  final _revisaoFormKey = GlobalKey<FormState>();

  final _dataLavraturaCtrl = TextEditingController();
  final _telefoneVisaCtrl = TextEditingController();
  final _emailVisaCtrl = TextEditingController();
  final _pasNumeroCtrl = TextEditingController();

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

  final _enquadramentoLegalCtrl = TextEditingController();
  final List<Map<String, dynamic>> _basesLegaisVinculadas = [];

  final _atoFatoCtrl = TextEditingController();

  final _especificacaoPenalidadeCtrl = TextEditingController();
  String _tipoPenalidade = 'Advertência';
  final _ufmCtrl = TextEditingController();
  final _valorMultaCtrl = TextEditingController();
  final _valorExtensoCtrl = TextEditingController();
  String _lastValorExtensoAuto = '';

  final List<Map<String, dynamic>> _autosIntimacaoRelacionados = [];
  final _aiNumeroAnoCtrl = TextEditingController();
  final _aiDataRecebimentoCtrl = TextEditingController();

  bool _loadingAutosRelacionados = false;
  final List<Map<String, dynamic>> _autosInfracaoRelacionados = [];
  final _infNumeroAnoCtrl = TextEditingController();
  final _infDataRecebimentoCtrl = TextEditingController();

  final _comentarioFiscalizacaoCtrl = TextEditingController();

  final _recebimentoDataCtrl = TextEditingController();
  final _recebimentoHoraCtrl = TextEditingController();
  final _recebimentoResponsavelCtrl = TextEditingController();
  Uint8List? _assinaturaRecebimento;

  bool _responsavelRecusouAssinatura = false;
  final _testemunha1RecusaCtrl = TextEditingController();
  final _testemunha2RecusaCtrl = TextEditingController();
  Uint8List? _assinaturaTestemunha1;
  Uint8List? _assinaturaTestemunha2;

  final _autoridadeSaudeCtrl = TextEditingController();
  final _autoridadeFuncaoCtrl = TextEditingController();
  Uint8List? _assinaturaAutoridadeSaude;

  bool _semEfeito = false;
  final _semEfeitoMotivoCtrl = TextEditingController();

  Map<String, dynamic> _dadosEstabelecimento = {};
  String _tipoAtividadeUltimoAuto = '';
  List<Map<String, dynamic>> _cnaesAutuado = [];

  @override
  void initState() {
    super.initState();
    _seedDefaults();
    _pasNumeroCtrl.addListener(_syncTemplatePenalidade);
    _valorMultaCtrl.addListener(_syncValorExtensoFromMulta);
    unawaited(_ensurePasNumero());
    _dbg('initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    _dbg('didChangeDependencies argsType=${rawArgs.runtimeType}');
    final args = rawArgs is Map ? rawArgs.cast<String, dynamic>() : null;
    if (args != null && _dadosEstabelecimento.isEmpty) {
      final rawEstab = args['estabelecimento'];
      final estab = rawEstab is Map ? rawEstab.cast<String, dynamic>() : <String, dynamic>{};
      if (estab.isNotEmpty) {
        _dadosEstabelecimento = estab;
        _prefillFromEstabelecimento(estab);
        unawaited(_hidratarEstabelecimentoDetalheSeNecessario(estab));
      }
      final numero = (args['numero_auto'] ?? '').toString().trim();
      if (numero.isNotEmpty) _numeroAuto = numero;
      final id = args['id'];
      if (id is int) _docIdOnline = id;
    }
    _ensureNumeroAuto();
  }

  @override
  void dispose() {
    _dataLavraturaCtrl.dispose();
    _telefoneVisaCtrl.dispose();
    _emailVisaCtrl.dispose();
    _pasNumeroCtrl.dispose();
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
    _enquadramentoLegalCtrl.dispose();
    _atoFatoCtrl.dispose();
    _especificacaoPenalidadeCtrl.dispose();
    _ufmCtrl.dispose();
    _valorMultaCtrl.dispose();
    _valorExtensoCtrl.dispose();
    _aiNumeroAnoCtrl.dispose();
    _aiDataRecebimentoCtrl.dispose();
    _infNumeroAnoCtrl.dispose();
    _infDataRecebimentoCtrl.dispose();
    _comentarioFiscalizacaoCtrl.dispose();
    _recebimentoDataCtrl.dispose();
    _recebimentoHoraCtrl.dispose();
    _recebimentoResponsavelCtrl.dispose();
    _testemunha1RecusaCtrl.dispose();
    _testemunha2RecusaCtrl.dispose();
    _autoridadeSaudeCtrl.dispose();
    _autoridadeFuncaoCtrl.dispose();
    _semEfeitoMotivoCtrl.dispose();
    super.dispose();
  }

  void _seedDefaults() {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _dataLavraturaCtrl.text = today;
    _recebimentoDataCtrl.text = today;
    _recebimentoHoraCtrl.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (_telefoneVisaCtrl.text.trim().isEmpty) _telefoneVisaCtrl.text = '(47) 3261-6256';
    if (_emailVisaCtrl.text.trim().isEmpty) _emailVisaCtrl.text = 'alimentos.devs@bc.sc.gov.br';
    if (_especificacaoPenalidadeCtrl.text.trim().isEmpty) {
      _especificacaoPenalidadeCtrl.text =
          'Conforme proferido no Processo Administrativo Sanitário nº _____/_____, restou decidida a penalidade de:';
    }
  }

  Future<void> _ensureNumeroAuto() async {
    if (_numeroAuto != null && _numeroAuto!.trim().isNotEmpty) return;
    final ano = DateTime.now().year;
    if (!kIsWeb) {
      final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      setState(() => _numeroAuto = 'PEN-$ano-$seq');
      return;
    }
    try {
      final numero = await _api.proximoNumeroImposicaoPenalidade(ano);
      if (!mounted) return;
      if (numero != null && numero.trim().isNotEmpty) {
        setState(() => _numeroAuto = numero);
        return;
      }
    } catch (_) {}
    final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    if (mounted) setState(() => _numeroAuto = 'PEN-$ano-$seq');
  }

  Future<void> _ensurePasNumero() async {
    if (_pasNumeroCtrl.text.trim().isNotEmpty) return;
    if (_documentoBloqueado) return;
    final ano = DateTime.now().year;

    if (kIsWeb) {
      try {
        final numero = await _api.proximoPasImposicaoPenalidade(ano);
        if (!mounted) return;
        if (numero != null && numero.trim().isNotEmpty) {
          _pasNumeroCtrl.text = numero;
          return;
        }
      } catch (_) {}
    }

    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'autos_sanitarios',
        columns: ['payload_json'],
        where: 'tipo_auto = ? AND payload_json IS NOT NULL',
        whereArgs: ['IMPOSICAO_DE_PENALIDADE'],
        orderBy: 'id DESC',
        limit: 500,
      );
      var maxSeq = 0;
      for (final row in rows) {
        final raw = row['payload_json']?.toString() ?? '';
        if (raw.trim().isEmpty) continue;
        final payload = jsonDecode(raw);
        if (payload is! Map) continue;
        final ip = payload['imposicao_penalidade'];
        if (ip is! Map) continue;
        final pas = (ip['pas_numero'] ?? '').toString().trim();
        final m = RegExp(r'^(\d{4})/(\d{4})$').firstMatch(pas);
        if (m == null) continue;
        final y = int.tryParse(m.group(2) ?? '');
        if (y != ano) continue;
        final s = int.tryParse(m.group(1) ?? '') ?? 0;
        if (s > maxSeq) maxSeq = s;
      }

      if (!mounted) return;
      _pasNumeroCtrl.text = '${(maxSeq + 1).toString().padLeft(4, '0')}/$ano';
      return;
    } catch (_) {}

    if (!mounted) return;
    _pasNumeroCtrl.text = '0001/$ano';
  }

  void _prefillFromEstabelecimento(Map<String, dynamic> estab) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = (estab[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    List<Map<String, dynamic>> extractCnaes() {
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

      void addIfNotExists(List<Map<String, dynamic>> out, {required String codigo, required String descricao, required bool principal}) {
        final c = codigo.trim();
        final d = descricao.trim();
        if (c.isEmpty && d.isEmpty) return;
        final exists = out.any((e) => (e['codigo'] ?? '').toString().trim() == c && (e['descricao'] ?? '').toString().trim() == d);
        if (exists) return;
        out.add({'codigo': c, 'descricao': d, 'principal': principal});
      }

      final out = <Map<String, dynamic>>[];
      final rawList = estab['cnaes'];
      if (rawList is List) {
        for (final e in rawList) {
          if (e is! Map) continue;
          final m = e.cast<String, dynamic>();
          final codigo = pickFrom(m, ['cnae', 'codigo', 'codigo_cnae', 'code']);
          final descricao = pickFrom(m, ['cnaeDescricao', 'descricao', 'cnae_descricao', 'cnae_fiscal_descricao']);
          final principal = pickBoolFrom(m, ['principal', 'is_principal', 'isPrincipal']);
          addIfNotExists(out, codigo: codigo, descricao: descricao, principal: principal);
        }
      }

      final atividadePrincipal = estab['atividade_principal'];
      if (atividadePrincipal is List) {
        for (final e in atividadePrincipal) {
          if (e is! Map) continue;
          final m = e.cast<String, dynamic>();
          final codigo = pickFrom(m, ['code', 'cnae', 'codigo']);
          final descricao = pickFrom(m, ['text', 'descricao', 'cnaeDescricao']);
          addIfNotExists(out, codigo: codigo, descricao: descricao, principal: true);
        }
      }

      final atividadesSec = estab['atividades_secundarias'];
      if (atividadesSec is List) {
        for (final e in atividadesSec) {
          if (e is! Map) continue;
          final m = e.cast<String, dynamic>();
          final codigo = pickFrom(m, ['code', 'cnae', 'codigo']);
          final descricao = pickFrom(m, ['text', 'descricao', 'cnaeDescricao']);
          addIfNotExists(out, codigo: codigo, descricao: descricao, principal: false);
        }
      }

      if (out.isEmpty) {
        final codigo = pick(['cnae', 'cnae_principal', 'cnaePrincipal']);
        final descricao = pick(['cnaeDescricao', 'cnae_descricao', 'cnae_fiscal_descricao', 'cnaeFiscalDescricao']);
        addIfNotExists(out, codigo: codigo, descricao: descricao, principal: true);
      }

      final hasPrincipal = out.any((e) => e['principal'] == true);
      if (!hasPrincipal && out.isNotEmpty) {
        out[0] = {...out[0], 'principal': true};
      }
      return out;
    }

    String formatCnaeItem(Map<String, dynamic> item) {
      final codigo = (item['codigo'] ?? '').toString().trim();
      final descricao = (item['descricao'] ?? '').toString().trim();
      if (codigo.isNotEmpty && descricao.isNotEmpty) return '$codigo - $descricao';
      return descricao.isNotEmpty ? descricao : codigo;
    }

    final nome = pick(['razaoSocial', 'razao_social', 'nome']);
    final fantasia = pick(['nomeFantasia', 'nome_fantasia', 'nome']);
    final cnpj = pick(['cnpj']);
    final endereco = pick(['endereco', 'logradouro']);
    final numero = pick(['numero']);
    final bairro = pick(['bairro']);
    final pasta = pick(['numero_pasta_visa', 'alvara_pasta_visa', 'alvara_sanitario', 'pasta_visa']);
    final cnaes = extractCnaes();
    _cnaesAutuado = cnaes;
    final cnaePrincipal = cnaes.isEmpty ? null : cnaes.firstWhere((e) => e['principal'] == true, orElse: () => cnaes.first);
    final atividade = cnaePrincipal == null ? '' : formatCnaeItem(cnaePrincipal);

    if (_autuadoNomeCtrl.text.trim().isEmpty) _autuadoNomeCtrl.text = nome;
    if (_autuadoNomeFantasiaCtrl.text.trim().isEmpty) _autuadoNomeFantasiaCtrl.text = fantasia;
    if (_autuadoCpfCnpjCtrl.text.trim().isEmpty) _autuadoCpfCnpjCtrl.text = cnpj;
    if (_autuadoEnderecoCompletoCtrl.text.trim().isEmpty) _autuadoEnderecoCompletoCtrl.text = endereco;
    if (_autuadoNumeroCtrl.text.trim().isEmpty) _autuadoNumeroCtrl.text = numero;
    if (_autuadoBairroCtrl.text.trim().isEmpty) _autuadoBairroCtrl.text = bairro;
    if (_autuadoAlvaraCtrl.text.trim().isEmpty) _autuadoAlvaraCtrl.text = pasta;
    {
      final cur = _autuadoTipoAtividadeCtrl.text.trim();
      if (atividade.isNotEmpty && (cur.isEmpty || cur == _tipoAtividadeUltimoAuto)) {
        _autuadoTipoAtividadeCtrl.text = atividade;
        _tipoAtividadeUltimoAuto = atividade;
      }
    }
    if (!_possuiPastaVisa && pasta.isNotEmpty) _possuiPastaVisa = true;
    unawaited(_autoLoadAutosRelacionadosFromCnpj());
  }

  Future<void> _hidratarEstabelecimentoDetalheSeNecessario(Map<String, dynamic> raw) async {
    if (ApiService.mockMode) return;
    if (_cnaesAutuado.isNotEmpty && _autuadoTipoAtividadeCtrl.text.trim().isNotEmpty) return;
    final digits = _onlyDigits((raw['cnpj'] ?? '').toString());
    if (digits.length != 14) return;
    final detail = await _api.buscarEstabelecimentoDetalhe(digits);
    if (!mounted || detail == null) return;
    setState(() {
      _dadosEstabelecimento = Map<String, dynamic>.from(detail);
      _prefillFromEstabelecimento(_dadosEstabelecimento);
    });
  }

  Future<void> _selecionarCnaeAutuado() async {
    if (_documentoBloqueado) return;
    if (_cnaesAutuado.isEmpty) return;
    String formatCnaeItem(Map<String, dynamic> item) {
      final codigo = (item['codigo'] ?? '').toString().trim();
      final descricao = (item['descricao'] ?? '').toString().trim();
      if (codigo.isNotEmpty && descricao.isNotEmpty) return '$codigo - $descricao';
      return descricao.isNotEmpty ? descricao : codigo;
    }

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
              final label = formatCnaeItem(it);
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
    final text = formatCnaeItem(selected);
    if (text.trim().isEmpty) return;
    _autuadoTipoAtividadeCtrl.text = text;
    _tipoAtividadeUltimoAuto = text;
  }

  void _syncTemplatePenalidade() {
    final pas = _pasNumeroCtrl.text.trim();
    if (pas.isEmpty) return;
    final templatePrefix = 'Conforme proferido no Processo Administrativo Sanitário nº ';
    final cur = _especificacaoPenalidadeCtrl.text;
    if (!cur.startsWith(templatePrefix)) return;
    final next = 'Conforme proferido no Processo Administrativo Sanitário nº $pas, restou decidida a penalidade de:';
    if (cur.trim() == next.trim()) return;
    _especificacaoPenalidadeCtrl.text = next;
  }

  void _syncValorExtensoFromMulta() {
    if (_documentoBloqueado) return;
    if (_tipoPenalidade != 'Multa') return;
    final value = _parseMoneyPtBr(_valorMultaCtrl.text);
    if (value == null) return;
    final next = _moneyToWordsPtBr(value);
    if (next.trim().isEmpty) return;
    final cur = _valorExtensoCtrl.text.trim();
    if (cur.isNotEmpty && cur != _lastValorExtensoAuto) return;
    if (cur == next) return;
    _lastValorExtensoAuto = next;
    _valorExtensoCtrl.text = next;
  }

  double? _parseMoneyPtBr(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll('R\$', '').trim();
    s = s.replaceAll('.', '');
    s = s.replaceAll(',', '.');
    return double.tryParse(s);
  }

  String _moneyToWordsPtBr(double value) {
    final cents = ((value - value.floorToDouble()) * 100).round();
    final reais = value.floor();
    final parts = <String>[];
    final reaisWords = _numberToWordsPtBr(reais);
    if (reais == 0) {
      parts.add('Zero Reais');
    } else {
      parts.add('${_titleWords(reaisWords)} ${reais == 1 ? 'Real' : 'Reais'}');
    }
    if (cents > 0) {
      final centsWords = _numberToWordsPtBr(cents);
      parts.add('E ${_titleWords(centsWords)} ${cents == 1 ? 'Centavo' : 'Centavos'}');
    }
    return parts.join(' ');
  }

  String _titleWords(String s) {
    final words = s.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();
    return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  String _numberToWordsPtBr(int n) {
    if (n == 0) return 'zero';
    if (n < 0) return 'menos ${_numberToWordsPtBr(-n)}';

    const units = [
      '',
      'um',
      'dois',
      'três',
      'quatro',
      'cinco',
      'seis',
      'sete',
      'oito',
      'nove',
      'dez',
      'onze',
      'doze',
      'treze',
      'quatorze',
      'quinze',
      'dezesseis',
      'dezessete',
      'dezoito',
      'dezenove',
    ];
    const tens = [
      '',
      '',
      'vinte',
      'trinta',
      'quarenta',
      'cinquenta',
      'sessenta',
      'setenta',
      'oitenta',
      'noventa',
    ];
    const hundreds = [
      '',
      'cento',
      'duzentos',
      'trezentos',
      'quatrocentos',
      'quinhentos',
      'seiscentos',
      'setecentos',
      'oitocentos',
      'novecentos',
    ];

    String joinParts(List<String> p) => p.where((e) => e.trim().isNotEmpty).join(' e ');

    String below1000(int x) {
      if (x == 0) return '';
      if (x < 20) return units[x];
      if (x < 100) {
        final t = x ~/ 10;
        final r = x % 10;
        if (r == 0) return tens[t];
        return joinParts([tens[t], units[r]]);
      }
      if (x == 100) return 'cem';
      final h = x ~/ 100;
      final r = x % 100;
      if (r == 0) return hundreds[h];
      return joinParts([hundreds[h], below1000(r)]);
    }

    String group(int x, String singular, String plural) {
      if (x == 0) return '';
      if (x == 1) return singular;
      return '$plural';
    }

    final millions = n ~/ 1000000;
    final thousands = (n % 1000000) ~/ 1000;
    final rest = n % 1000;

    final out = <String>[];
    if (millions > 0) {
      final prefix = below1000(millions);
      out.add('${prefix} ${group(millions, 'milhão', 'milhões')}');
    }
    if (thousands > 0) {
      if (thousands == 1) {
        out.add('mil');
      } else {
        out.add('${below1000(thousands)} mil');
      }
    }
    if (rest > 0) {
      out.add(below1000(rest));
    }

    return out.join(' e ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _docNumeroAno(Map<String, dynamic> doc) {
    return (doc['numero_ano'] ?? doc['numero_auto'] ?? doc['numero'] ?? '').toString().trim();
  }

  String _docRecebimentoDataBr(Map<String, dynamic> doc, String tipo) {
    final payload = (doc['payload'] is Map) ? (doc['payload'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final section = (payload[tipo] is Map) ? (payload[tipo] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final receb = (section['recebimento'] is Map) ? (section['recebimento'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final data = (receb['data'] ?? '').toString().trim();
    if (data.isNotEmpty) return data;
    final raw = (doc['data_documento'] ?? doc['created_at'] ?? '').toString().trim();
    return raw;
  }

  Future<void> _autoLoadAutosRelacionadosFromCnpj() async {
    final cnpj = _onlyDigits(_autuadoCpfCnpjCtrl.text);
    if (cnpj.length != 14) return;
    if (_loadingAutosRelacionados) return;
    if (_autosIntimacaoRelacionados.isNotEmpty || _autosInfracaoRelacionados.isNotEmpty) return;

    setState(() => _loadingAutosRelacionados = true);
    try {
      List<Map<String, dynamic>> intimacoes = [];
      List<Map<String, dynamic>> infracoes = [];
      if (kIsWeb) {
        final rawAi = await _api.listarAutoIntimacaoDocumentos(cnpj: cnpj, status: 'TODOS');
        final rawInf = await _api.listarAutoInfracaoDocumentos(cnpj: cnpj, status: 'TODOS');
        intimacoes = rawAi.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        infracoes = rawInf.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        final raw = await LocalDb.listarAutosTermosLocal();
        intimacoes = raw.where((e) => (e['tipo_documento'] ?? '').toString() == 'AUTO_INTIMACAO' && (e['estabelecimento_cnpj'] ?? '').toString() == cnpj).toList();
        infracoes = raw.where((e) => (e['tipo_documento'] ?? '').toString() == 'AUTO_INFRACAO' && (e['estabelecimento_cnpj'] ?? '').toString() == cnpj).toList();
      }

      if (!mounted) return;
      setState(() {
        for (final doc in intimacoes) {
          final numero = _docNumeroAno(doc);
          if (numero.isEmpty) continue;
          if (_autosIntimacaoRelacionados.any((e) => (e['numero_ano'] ?? '').toString().trim() == numero)) continue;
          _autosIntimacaoRelacionados.add({
            'numero_ano': numero,
            'data_recebimento': _docRecebimentoDataBr(doc, 'auto_intimacao'),
          });
        }
        for (final doc in infracoes) {
          final numero = _docNumeroAno(doc);
          if (numero.isEmpty) continue;
          if (_autosInfracaoRelacionados.any((e) => (e['numero_ano'] ?? '').toString().trim() == numero)) continue;
          _autosInfracaoRelacionados.add({
            'numero_ano': numero,
            'data_recebimento': _docRecebimentoDataBr(doc, 'auto_infracao'),
          });
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAutosRelacionados = false);
    }
  }

  String _onlyDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

  String? _pasValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    final v = value.trim();
    final m = RegExp(r'^(\d{4})/(\d{4})$').firstMatch(v);
    if (m == null) return 'Informe no formato 0001/2026';
    if ((m.group(2) ?? '').length != 4) return 'Ano inválido';
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    final v = value.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'E-mail inválido';
  }

  String? _minCharsValidator(String? value, int min) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    if (value.trim().length < min) return 'Mínimo de $min caracteres';
    return null;
  }

  Future<void> _pickAssinatura(ValueChanged<Uint8List?> onSelected) async {
    final bytes = await Navigator.pushNamed(context, '/assinatura');
    if (!mounted) return;
    if (bytes is Uint8List) onSelected(bytes);
  }

  bool _validateStep(int index) {
    GlobalKey<FormState>? key;
    switch (index) {
      case 0:
        key = _dadosFormKey;
        break;
      case 1:
        key = _autuadoFormKey;
        break;
      case 2:
        key = _enquadramentoFormKey;
        break;
      case 3:
        key = _autosRelacionadosFormKey;
        break;
      case 4:
        key = _penalidadeFormKey;
        break;
      case 5:
        key = _recebimentoFormKey;
        break;
      case 6:
        key = _revisaoFormKey;
        break;
      default:
        return true;
    }
    final form = key.currentState;
    if (form == null) return true;
    return form.validate();
  }

  Map<String, dynamic> _buildPayload() {
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
      'possui_pasta_visa': _possuiPastaVisa,
      'numero_pasta_visa': _possuiPastaVisa ? _autuadoAlvaraCtrl.text.trim() : '',
      'alvara_pasta_visa': _possuiPastaVisa ? _autuadoAlvaraCtrl.text.trim() : '',
    };

    final baseLegal = <String, dynamic>{
      'enquadramento_legal': _enquadramentoLegalCtrl.text.trim(),
      'bases_legais_vinculadas': _basesLegaisVinculadas,
    };

    final penalidade = <String, dynamic>{
      'texto': _especificacaoPenalidadeCtrl.text.trim(),
      'tipo': _tipoPenalidade,
      'ufm': _ufmCtrl.text.trim(),
      'valor': _valorMultaCtrl.text.trim(),
      'valor_extenso': _valorExtensoCtrl.text.trim(),
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

    final autoridade = <String, dynamic>{
      'nome': _autoridadeSaudeCtrl.text.trim(),
      'funcao': _autoridadeFuncaoCtrl.text.trim(),
      'assinatura_base64': _assinaturaAutoridadeSaude == null ? null : base64Encode(_assinaturaAutoridadeSaude!),
    };

    final autosInfracao = <Map<String, dynamic>>[
      ..._autosInfracaoRelacionados.map((e) => Map<String, dynamic>.from(e)),
    ];
    final infNumeroTmp = _infNumeroAnoCtrl.text.trim();
    final infDataTmp = _infDataRecebimentoCtrl.text.trim();
    if (autosInfracao.isEmpty && (infNumeroTmp.isNotEmpty || infDataTmp.isNotEmpty)) {
      autosInfracao.add({'numero_ano': infNumeroTmp, 'data_recebimento': infDataTmp});
    }

    final ip = <String, dynamic>{
      'numero_auto': (_numeroAuto ?? '').trim(),
      'data_lavratura': _dataLavraturaCtrl.text.trim(),
      'setor_vigilancia': _setor,
      'telefone_visa': _telefoneVisaCtrl.text.trim(),
      'email_visa': _emailVisaCtrl.text.trim(),
      'pas_numero': _pasNumeroCtrl.text.trim(),
      'autos_intimacao_relacionados': _autosIntimacaoRelacionados,
      'autos_infracao_relacionados': autosInfracao,
      'auto_infracao_relacionado': autosInfracao.isEmpty ? {'numero_ano': '', 'data_recebimento': ''} : autosInfracao.first,
      'autuado': autuado,
      'base_legal': baseLegal,
      'ato_ou_fato': _atoFatoCtrl.text.trim(),
      'penalidade': penalidade,
      'comentario_fiscalizacao': _comentarioFiscalizacaoCtrl.text.trim(),
      'ciencia_texto': _cienciaTexto,
      'observacao_texto': _observacaoTexto,
      'recebimento': recebimento,
      'recusa': recusa,
      'autoridade_saude': autoridade,
      'sem_efeito': _semEfeito,
      'sem_efeito_motivo': _semEfeitoMotivoCtrl.text.trim(),
    };

    final payload = <String, dynamic>{
      'ano': DateTime.now().year.toString(),
      'data_hora': DateTime.now().toIso8601String(),
      'tipo_documento': 'IMPOSICAO_DE_PENALIDADE',
      'status': _statusDocumento,
      'status_documento': _statusDocumento,
      'dados_estabelecimento': _dadosEstabelecimento,
      'imposicao_penalidade': ip,
      'bases_legais_vinculadas': _basesLegaisVinculadas,
    };

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

  Future<void> _abrirRelatorioInspecao(Map<String, dynamic> payload) async {
    final estab = _dadosEstabelecimento.isEmpty ? null : Map<String, dynamic>.from(_dadosEstabelecimento);
    await Navigator.pushNamed(
      context,
      '/relatorio-inspecao-sanitario',
      arguments: {
        if (estab != null) 'estabelecimento': estab,
        'documento_vinculado': {
          'tipo_documento': payload['tipo_documento'],
          'numero_ano': payload['numero_ano'] ?? payload['numero_auto'] ?? payload['numero'] ?? '',
          'payload': payload,
        },
      },
    );
  }

  Future<void> _salvar({required String statusDocumento}) async {
    final invalid = _firstInvalidStep();
    if (invalid != null) {
      setState(() => _currentStep = invalid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revise os campos obrigatórios antes de salvar.')));
      return;
    }
    if (statusDocumento == 'FINALIZADO') {
      if (!_responsavelRecusouAssinatura && _assinaturaRecebimento == null) {
        setState(() => _currentStep = 5);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinatura do recebimento é obrigatória.')));
        return;
      }
      if (_assinaturaAutoridadeSaude == null) {
        setState(() => _currentStep = 5);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinatura da Autoridade de Saúde é obrigatória.')));
        return;
      }
      if (_responsavelRecusouAssinatura && (_assinaturaTestemunha1 == null || _assinaturaTestemunha2 == null)) {
        setState(() => _currentStep = 5);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinaturas das testemunhas são obrigatórias em caso de recusa.')));
        return;
      }
    }
    if (statusDocumento == 'SEM_EFEITO' && _semEfeitoMotivoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a justificativa para "Não Emitido / Sem Efeito".')));
      return;
    }

    setState(() {
      _saving = true;
      _statusDocumento = statusDocumento;
    });
    final payload = _buildPayload();
    try {
      if (kIsWeb) {
        final ano = int.tryParse(payload['ano']?.toString() ?? '') ?? DateTime.now().year;
        Map<String, dynamic> saved;
        if (_docIdOnline == null) {
          saved = await _api.salvarImposicaoPenalidade(
            ano: ano,
            status: statusDocumento,
            dados: payload,
            dispositivo: 'Flutter Web',
          );
          final id = int.tryParse((saved['id'] ?? '').toString());
          if (id != null) _docIdOnline = id;
        } else {
          saved = await _api.atualizarImposicaoPenalidade(
            id: _docIdOnline!,
            status: statusDocumento,
            dados: payload,
            dispositivo: 'Flutter Web',
          );
        }
        final numero = (saved['numero'] ?? '').toString().trim();
        if (numero.isNotEmpty) {
          _numeroAuto = numero;
          payload['numero_ano'] = numero;
          final ip = payload['imposicao_penalidade'];
          if (ip is Map) {
            final updated = Map<String, dynamic>.from(ip);
            updated['numero_auto'] = numero;
            payload['imposicao_penalidade'] = updated;
          }
        }
        if (!mounted) return;
        if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
          setState(() => _documentoBloqueado = true);
          final abrir = await _perguntarAbrirRelatorioInspecao();
          if (!mounted) return;
          if (abrir) {
            await _abrirRelatorioInspecao(payload);
            if (!mounted) return;
          }
          Navigator.of(context).maybePop(true);
        }
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
        return;
      }

      final db = await LocalDb.instance;
      final imposicaoPenalidadeJson = jsonEncode(payload['imposicao_penalidade']);
      final insertedId = await db.insert('autos_sanitarios', {
        'tipo_auto': 'IMPOSICAO_DE_PENALIDADE',
        'numero_auto': (_numeroAuto ?? '').trim(),
        'numero_ano': (_numeroAuto ?? '').trim(),
        'estabelecimento_id': 0,
        'fiscal_id': 0,
        'data': DateTime.now().toIso8601String().substring(0, 10),
        'data_hora': payload['data_hora'],
        'descricao': _especificacaoPenalidadeCtrl.text.trim(),
        'fundamentacao_legal': _enquadramentoLegalCtrl.text.trim(),
        'observacoes': _comentarioFiscalizacaoCtrl.text.trim(),
        'status': statusDocumento,
        'ano': payload['ano'],
        'tipo_documento': payload['tipo_documento'],
        'dados_estabelecimento': jsonEncode(payload['dados_estabelecimento']),
        'imposicao_penalidade_json': imposicaoPenalidadeJson,
        'payload_json': jsonEncode(payload),
        'data_documento': DateTime.now().toIso8601String().substring(0, 10),
        'estabelecimento_nome': _autuadoNomeFantasiaCtrl.text.trim(),
        'estabelecimento_cnpj': _onlyDigits(_autuadoCpfCnpjCtrl.text),
        'status_sincronizacao': 'PENDENTE_SINCRONIZACAO',
      });

      if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
        final pdfBytes = await PdfGeneratorService().gerarImposicaoPenalidadePdf(payload);
        await LocalDb.atualizarAutoSanitario(insertedId, {'pdf_local': base64Encode(pdfBytes)});
        setState(() => _documentoBloqueado = true);
        if (!mounted) return;
        final abrir = await _perguntarAbrirRelatorioInspecao();
        if (!mounted) return;
        if (abrir) {
          await _abrirRelatorioInspecao(payload);
          if (!mounted) return;
        }
        Navigator.of(context).maybePop(true);
      }

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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _validateAll() {
    final keys = [
      _dadosFormKey,
      _autuadoFormKey,
      _enquadramentoFormKey,
      _autosRelacionadosFormKey,
      _penalidadeFormKey,
      _recebimentoFormKey,
    ];
    for (final k in keys) {
      final form = k.currentState;
      if (form != null && !form.validate()) return false;
    }
    return true;
  }

  int? _firstInvalidStep() {
    final items = <({int step, GlobalKey<FormState> key})>[
      (step: 0, key: _dadosFormKey),
      (step: 1, key: _autuadoFormKey),
      (step: 2, key: _enquadramentoFormKey),
      (step: 3, key: _autosRelacionadosFormKey),
      (step: 4, key: _penalidadeFormKey),
      (step: 5, key: _recebimentoFormKey),
      (step: 6, key: _revisaoFormKey),
    ];
    for (final it in items) {
      final form = it.key.currentState;
      if (form != null && !form.validate()) return it.step;
    }
    return null;
  }

  Future<void> _addBaseLegal() async {
    final result = await Navigator.pushNamed(context, '/base-legal', arguments: {'selectionMode': true});
    if (!mounted || result == null) return;
    if (result is Map) {
      final map = Map<String, dynamic>.from(result);
      final id = (map['id'] ?? '').toString().trim();
      if (id.isEmpty) return;
      if (_basesLegaisVinculadas.any((e) => (e['id'] ?? '').toString().trim() == id)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base legal já adicionada.')));
        return;
      }
      setState(() => _basesLegaisVinculadas.add(map));
      final texto = _formatBasesLegais(_basesLegaisVinculadas);
      if (_enquadramentoLegalCtrl.text.trim().isEmpty) {
        _enquadramentoLegalCtrl.text = texto;
      }
    }
  }

  String _formatBasesLegais(List<Map<String, dynamic>> list) {
    String item(Map<String, dynamic> v) {
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

    return list.map((e) => '• ${item(e)}').join('\n');
  }

  void _addAutoIntimacaoRelacionado() {
    final numero = _aiNumeroAnoCtrl.text.trim();
    final data = _aiDataRecebimentoCtrl.text.trim();
    if (numero.isEmpty && data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é permitido adicionar item vazio.')));
      return;
    }
    if (numero.isEmpty || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe Número/Ano e Data de recebimento.')));
      return;
    }
    if (_autosIntimacaoRelacionados.any((e) => (e['numero_ano'] ?? '').toString().trim() == numero)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto de Intimação já adicionado.')));
      return;
    }
    setState(() {
      _autosIntimacaoRelacionados.add({'numero_ano': numero, 'data_recebimento': data});
      _aiNumeroAnoCtrl.clear();
      _aiDataRecebimentoCtrl.clear();
    });
  }

  void _removeAutoIntimacaoRelacionado(int index) {
    setState(() => _autosIntimacaoRelacionados.removeAt(index));
  }

  void _addAutoInfracaoRelacionado() {
    final numero = _infNumeroAnoCtrl.text.trim();
    final data = _infDataRecebimentoCtrl.text.trim();
    if (numero.isEmpty && data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é permitido adicionar item vazio.')));
      return;
    }
    if (numero.isEmpty || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe Número/Ano e Data de recebimento.')));
      return;
    }
    if (_autosInfracaoRelacionados.any((e) => (e['numero_ano'] ?? '').toString().trim() == numero)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto de Infração já adicionado.')));
      return;
    }
    setState(() {
      _autosInfracaoRelacionados.add({'numero_ano': numero, 'data_recebimento': data});
      _infNumeroAnoCtrl.clear();
      _infDataRecebimentoCtrl.clear();
    });
  }

  void _removeAutoInfracaoRelacionado(int index) {
    setState(() => _autosInfracaoRelacionados.removeAt(index));
  }

  List<Step> _buildSteps() {
    final steps = <Step>[
      Step(
        title: const Text('Dados'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _dadosFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(),
              const SizedBox(height: 12),
              OfficialDropdownField.fromStrings(
                value: _setor,
                items: _setores,
                onChanged: _documentoBloqueado
                    ? null
                    : (v) => setState(() => _setor = v ?? _setores.first),
                label: 'Nome do setor da Vigilância Sanitária',
                required: true,
              ),
              const SizedBox(height: 12),
              OfficialDateField(
                controller: _dataLavraturaCtrl,
                label: 'Data da lavratura do Auto de Imposição de Penalidade',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialPhoneField(
                controller: _telefoneVisaCtrl,
                label: 'Telefone da VISA',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _emailVisaCtrl,
                label: 'E-mail da VISA',
                required: true,
                enabled: !_documentoBloqueado,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _pasNumeroCtrl,
                label: 'Número do Processo Administrativo Sanitário (PAS) / Ano:',
                required: true,
                enabled: !_documentoBloqueado,
                hint: '0001/2026',
                validator: _pasValidator,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Possui Pasta VISA?'),
                value: _possuiPastaVisa,
                onChanged: _documentoBloqueado
                    ? null
                    : (v) {
                        setState(() {
                          _possuiPastaVisa = v;
                          if (!v) _autuadoAlvaraCtrl.clear();
                        });
                        _dadosFormKey.currentState?.validate();
                      },
                contentPadding: EdgeInsets.zero,
              ),
              if (_possuiPastaVisa) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _autuadoAlvaraCtrl,
                  label: 'Número da Pasta VISA',
                  required: true,
                  enabled: !_documentoBloqueado,
                  validator: (v) {
                    if (!_possuiPastaVisa) return null;
                    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Autuado'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _autuadoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OfficialTextField(
                controller: _autuadoNomeCtrl,
                label: 'Nome da Pessoa Física/Jurídica',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoCpfCnpjCtrl,
                label: 'CNPJ/CPF',
                required: true,
                enabled: !_documentoBloqueado,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final digits = _onlyDigits(v);
                  if (digits.length == 14) unawaited(_autoLoadAutosRelacionadosFromCnpj());
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                  final digits = _onlyDigits(v);
                  if (digits.length != 11 && digits.length != 14) return 'Informe CPF ou CNPJ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _documentoBloqueado
                    ? null
                    : () async {
                        final digits = _onlyDigits(_autuadoCpfCnpjCtrl.text);
                        if (digits.length != 14) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um CNPJ válido para buscar na e-Pública.')));
                          return;
                        }
                        try {
                          final estab = await _api.buscarEstabelecimentoPorCnpj(digits);
                          if (!mounted || estab == null) return;
                          setState(() {
                            _dadosEstabelecimento = estab;
                            _prefillFromEstabelecimento(estab);
                          });
                        } catch (_) {}
                      },
                icon: const Icon(Icons.search),
                label: const Text('Buscar dados pela e-Pública (CNPJ)'),
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoNomeFantasiaCtrl,
                label: 'Denominação Comercial / Nome Fantasia',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoEnderecoCompletoCtrl,
                label: 'Endereço Completo',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoNumeroCtrl,
                label: 'Número',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoBairroCtrl,
                label: 'Bairro',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _autuadoMunicipioCtrl,
                      label: 'Município',
                      required: true,
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: OfficialTextField(
                      controller: _autuadoUfCtrl,
                      label: 'UF',
                      required: true,
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoProprietarioCtrl,
                label: 'Proprietário e/ou Responsável',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _autuadoTipoAtividadeCtrl,
                label: 'Tipo de Estabelecimento / Negócio / Atividade',
                required: true,
                enabled: !_documentoBloqueado,
                helperText: _cnaesAutuado.isEmpty ? null : 'Preenchido pelo CNAE do CNPJ. Você pode selecionar outro CNAE.',
                suffixIcon: _documentoBloqueado || _cnaesAutuado.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _selecionarCnaeAutuado,
                        icon: const Icon(Icons.search_outlined),
                        tooltip: 'Selecionar CNAE',
                      ),
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Enquadramento'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _enquadramentoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Enquadramento Legal (Legislação sanitária infringida que autoriza a medida):',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _documentoBloqueado ? null : _addBaseLegal,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar Base Legal (SINNC Saúde)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _enquadramentoLegalCtrl,
                label: 'Enquadramento legal',
                required: true,
                enabled: !_documentoBloqueado,
                multiline: true,
                validator: (v) => _minCharsValidator(v, 5),
              ),
              if (_basesLegaisVinculadas.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._basesLegaisVinculadas.asMap().entries.map((e) {
                  final idx = e.key;
                  final v = e.value;
                  final titulo = [
                    (v['tipo'] ?? '').toString().trim(),
                    [v['numero'] ?? '', v['ano'] ?? ''].where((x) => x.toString().trim().isNotEmpty).join('/'),
                    (v['esfera'] ?? '').toString().trim().isEmpty ? '' : '(${v['esfera']})',
                  ].where((x) => x.toString().trim().isNotEmpty).join(' ').trim();
                  final artigo = [
                    if ((v['artigo'] ?? '').toString().trim().isNotEmpty) 'Art. ${v['artigo']}',
                    if ((v['inciso'] ?? '').toString().trim().isNotEmpty) 'Inciso ${v['inciso']}',
                    if ((v['paragrafo'] ?? '').toString().trim().isNotEmpty) '§ ${v['paragrafo']}',
                  ].join(' ').trim();
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: artigo.isEmpty ? null : Text(artigo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _documentoBloqueado
                            ? null
                            : () {
                                setState(() => _basesLegaisVinculadas.removeAt(idx));
                              },
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _atoFatoCtrl,
                label: 'Ato ou Fato Constitutivo da Infração Cometida:',
                required: true,
                enabled: !_documentoBloqueado,
                multiline: true,
                validator: (v) => _minCharsValidator(v, 20),
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Autos'),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _autosRelacionadosFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Auto de Intimação', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _documentoBloqueado || _loadingAutosRelacionados ? null : _autoLoadAutosRelacionadosFromCnpj,
                      icon: _loadingAutosRelacionados ? const Icon(Icons.hourglass_top) : const Icon(Icons.refresh),
                      label: const Text('Carregar autos do CNPJ'),
                    ),
                  ),
                ],
              ),
              if (_loadingAutosRelacionados) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _aiNumeroAnoCtrl,
                      label: 'Número/Ano do Auto de Intimação',
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: OfficialDateField(
                      controller: _aiDataRecebimentoCtrl,
                      label: 'Data de recebimento',
                      enabled: !_documentoBloqueado,
                      autoFillNow: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _documentoBloqueado ? null : _addAutoIntimacaoRelacionado,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
              if (_autosIntimacaoRelacionados.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._autosIntimacaoRelacionados.asMap().entries.map((e) {
                  final i = e.key;
                  final v = e.value;
                  return ListTile(
                    title: Text((v['numero_ano'] ?? '').toString()),
                    subtitle: Text('Recebido em: ${(v['data_recebimento'] ?? '').toString()}'),
                    trailing: IconButton(
                      onPressed: _documentoBloqueado ? null : () => _removeAutoIntimacaoRelacionado(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                }),
              ],
              const Divider(height: 24),
              const Text('Auto de Infração', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _infNumeroAnoCtrl,
                      label: 'Número/Ano do Auto de Infração',
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: OfficialDateField(
                      controller: _infDataRecebimentoCtrl,
                      label: 'Data de recebimento',
                      enabled: !_documentoBloqueado,
                      autoFillNow: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _documentoBloqueado ? null : _addAutoInfracaoRelacionado,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
              if (_autosInfracaoRelacionados.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._autosInfracaoRelacionados.asMap().entries.map((e) {
                  final i = e.key;
                  final v = e.value;
                  return ListTile(
                    title: Text((v['numero_ano'] ?? '').toString()),
                    subtitle: Text('Recebido em: ${(v['data_recebimento'] ?? '').toString()}'),
                    trailing: IconButton(
                      onPressed: _documentoBloqueado ? null : () => _removeAutoInfracaoRelacionado(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 8),
              FormField<bool>(
                validator: (_) {
                  final n = _infNumeroAnoCtrl.text.trim();
                  final d = _infDataRecebimentoCtrl.text.trim();
                  if (n.isEmpty && d.isEmpty) return null;
                  if (n.isEmpty || d.isEmpty) return 'Informe Número/Ano e Data de recebimento do Auto de Infração.';
                  return null;
                },
                builder: (state) {
                  if (state.errorText == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Penalidade'),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _penalidadeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OfficialTextField(
                controller: _especificacaoPenalidadeCtrl,
                label: 'Especificação Detalhada da Penalidade Imposta:',
                required: true,
                enabled: !_documentoBloqueado,
                multiline: true,
                validator: (v) => _minCharsValidator(v, 10),
              ),
              const SizedBox(height: 12),
              OfficialDropdownField.fromStrings(
                value: _tipoPenalidade,
                items: const ['Advertência', 'Multa'],
                onChanged: _documentoBloqueado
                    ? null
                    : (v) {
                        setState(() => _tipoPenalidade = v ?? 'Advertência');
                        _syncValorExtensoFromMulta();
                      },
                label: 'Tipo de penalidade',
                required: true,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _ufmCtrl,
                label: 'Quantidade de UFM',
                enabled: !_documentoBloqueado,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              OfficialMoneyField(
                controller: _valorMultaCtrl,
                label: 'Valor da multa',
                enabled: !_documentoBloqueado,
                required: _tipoPenalidade == 'Multa',
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _valorExtensoCtrl,
                label: 'Valor por extenso',
                enabled: !_documentoBloqueado,
                required: _tipoPenalidade == 'Multa',
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _comentarioFiscalizacaoCtrl,
                label: 'Comentário sobre a Fiscalização:',
                enabled: !_documentoBloqueado,
                multiline: true,
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: const Color(0xFFFFF3CD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFFC107)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFF664D03)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _cienciaTexto,
                          style: TextStyle(color: Color(0xFF664D03), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: const Color(0xFFE7F1FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF0D6EFD)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('OBSERVAÇÃO:', style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 8),
                      Text(_observacaoTexto),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Recebimento'),
        isActive: _currentStep >= 5,
        state: _currentStep > 5 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _recebimentoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Recebimento', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialDateField(
                      controller: _recebimentoDataCtrl,
                      label: 'Data de recebimento',
                      required: true,
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: OfficialTextField(
                      controller: _recebimentoHoraCtrl,
                      label: 'Horário',
                      required: true,
                      enabled: !_documentoBloqueado,
                      hint: 'HH:mm',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _recebimentoResponsavelCtrl,
                label: 'Responsável',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              if (!_responsavelRecusouAssinatura)
                OfficialSignatureField(
                  label: 'Assinatura digital',
                  required: true,
                  enabled: !_documentoBloqueado,
                  value: _assinaturaRecebimento,
                  onPick: () {
                    _pickAssinatura((b) => setState(() => _assinaturaRecebimento = b));
                  },
                  onClear: () => setState(() => _assinaturaRecebimento = null),
                )
              else
                Card(
                  elevation: 0,
                  color: const Color(0xFFE7F1FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF0D6EFD)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Assinatura do responsável dispensada por recusa.'),
                  ),
                ),
              FormField<bool>(
                validator: (_) {
                  if (_responsavelRecusouAssinatura) return null;
                  if (_assinaturaRecebimento == null) return 'Assinatura do recebimento é obrigatória.';
                  return null;
                },
                builder: (state) {
                  if (state.errorText == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                  );
                },
              ),
              const Divider(height: 28),
              SwitchListTile(
                value: _responsavelRecusouAssinatura,
                onChanged: _documentoBloqueado
                    ? null
                    : (v) {
                        setState(() {
                          _responsavelRecusouAssinatura = v;
                          if (v) {
                            _assinaturaRecebimento = null;
                          } else {
                            _testemunha1RecusaCtrl.clear();
                            _testemunha2RecusaCtrl.clear();
                            _assinaturaTestemunha1 = null;
                            _assinaturaTestemunha2 = null;
                          }
                        });
                      },
                title: const Text('Responsável recusou assinar'),
              ),
              if (_responsavelRecusouAssinatura) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _testemunha1RecusaCtrl,
                  label: '1ª Testemunha',
                  required: true,
                  enabled: !_documentoBloqueado,
                ),
                const SizedBox(height: 12),
                OfficialSignatureField(
                  label: 'Assinatura da 1ª Testemunha',
                  required: true,
                  enabled: !_documentoBloqueado,
                  value: _assinaturaTestemunha1,
                  onPick: () {
                    _pickAssinatura((b) => setState(() => _assinaturaTestemunha1 = b));
                  },
                  onClear: () => setState(() => _assinaturaTestemunha1 = null),
                ),
                FormField<bool>(
                  validator: (_) {
                    if (!_responsavelRecusouAssinatura) return null;
                    if (_assinaturaTestemunha1 == null) return 'Assinatura da 1ª testemunha é obrigatória.';
                    return null;
                  },
                  builder: (state) {
                    if (state.errorText == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _testemunha2RecusaCtrl,
                  label: '2ª Testemunha',
                  required: true,
                  enabled: !_documentoBloqueado,
                ),
                const SizedBox(height: 12),
                OfficialSignatureField(
                  label: 'Assinatura da 2ª Testemunha',
                  required: true,
                  enabled: !_documentoBloqueado,
                  value: _assinaturaTestemunha2,
                  onPick: () {
                    _pickAssinatura((b) => setState(() => _assinaturaTestemunha2 = b));
                  },
                  onClear: () => setState(() => _assinaturaTestemunha2 = null),
                ),
                FormField<bool>(
                  validator: (_) {
                    if (!_responsavelRecusouAssinatura) return null;
                    if (_assinaturaTestemunha2 == null) return 'Assinatura da 2ª testemunha é obrigatória.';
                    return null;
                  },
                  builder: (state) {
                    if (state.errorText == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                    );
                  },
                ),
              ],
              const Divider(height: 28),
              const Text('Autoridade de Saúde', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _autoridadeSaudeCtrl,
                      label: 'Autoridade de Saúde',
                      required: true,
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      controller: _autoridadeFuncaoCtrl,
                      label: 'Função',
                      required: true,
                      enabled: !_documentoBloqueado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialSignatureField(
                label: 'Assinatura da Autoridade',
                required: true,
                enabled: !_documentoBloqueado,
                value: _assinaturaAutoridadeSaude,
                onPick: () {
                  _pickAssinatura((b) => setState(() => _assinaturaAutoridadeSaude = b));
                },
                onClear: () => setState(() => _assinaturaAutoridadeSaude = null),
              ),
              FormField<bool>(
                validator: (_) {
                  if (_assinaturaAutoridadeSaude == null) return 'Assinatura da Autoridade é obrigatória.';
                  return null;
                },
                builder: (state) {
                  if (state.errorText == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Revisão'),
        isActive: _currentStep >= 6,
        state: _currentStep > 6 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _revisaoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Revise os campos antes de salvar.', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _buildRevisaoCompleta(),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Salvar'),
        isActive: _currentStep >= 7,
        state: StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: _semEfeito,
              onChanged: _documentoBloqueado ? null : (v) => setState(() => _semEfeito = v),
              title: const Text('Não Emitido / Sem Efeito'),
            ),
            if (_semEfeito) ...[
              const SizedBox(height: 8),
              OfficialTextField(
                controller: _semEfeitoMotivoCtrl,
                label: 'Justificativa',
                required: true,
                enabled: !_documentoBloqueado,
                multiline: true,
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving || _documentoBloqueado ? null : () => _salvar(statusDocumento: 'EM_EDICAO'),
              child: const Text('Salvar e Editar'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saving || _documentoBloqueado
                  ? null
                  : () => _salvar(statusDocumento: _semEfeito ? 'SEM_EFEITO' : 'FINALIZADO'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
              child: Text(_semEfeito ? 'Salvar (Sem Efeito)' : 'Salvar'),
            ),
          ],
        ),
      ),
    ];
    return steps;
  }

  Widget _buildCabecalho() {
    final numero = (_numeroAuto ?? '').trim();
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
            const Text('ESTADO DE SANTA CATARINA', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('PREFEITURA DE BALNEÁRIO CAMBORIÚ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('SECRETARIA MUNICIPAL DE SAÚDE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text('DIVISÃO DE VIGILÂNCIA SANITÁRIA', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              'Avenida Palestina, nº 150,\nesquina com Rua Suíça –\nBairro das Nações –\nBalneário Camboriú/SC',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('AUTO DE IMPOSIÇÃO DE PENALIDADE', style: TextStyle(fontWeight: FontWeight.w800))),
                Text(numero, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumo() {
    final base = _enquadramentoLegalCtrl.text.trim();
    final autosInt = _autosIntimacaoRelacionados.map((e) => '${e['numero_ano']} (${e['data_recebimento']})').join(' | ');
    final autosInfList = _autosInfracaoRelacionados.isNotEmpty
        ? _autosInfracaoRelacionados
        : [
            {
              'numero_ano': _infNumeroAnoCtrl.text.trim(),
              'data_recebimento': _infDataRecebimentoCtrl.text.trim(),
            }
          ].where((e) => (e['numero_ano'] ?? '').toString().trim().isNotEmpty || (e['data_recebimento'] ?? '').toString().trim().isNotEmpty).toList();
    final autosInf = autosInfList.map((e) => '${e['numero_ano']} (${e['data_recebimento']})').join(' | ');
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Número: ${(_numeroAuto ?? '').trim()}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('PAS: ${_pasNumeroCtrl.text.trim()}'),
            const SizedBox(height: 6),
            Text('Autuado: ${_autuadoNomeCtrl.text.trim()}'),
            Text('CNPJ/CPF: ${_autuadoCpfCnpjCtrl.text.trim()}'),
            const SizedBox(height: 6),
            Text('Enquadramento: ${base.isEmpty ? '-' : base}', maxLines: 6, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            if (autosInt.isNotEmpty) Text('Autos de Intimação: $autosInt'),
            if (autosInf.isNotEmpty) Text('Autos de Infração: $autosInf'),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisaoCompleta() {
    String v(String s) => s.trim().isEmpty ? '-' : s.trim();
    final numero = (_numeroAuto ?? '').trim();
    final autosInt = _autosIntimacaoRelacionados;
    final autosInf = _autosInfracaoRelacionados.isNotEmpty
        ? _autosInfracaoRelacionados
        : [
            {
              'numero_ano': _infNumeroAnoCtrl.text.trim(),
              'data_recebimento': _infDataRecebimentoCtrl.text.trim(),
            }
          ].where((e) => (e['numero_ano'] ?? '').toString().trim().isNotEmpty || (e['data_recebimento'] ?? '').toString().trim().isNotEmpty).toList();

    final autuadoNome = _autuadoNomeCtrl.text.trim();
    final autuadoCpfCnpj = _autuadoCpfCnpjCtrl.text.trim();
    final autuadoNomeFantasia = _autuadoNomeFantasiaCtrl.text.trim();
    final autuadoEndereco = _autuadoEnderecoCompletoCtrl.text.trim();
    final autuadoNumero = _autuadoNumeroCtrl.text.trim();
    final autuadoBairro = _autuadoBairroCtrl.text.trim();
    final autuadoMunicipio = _autuadoMunicipioCtrl.text.trim();
    final autuadoUf = _autuadoUfCtrl.text.trim();
    final autuadoProprietario = _autuadoProprietarioCtrl.text.trim();
    final autuadoTipoAtividade = _autuadoTipoAtividadeCtrl.text.trim();

    final base = _basesLegaisVinculadas;
    final recebAssOk = _assinaturaRecebimento != null || _responsavelRecusouAssinatura;
    final t1Ok = !_responsavelRecusouAssinatura || _assinaturaTestemunha1 != null;
    final t2Ok = !_responsavelRecusouAssinatura || _assinaturaTestemunha2 != null;
    final autOk = _assinaturaAutoridadeSaude != null;

    Widget section(String title, List<Widget> children) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
    }

    Widget rowText(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$label: ${v(value)}'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('Dados', [
          rowText('Número', numero),
          rowText('Data da lavratura', _dataLavraturaCtrl.text),
          rowText('Setor', _setor),
          rowText('Telefone VISA', _telefoneVisaCtrl.text),
          rowText('E-mail VISA', _emailVisaCtrl.text),
          rowText('PAS', _pasNumeroCtrl.text),
          rowText('Possui pasta VISA', _possuiPastaVisa ? 'Sim' : 'Não'),
          if (_possuiPastaVisa) rowText('Número da Pasta VISA', _autuadoAlvaraCtrl.text),
        ]),
        const SizedBox(height: 12),
        section('Autuado', [
          rowText('Nome', autuadoNome),
          rowText('CNPJ/CPF', autuadoCpfCnpj),
          rowText('Nome Fantasia', autuadoNomeFantasia),
          rowText('Endereço', autuadoEndereco),
          rowText('Número', autuadoNumero),
          rowText('Bairro', autuadoBairro),
          rowText('Município', autuadoMunicipio),
          rowText('UF', autuadoUf),
          rowText('Proprietário/Responsável', autuadoProprietario),
          rowText('Tipo de atividade', autuadoTipoAtividade),
        ]),
        const SizedBox(height: 12),
        section('Enquadramento e Base legal', [
          rowText('Enquadramento legal', _enquadramentoLegalCtrl.text),
          if (base.isEmpty)
            rowText('Base legal', '')
          else
            ...base.map((e) {
              final t = (e['titulo'] ?? e['ementa'] ?? '').toString().trim();
              final d = (e['descricao'] ?? '').toString().trim();
              final text = [t, d].where((x) => x.isNotEmpty).join(' — ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${text.isEmpty ? '-' : text}'),
              );
            }),
        ]),
        const SizedBox(height: 12),
        section('Autos relacionados', [
          if (autosInt.isEmpty)
            rowText('Autos de Intimação', '')
          else
            ...autosInt.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• Intimação: ${(a['numero_ano'] ?? '').toString()} (${(a['data_recebimento'] ?? '').toString()})'),
                )),
          if (autosInf.isEmpty)
            rowText('Autos de Infração', '')
          else
            ...autosInf.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• Infração: ${(a['numero_ano'] ?? '').toString()} (${(a['data_recebimento'] ?? '').toString()})'),
                )),
        ]),
        const SizedBox(height: 12),
        section('Penalidade', [
          rowText('Ato ou fato', _atoFatoCtrl.text),
          rowText('Tipo', _tipoPenalidade),
          rowText('UFM', _ufmCtrl.text),
          rowText('Valor da multa', _valorMultaCtrl.text),
          rowText('Valor por extenso', _valorExtensoCtrl.text),
          rowText('Especificação', _especificacaoPenalidadeCtrl.text),
          rowText('Comentário', _comentarioFiscalizacaoCtrl.text),
        ]),
        const SizedBox(height: 12),
        section('Recebimento', [
          rowText('Data', _recebimentoDataCtrl.text),
          rowText('Hora', _recebimentoHoraCtrl.text),
          rowText('Responsável', _recebimentoResponsavelCtrl.text),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(recebAssOk ? Icons.check_circle_outline : Icons.error_outline, color: recebAssOk ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_responsavelRecusouAssinatura ? 'Assinatura do responsável (recusa)' : 'Assinatura do responsável')),
              ],
            ),
          ),
          if (_responsavelRecusouAssinatura) ...[
            rowText('1ª Testemunha', _testemunha1RecusaCtrl.text),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(t1Ok ? Icons.check_circle_outline : Icons.error_outline, color: t1Ok ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Assinatura da 1ª Testemunha')),
                ],
              ),
            ),
            rowText('2ª Testemunha', _testemunha2RecusaCtrl.text),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(t2Ok ? Icons.check_circle_outline : Icons.error_outline, color: t2Ok ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Assinatura da 2ª Testemunha')),
                ],
              ),
            ),
          ],
          rowText('Autoridade de Saúde', _autoridadeSaudeCtrl.text),
          rowText('Função', _autoridadeFuncaoCtrl.text),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(autOk ? Icons.check_circle_outline : Icons.error_outline, color: autOk ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                const Expanded(child: Text('Assinatura da Autoridade')),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      _dbg('build enter currentStep=$_currentStep');
      final steps = _buildSteps();
      final safeStep = steps.isEmpty ? 0 : _currentStep.clamp(0, steps.length - 1);
      _dbg('build steps=${steps.length} safeStep=$safeStep');
      if (safeStep != _currentStep) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentStep = safeStep);
        });
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Auto de Imposição de Penalidade'),
          backgroundColor: AppColors.azulInstitucional,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: steps.isEmpty
              ? const Center(child: Text('Nenhuma etapa disponível.'))
              : Column(
                  children: [
                    OfficialStepper(
                      currentStep: safeStep,
                      steps: steps
                          .map((s) => s.title is Text ? (((s.title as Text).data ?? '').trim()) : 'Etapa')
                          .toList(),
                      onStepTapped: (i) {
                        if (i == safeStep) return;
                        if (i > safeStep) {
                          for (var s = safeStep; s < i; s++) {
                            if (!_validateStep(s)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Preencha os campos obrigatórios desta etapa para avançar.')),
                              );
                              setState(() => _currentStep = s);
                              return;
                            }
                          }
                        }
                        setState(() => _currentStep = i);
                      },
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: steps[safeStep].content,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: safeStep > 0 ? () => setState(() => _currentStep = safeStep - 1) : null,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.azulInstitucional),
                              ),
                              child: const Text('Voltar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: safeStep >= steps.length - 1
                                  ? null
                                  : () {
                                      if (!_validateStep(safeStep)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Preencha os campos obrigatórios desta etapa para continuar.')),
                                        );
                                        return;
                                      }
                                      setState(() => _currentStep = safeStep + 1);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.azulInstitucional,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Continuar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      );
    } catch (e) {
      _dbg('build exception=$e', hypothesisId: 'A');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Auto de Imposição de Penalidade'),
          backgroundColor: AppColors.azulInstitucional,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text('Falha ao abrir o formulário: $e')),
      );
    }
  }
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged});

  final ValueChanged<Uint8List?> onChanged;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _points = <Offset>[];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(d.globalPosition);
        setState(() => _points.add(local));
      },
      onPanEnd: (_) async {
        final img = await _renderToPngBytes();
        widget.onChanged(img);
      },
      child: CustomPaint(
        painter: _SignaturePainter(points: _points),
        child: SizedBox(
          width: double.infinity,
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _renderToPngBytes() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _points.length - 1; i++) {
      canvas.drawLine(_points[i], _points[i + 1], paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(520, 220);
    final bytes = await img.toByteData(format: ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => oldDelegate.points != points;
}

