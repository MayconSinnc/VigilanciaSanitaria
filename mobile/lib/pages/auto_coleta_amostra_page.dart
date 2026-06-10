import 'dart:async';
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

class AutoColetaAmostraPage extends StatefulWidget {
  const AutoColetaAmostraPage({super.key});

  @override
  State<AutoColetaAmostraPage> createState() => _AutoColetaAmostraPageState();
}

class _AutoColetaAmostraPageState extends State<AutoColetaAmostraPage> {
  static const _setores = [
    'Departamento de Fiscalização de Alimentos',
    'Departamento de Fiscalização de Serviços de Saúde e de Interesse à Saúde',
  ];

  static const _cienciaTexto =
      'ESTOU CIENTE DE QUE A COLETA AQUI REGISTRADA FOI REALIZADA CONFORME OS PROCEDIMENTOS LEGAIS E REGULAMENTARES (ART. 67 DA LEI ESTADUAL Nº 6.320/83 E ART. 40 DO DECRETO ESTADUAL Nº 23.663/84), BEM COMO ATESTO QUE TODOS OS DADOS LANÇADOS NO PRESENTE SÃO VERDADEIROS. ADEMAIS, TAMBÉM ESTOU CIENTE DE QUE O EXTRAVIO, VIOLAÇÃO E/OU ALTERAÇÃO DAS AMOSTRAS EM MEU PODER ELIMINARÁ A POSSIBILIDADE DE REALIZAÇÃO DE PERÍCIA DE CONTRAPROVA, SUJEITANDO O DETENTOR (FIEL DEPOSITÁRIO) ÀS PENALIDADES PREVISTAS NA LEGISLAÇÃO SANITÁRIA.';

  static const _laboratorioTexto =
      'LABORATÓRIO CENTRAL DE SAÚDE PÚBLICA (LACEN/SC)\nRua Felipe Schmidt, nº 788 – Centro – Florianópolis/SC\nFone: (48) 3664-7800\nE-Mail: lacen@saude.sc.gov.br';

  final ApiService _api = ApiService();

  int _currentStep = 0;
  bool _saving = false;
  bool _documentoBloqueado = false;
  String _statusDocumento = 'EM_EDICAO';
  int? _docIdOnline;

  String? _numeroAuto;
  String _setor = _setores.first;
  String? _tipoAmostra;

  final _dadosFormKey = GlobalKey<FormState>();
  final _detentorFormKey = GlobalKey<FormState>();
  final _produtoFormKey = GlobalKey<FormState>();
  final _recebimentoFormKey = GlobalKey<FormState>();
  final _autoridadeFormKey = GlobalKey<FormState>();
  final _revisaoFormKey = GlobalKey<FormState>();

  final _dataLavraturaCtrl = TextEditingController();
  final _telefoneVisaCtrl = TextEditingController();
  final _emailVisaCtrl = TextEditingController();
  bool _possuiPastaVisa = false;
  final _numeroPastaVisaCtrl = TextEditingController();

  final _detentorNomeCtrl = TextEditingController();
  final _detentorCpfCnpjCtrl = TextEditingController();
  final _detentorNomeFantasiaCtrl = TextEditingController();
  final _detentorEnderecoCompletoCtrl = TextEditingController();
  final _detentorNumeroCtrl = TextEditingController();
  final _detentorBairroCtrl = TextEditingController();
  final _detentorCepCtrl = TextEditingController();
  final _detentorProprietarioCtrl = TextEditingController();
  final _detentorMunicipioCtrl = TextEditingController(text: 'Balneário Camboriú');
  final _detentorUfCtrl = TextEditingController(text: 'SC');
  final _detentorTipoAtividadeCtrl = TextEditingController();
  final _detentorAlvaraCtrl = TextEditingController();

  final List<Map<String, dynamic>> _produtos = [];

  final _comentarioFiscalizacaoCtrl = TextEditingController();

  final _recebimentoDataCtrl = TextEditingController();
  final _recebimentoHoraCtrl = TextEditingController();
  final _recebimentoResponsavelCtrl = TextEditingController();
  Uint8List? _assinaturaRecebimento;

  bool _responsavelRecusouAssinatura = false;
  final _testemunha1Ctrl = TextEditingController();
  final _testemunha2Ctrl = TextEditingController();
  Uint8List? _assinaturaTestemunha1;
  Uint8List? _assinaturaTestemunha2;

  final _autoridadeNomeCtrl = TextEditingController();
  final _autoridadeFuncaoCtrl = TextEditingController();
  Uint8List? _assinaturaAutoridade;

  bool _semEfeito = false;
  final _semEfeitoMotivoCtrl = TextEditingController();

  Map<String, dynamic> _dadosEstabelecimento = {};
  String _tipoAtividadeUltimoAuto = '';
  List<Map<String, dynamic>> _cnaesDetentor = [];

  @override
  void initState() {
    super.initState();
    _seedDefaults();
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
    _numeroPastaVisaCtrl.dispose();
    _detentorNomeCtrl.dispose();
    _detentorCpfCnpjCtrl.dispose();
    _detentorNomeFantasiaCtrl.dispose();
    _detentorEnderecoCompletoCtrl.dispose();
    _detentorNumeroCtrl.dispose();
    _detentorBairroCtrl.dispose();
    _detentorCepCtrl.dispose();
    _detentorProprietarioCtrl.dispose();
    _detentorMunicipioCtrl.dispose();
    _detentorUfCtrl.dispose();
    _detentorTipoAtividadeCtrl.dispose();
    _detentorAlvaraCtrl.dispose();
    _comentarioFiscalizacaoCtrl.dispose();
    _recebimentoDataCtrl.dispose();
    _recebimentoHoraCtrl.dispose();
    _recebimentoResponsavelCtrl.dispose();
    _testemunha1Ctrl.dispose();
    _testemunha2Ctrl.dispose();
    _autoridadeNomeCtrl.dispose();
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
  }

