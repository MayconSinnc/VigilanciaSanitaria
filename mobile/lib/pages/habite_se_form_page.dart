import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/step_header.dart';
import '../widgets/official_form_fields.dart';

class HabiteSeFormPage extends StatefulWidget {
  const HabiteSeFormPage({super.key});

  @override
  State<HabiteSeFormPage> createState() => _HabiteSeFormPageState();
}

class _HabiteSeFormPageState extends State<HabiteSeFormPage> {
  // GlobalKeys para validação por step
  final _identificacaoFormKey = GlobalKey<FormState>();
  final _imovelFormKey = GlobalKey<FormState>();
  final _responsaveisFormKey = GlobalKey<FormState>();
  final _vistoriaFormKey = GlobalKey<FormState>();
  final _evidenciasFormKey = GlobalKey<FormState>();
  final _revisaoFormKey = GlobalKey<FormState>();
  final _assinaturaFormKey = GlobalKey<FormState>();

  // Step 1 - Identificação
  final _protocoloCtrl = TextEditingController();
  String _tipoSolicitacao = 'HABITESE_SANITARIO';
  final _dataSolicitacaoCtrl = TextEditingController();
  String _situacaoInicial = 'EM_ANALISE';

  // Step 2 - Dados do Imóvel
  final _nomeEmpreendimentoCtrl = TextEditingController();
  final _cnpjCpfCtrl = TextEditingController();
  final _inscricaoMunicipalCtrl = TextEditingController();
  final _logradouroCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  String _tipoImovel = 'RESIDENCIAL';
  final _areaConstruidaCtrl = TextEditingController();
  final _pavimentosCtrl = TextEditingController();

  // Step 3 - Responsáveis
  final _responsavelTecnicoCtrl = TextEditingController();
  final _creaCauCtrl = TextEditingController();
  final _telefoneTecnicoCtrl = TextEditingController();
  final _emailTecnicoCtrl = TextEditingController();
  final _fiscalResponsavelCtrl = TextEditingController();
  final _matriculaFiscalCtrl = TextEditingController();

  // Step 4 - Vistoria
  final _dataVistoriaCtrl = TextEditingController();
  final _horaVistoriaCtrl = TextEditingController();
  TimeOfDay? _horaVistoria;
  final _situacaoEncontradaCtrl = TextEditingController();
  final _parecerPreliminarCtrl = TextEditingController();
  final _pendenciasCtrl = TextEditingController();
  String _riscoSanitario = 'MEDIO';

  // Step 5 - Evidências
  final _observacoesCtrl = TextEditingController();

  // Step 6 - Revisão
  bool _confirmacao = false;

  // Step 7 - Assinatura
  Uint8List? _assinaturaFiscal;
  Uint8List? _assinaturaResponsavel;

