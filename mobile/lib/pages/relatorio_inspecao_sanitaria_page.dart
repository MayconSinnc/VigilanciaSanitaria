import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../services/pdf_generator_service.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/official_form_fields.dart';

class RelatorioInspecaoSanitariaPage extends StatefulWidget {
  const RelatorioInspecaoSanitariaPage({super.key});

  @override
  State<RelatorioInspecaoSanitariaPage> createState() => _RelatorioInspecaoSanitariaPageState();
}

class _RelatorioInspecaoSanitariaPageState extends State<RelatorioInspecaoSanitariaPage> {
  static const _setores = [
    'Departamento de Fiscalização de Alimentos',
    'Departamento de Fiscalização de Serviços de Saúde e de Interesse à Saúde',
    'Centro de Controle de Pragas Urbanas',
    'Programa Municipal de Controle da Dengue',
  ];

  final ApiService _api = ApiService();

  int _currentStep = 0;
  bool _saving = false;
  bool _documentoBloqueado = false;
  String _statusDocumento = 'EM_EDICAO';
  int? _docIdOnline;

  String? _numeroRelatorio;
  String _setor = _setores.first;

  final _dadosFormKey = GlobalKey<FormState>();
  final _estabelecimentoFormKey = GlobalKey<FormState>();
  final _motivoFormKey = GlobalKey<FormState>();
  final _historicoFormKey = GlobalKey<FormState>();
  final _situacaoFormKey = GlobalKey<FormState>();
  final _medidaFormKey = GlobalKey<FormState>();
  final _equipeFormKey = GlobalKey<FormState>();
  final _revisaoFormKey = GlobalKey<FormState>();

  final _dataLavraturaCtrl = TextEditingController();
  final _telefoneVisaCtrl = TextEditingController();
  final _emailVisaCtrl = TextEditingController();

  final _periodoInspecaoCtrl = TextEditingController();
  final _nomePessoaCtrl = TextEditingController();
  final _nomeFantasiaCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _alvaraCtrl = TextEditingController();
  final _telefoneEstabCtrl = TextEditingController();
  final _emailEstabCtrl = TextEditingController();
  final _representanteLegalCtrl = TextEditingController();
  final _pessoasContatadasCtrl = TextEditingController();
  final _outrasObsCtrl = TextEditingController();

  final _motivoCtrl = TextEditingController();
  final _historicoCtrl = TextEditingController();
  final _situacaoCtrl = TextEditingController();
  final _medidaCtrl = TextEditingController();

  final List<Map<String, dynamic>> _equipe = [];

  bool _semEfeito = false;
  final _semEfeitoMotivoCtrl = TextEditingController();
  bool _possuiPastaVisa = false;

  Map<String, dynamic> _dadosEstabelecimento = {};
  Map<String, dynamic>? _documentoVinculado;

  @override
  void initState() {
    super.initState();
    _seedDefaults();
    _prefillDadosVisa();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map ? rawArgs.cast<String, dynamic>() : null;
    if (args != null && _dadosEstabelecimento.isEmpty) {
      final rawEstab = args['estabelecimento'];
      final estab = rawEstab is Map ? rawEstab.cast<String, dynamic>() : <String, dynamic>{};
      if (estab.isNotEmpty) {
        _dadosEstabelecimento = estab;
        _prefillFromEstabelecimento(estab);
      }
      final rawVinculo = args['documento_vinculado'];
      final vinculo = rawVinculo is Map ? rawVinculo.cast<String, dynamic>() : null;
      if (vinculo != null && vinculo.isNotEmpty) {
        _documentoVinculado = vinculo;
      }
      _prefillHistoricoAutomatico(estab, vinculo);
      final numero = (args['numero_relatorio'] ?? args['numero_auto'] ?? '').toString().trim();
      if (numero.isNotEmpty) _numeroRelatorio = numero;
      final id = args['id'];
      if (id is int) _docIdOnline = id;
    }
    _ensureNumeroRelatorio();
  }

