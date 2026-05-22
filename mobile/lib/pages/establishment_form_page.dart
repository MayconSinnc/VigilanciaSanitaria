import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../storage/db.dart';
import '../services/api.dart';
import '../ui/theme.dart';
import '../widgets/step_header.dart';
import '../widgets/official_form_fields.dart';

class EstablishmentFormPage extends StatefulWidget {
  const EstablishmentFormPage({super.key});
  @override
  State<EstablishmentFormPage> createState() => _EstablishmentFormPageState();
}

class _EstablishmentFormPageState extends State<EstablishmentFormPage> {
  // GlobalKeys para validação por step
  final _dadosFormKey = GlobalKey<FormState>();
  final _enderecoFormKey = GlobalKey<FormState>();
  final _revisaoFormKey = GlobalKey<FormState>();

  // Form Controllers
  final _cnpjCtrl = TextEditingController();
  final _razaoCtrl = TextEditingController();
  final _fantasiaCtrl = TextEditingController();
  final _inscricaoMunicipalCtrl = TextEditingController();
  final _cnaeCtrl = TextEditingController();
  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _cpfRespCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  // State Variables
  String _risco = 'Médio';
  String _statusAlvara = 'Regular';
  String _statusSanitario = 'Regular';
  bool _saving = false;
  bool _confirmacao = false;
  String? _prefetchedCnpjDigits;
  bool _prefilledFromArgs = false;
  int _step = 0;

  final _api = ApiService();