  Future<void> _ensureNumeroAuto() async {
    if (_numeroAuto != null && _numeroAuto!.trim().isNotEmpty) return;
    final ano = DateTime.now().year;
    if (!kIsWeb) {
      final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      setState(() => _numeroAuto = 'COL-$ano-$seq');
      return;
    }
    try {
      final numero = await _api.proximoNumeroAutoColetaAmostra(ano);
      if (!mounted) return;
      if (numero != null && numero.trim().isNotEmpty) {
        setState(() => _numeroAuto = numero);
        return;
      }
    } catch (_) {}
    final seq = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    if (mounted) setState(() => _numeroAuto = 'COL-$ano-$seq');
  }

  String _onlyDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

  DateTime? _parseDate(String input) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(input.trim());
    if (m == null) return null;
    final day = int.tryParse(m.group(1) ?? '');
    final month = int.tryParse(m.group(2) ?? '');
    final year = int.tryParse(m.group(3) ?? '');
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) return null;
    return parsed;
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
    final cep = pick(['cep']);
    final municipio = pick(['cidade', 'municipio']);
    final uf = pick(['uf', 'estado']);
    final pasta = pick(['numero_pasta_visa', 'alvara_pasta_visa', 'alvara_sanitario', 'pasta_visa']);
    final cnaes = extractCnaes();
    _cnaesDetentor = cnaes;
    final cnaePrincipal = cnaes.isEmpty ? null : cnaes.firstWhere((e) => e['principal'] == true, orElse: () => cnaes.first);
    final atividade = cnaePrincipal == null ? '' : formatCnaeItem(cnaePrincipal);

    if (_detentorNomeCtrl.text.trim().isEmpty) _detentorNomeCtrl.text = nome;
    if (_detentorNomeFantasiaCtrl.text.trim().isEmpty) _detentorNomeFantasiaCtrl.text = fantasia;
    if (_detentorCpfCnpjCtrl.text.trim().isEmpty) _detentorCpfCnpjCtrl.text = cnpj;
    if (_detentorEnderecoCompletoCtrl.text.trim().isEmpty) _detentorEnderecoCompletoCtrl.text = endereco;
    if (_detentorNumeroCtrl.text.trim().isEmpty) _detentorNumeroCtrl.text = numero;
    if (_detentorBairroCtrl.text.trim().isEmpty) _detentorBairroCtrl.text = bairro;
    if (_detentorCepCtrl.text.trim().isEmpty) _detentorCepCtrl.text = _formatCep(cep);
    if (_detentorMunicipioCtrl.text.trim().isEmpty && municipio.isNotEmpty) _detentorMunicipioCtrl.text = municipio;
    if (_detentorUfCtrl.text.trim().isEmpty && uf.isNotEmpty) _detentorUfCtrl.text = uf;
    if (_numeroPastaVisaCtrl.text.trim().isEmpty) _numeroPastaVisaCtrl.text = pasta;
    {
      final cur = _detentorTipoAtividadeCtrl.text.trim();
      if (atividade.isNotEmpty && (cur.isEmpty || cur == _tipoAtividadeUltimoAuto)) {
        _detentorTipoAtividadeCtrl.text = atividade;
        _tipoAtividadeUltimoAuto = atividade;
      }
    }
    if (!_possuiPastaVisa && pasta.isNotEmpty) _possuiPastaVisa = true;
  }

  Future<void> _hidratarEstabelecimentoDetalheSeNecessario(Map<String, dynamic> raw) async {
    if (ApiService.mockMode) return;
    if (_cnaesDetentor.isNotEmpty && _detentorTipoAtividadeCtrl.text.trim().isNotEmpty) return;
    final digits = _onlyDigits((raw['cnpj'] ?? '').toString());
    if (digits.length != 14) return;
    final detail = await _api.buscarEstabelecimentoDetalhe(digits);
    if (!mounted || detail == null) return;
    setState(() {
      _dadosEstabelecimento = Map<String, dynamic>.from(detail);
      _prefillFromEstabelecimento(_dadosEstabelecimento);
    });
  }

  Future<void> _selecionarCnaeDetentor() async {
    if (_documentoBloqueado) return;
    if (_cnaesDetentor.isEmpty) return;
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
            itemCount: _cnaesDetentor.length,
            itemBuilder: (ctx, index) {
              final it = _cnaesDetentor[index];
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
    _detentorTipoAtividadeCtrl.text = text;
    _tipoAtividadeUltimoAuto = text;
  }

  String _formatCep(String? value) {
    final digits = _onlyDigits(value ?? '');
    if (digits.length != 8) return (value ?? '').trim();
    return '${digits.substring(0, 5)}-${digits.substring(5, 8)}';
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
    final v = value.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'E-mail inválido';
  }

  String? _tipoAmostraValidator(_) {
    if (_tipoAmostra == null || _tipoAmostra!.trim().isEmpty) return 'Selecione o Tipo de Amostra';
    return null;
  }

  TextInputFormatter _cpfCnpjFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
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
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  bool _validateStep(int index) {
    GlobalKey<FormState>? key;
    switch (index) {
      case 0:
        key = _dadosFormKey;
        break;
      case 1:
        key = _detentorFormKey;
        break;
      case 2:
        key = _produtoFormKey;
        break;
      case 3:
        key = _recebimentoFormKey;
        break;
      case 4:
        key = _autoridadeFormKey;
        break;
      case 5:
        key = _revisaoFormKey;
        break;
      default:
        return true;
    }
    final form = key.currentState;
    if (form == null) return true;
    return form.validate();
  }

  Future<void> _pickSignature(ValueChanged<Uint8List?> onSelected) async {
    final bytes = await Navigator.pushNamed(context, '/assinatura');
    if (!mounted) return;
    if (bytes is Uint8List) {
      onSelected(bytes);
    }
  }

  Future<Map<String, dynamic>?> _showProdutoDialog({Map<String, dynamic>? initial}) async {
    final nomeCtrl = TextEditingController(text: (initial?['nome_produto'] ?? '').toString());
    final marcaCtrl = TextEditingController(text: (initial?['marca'] ?? '').toString());
    final quantidadeCtrl = TextEditingController(text: (initial?['quantidade'] ?? '').toString());
    final pesoVolumeCtrl = TextEditingController(text: (initial?['peso_volume'] ?? '').toString());
    final loteCtrl = TextEditingController(text: (initial?['lote'] ?? '').toString());
    final registroCtrl = TextEditingController(text: (initial?['registro_produto'] ?? '').toString());
    final dataFabCtrl = TextEditingController(text: (initial?['data_fabricacao'] ?? '').toString());
    final dataValCtrl = TextEditingController(text: (initial?['data_validade'] ?? '').toString());
    final produtorNomeCtrl = TextEditingController(text: (initial?['produtor_nome'] ?? '').toString());
    final produtorCpfCnpjCtrl = TextEditingController(text: (initial?['produtor_cnpj_cpf'] ?? '').toString());
    final produtorEnderecoCtrl =
        TextEditingController(text: (initial?['produtor_endereco_completo'] ?? initial?['produtor_endereco_cep'] ?? '').toString());
    final produtorCepCtrl = TextEditingController(text: (initial?['produtor_cep'] ?? '').toString());
    final produtorMunicipioCtrl =
        TextEditingController(text: (initial?['produtor_municipio'] ?? initial?['produtor_municipio_estado'] ?? '').toString());
    final produtorUfCtrl = TextEditingController(text: (initial?['produtor_uf'] ?? '').toString());
    final infoAdicionaisCtrl = TextEditingController(text: (initial?['informacoes_adicionais'] ?? '').toString());
    final motivoColetaCtrl = TextEditingController(text: (initial?['motivo_coleta'] ?? '').toString());
    final tempConservacaoCtrl = TextEditingController(text: (initial?['temperatura_conservacao'] ?? '').toString());
    final lacresDetentorCtrl = TextEditingController(text: (initial?['lacres_detentor'] ?? '').toString());
    final lacresLaboratorioCtrl = TextEditingController(text: (initial?['lacres_laboratorio'] ?? '').toString());

    final formKey = GlobalKey<FormState>();

    if (dataFabCtrl.text.trim().isEmpty || dataValCtrl.text.trim().isEmpty) {
      final now = DateTime.now();
      final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      if (dataFabCtrl.text.trim().isEmpty) dataFabCtrl.text = today;
      if (dataValCtrl.text.trim().isEmpty) dataValCtrl.text = today;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final maxWidth = MediaQuery.of(ctx).size.width * 0.92;
        final dialogWidth = maxWidth < 720 ? maxWidth : 720.0;
        return AlertDialog(
          title: Text(initial == null ? 'Adicionar produto' : 'Editar produto'),
          content: SizedBox(
            width: dialogWidth,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OfficialTextField(controller: nomeCtrl, label: 'Nome do Produto', required: true, enabled: true, validator: _requiredValidator),
                    const SizedBox(height: 12),
                    OfficialTextField(controller: marcaCtrl, label: 'Marca', required: true, enabled: true, validator: _requiredValidator),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OfficialTextField(
                            controller: quantidadeCtrl,
                            label: 'Quantidade',
                            required: true,
                            enabled: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\\.,]'))],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                              final s = v.replaceAll('.', '').replaceAll(',', '.');
                              final n = double.tryParse(s);
                              if (n == null) return 'Valor inválido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialTextField(controller: pesoVolumeCtrl, label: 'Peso / Volume', required: true, enabled: true, validator: _requiredValidator),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(controller: loteCtrl, label: 'Lote / Partida', required: true, enabled: true, validator: _requiredValidator),
                    const SizedBox(height: 12),
                    OfficialTextField(controller: registroCtrl, label: 'Número de Registro do Produto', required: true, enabled: true, validator: _requiredValidator),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: OfficialDateField(controller: dataFabCtrl, label: 'Data de Fabricação', required: true, enabled: true)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialDateField(
                            controller: dataValCtrl,
                            label: 'Data de Validade',
                            required: true,
                            enabled: true,
                            validator: (val) {
                              if (val == null) return 'Campo obrigatório';
                              final fab = _parseDate(dataFabCtrl.text);
                              if (fab != null && val.isBefore(fab)) return 'Validade não pode ser anterior à fabricação';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: produtorNomeCtrl,
                      label: 'Indústria Produtora / Produtor / Importador',
                      required: true,
                      enabled: true,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: produtorCpfCnpjCtrl,
                      label: 'CNPJ/CPF do Produtor',
                      required: true,
                      enabled: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cpfCnpjFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                        final digits = _onlyDigits(v);
                        if (digits.length != 11 && digits.length != 14) return 'Informe CPF ou CNPJ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OfficialTextField(
                            controller: produtorEnderecoCtrl,
                            label: 'Endereço Completo',
                            required: true,
                            enabled: true,
                            validator: _requiredValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 170,
                          child: OfficialCepField(
                            controller: produtorCepCtrl,
                            label: 'CEP',
                            required: true,
                            enabled: true,
                            validator: _requiredValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OfficialTextField(
                            controller: produtorMunicipioCtrl,
                            label: 'Município',
                            required: true,
                            enabled: true,
                            validator: _requiredValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: OfficialTextField(
                            controller: produtorUfCtrl,
                            label: 'UF',
                            required: true,
                            enabled: true,
                            validator: _requiredValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: infoAdicionaisCtrl,
                      label: 'Informações adicionais',
                      required: true,
                      enabled: true,
                      multiline: true,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: motivoColetaCtrl,
                      label: 'Motivo da Coleta',
                      required: true,
                      enabled: true,
                      multiline: true,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: tempConservacaoCtrl,
                      label: 'Temperatura / Conservação',
                      required: true,
                      enabled: true,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9A-Za-z°\\s\\.]'))],
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: lacresDetentorCtrl,
                      label: 'Número dos Lacres (Detentor/Fiel Depositário)',
                      required: true,
                      enabled: true,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: lacresLaboratorioCtrl,
                      label: 'Número dos Lacres (Laboratório)',
                      required: true,
                      enabled: true,
                      validator: _requiredValidator,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final endereco = produtorEnderecoCtrl.text.trim();
                final cep = produtorCepCtrl.text.trim();
                final municipio = produtorMunicipioCtrl.text.trim();
                final uf = produtorUfCtrl.text.trim();
                Navigator.of(ctx).pop({
                  'nome_produto': nomeCtrl.text.trim(),
                  'marca': marcaCtrl.text.trim(),
                  'quantidade': quantidadeCtrl.text.trim(),
                  'peso_volume': pesoVolumeCtrl.text.trim(),
                  'lote': loteCtrl.text.trim(),
                  'registro_produto': registroCtrl.text.trim(),
                  'data_fabricacao': dataFabCtrl.text.trim(),
                  'data_validade': dataValCtrl.text.trim(),
                  'produtor_nome': produtorNomeCtrl.text.trim(),
                  'produtor_cnpj_cpf': produtorCpfCnpjCtrl.text.trim(),
                  'produtor_endereco_completo': endereco,
                  'produtor_cep': cep,
                  'produtor_municipio': municipio,
                  'produtor_uf': uf,
                  'produtor_endereco_cep': [endereco, cep].where((e) => e.trim().isNotEmpty).join(' - '),
                  'produtor_municipio_estado': [municipio, uf].where((e) => e.trim().isNotEmpty).join('/'),
                  'informacoes_adicionais': infoAdicionaisCtrl.text.trim(),
                  'motivo_coleta': motivoColetaCtrl.text.trim(),
                  'temperatura_conservacao': tempConservacaoCtrl.text.trim(),
                  'lacres_detentor': lacresDetentorCtrl.text.trim(),
                  'lacres_laboratorio': lacresLaboratorioCtrl.text.trim(),
                });
              },
              child: Text(initial == null ? 'Adicionar' : 'Salvar'),
            ),
          ],
        );
      },
    );

    nomeCtrl.dispose();
    marcaCtrl.dispose();
    quantidadeCtrl.dispose();
    pesoVolumeCtrl.dispose();
    loteCtrl.dispose();
    registroCtrl.dispose();
    dataFabCtrl.dispose();
    dataValCtrl.dispose();
    produtorNomeCtrl.dispose();
    produtorCpfCnpjCtrl.dispose();
    produtorEnderecoCtrl.dispose();
    produtorCepCtrl.dispose();
    produtorMunicipioCtrl.dispose();
    produtorUfCtrl.dispose();
    infoAdicionaisCtrl.dispose();
    motivoColetaCtrl.dispose();
    tempConservacaoCtrl.dispose();
    lacresDetentorCtrl.dispose();
    lacresLaboratorioCtrl.dispose();

    return result;
  }

  String _produtoTitulo(Map<String, dynamic> p) {
    final nome = (p['nome_produto'] ?? '').toString().trim();
    final marca = (p['marca'] ?? '').toString().trim();
    final lote = (p['lote'] ?? '').toString().trim();
    final parts = <String>[
      if (nome.isNotEmpty) nome,
      if (marca.isNotEmpty) marca,
      if (lote.isNotEmpty) 'Lote $lote',
    ];
    return parts.isEmpty ? 'Produto' : parts.join(' • ');
  }

  Widget _buildRevisaoCompleta() {
    String v(String s) => s.trim().isEmpty ? '-' : s.trim();

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

    Widget assinaturaStatus(String label, bool ok) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: ok ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      );
    }

    final numero = (_numeroAuto ?? '').trim();
    final recebAssOk = _assinaturaRecebimento != null || _responsavelRecusouAssinatura;
    final t1Ok = !_responsavelRecusouAssinatura || _assinaturaTestemunha1 != null;
    final t2Ok = !_responsavelRecusouAssinatura || _assinaturaTestemunha2 != null;
    final autOk = _assinaturaAutoridade != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('Dados', [
          rowText('Número', numero),
          rowText('Tipo de Amostra', _tipoAmostra ?? ''),
          rowText('Data da lavratura', _dataLavraturaCtrl.text),
          rowText('Setor da Vigilância Sanitária', _setor),
          rowText('Telefone VISA', _telefoneVisaCtrl.text),
          rowText('E-mail VISA', _emailVisaCtrl.text),
        ]),
        const SizedBox(height: 12),
        section('Laboratório de destino', [rowText('Laboratório', _laboratorioTexto)]),
        const SizedBox(height: 12),
        section('Detentor', [
          rowText('Nome', _detentorNomeCtrl.text),
          rowText('CNPJ/CPF', _detentorCpfCnpjCtrl.text),
          rowText('Nome Fantasia', _detentorNomeFantasiaCtrl.text),
          rowText('Endereço Completo', _detentorEnderecoCompletoCtrl.text),
          rowText('Número', _detentorNumeroCtrl.text),
          rowText('Bairro', _detentorBairroCtrl.text),
          rowText('CEP', _detentorCepCtrl.text),
          rowText('Proprietário/Responsável', _detentorProprietarioCtrl.text),
          rowText('Município', _detentorMunicipioCtrl.text),
          rowText('UF', _detentorUfCtrl.text),
          rowText('Tipo de atividade', _detentorTipoAtividadeCtrl.text),
          rowText('Número Alvará Sanitário', _detentorAlvaraCtrl.text),
          rowText('Possui pasta VISA', _possuiPastaVisa ? 'Sim' : 'Não'),
          if (_possuiPastaVisa) rowText('Número da Pasta VISA', _numeroPastaVisaCtrl.text),
        ]),
        const SizedBox(height: 12),
        section(
          'Produtos',
          _produtos.isEmpty
              ? [rowText('Produtos', '')]
              : [
                  for (var i = 0; i < _produtos.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _produtos.length > 1 ? 'Produto (${i + 1}/${_produtos.length})' : 'Produto',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    rowText('Nome do Produto', (_produtos[i]['nome_produto'] ?? '').toString()),
                    rowText('Marca', (_produtos[i]['marca'] ?? '').toString()),
                    rowText('Quantidade', (_produtos[i]['quantidade'] ?? '').toString()),
                    rowText('Peso / Volume', (_produtos[i]['peso_volume'] ?? '').toString()),
                    rowText('Lote / Partida', (_produtos[i]['lote'] ?? '').toString()),
                    rowText('Número de Registro do Produto', (_produtos[i]['registro_produto'] ?? '').toString()),
                    rowText('Data de Fabricação', (_produtos[i]['data_fabricacao'] ?? '').toString()),
                    rowText('Data de Validade', (_produtos[i]['data_validade'] ?? '').toString()),
                    rowText('Indústria Produtora / Produtor / Importador', (_produtos[i]['produtor_nome'] ?? '').toString()),
                    rowText('CNPJ/CPF do Produtor', (_produtos[i]['produtor_cnpj_cpf'] ?? '').toString()),
                    rowText(
                      'Endereço Completo',
                      ((_produtos[i]['produtor_endereco_completo'] ?? _produtos[i]['produtor_endereco_cep']) ?? '').toString(),
                    ),
                    rowText('CEP', (_produtos[i]['produtor_cep'] ?? '').toString()),
                    rowText(
                      'Município',
                      ((_produtos[i]['produtor_municipio'] ?? _produtos[i]['produtor_municipio_estado']) ?? '').toString(),
                    ),
                    rowText('UF', (_produtos[i]['produtor_uf'] ?? '').toString()),
                    rowText('Informações adicionais', (_produtos[i]['informacoes_adicionais'] ?? '').toString()),
                    rowText('Motivo da Coleta', (_produtos[i]['motivo_coleta'] ?? '').toString()),
                    rowText('Temperatura / Conservação', (_produtos[i]['temperatura_conservacao'] ?? '').toString()),
                    rowText('Número dos Lacres (Detentor/Fiel Depositário)', (_produtos[i]['lacres_detentor'] ?? '').toString()),
                    rowText('Número dos Lacres (Laboratório)', (_produtos[i]['lacres_laboratorio'] ?? '').toString()),
                    if (i < _produtos.length - 1) const Divider(height: 24),
                  ],
                ],
        ),
        const SizedBox(height: 12),
        section('Ciência e Observações', [
          rowText('Ciência', _cienciaTexto),
          rowText('Comentário sobre a Fiscalização', _comentarioFiscalizacaoCtrl.text),
        ]),
        const SizedBox(height: 12),
        section('Recebimento', [
          rowText('Data', _recebimentoDataCtrl.text),
          rowText('Hora', _recebimentoHoraCtrl.text),
          rowText('Responsável', _recebimentoResponsavelCtrl.text),
          assinaturaStatus(_responsavelRecusouAssinatura ? 'Assinatura do responsável (recusa)' : 'Assinatura do responsável', recebAssOk),
          if (_responsavelRecusouAssinatura) ...[
            rowText('1ª Testemunha', _testemunha1Ctrl.text),
            assinaturaStatus('Assinatura (1ª testemunha)', t1Ok),
            rowText('2ª Testemunha', _testemunha2Ctrl.text),
            assinaturaStatus('Assinatura (2ª testemunha)', t2Ok),
          ],
        ]),
        const SizedBox(height: 12),
        section('Autoridade de Saúde', [
          rowText('Nome', _autoridadeNomeCtrl.text),
          rowText('Função', _autoridadeFuncaoCtrl.text),
          assinaturaStatus('Assinatura digital', autOk),
        ]),
      ],
    );
  }

  Map<String, dynamic> _buildPayload() {
    final detentor = <String, dynamic>{
      'nome': _detentorNomeCtrl.text.trim(),
      'cnpj_cpf': _onlyDigits(_detentorCpfCnpjCtrl.text),
      'cnpj_cpf_formatado': _detentorCpfCnpjCtrl.text.trim(),
      'nome_fantasia': _detentorNomeFantasiaCtrl.text.trim(),
      'endereco_completo': _detentorEnderecoCompletoCtrl.text.trim(),
      'numero': _detentorNumeroCtrl.text.trim(),
      'bairro': _detentorBairroCtrl.text.trim(),
      'cep': _detentorCepCtrl.text.trim(),
      'proprietario_responsavel': _detentorProprietarioCtrl.text.trim(),
      'municipio': _detentorMunicipioCtrl.text.trim(),
      'uf': _detentorUfCtrl.text.trim(),
      'tipo_atividade': _detentorTipoAtividadeCtrl.text.trim(),
      'alvara_sanitario': _detentorAlvaraCtrl.text.trim(),
      'possui_pasta_visa': _possuiPastaVisa,
      'numero_pasta_visa': _possuiPastaVisa ? _numeroPastaVisaCtrl.text.trim() : '',
    };

    final produtos = _produtos.map((e) => Map<String, dynamic>.from(e)).toList();
    final produto = produtos.isNotEmpty ? produtos.first : <String, dynamic>{};

    final recebimento = <String, dynamic>{
      'data': _recebimentoDataCtrl.text.trim(),
      'hora': _recebimentoHoraCtrl.text.trim(),
      'responsavel': _recebimentoResponsavelCtrl.text.trim(),
      'assinatura_base64': _assinaturaRecebimento == null ? null : base64Encode(_assinaturaRecebimento!),
    };

    final recusa = <String, dynamic>{
      'responsavel_recusou_assinatura': _responsavelRecusouAssinatura,
      'testemunha_1': _testemunha1Ctrl.text.trim(),
      'assinatura_testemunha_1_base64': _assinaturaTestemunha1 == null ? null : base64Encode(_assinaturaTestemunha1!),
      'testemunha_2': _testemunha2Ctrl.text.trim(),
      'assinatura_testemunha_2_base64': _assinaturaTestemunha2 == null ? null : base64Encode(_assinaturaTestemunha2!),
    };

    final autoridade = <String, dynamic>{
      'nome': _autoridadeNomeCtrl.text.trim(),
      'funcao': _autoridadeFuncaoCtrl.text.trim(),
      'assinatura_base64': _assinaturaAutoridade == null ? null : base64Encode(_assinaturaAutoridade!),
    };

    final col = <String, dynamic>{
      'numero_auto': (_numeroAuto ?? '').trim(),
      'tipo_amostra': _tipoAmostra,
      'data_lavratura': _dataLavraturaCtrl.text.trim(),
      'setor_vigilancia': _setor,
      'telefone_visa': _telefoneVisaCtrl.text.trim(),
      'email_visa': _emailVisaCtrl.text.trim(),
      'laboratorio_destino': _laboratorioTexto,
      'detentor': detentor,
      'produto': produto,
      'produtos': produtos,
      'ciencia_texto': _cienciaTexto,
      'comentario_fiscalizacao': _comentarioFiscalizacaoCtrl.text.trim(),
      'recebimento': recebimento,
      'recusa': recusa,
      'autoridade_saude': autoridade,
      'sem_efeito': _semEfeito,
      'sem_efeito_motivo': _semEfeitoMotivoCtrl.text.trim(),
    };

    return <String, dynamic>{
      'ano': DateTime.now().year.toString(),
      'data_hora': DateTime.now().toIso8601String(),
      'tipo_documento': 'AUTO_COLETA_AMOSTRA',
      'status': _statusDocumento,
      'status_documento': _statusDocumento,
      'dados_estabelecimento': _dadosEstabelecimento,
      'auto_coleta_amostra': col,
    };
  }

  bool _validateAll() {
    final keys = [
      _dadosFormKey,
      _detentorFormKey,
      _produtoFormKey,
      _recebimentoFormKey,
      _autoridadeFormKey,
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
      (step: 1, key: _detentorFormKey),
      (step: 2, key: _produtoFormKey),
      (step: 3, key: _recebimentoFormKey),
      (step: 4, key: _autoridadeFormKey),
      (step: 5, key: _revisaoFormKey),
    ];
    for (final it in items) {
      final form = it.key.currentState;
      if (form != null && !form.validate()) return it.step;
    }
    return null;
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
        setState(() => _currentStep = 3);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinatura do recebimento é obrigatória.')));
        return;
      }
      if (_responsavelRecusouAssinatura && (_assinaturaTestemunha1 == null || _assinaturaTestemunha2 == null)) {
        setState(() => _currentStep = 3);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinaturas das testemunhas são obrigatórias em caso de recusa.')));
        return;
      }
      if (_assinaturaAutoridade == null) {
        setState(() => _currentStep = 4);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assinatura da Autoridade de Saúde é obrigatória.')));
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
          saved = await _api.salvarAutoColetaAmostra(
            ano: ano,
            status: statusDocumento,
            dados: payload,
            dispositivo: 'Flutter Web',
          );
          final id = int.tryParse((saved['id'] ?? '').toString());
          if (id != null) _docIdOnline = id;
        } else {
          saved = await _api.atualizarAutoColetaAmostra(
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
          final col = payload['auto_coleta_amostra'];
          if (col is Map) {
            final updated = Map<String, dynamic>.from(col);
            updated['numero_auto'] = numero;
            payload['auto_coleta_amostra'] = updated;
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
      final coletaJson = jsonEncode(payload['auto_coleta_amostra']);
      final insertedId = await db.insert('autos_sanitarios', {
        'tipo_auto': 'AUTO_COLETA_AMOSTRA',
        'numero_auto': (_numeroAuto ?? '').trim(),
        'numero_ano': (_numeroAuto ?? '').trim(),
        'estabelecimento_id': 0,
        'fiscal_id': 0,
        'data': DateTime.now().toIso8601String().substring(0, 10),
        'data_hora': payload['data_hora'],
        'descricao': _produtos.isEmpty ? '' : (_produtos.first['nome_produto'] ?? '').toString().trim(),
        'fundamentacao_legal': '',
        'observacoes': '',
        'status': statusDocumento,
        'ano': payload['ano'],
        'tipo_documento': payload['tipo_documento'],
        'dados_estabelecimento': jsonEncode(payload['dados_estabelecimento']),
        'auto_coleta_amostra_json': coletaJson,
        'payload_json': jsonEncode(payload),
        'data_documento': DateTime.now().toIso8601String().substring(0, 10),
        'estabelecimento_nome': _detentorNomeFantasiaCtrl.text.trim(),
        'estabelecimento_cnpj': _onlyDigits(_detentorCpfCnpjCtrl.text),
        'status_sincronizacao': 'PENDENTE_SINCRONIZACAO',
      });

      if (statusDocumento == 'FINALIZADO' || statusDocumento == 'SEM_EFEITO') {
        final pdfBytes = await PdfGeneratorService().gerarAutoColetaAmostraPdf(payload, via: 2);
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
      if (mounted) setState(() => _saving = false);
    }
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
                const Expanded(
                  child: Text(
                    'AUTO DE COLETA DE AMOSTRA PARA ANÁLISE',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(numero, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Step> _buildSteps() {
    return [
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
              FormField<bool>(
                validator: _tipoAmostraValidator,
                builder: (state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text('Tipo de Amostra', style: TextStyle(fontWeight: FontWeight.w800)),
                          const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RadioListTile<String>(
                        value: 'Amostra Triplicata Fiscalização',
                        groupValue: _tipoAmostra,
                        onChanged: _documentoBloqueado ? null : (v) => setState(() => _tipoAmostra = v),
                        title: const Text('Amostra Triplicata Fiscalização'),
                        dense: true,
                      ),
                      RadioListTile<String>(
                        value: 'Amostra Única Fiscal',
                        groupValue: _tipoAmostra,
                        onChanged: _documentoBloqueado ? null : (v) => setState(() => _tipoAmostra = v),
                        title: const Text('Amostra Única Fiscal'),
                        dense: true,
                      ),
                      RadioListTile<String>(
                        value: 'Amostra de Orientação',
                        groupValue: _tipoAmostra,
                        onChanged: _documentoBloqueado ? null : (v) => setState(() => _tipoAmostra = v),
                        title: const Text('Amostra de Orientação'),
                        dense: true,
                      ),
                      if (state.errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(state.errorText!, style: const TextStyle(color: Colors.red)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              OfficialDateField(
                controller: _dataLavraturaCtrl,
                label: 'Data da lavratura',
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
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Possui Pasta VISA?'),
                value: _possuiPastaVisa,
                onChanged: _documentoBloqueado
                    ? null
                    : (v) {
                        setState(() {
                          _possuiPastaVisa = v;
                          if (!v) _numeroPastaVisaCtrl.clear();
                        });
                        _dadosFormKey.currentState?.validate();
                      },
                contentPadding: EdgeInsets.zero,
              ),
              if (_possuiPastaVisa) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _numeroPastaVisaCtrl,
                  label: 'Número da Pasta VISA',
                  required: true,
                  enabled: !_documentoBloqueado,
                  validator: (v) {
                    if (!_possuiPastaVisa) return null;
                    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Text('LABORATÓRIO DE DESTINO', style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 8),
                      Text(_laboratorioTexto),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Detentor'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _detentorFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('DETENTOR', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _detentorNomeCtrl,
                label: 'Nome da Pessoa Física/Jurídica',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _detentorCpfCnpjCtrl,
                      label: 'CNPJ/CPF',
                      required: true,
                      enabled: !_documentoBloqueado,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cpfCnpjFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                        final digits = _onlyDigits(v);
                        if (digits.length != 11 && digits.length != 14) return 'Informe CPF ou CNPJ';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _documentoBloqueado
                        ? null
                        : () async {
                            final digits = _onlyDigits(_detentorCpfCnpjCtrl.text);
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
                controller: _detentorNomeFantasiaCtrl,
                label: 'Denominação Comercial / Nome Fantasia',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _detentorEnderecoCompletoCtrl,
                label: 'Endereço Completo',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _detentorNumeroCtrl,
                      label: 'Número',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      controller: _detentorBairroCtrl,
                      label: 'Bairro',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: _requiredValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialCepField(
                controller: _detentorCepCtrl,
                label: 'CEP',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _detentorProprietarioCtrl,
                label: 'Proprietário / Responsável',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _detentorMunicipioCtrl,
                      label: 'Município',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: OfficialTextField(
                      controller: _detentorUfCtrl,
                      label: 'UF',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: _requiredValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _detentorTipoAtividadeCtrl,
                label: 'Tipo de Estabelecimento / Negócio / Atividade',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
                helperText: _cnaesDetentor.isEmpty ? null : 'Preenchido pelo CNAE do CNPJ. Você pode selecionar outro CNAE.',
                suffixIcon: _documentoBloqueado || _cnaesDetentor.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _selecionarCnaeDetentor,
                        icon: const Icon(Icons.search_outlined),
                        tooltip: 'Selecionar CNAE',
                      ),
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _detentorAlvaraCtrl,
                label: 'Número Alvará Sanitário',
                required: true,
                enabled: !_documentoBloqueado,
                validator: _requiredValidator,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Produto'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _produtoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('PRODUTOS COLETADOS', style: TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _documentoBloqueado
                        ? null
                        : () async {
                            final produto = await _showProdutoDialog();
                            if (!mounted || produto == null) return;
                            setState(() => _produtos.add(produto));
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_produtos.isEmpty)
                const Text('Nenhum produto adicionado.')
              else
                ..._produtos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      title: Text(_produtoTitulo(item)),
                      subtitle: Text('Item ${index + 1}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _documentoBloqueado
                                ? null
                                : () async {
                                    final edited = await _showProdutoDialog(initial: item);
                                    if (!mounted || edited == null) return;
                                    setState(() => _produtos[index] = edited);
                                  },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: _documentoBloqueado ? null : () => setState(() => _produtos.removeAt(index)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              FormField<bool>(
                validator: (_) => _produtos.isEmpty ? 'Adicione ao menos 1 produto' : null,
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
                controller: _comentarioFiscalizacaoCtrl,
                label: 'Comentário sobre a Fiscalização',
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
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Recebimento'),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _recebimentoFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Recebi a 1ª via deste em:', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialDateField(
                      controller: _recebimentoDataCtrl,
                      label: 'Data recebimento',
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
                      validator: _requiredValidator,
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
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              OfficialSignatureField(
                label: 'Assinatura digital',
                value: _assinaturaRecebimento,
                required: !_responsavelRecusouAssinatura,
                enabled: !_documentoBloqueado,
                onPick: () {
                  _pickSignature((b) => setState(() => _assinaturaRecebimento = b));
                },
                onClear: () => setState(() => _assinaturaRecebimento = null),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _responsavelRecusouAssinatura,
                onChanged: _documentoBloqueado ? null : (v) => setState(() => _responsavelRecusouAssinatura = v),
                title: const Text('Responsável recusou assinatura'),
              ),
              if (_responsavelRecusouAssinatura) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _testemunha1Ctrl,
                  label: '1ª testemunha',
                  required: true,
                  enabled: !_documentoBloqueado,
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                OfficialSignatureField(
                  label: 'Assinatura (1ª testemunha)',
                  value: _assinaturaTestemunha1,
                  required: true,
                  enabled: !_documentoBloqueado,
                  onPick: () {
                    _pickSignature((b) => setState(() => _assinaturaTestemunha1 = b));
                  },
                  onClear: () => setState(() => _assinaturaTestemunha1 = null),
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _testemunha2Ctrl,
                  label: '2ª testemunha',
                  required: true,
                  enabled: !_documentoBloqueado,
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                OfficialSignatureField(
                  label: 'Assinatura (2ª testemunha)',
                  value: _assinaturaTestemunha2,
                  required: true,
                  enabled: !_documentoBloqueado,
                  onPick: () {
                    _pickSignature((b) => setState(() => _assinaturaTestemunha2 = b));
                  },
                  onClear: () => setState(() => _assinaturaTestemunha2 = null),
                ),
              ],
              FormField<bool>(
                validator: (_) {
                  if (_responsavelRecusouAssinatura) {
                    if (_assinaturaTestemunha1 == null || _assinaturaTestemunha2 == null) return 'Assinaturas das testemunhas são obrigatórias';
                    return null;
                  }
                  if (_assinaturaRecebimento == null) return 'Assinatura do recebimento é obrigatória';
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
        title: const Text('Autoridade'),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _autoridadeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('AUTORIDADE DE SAÚDE', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      controller: _autoridadeNomeCtrl,
                      label: 'Nome',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      controller: _autoridadeFuncaoCtrl,
                      label: 'Função',
                      required: true,
                      enabled: !_documentoBloqueado,
                      validator: _requiredValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialSignatureField(
                label: 'Assinatura digital',
                value: _assinaturaAutoridade,
                required: true,
                enabled: !_documentoBloqueado,
                onPick: () {
                  _pickSignature((b) => setState(() => _assinaturaAutoridade = b));
                },
                onClear: () => setState(() => _assinaturaAutoridade = null),
              ),
              FormField<bool>(
                validator: (_) => _assinaturaAutoridade == null ? 'Assinatura é obrigatória' : null,
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
        isActive: _currentStep >= 5,
        state: _currentStep > 5 ? StepState.complete : StepState.indexed,
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
        isActive: _currentStep >= 6,
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      final payload = _buildPayload();
                      Navigator.pushNamed(context, '/auto-coleta-amostra-pdf', arguments: {'payload': payload, 'via': 2});
                    },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Imprimir/Exportar PDF'),
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
          title: const Text('Auto de Coleta de Amostra para Análise'),
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
          title: const Text('Auto de Coleta de Amostra para Análise'),
          backgroundColor: AppColors.azulInstitucional,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text('Falha ao abrir o formulário: $e')),
      );
    }
  }
}