  @override
  void dispose() {
    _dataLavraturaCtrl.dispose();
    _telefoneVisaCtrl.dispose();
    _emailVisaCtrl.dispose();
    _periodoInspecaoCtrl.dispose();
    _nomePessoaCtrl.dispose();
    _nomeFantasiaCtrl.dispose();
    _enderecoCtrl.dispose();
    _cnpjCtrl.dispose();
    _alvaraCtrl.dispose();
    _telefoneEstabCtrl.dispose();
    _emailEstabCtrl.dispose();
    _representanteLegalCtrl.dispose();
    _pessoasContatadasCtrl.dispose();
    _outrasObsCtrl.dispose();
    _motivoCtrl.dispose();
    _historicoCtrl.dispose();
    _situacaoCtrl.dispose();
    _medidaCtrl.dispose();
    _semEfeitoMotivoCtrl.dispose();
    super.dispose();
  }

  void _seedDefaults() {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _dataLavraturaCtrl.text = today;
    if (_periodoInspecaoCtrl.text.trim().isEmpty) _periodoInspecaoCtrl.text = today;
    if (_telefoneVisaCtrl.text.trim().isEmpty) _telefoneVisaCtrl.text = '(47) 3261-6256';
    if (_emailVisaCtrl.text.trim().isEmpty) _emailVisaCtrl.text = 'alimentos.devs@bc.sc.gov.br';
  }

  Future<void> _prefillDadosVisa() async {
    try {
      final setor = (await _api.readPreference('visa_setor'))?.trim() ?? '';
      final telefone = (await _api.readPreference('visa_telefone'))?.trim() ?? '';
      final email = (await _api.readPreference('visa_email'))?.trim() ?? '';

      if (!mounted) return;
      setState(() {
        if (setor.isNotEmpty && _setores.contains(setor)) _setor = setor;
        if (telefone.isNotEmpty) _telefoneVisaCtrl.text = telefone;
        if (email.isNotEmpty) _emailVisaCtrl.text = email;
      });
    } catch (_) {}
  }

  Future<void> _ensureNumeroRelatorio() async {
    if (_numeroRelatorio != null && _numeroRelatorio!.trim().isNotEmpty) return;
    final ano = DateTime.now().year;
    if (!kIsWeb) {
      final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      setState(() => _numeroRelatorio = 'RIS-$ano-$seq');
      return;
    }
    try {
      final numero = await _api.proximoNumeroRelatorioInspecao(ano);
      if (!mounted) return;
      if (numero != null && numero.trim().isNotEmpty) {
        setState(() => _numeroRelatorio = numero);
        return;
      }
    } catch (_) {}
    final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    if (mounted) setState(() => _numeroRelatorio = 'RIS-$ano-$seq');
  }