  static String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');
  static bool _isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty);
  static String _pick(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v;
      if (v is num) return v.toString();
    }
    return '';
  }

  static void _setTextIfEmpty(TextEditingController controller, String value) {
    if (controller.text.trim().isNotEmpty) return;
    if (value.trim().isEmpty) return;
    controller.text = value;
  }

  void _applyPrefill(Map<String, dynamic> data, {required bool overwrite}) {
    final cnpjValue = _pick(data, ['cnpj']);
    if (cnpjValue.isNotEmpty) {
      final formatted = CnpjInputFormatter.format(cnpjValue);
      if (overwrite || _cnpjCtrl.text.trim().isEmpty) _cnpjCtrl.text = formatted;
    }

    final razao = _pick(data, ['razaoSocial', 'razao_social', 'razao']);
    final fantasia = _pick(data, ['nomeFantasia', 'nome_fantasia', 'nome']);
    final endereco = _pick(data, ['endereco', 'logradouro', 'rua']);
    final numero = _pick(data, ['numero']);
    final complemento = _pick(data, ['complemento']);
    final bairro = _pick(data, ['bairro']);
    final cep = _pick(data, ['cep']);
    final cidade = _pick(data, ['cidade', 'municipio']);
    final uf = _pick(data, ['estado', 'uf']);
    final telefone = _pick(data, ['telefone']);
    final email = _pick(data, ['email']);
    final responsavel = _pick(data, ['responsavel']);
    final cpfResp = _pick(data, ['cpfResponsavel', 'cpf_responsavel']);
    final inscricaoMunicipal = _pick(data, ['inscricaoMunicipal', 'inscricao_municipal', 'inscricao']);
    final cnae = _pick(data, ['cnaeDescricao', 'cnae_fiscal_descricao', 'cnaeDenominacao', 'cnae_descricao', 'cnae']);

    if (overwrite) {
      if (razao.isNotEmpty) _razaoCtrl.text = razao;
      if (fantasia.isNotEmpty) _fantasiaCtrl.text = fantasia;
      if (endereco.isNotEmpty) _ruaCtrl.text = endereco;
      if (numero.isNotEmpty) _numeroCtrl.text = numero;
      if (complemento.isNotEmpty) _complementoCtrl.text = complemento;
      if (bairro.isNotEmpty) _bairroCtrl.text = bairro;
      if (cep.isNotEmpty) _cepCtrl.text = cep;
      if (cidade.isNotEmpty) _cidadeCtrl.text = cidade;
      if (uf.isNotEmpty) _ufCtrl.text = uf;
      if (telefone.isNotEmpty) _telefoneCtrl.text = telefone;
      if (email.isNotEmpty) _emailCtrl.text = email;
      if (responsavel.isNotEmpty) _responsavelCtrl.text = responsavel;
      if (cpfResp.isNotEmpty) _cpfRespCtrl.text = cpfResp;
      if (inscricaoMunicipal.isNotEmpty) _inscricaoMunicipalCtrl.text = inscricaoMunicipal;
      if (cnae.isNotEmpty) _cnaeCtrl.text = cnae;
    } else {
      _setTextIfEmpty(_razaoCtrl, razao);
      _setTextIfEmpty(_fantasiaCtrl, fantasia);
      _setTextIfEmpty(_ruaCtrl, endereco);
      _setTextIfEmpty(_numeroCtrl, numero);
      _setTextIfEmpty(_complementoCtrl, complemento);
      _setTextIfEmpty(_bairroCtrl, bairro);
      _setTextIfEmpty(_cepCtrl, cep);
      _setTextIfEmpty(_cidadeCtrl, cidade);
      _setTextIfEmpty(_ufCtrl, uf);
      _setTextIfEmpty(_telefoneCtrl, telefone);
      _setTextIfEmpty(_emailCtrl, email);
      _setTextIfEmpty(_responsavelCtrl, responsavel);
      _setTextIfEmpty(_cpfRespCtrl, cpfResp);
      _setTextIfEmpty(_inscricaoMunicipalCtrl, inscricaoMunicipal);
      _setTextIfEmpty(_cnaeCtrl, cnae);
    }

    final risco = _pick(data, ['risco', 'grauRisco', 'grau_risco']);
    if (risco.isNotEmpty && (_risco == 'Médio' || overwrite)) _risco = risco;

    final statusAlvara = _pick(data, ['statusAlvara', 'status_alvara']);
    if (statusAlvara.isNotEmpty && (_statusAlvara == 'Regular' || overwrite)) _statusAlvara = statusAlvara;

    final statusSanitario = _pick(data, ['statusSanitario', 'status_sanitario']);
    if (statusSanitario.isNotEmpty && (_statusSanitario == 'Regular' || overwrite)) _statusSanitario = statusSanitario;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cnpjCtrl.dispose();
    _razaoCtrl.dispose();
    _fantasiaCtrl.dispose();
    _inscricaoMunicipalCtrl.dispose();
    _cnaeCtrl.dispose();
    _ruaCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _bairroCtrl.dispose();
    _cepCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _responsavelCtrl.dispose();
    _cpfRespCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefillFromCnpj() async {
    final digits = _digitsOnly(_cnpjCtrl.text);
    if (digits.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CNPJ inválido. Digite 14 dígitos.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return;
    }
    if (_prefetchedCnpjDigits == digits) return;

    setState(() => _saving = true);
    try {
      await _api.init();
      final data = await _api.buscarEstabelecimentoPorCnpj(digits);

      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CNPJ não encontrado na e-Pública.'),
              backgroundColor: AppColors.vermelho,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _prefetchedCnpjDigits = digits;
          _applyPrefill(data, overwrite: false);
        });
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao buscar CNPJ: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar CNPJ: $e'),
            backgroundColor: AppColors.vermelho,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilledFromArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _applyPrefill(args, overwrite: true);
      });
      _prefilledFromArgs = true;
      final digits = _digitsOnly(_cnpjCtrl.text);
      final shouldFetch =
          digits.length == 14 &&
          (_isBlank(args['razaoSocial']) ||
              _isBlank(args['razao_social']) ||
              _isBlank(args['endereco']) ||
              _isBlank(args['logradouro']) ||
              _isBlank(args['cidade']) ||
              _isBlank(args['municipio']) ||
              _isBlank(args['estado']) ||
              _isBlank(args['uf']));
      if (shouldFetch) {
        Future.microtask(_prefillFromCnpj);
      }
    }
  }

  /// Valida o step atual
  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        return _dadosFormKey.currentState?.validate() ?? false;
      case 1:
        return _enderecoFormKey.currentState?.validate() ?? false;
      case 2:
        return _revisaoFormKey.currentState?.validate() ?? false;
      default:
        return false;
    }
  }

  /// Valida todos os dados obrigatórios antes de salvar
  bool _validateAllData() {
    // Validar CNPJ
    final cnpjDigits = _digitsOnly(_cnpjCtrl.text);
    if (cnpjDigits.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CNPJ inválido. Digite 14 dígitos.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }

    // Validar razão social ou nome fantasia
    if (_razaoCtrl.text.trim().isEmpty && _fantasiaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha Razão Social ou Nome Fantasia.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }

    // Validar endereço
    if (_ruaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logradouro é obrigatório.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }
    if (_numeroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Número é obrigatório.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }
    if (_bairroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bairro é obrigatório.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }
    if (_cidadeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cidade é obrigatória.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }
    if (_ufCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado é obrigatório.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }

    // Validar confirmação
    if (!_confirmacao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirme os dados para salvar.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _save() async {
    if (!_validateAllData()) {
      return;
    }

    setState(() => _saving = true);

    try {
      if (kIsWeb) {
        await _api.init();
        await _api.criarEstabelecimento(
          cnpj: _cnpjCtrl.text,
          razaoSocial: _razaoCtrl.text,
          nomeFantasia: _fantasiaCtrl.text,
          endereco: _ruaCtrl.text,
          numero: _numeroCtrl.text,
          cep: _cepCtrl.text,
          cidade: _cidadeCtrl.text,
          estado: _ufCtrl.text,
          bairro: _bairroCtrl.text.isEmpty ? null : _bairroCtrl.text,
          inscricaoMunicipal: _inscricaoMunicipalCtrl.text.isEmpty ? null : _inscricaoMunicipalCtrl.text,
          telefone: _telefoneCtrl.text.isEmpty ? null : _telefoneCtrl.text,
          email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
          responsavel: _responsavelCtrl.text.isEmpty ? null : _responsavelCtrl.text,
          cpfResponsavel: _cpfRespCtrl.text.isEmpty ? null : _cpfRespCtrl.text,
          risco: _risco,
          statusAlvara: _statusAlvara,
          statusSanitario: _statusSanitario,
          grauRisco: _risco,
          latitude: double.tryParse(_latCtrl.text),
          longitude: double.tryParse(_lngCtrl.text),
        );
      } else {
        final db = await LocalDb.instance;
        await db.insert('estabelecimentos', {
          'cnpj': _cnpjCtrl.text,
          'razao_social': _razaoCtrl.text,
          'nome_fantasia': _fantasiaCtrl.text,
          'cnae': _cnaeCtrl.text,
          'inscricao_municipal': _inscricaoMunicipalCtrl.text,
          'rua': _ruaCtrl.text,
          'numero': _numeroCtrl.text,
          'bairro': _bairroCtrl.text,
          'cep': _cepCtrl.text,
          'cidade': _cidadeCtrl.text,
          'uf': _ufCtrl.text,
          'telefone': _telefoneCtrl.text,
          'email': _emailCtrl.text,
          'responsavel': _responsavelCtrl.text,
          'cpf_responsavel': _cpfRespCtrl.text,
          'risco': _risco,
          'grau_risco': _risco,
          'status_sanitario': _statusSanitario,
          'data_cadastro': DateTime.now().toIso8601String(),
          'status_alvara': _statusAlvara,
          'lat': double.tryParse(_latCtrl.text),
          'lng': double.tryParse(_lngCtrl.text),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) print('Erro ao salvar estabelecimento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.vermelho,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Estabelecimento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
      ),
      body: Column(
        children: [
          StepHeader(labels: const ['Dados', 'Endereço', 'Revisão'], currentStep: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 0) _buildStepDados(),
                  if (_step == 1) _buildStepEndereco(),
                  if (_step == 2) _buildStepRevisao(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildWizardButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDados() {
    return Form(
      key: _dadosFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialCnpjField(
            controller: _cnpjCtrl,
            label: 'CNPJ',
            required: true,
            validator: (value) {
              final digits = _digitsOnly(value ?? '');
              if (digits.isEmpty) return 'CNPJ é obrigatório';
              if (digits.length != 14) return 'CNPJ inválido. Digite 14 dígitos';
              return null;
            },
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _razaoCtrl,
            label: 'Razão Social',
            required: false,
            validator: (value) {
              if (_fantasiaCtrl.text.trim().isEmpty && (value == null || value.trim().isEmpty)) {
                return 'Preencha Razão Social ou Nome Fantasia';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _fantasiaCtrl,
            label: 'Nome Fantasia',
            required: false,
            validator: (value) {
              if (_razaoCtrl.text.trim().isEmpty && (value == null || value.trim().isEmpty)) {
                return 'Preencha Razão Social ou Nome Fantasia';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _inscricaoMunicipalCtrl,
            label: 'Inscrição Municipal',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _cnaeCtrl,
            label: 'Atividade CNAE',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialPhoneField(
            controller: _telefoneCtrl,
            label: 'Telefone',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _emailCtrl,
            label: 'Email',
            required: false,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _responsavelCtrl,
            label: 'Responsável Legal',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialCpfField(
            controller: _cpfRespCtrl,
            label: 'CPF do Responsável',
            required: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepEndereco() {
    return Form(
      key: _enderecoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 600;
              if (narrow) {
                return Column(
                  children: [
                    OfficialTextField(
                      controller: _ruaCtrl,
                      label: 'Logradouro',
                      required: true,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Logradouro é obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _numeroCtrl,
                      label: 'Número',
                      required: true,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Número é obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _bairroCtrl,
                      label: 'Bairro',
                      required: true,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Bairro é obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _cepCtrl,
                      label: 'CEP',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _cidadeCtrl,
                      label: 'Cidade',
                      required: true,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Cidade é obrigatória' : null,
                    ),
                    const SizedBox(height: 12),
                    OfficialDropdownField.fromStrings(
                      label: 'Estado (UF)',
                      value: _ufCtrl.text.isEmpty ? null : _ufCtrl.text,
                      items: const ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'],
                      required: true,
                      onChanged: (value) {
                        if (value != null) {
                          _ufCtrl.text = value;
                        }
                      },
                      validator: (value) => value == null || value.trim().isEmpty ? 'Estado é obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _complementoCtrl,
                      label: 'Complemento',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OfficialTextField(
                            controller: _latCtrl,
                            label: 'Latitude',
                            required: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialTextField(
                            controller: _lngCtrl,
                            label: 'Longitude',
                            required: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OfficialTextField(
                            controller: _ruaCtrl,
                            label: 'Logradouro',
                            required: true,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Logradouro é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialTextField(
                            controller: _numeroCtrl,
                            label: 'Número',
                            required: true,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Número é obrigatório' : null,
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
                            required: true,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Bairro é obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialTextField(
                            controller: _cepCtrl,
                            label: 'CEP',
                            required: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OfficialTextField(
                            controller: _cidadeCtrl,
                            label: 'Cidade',
                            required: true,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Cidade é obrigatória' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialDropdownField.fromStrings(
                            label: 'Estado (UF)',
                            value: _ufCtrl.text.isEmpty ? null : _ufCtrl.text,
                            items: const ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'],
                            required: true,
                            onChanged: (value) {
                              if (value != null) {
                                _ufCtrl.text = value;
                              }
                            },
                            validator: (value) => value == null || value.trim().isEmpty ? 'Estado é obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _complementoCtrl,
                      label: 'Complemento',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OfficialDecimalField(
                            controller: _latCtrl,
                            label: 'Latitude',
                            required: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialDecimalField(
                            controller: _lngCtrl,
                            label: 'Longitude',
                            required: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          const Text('Dados Sanitários', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OfficialDropdownField.fromStrings(
                  label: 'Risco Sanitário',
                  value: _risco,
                  items: const ['Baixo', 'Médio', 'Alto'],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _risco = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OfficialDropdownField.fromStrings(
                  label: 'Situação do Alvará',
                  value: _statusAlvara,
                  items: const ['Regular', 'Vencido', 'Suspenso'],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _statusAlvara = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OfficialDropdownField.fromStrings(
            label: 'Status Sanitário',
            value: _statusSanitario,
            items: const ['Regular', 'Irregular'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _statusSanitario = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepRevisao() {
    return Form(
      key: _revisaoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewCard(),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _confirmacao,
            onChanged: (value) {
              setState(() => _confirmacao = value ?? false);
            },
            title: const Text('Confirmo que os dados estão corretos'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    final cnpjDigits = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do Cadastro', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildReviewSection('Dados Cadastrais', [
              _rowResumo('CNPJ', cnpjDigits.isEmpty ? 'Não informado' : _cnpjCtrl.text),
              _rowResumo('Razão Social', _razaoCtrl.text.isEmpty ? 'Não informado' : _razaoCtrl.text),
              _rowResumo('Nome Fantasia', _fantasiaCtrl.text.isEmpty ? 'Não informado' : _fantasiaCtrl.text),
              _rowResumo('Inscrição Municipal', _inscricaoMunicipalCtrl.text.isEmpty ? 'Não informado' : _inscricaoMunicipalCtrl.text),
              _rowResumo('CNAE', _cnaeCtrl.text.isEmpty ? 'Não informado' : _cnaeCtrl.text),
              _rowResumo('Telefone', _telefoneCtrl.text.isEmpty ? 'Não informado' : _telefoneCtrl.text),
              _rowResumo('Email', _emailCtrl.text.isEmpty ? 'Não informado' : _emailCtrl.text),
              _rowResumo('Responsável', _responsavelCtrl.text.isEmpty ? 'Não informado' : _responsavelCtrl.text),
              _rowResumo('CPF Responsável', _cpfRespCtrl.text.isEmpty ? 'Não informado' : _cpfRespCtrl.text),
            ]),
            const SizedBox(height: 16),
            _buildReviewSection('Endereço', [
              _rowResumo('Logradouro', _ruaCtrl.text.isEmpty ? 'Não informado' : _ruaCtrl.text),
              _rowResumo('Número', _numeroCtrl.text.isEmpty ? 'Não informado' : _numeroCtrl.text),
              _rowResumo('Complemento', _complementoCtrl.text.isEmpty ? 'Não informado' : _complementoCtrl.text),
              _rowResumo('Bairro', _bairroCtrl.text.isEmpty ? 'Não informado' : _bairroCtrl.text),
              _rowResumo('CEP', _cepCtrl.text.isEmpty ? 'Não informado' : _cepCtrl.text),
              _rowResumo('Cidade', _cidadeCtrl.text.isEmpty ? 'Não informado' : _cidadeCtrl.text),
              _rowResumo('Estado', _ufCtrl.text.isEmpty ? 'Não informado' : _ufCtrl.text),
              _rowResumo('Latitude', _latCtrl.text.isEmpty ? 'Não informado' : _latCtrl.text),
              _rowResumo('Longitude', _lngCtrl.text.isEmpty ? 'Não informado' : _lngCtrl.text),
            ]),
            const SizedBox(height: 16),
            _buildReviewSection('Dados Sanitários', [
              _rowResumo('Risco Sanitário', _risco),
              _rowResumo('Situação do Alvará', _statusAlvara),
              _rowResumo('Status Sanitário', _statusSanitario),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulInstitucional)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _rowResumo(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildWizardButtons() {
    final canBack = _step > 0 && !_saving;
    final isLast = _step == 2;
    final canNext = !_saving;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: canBack ? () => setState(() => _step -= 1) : null,
            child: const Text('Voltar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: canNext
                ? () async {
                    if (!_validateCurrentStep()) {
                      return;
                    }
                    if (isLast) {
                      await _save();
                      return;
                    }
                    setState(() => _step += 1);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLast ? 'Salvar' : 'Continuar'),
          ),
        ),
      ],
    );
  }
}

class CnpjInputFormatter extends TextInputFormatter {
  static String format(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 14 ? digits.substring(0, 14) : digits;
    final b = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 5) b.write('.');
      if (i == 8) b.write('/');
      if (i == 12) b.write('-');
      b.write(limited[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final next = format(newValue.text);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