  // State
  int _step = 0;
  bool _saving = false;
  String _usuarioNomeLogado = '';

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _dataSolicitacaoCtrl.text = today;
    _dataVistoriaCtrl.text = today;
    _protocoloCtrl.text = _generateProtocolo();
    _prefillUsuarioLogado();
  }

  Future<void> _prefillUsuarioLogado() async {
    try {
      final nome = (await _api.readPreference('usuario_nome'))?.trim() ?? '';
      if (!mounted) return;
      if (nome.isEmpty) return;
      setState(() => _usuarioNomeLogado = nome);
      _responsavelTecnicoCtrl.text = nome;
    } catch (_) {}
  }

  @override
  void dispose() {
    _protocoloCtrl.dispose();
    _dataSolicitacaoCtrl.dispose();
    _nomeEmpreendimentoCtrl.dispose();
    _cnpjCpfCtrl.dispose();
    _inscricaoMunicipalCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    _cepCtrl.dispose();
    _areaConstruidaCtrl.dispose();
    _pavimentosCtrl.dispose();
    _responsavelTecnicoCtrl.dispose();
    _creaCauCtrl.dispose();
    _telefoneTecnicoCtrl.dispose();
    _emailTecnicoCtrl.dispose();
    _fiscalResponsavelCtrl.dispose();
    _matriculaFiscalCtrl.dispose();
    _dataVistoriaCtrl.dispose();
    _horaVistoriaCtrl.dispose();
    _situacaoEncontradaCtrl.dispose();
    _parecerPreliminarCtrl.dispose();
    _pendenciasCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  String _generateProtocolo() {
    final year = DateTime.now().year;
    final random = (DateTime.now().millisecondsSinceEpoch % 999999).toString().padLeft(6, '0');
    return 'HB-$year-$random';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Valida o step atual
  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        return _identificacaoFormKey.currentState?.validate() ?? false;
      case 1:
        return _imovelFormKey.currentState?.validate() ?? false;
      case 2:
        return _responsaveisFormKey.currentState?.validate() ?? false;
      case 3:
        return _vistoriaFormKey.currentState?.validate() ?? false;
      case 4:
        return _evidenciasFormKey.currentState?.validate() ?? false;
      case 5:
        return _revisaoFormKey.currentState?.validate() ?? false;
      case 6:
        return _assinaturaFormKey.currentState?.validate() ?? false;
      default:
        return false;
    }
  }

  /// Valida todos os dados obrigatórios antes de salvar
  bool _validateAllData() {
    // Validar Step 1
    if (_tipoSolicitacao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tipo de solicitação é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_dataSolicitacaoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data da solicitação é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar Step 2
    if (_nomeEmpreendimentoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do empreendimento é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_logradouroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logradouro é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_numeroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_bairroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bairro é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_cidadeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cidade é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_tipoImovel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tipo de imóvel é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar Step 3
    if (_usuarioNomeLogado.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário logado não identificado. Faça login novamente.'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_fiscalResponsavelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fiscal responsável é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar Step 4
    if (_situacaoEncontradaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Situação encontrada é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_parecerPreliminarCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parecer preliminar é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar Step 6
    if (!_confirmacao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirme os dados para salvar'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar Step 7
    if (_assinaturaFiscal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura do fiscal é obrigatória'), backgroundColor: AppColors.vermelho),
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
      final payload = {
        'protocolo': _protocoloCtrl.text,
        'tipo': _tipoSolicitacao,
        'status': _situacaoInicial,
        'data_solicitacao': _dataSolicitacaoCtrl.text,
        'empreendimento': {
          'nome': _nomeEmpreendimentoCtrl.text,
          'cnpj': _cnpjCpfCtrl.text.trim().isEmpty ? null : _cnpjCpfCtrl.text,
          'inscricao_municipal': _inscricaoMunicipalCtrl.text.trim().isEmpty ? null : _inscricaoMunicipalCtrl.text,
        },
        'endereco': {
          'logradouro': _logradouroCtrl.text,
          'numero': _numeroCtrl.text,
          'complemento': _complementoCtrl.text.trim().isEmpty ? null : _complementoCtrl.text,
          'bairro': _bairroCtrl.text,
          'cidade': _cidadeCtrl.text,
          'estado': _ufCtrl.text,
          'cep': _cepCtrl.text.trim().isEmpty ? null : _cepCtrl.text,
        },
        'imovel': {
          'tipo': _tipoImovel,
          'area_construida': double.tryParse(_areaConstruidaCtrl.text),
          'pavimentos': int.tryParse(_pavimentosCtrl.text),
        },
        'responsavel_tecnico': {
          'nome': _usuarioNomeLogado.trim(),
          'crea': _creaCauCtrl.text.trim().isEmpty ? null : _creaCauCtrl.text,
          'telefone': _telefoneTecnicoCtrl.text.trim().isEmpty ? null : _telefoneTecnicoCtrl.text,
          'email': _emailTecnicoCtrl.text.trim().isEmpty ? null : _emailTecnicoCtrl.text,
        },
        'fiscal_responsavel': {
          'nome': _fiscalResponsavelCtrl.text,
          'matricula': _matriculaFiscalCtrl.text.trim().isEmpty ? null : _matriculaFiscalCtrl.text,
        },
        'vistoria': {
          'data': _dataVistoriaCtrl.text.trim().isEmpty ? null : _dataVistoriaCtrl.text,
          'hora': _horaVistoriaCtrl.text.trim().isEmpty ? null : _horaVistoriaCtrl.text,
          'situacao_encontrada': _situacaoEncontradaCtrl.text,
          'parecer': _parecerPreliminarCtrl.text,
          'pendencias': _pendenciasCtrl.text.trim().isEmpty ? null : _pendenciasCtrl.text,
          'risco_sanitario': _riscoSanitario,
        },
        'evidencias': {
          'observacoes': _observacoesCtrl.text.trim().isEmpty ? null : _observacoesCtrl.text,
        },
        'assinaturas': {
          'fiscal': _assinaturaFiscal != null ? 'assinatura_capturada' : null,
          'responsavel': _assinaturaResponsavel != null ? 'assinatura_capturada' : null,
        },
        'status_sincronizacao': kIsWeb ? 'SINCRONIZADO' : 'PENDENTE_SINCRONIZACAO',
      };

      if (kIsWeb) {
        await _api.init();
        await _api.criarHabiteSe(payload);
      } else {
        final db = await LocalDb.instance;
        await db.insert('habite_se', {
          'protocolo': _protocoloCtrl.text,
          'tipo': _tipoSolicitacao,
          'status': _situacaoInicial,
          'data_solicitacao': _dataSolicitacaoCtrl.text,
          'nome_empreendimento': _nomeEmpreendimentoCtrl.text,
          'cnpj': _cnpjCpfCtrl.text,
          'endereco': _logradouroCtrl.text,
          'numero': _numeroCtrl.text,
          'bairro': _bairroCtrl.text,
          'cidade': _cidadeCtrl.text,
          'uf': _ufCtrl.text,
          'responsavel': _usuarioNomeLogado.trim(),
          'data_cadastro': DateTime.now().toIso8601String(),
          ...payload,
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) print('Erro ao salvar habite-se: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.vermelho),
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
        title: const Text('Nova Solicitação - Habite-se Sanitário'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
      ),
      body: Column(
        children: [
          StepHeader(labels: const ['Identificação', 'Imóvel', 'Responsáveis', 'Vistoria', 'Evidências', 'Revisão', 'Assinatura'], currentStep: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 0) _buildStepIdentificacao(),
                  if (_step == 1) _buildStepImovel(),
                  if (_step == 2) _buildStepResponsaveis(),
                  if (_step == 3) _buildStepVistoria(),
                  if (_step == 4) _buildStepEvidencias(),
                  if (_step == 5) _buildStepRevisao(),
                  if (_step == 6) _buildStepAssinatura(),
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

  Widget _buildStepIdentificacao() {
    return Form(
      key: _identificacaoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialTextField(
            controller: _protocoloCtrl,
            label: 'Número do Protocolo',
            required: false,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          OfficialDropdownField.fromStrings(
            label: 'Tipo da Solicitação',
            value: _tipoSolicitacao,
            items: const ['HABITESE_SANITARIO', 'HABITESE_COMERCIAL', 'HABITESE_RESIDENCIAL'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _tipoSolicitacao = value);
              }
            },
          ),
          const SizedBox(height: 12),
          OfficialDateField(
            controller: _dataSolicitacaoCtrl,
            label: 'Data da Solicitação',
            required: true,
          ),
          const SizedBox(height: 12),
          OfficialDropdownField.fromStrings(
            label: 'Situação Inicial',
            value: _situacaoInicial,
            items: const ['EM_ANALISE', 'PENDENTE', 'VISTORIA_AGENDADA'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _situacaoInicial = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepImovel() {
    return Form(
      key: _imovelFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dados do Empreendimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _nomeEmpreendimentoCtrl,
            label: 'Nome do Empreendimento',
            required: true,
          ),
          const SizedBox(height: 12),
          OfficialCnpjField(
            controller: _cnpjCpfCtrl,
            label: 'CNPJ/CPF',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _inscricaoMunicipalCtrl,
            label: 'Inscrição Municipal',
            required: false,
          ),
          const SizedBox(height: 16),
          const Text('Endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 600;
              if (narrow) {
                return Column(
                  children: [
                    OfficialTextField(
                      controller: _logradouroCtrl,
                      label: 'Logradouro',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _numeroCtrl,
                      label: 'Número',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _bairroCtrl,
                      label: 'Bairro',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    OfficialCepField(
                      controller: _cepCtrl,
                      label: 'CEP',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _cidadeCtrl,
                      label: 'Cidade',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    OfficialDropdownField.fromStrings(
                      label: 'Estado (UF)',
                      value: _ufCtrl.text.isEmpty ? null : _ufCtrl.text,
                      items: const ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'],
                      onChanged: (value) {
                        if (value != null) {
                          _ufCtrl.text = value;
                        }
                      },
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
                            controller: _logradouroCtrl,
                            label: 'Logradouro',
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialTextField(
                            controller: _numeroCtrl,
                            label: 'Número',
                            required: true,
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialCepField(
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialDropdownField.fromStrings(
                            label: 'Estado (UF)',
                            value: _ufCtrl.text.isEmpty ? null : _ufCtrl.text,
                            items: const ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'],
                            onChanged: (value) {
                              if (value != null) {
                                _ufCtrl.text = value;
                              }
                            },
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
          OfficialTextField(
            controller: _complementoCtrl,
            label: 'Complemento',
            required: false,
          ),
          const SizedBox(height: 16),
          const Text('Dados do Imóvel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          OfficialDropdownField.fromStrings(
            label: 'Tipo de Imóvel',
            value: _tipoImovel,
            items: const ['RESIDENCIAL', 'COMERCIAL', 'MISTO', 'INDUSTRIAL'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _tipoImovel = value);
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OfficialDecimalField(
                  controller: _areaConstruidaCtrl,
                  label: 'Área Construída (m²)',
                  required: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OfficialNumericField(
                  controller: _pavimentosCtrl,
                  label: 'Pavimentos',
                  required: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepResponsaveis() {
    return Form(
      key: _responsaveisFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Responsável Técnico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Técnico responsável logado', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_usuarioNomeLogado.trim().isEmpty ? 'Não identificado' : _usuarioNomeLogado.trim()),
                ],
              ),
            ),
          ),
          FormField<bool>(
            validator: (_) => _usuarioNomeLogado.trim().isEmpty ? 'Usuário logado não identificado. Faça login novamente.' : null,
            builder: (state) {
              if (state.errorText == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(state.errorText!, style: const TextStyle(color: AppColors.vermelho)),
              );
            },
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _creaCauCtrl,
            label: 'CREA/CAU',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialPhoneField(
            controller: _telefoneTecnicoCtrl,
            label: 'Telefone',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _emailTecnicoCtrl,
            label: 'Email',
            required: false,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          const Text('Fiscal Responsável', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _fiscalResponsavelCtrl,
            label: 'Nome do Fiscal Responsável',
            required: true,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _matriculaFiscalCtrl,
            label: 'Matrícula Fiscal',
            required: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepVistoria() {
    return Form(
      key: _vistoriaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialDateField(
            controller: _dataVistoriaCtrl,
            label: 'Data da Vistoria',
            required: false,
          ),
          const SizedBox(height: 12),
          OfficialTimeField(
            value: _horaVistoria,
            label: 'Hora da Vistoria',
            required: false,
            onChanged: (picked) {
              setState(() => _horaVistoria = picked);
              _horaVistoriaCtrl.text = picked == null ? '' : _formatTime(picked);
            },
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _situacaoEncontradaCtrl,
            label: 'Situação Encontrada',
            required: true,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _parecerPreliminarCtrl,
            label: 'Parecer Preliminar',
            required: true,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OfficialTextField(
            controller: _pendenciasCtrl,
            label: 'Pendências',
            required: false,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OfficialDropdownField.fromStrings(
            label: 'Risco Sanitário',
            value: _riscoSanitario,
            items: const ['BAIXO', 'MEDIO', 'ALTO'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _riscoSanitario = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepEvidencias() {
    return Form(
      key: _evidenciasFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload de Evidências', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text('Arraste arquivos ou clique para upload'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funcionalidade de upload será implementada.')),
                      );
                    },
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Adicionar Fotos'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OfficialTextField(
            controller: _observacoesCtrl,
            label: 'Observações',
            required: false,
            maxLines: 5,
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo da Solicitação', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildReviewSection('Identificação', [
              _rowResumo('Protocolo', _protocoloCtrl.text.isEmpty ? 'Não informado' : _protocoloCtrl.text),
              _rowResumo('Tipo', _tipoSolicitacao),
              _rowResumo('Data', _dataSolicitacaoCtrl.text.isEmpty ? 'Não informado' : _dataSolicitacaoCtrl.text),
              _rowResumo('Situação', _situacaoInicial),
            ]),
            const SizedBox(height: 16),
            _buildReviewSection('Empreendimento', [
              _rowResumo('Nome', _nomeEmpreendimentoCtrl.text.isEmpty ? 'Não informado' : _nomeEmpreendimentoCtrl.text),
              _rowResumo('CNPJ/CPF', _cnpjCpfCtrl.text.isEmpty ? 'Não informado' : _cnpjCpfCtrl.text),
              _rowResumo('Inscrição Municipal', _inscricaoMunicipalCtrl.text.isEmpty ? 'Não informado' : _inscricaoMunicipalCtrl.text),
            ]),
            const SizedBox(height: 16),
            _buildReviewSection('Endereço', [
              _rowResumo('Logradouro', _logradouroCtrl.text.isEmpty ? 'Não informado' : _logradouroCtrl.text),
              _rowResumo('Número', _numeroCtrl.text.isEmpty ? 'Não informado' : _numeroCtrl.text),
              _rowResumo('Bairro', _bairroCtrl.text.isEmpty ? 'Não informado' : _bairroCtrl.text),
              _rowResumo('Cidade', _cidadeCtrl.text.isEmpty ? 'Não informado' : _cidadeCtrl.text),
              _rowResumo('Estado', _ufCtrl.text.isEmpty ? 'Não informado' : _ufCtrl.text),
            ]),
            const SizedBox(height: 16),
            _buildReviewSection('Responsáveis', [
              _rowResumo('Responsável Técnico', _usuarioNomeLogado.trim().isEmpty ? 'Não informado' : _usuarioNomeLogado.trim()),
              _rowResumo('CREA/CAU', _creaCauCtrl.text.isEmpty ? 'Não informado' : _creaCauCtrl.text),
              _rowResumo('Fiscal Responsável', _fiscalResponsavelCtrl.text.isEmpty ? 'Não informado' : _fiscalResponsavelCtrl.text),
            ]),
            const SizedBox(height: 16),
            _buildReviewSection('Vistoria', [
              _rowResumo('Situação Encontrada', _situacaoEncontradaCtrl.text.isEmpty ? 'Não informado' : _situacaoEncontradaCtrl.text),
              _rowResumo('Parecer', _parecerPreliminarCtrl.text.isEmpty ? 'Não informado' : _parecerPreliminarCtrl.text),
              _rowResumo('Risco Sanitário', _riscoSanitario),
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

  Widget _buildStepAssinatura() {
    return Form(
      key: _assinaturaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assinatura do Fiscal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _assinaturaFiscal != null
                        ? Center(child: Text('Assinatura capturada'))
                        : Center(child: Text('Área de assinatura', style: TextStyle(color: Colors.grey[400]))),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Funcionalidade de assinatura será implementada.')),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Assinar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _assinaturaFiscal = null);
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Assinatura do Responsável (Opcional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _assinaturaResponsavel != null
                        ? Center(child: Text('Assinatura capturada'))
                        : Center(child: Text('Área de assinatura', style: TextStyle(color: Colors.grey[400]))),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Funcionalidade de assinatura será implementada.')),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Assinar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _assinaturaResponsavel = null);
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardButtons() {
    final canBack = _step > 0 && !_saving;
    final isLast = _step == 6;
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