  String _onlyDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    return null;
  }

  String? _minCharsValidator(String? value, int min) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    if (value.trim().length < min) return 'Mínimo de $min caracteres';
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    final v = value.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'E-mail inválido';
  }

  TextInputFormatter _cpfCnpjFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final digits = newValue.text.replaceAll(RegExp(r'\\D'), '');
      if (digits.isEmpty) return newValue.copyWith(text: '');

      String formatted;
      if (digits.length <= 11) {
        final d = digits.padRight(11, ' ');
        formatted = '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9, 11)}'.replaceAll(' ', '');
      } else {
        final d = digits.padRight(14, ' ');
        formatted =
            '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12, 14)}'
                .replaceAll(' ', '');
      }
      return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    });
  }

  void _prefillFromEstabelecimento(Map<String, dynamic> estab) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = (estab[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final nome = pick(['razaoSocial', 'razao_social', 'nome']);
    final fantasia = pick(['nomeFantasia', 'nome_fantasia', 'nome']);
    final cnpj = pick(['cnpj']);
    final endereco = pick(['endereco', 'logradouro']);
    final telefone = pick(['telefone']);
    final email = pick(['email']);

    if (_nomePessoaCtrl.text.trim().isEmpty) _nomePessoaCtrl.text = nome;
    if (_nomeFantasiaCtrl.text.trim().isEmpty) _nomeFantasiaCtrl.text = fantasia;
    if (_cnpjCtrl.text.trim().isEmpty) _cnpjCtrl.text = cnpj;
    if (_enderecoCtrl.text.trim().isEmpty) _enderecoCtrl.text = endereco;
    if (_telefoneEstabCtrl.text.trim().isEmpty) _telefoneEstabCtrl.text = telefone;
    if (_emailEstabCtrl.text.trim().isEmpty) _emailEstabCtrl.text = email;
  }

  void _prefillHistoricoAutomatico(Map<String, dynamic> estab, Map<String, dynamic>? vinculo) {
    if (_historicoCtrl.text.trim().isNotEmpty) return;

    String pickFromEstab(List<String> keys) {
      for (final k in keys) {
        final v = (estab[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final historicoBase = pickFromEstab([
      'historico_estabelecimento',
      'historicoEstabelecimento',
      'historico',
      'observacoes',
    ]);

    String vinculoResumo() {
      if (vinculo == null) return '';
      final tipo = (vinculo['tipo_documento'] ?? vinculo['tipo'] ?? '').toString().trim();
      final numero = (vinculo['numero_ano'] ?? vinculo['numero_auto'] ?? '').toString().trim();
      final payload = vinculo['payload'];
      if (payload is! Map) {
        return [tipo.isEmpty ? '' : tipo, numero.isEmpty ? '' : numero].where((e) => e.isNotEmpty).join(' ');
      }
      final p = payload.cast<String, dynamic>();
      final ai = (p['auto_intimacao'] is Map) ? (p['auto_intimacao'] as Map).cast<String, dynamic>() : null;
      final infr = (p['auto_infracao'] is Map) ? (p['auto_infracao'] as Map).cast<String, dynamic>() : null;
      final doc = ai ?? infr;
      if (doc == null) {
        return [tipo.isEmpty ? '' : tipo, numero.isEmpty ? '' : numero].where((e) => e.isNotEmpty).join(' ');
      }
      final data = (doc['data_lavratura'] ?? '').toString().trim();
      final irregularidades = (doc['descricao_irregularidades'] ?? '').toString().trim();
      final providencias = (doc['descricao_providencias'] ?? '').toString().trim();
      final header = [
        if (tipo.isNotEmpty) tipo,
        if (numero.isNotEmpty) numero,
        if (data.isNotEmpty) 'lavrado em $data',
      ].join(' • ');
      final parts = <String>[
        if (header.trim().isNotEmpty) header,
        if (irregularidades.isNotEmpty) 'Irregularidades:\n$irregularidades',
        if (providencias.isNotEmpty) 'Providências:\n$providencias',
      ];
      return parts.join('\n\n').trim();
    }

    final resumo = vinculoResumo();
    final finalText = [historicoBase, resumo].where((e) => e.trim().isNotEmpty).join('\n\n').trim();
    if (finalText.isNotEmpty) _historicoCtrl.text = finalText;
  }

  bool _validateStep(int index) {
    GlobalKey<FormState>? key;
    switch (index) {
      case 0:
        key = _dadosFormKey;
        break;
      case 1:
        key = _estabelecimentoFormKey;
        break;
      case 2:
        key = _motivoFormKey;
        break;
      case 3:
        key = _historicoFormKey;
        break;
      case 4:
        key = _situacaoFormKey;
        break;
      case 5:
        key = _medidaFormKey;
        break;
      case 6:
        key = _equipeFormKey;
        break;
      case 7:
        key = _revisaoFormKey;
        break;
      default:
        return true;
    }
    final form = key.currentState;
    if (form == null) return true;
    return form.validate();
  }

  Future<Uint8List?> _pickSignature() async {
    final bytes = await Navigator.pushNamed(context, '/assinatura');
    if (!mounted) return null;
    if (bytes is Uint8List) return bytes;
    return null;
  }

  Future<void> _addFiscalDialog() async {
    final nomeCtrl = TextEditingController();
    final funcaoCtrl = TextEditingController();
    Uint8List? assinatura;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final maxWidth = MediaQuery.of(ctx).size.width * 0.92;
            final dialogWidth = maxWidth < 520 ? maxWidth : 520.0;
            return AlertDialog(
              title: const Text('Adicionar fiscal'),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OfficialTextField(controller: nomeCtrl, label: 'Nome', required: true, enabled: true),
                    const SizedBox(height: 12),
                    OfficialTextField(controller: funcaoCtrl, label: 'Função', required: true, enabled: true),
                    const SizedBox(height: 12),
                    OfficialSignatureField(
                      label: 'Assinatura digital',
                      required: true,
                      enabled: true,
                      value: assinatura,
                      onPick: () {
                        _pickSignature().then((b) {
                          if (b == null) return;
                          setLocal(() => assinatura = b);
                        });
                      },
                      onClear: () => setLocal(() => assinatura = null),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (nomeCtrl.text.trim().isEmpty || funcaoCtrl.text.trim().isEmpty || assinatura == null) return;
                    Navigator.of(ctx).pop();
                    setState(() {
                      _equipe.add({
                        'nome': nomeCtrl.text.trim(),
                        'funcao': funcaoCtrl.text.trim(),
                        'assinatura_bytes': assinatura,
                      });
                    });
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
    nomeCtrl.dispose();
    funcaoCtrl.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    final equipe = _equipe
        .map((e) => {
              'nome': (e['nome'] ?? '').toString().trim(),
              'funcao': (e['funcao'] ?? '').toString().trim(),
              'assinatura_base64': (e['assinatura_bytes'] is Uint8List) ? base64Encode(e['assinatura_bytes'] as Uint8List) : null,
            })
        .toList();

    final estabelecimento = {
      'periodo_inspecao': _periodoInspecaoCtrl.text.trim(),
      'nome_pessoa': _nomePessoaCtrl.text.trim(),
      'nome_fantasia': _nomeFantasiaCtrl.text.trim(),
      'endereco': _enderecoCtrl.text.trim(),
      'cnpj': _cnpjCtrl.text.trim(),
      'possui_pasta_visa': _possuiPastaVisa,
      'numero_pasta_visa': _possuiPastaVisa ? _alvaraCtrl.text.trim() : '',
      'alvara_pasta_visa': _possuiPastaVisa ? _alvaraCtrl.text.trim() : '',
      'telefone': _telefoneEstabCtrl.text.trim(),
      'email': _emailEstabCtrl.text.trim(),
      'representante_legal': _representanteLegalCtrl.text.trim(),
      'pessoas_contatadas': _pessoasContatadasCtrl.text.trim(),
      'outras_observacoes': _outrasObsCtrl.text.trim(),
    };

    final rel = <String, dynamic>{
      'numero_relatorio': (_numeroRelatorio ?? '').trim(),
      'data_lavratura': _dataLavraturaCtrl.text.trim(),
      'setor_vigilancia': _setor,
      'telefone_visa': _telefoneVisaCtrl.text.trim(),
      'email_visa': _emailVisaCtrl.text.trim(),
      'estabelecimento': estabelecimento,
      'motivo_inspecao': _motivoCtrl.text,
      'historico_estabelecimento': _historicoCtrl.text,
      'situacao_encontrada': _situacaoCtrl.text,
      'medida_adotada': _medidaCtrl.text,
      'equipe_fiscalizacao': equipe,
      'sem_efeito': _semEfeito,
      'sem_efeito_motivo': _semEfeitoMotivoCtrl.text.trim(),
    };
    if (_documentoVinculado != null) {
      rel['documento_vinculado'] = _documentoVinculado;
    }

    return <String, dynamic>{
      'ano': DateTime.now().year.toString(),
      'data_hora': DateTime.now().toIso8601String(),
      'tipo_documento': 'INSPECAO_SANITARIA',
      'status': _statusDocumento,
      'status_documento': _statusDocumento,
      'dados_estabelecimento': _dadosEstabelecimento,
      'inspecao_sanitaria': rel,
    };
  }

  bool _validateAll() {
    final keys = [
      _dadosFormKey,
      _estabelecimentoFormKey,
      _motivoFormKey,
      _historicoFormKey,
      _situacaoFormKey,
      _medidaFormKey,
      _equipeFormKey,
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
      (step: 1, key: _estabelecimentoFormKey),
      (step: 2, key: _motivoFormKey),
      (step: 3, key: _historicoFormKey),
      (step: 4, key: _situacaoFormKey),
      (step: 5, key: _medidaFormKey),
      (step: 6, key: _equipeFormKey),
      (step: 7, key: _revisaoFormKey),
    ];
    for (final it in items) {
      final form = it.key.currentState;
      if (form != null && !form.validate()) return it.step;
    }
    return null;
  }

  Future<void> _salvar({required String statusDocumento}) async {
    final invalid = _firstInvalidStep();
    if (invalid != null) {
      setState(() => _currentStep = invalid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revise os campos obrigatórios antes de salvar.')));
      return;
    }
    if (statusDocumento == 'SEM_EFEITO' && _semEfeitoMotivoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a justificativa para "Não Emitido / Sem Efeito".')));
      return;
    }
    if (statusDocumento == 'FINALIZADO') {
      if (_equipe.isEmpty) {
        setState(() => _currentStep = 6);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe ao menos 1 fiscal na equipe.')));
        return;
      }
      if (_equipe.any((e) => e['assinatura_bytes'] == null)) {
        setState(() => _currentStep = 6);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinatura digital é obrigatória para toda a equipe.')));
        return;
      }
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
          saved = await _api.salvarRelatorioInspecao(
            ano: ano,
            status: statusDocumento,
            dados: payload,
            dispositivo: 'Flutter Web',
          );
          final id = int.tryParse((saved['id'] ?? '').toString());
          if (id != null) _docIdOnline = id;
        } else {
          saved = await _api.atualizarRelatorioInspecao(
            id: _docIdOnline!,
            status: statusDocumento,
            dados: payload,
            dispositivo: 'Flutter Web',
          );
        }
        final numero = (saved['numero'] ?? '').toString().trim();
        if (numero.isNotEmpty) {
          _numeroRelatorio = numero;
          final rel = payload['inspecao_sanitaria'];
          if (rel is Map) {
            final updated = Map<String, dynamic>.from(rel);
            updated['numero_relatorio'] = numero;
            payload['inspecao_sanitaria'] = updated;
          }
        }
        if (!mounted) return;
        if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
          setState(() => _documentoBloqueado = true);
          await Navigator.pushNamed(
            context,
            '/relatorio-inspecao-sanitario-pdf',
            arguments: {'payload': payload, 'autoReturnToList': true},
          );
          if (!mounted) return;
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
      final relJson = jsonEncode(payload['inspecao_sanitaria']);
      final insertedId = await db.insert('autos_sanitarios', {
        'tipo_auto': 'INSPECAO_SANITARIA',
        'numero_auto': (_numeroRelatorio ?? '').trim(),
        'numero_ano': (_numeroRelatorio ?? '').trim(),
        'estabelecimento_id': 0,
        'fiscal_id': 0,
        'data': DateTime.now().toIso8601String().substring(0, 10),
        'data_hora': payload['data_hora'],
        'descricao': 'Relatório de Inspeção Sanitária',
        'fundamentacao_legal': '',
        'observacoes': '',
        'status': statusDocumento,
        'ano': payload['ano'],
        'tipo_documento': payload['tipo_documento'],
        'dados_estabelecimento': jsonEncode(payload['dados_estabelecimento']),
        'inspecao_sanitaria_json': relJson,
        'payload_json': jsonEncode(payload),
        'data_documento': DateTime.now().toIso8601String().substring(0, 10),
        'estabelecimento_nome': _nomePessoaCtrl.text.trim().isNotEmpty ? _nomePessoaCtrl.text.trim() : _nomeFantasiaCtrl.text.trim(),
        'estabelecimento_cnpj': _onlyDigits(_cnpjCtrl.text),
        'status_sincronizacao': 'PENDENTE_SINCRONIZACAO',
      });

      if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
        final pdfBytes = await PdfGeneratorService().gerarRelatorioInspecaoSanitariaPdf(payload);
        await LocalDb.atualizarAutoSanitario(insertedId, {'pdf_local': base64Encode(pdfBytes)});
        setState(() => _documentoBloqueado = true);
        if (!mounted) return;
        await Navigator.pushNamed(
          context,
          '/relatorio-inspecao-sanitario-pdf',
          arguments: {'payload': payload, 'autoReturnToList': true},
        );
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
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCabecalho() {
    final numero = (_numeroRelatorio ?? '').trim();
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
            const Text('SECRETARIA DE SAÚDE E SANEAMENTO', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
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
                const Expanded(
                  child: Text('RELATÓRIO DE INSPEÇÃO SANITÁRIA', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(numero, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisaoCompleta() {
    final numero = (_numeroRelatorio ?? '').trim();
    String v(String s) => s.trim().isEmpty ? '-' : s.trim();
    final estabNome = _nomePessoaCtrl.text.trim().isNotEmpty ? _nomePessoaCtrl.text.trim() : _nomeFantasiaCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dados gerais', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Número: ${v(numero)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Data da lavratura: ${v(_dataLavraturaCtrl.text)}'),
                Text('Setor: ${v(_setor)}'),
                Text('Telefone VISA: ${v(_telefoneVisaCtrl.text)}'),
                Text('E-mail VISA: ${v(_emailVisaCtrl.text)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estabelecimento', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Data / Período da inspeção: ${v(_periodoInspecaoCtrl.text)}'),
                Text('Nome: ${v(estabNome)}'),
                Text('CNPJ: ${v(_cnpjCtrl.text)}'),
                Text('Endereço: ${v(_enderecoCtrl.text)}'),
                if (_possuiPastaVisa) Text('Pasta VISA: ${v(_alvaraCtrl.text)}'),
                Text('Telefone: ${v(_telefoneEstabCtrl.text)}'),
                Text('E-mail: ${v(_emailEstabCtrl.text)}'),
                Text('Representante legal: ${v(_representanteLegalCtrl.text)}'),
                const SizedBox(height: 10),
                Text('Pessoas contatadas:\n${v(_pessoasContatadasCtrl.text)}'),
                const SizedBox(height: 10),
                Text('Outras observações:\n${v(_outrasObsCtrl.text)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conteúdo', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Motivo da inspeção:\n${v(_motivoCtrl.text)}'),
                const SizedBox(height: 10),
                Text('Histórico do estabelecimento:\n${v(_historicoCtrl.text)}'),
                const SizedBox(height: 10),
                Text('Situação encontrada:\n${v(_situacaoCtrl.text)}'),
                const SizedBox(height: 10),
                Text('Medida adotada:\n${v(_medidaCtrl.text)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Equipe', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Total: ${_equipe.length} fiscal(is)'),
                if (_equipe.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._equipe.map((e) {
                    final nome = (e['nome'] ?? '').toString().trim();
                    final funcao = (e['funcao'] ?? '').toString().trim();
                    final ok = e['assinatura_bytes'] is Uint8List;
                    final base = [nome, funcao].where((x) => x.trim().isNotEmpty).join(' — ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: ok ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(base.isEmpty ? '-' : base)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Dados Gerais'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _dadosFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(),
              const SizedBox(height: 12),
              OfficialDateField(
                controller: _dataLavraturaCtrl,
                label: 'Data da lavratura do Relatório',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialDropdownField.fromStrings(
                value: _setor,
                items: _setores,
                onChanged: _documentoBloqueado ? null : (v) => setState(() => _setor = v ?? _setores.first),
                label: 'Nome do setor da Vigilância Sanitária',
                required: true,
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
                label: 'E-Mail da VISA',
                required: true,
                enabled: !_documentoBloqueado,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Estabelecimento'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _estabelecimentoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('IDENTIFICAÇÃO DO ESTABELECIMENTO INSPECIONADO', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _periodoInspecaoCtrl,
                label: 'Data / Período da Inspeção',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _nomePessoaCtrl,
                label: 'Nome da Pessoa Física / Jurídica',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _cnpjCtrl,
                      label: 'CNPJ',
                      required: true,
                      enabled: !_documentoBloqueado,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cpfCnpjFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                        final digits = _onlyDigits(v);
                        if (digits.length != 14) return 'CNPJ inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _documentoBloqueado
                        ? null
                        : () async {
                            final digits = _onlyDigits(_cnpjCtrl.text);
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
                    label: const Text('e-Pública'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _nomeFantasiaCtrl,
                label: 'Denominação Comercial / Nome Fantasia',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _enderecoCtrl,
                label: 'Endereço',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
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
                          if (!v) _alvaraCtrl.clear();
                        });
                      },
              ),
              if (_possuiPastaVisa) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _alvaraCtrl,
                  label: 'Número da Pasta VISA',
                  required: true,
                  enabled: !_documentoBloqueado,
                  validator: _requiredValidator,
                ),
              ],
              const SizedBox(height: 12),
              OfficialPhoneField(
                controller: _telefoneEstabCtrl,
                label: 'Telefone',
                required: true,
                enabled: !_documentoBloqueado,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _emailEstabCtrl,
                label: 'E-Mail',
                required: true,
                enabled: !_documentoBloqueado,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _representanteLegalCtrl,
                label: 'Representante Legal',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _pessoasContatadasCtrl,
                label: 'Pessoas Contatadas',
                required: true,
                enabled: !_documentoBloqueado,
                multiline: true,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _outrasObsCtrl,
                label: 'Outras Observações',
                required: true,
                enabled: !_documentoBloqueado,
                multiline: true,
                validator: _requiredValidator,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Motivo'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _motivoFormKey,
          child: OfficialTextField(
            controller: _motivoCtrl,
            label: 'Motivo da Inspeção',
            required: true,
            enabled: !_documentoBloqueado,
            multiline: true,
            validator: (v) => _minCharsValidator(v, 20),
          ),
        ),
      ),
      Step(
        title: const Text('Histórico'),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _historicoFormKey,
          child: OfficialTextField(
            controller: _historicoCtrl,
            label: 'Histórico do Estabelecimento',
            required: true,
            enabled: !_documentoBloqueado,
            multiline: true,
            validator: _requiredValidator,
          ),
        ),
      ),
      Step(
        title: const Text('Situação'),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _situacaoFormKey,
          child: OfficialTextField(
            controller: _situacaoCtrl,
            label: 'Situação Encontrada',
            required: true,
            enabled: !_documentoBloqueado,
            multiline: true,
            validator: _requiredValidator,
          ),
        ),
      ),
      Step(
        title: const Text('Medida'),
        isActive: _currentStep >= 5,
        state: _currentStep > 5 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _medidaFormKey,
          child: OfficialTextField(
            controller: _medidaCtrl,
            label: 'Medida Adotada',
            required: true,
            enabled: !_documentoBloqueado,
            multiline: true,
            validator: _requiredValidator,
          ),
        ),
      ),
      Step(
        title: const Text('Equipe'),
        isActive: _currentStep >= 6,
        state: _currentStep > 6 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _equipeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Equipe de Fiscalização', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _documentoBloqueado ? null : _addFiscalDialog,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar fiscal'),
              ),
              const SizedBox(height: 12),
              if (_equipe.isNotEmpty) ...[
                ..._equipe.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final nome = (item['nome'] ?? '').toString();
                  final funcao = (item['funcao'] ?? '').toString();
                  final hasAss = item['assinatura_bytes'] is Uint8List;
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(funcao),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(hasAss ? Icons.check_circle_outline : Icons.error_outline, color: hasAss ? Colors.green : Colors.red),
                          IconButton(
                            onPressed: _documentoBloqueado ? null : () => setState(() => _equipe.removeAt(idx)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              FormField<bool>(
                validator: (_) {
                  if (_equipe.isEmpty) return 'Informe ao menos 1 fiscal';
                  if (_equipe.any((e) => e['assinatura_bytes'] == null)) return 'Assinatura é obrigatória para todos os fiscais';
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
        isActive: _currentStep >= 7,
        state: _currentStep > 7 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _revisaoFormKey,
          child: _buildRevisaoCompleta(),
        ),
      ),
      Step(
        title: const Text('Salvar'),
        isActive: _currentStep >= 8,
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
              onPressed: _saving || _documentoBloqueado ? null : () => _salvar(statusDocumento: _semEfeito ? 'SEM_EFEITO' : 'FINALIZADO'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
              child: Text(_semEfeito ? 'Salvar (Sem Efeito)' : 'Salvar'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      final payload = _buildPayload();
                      Navigator.pushNamed(context, '/relatorio-inspecao-sanitario-pdf', arguments: {'payload': payload});
                    },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Gerar PDF'),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    try {
      final steps = _buildSteps();
      final safeStep = steps.isEmpty ? 0 : _currentStep.clamp(0, steps.length - 1);
      if (safeStep != _currentStep) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentStep = safeStep);
        });
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Relatório de Inspeção Sanitária'),
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
                        if (i > safeStep && !_validateStep(safeStep)) return;
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
                                      if (!_validateStep(safeStep)) return;
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
      return Scaffold(
        appBar: AppBar(
          title: const Text('Relatório de Inspeção Sanitária'),
          backgroundColor: AppColors.azulInstitucional,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text('Falha ao abrir o formulário: $e')),
      );
    }
  }
}

