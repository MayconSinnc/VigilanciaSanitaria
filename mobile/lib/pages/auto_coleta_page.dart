import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import '../ui/theme.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/inspection_header.dart';
import '../widgets/official_form_fields.dart';

class AutoColetaPage extends StatefulWidget {
  const AutoColetaPage({super.key});

  @override
  State<AutoColetaPage> createState() => _AutoColetaPageState();
}

class _AutoColetaPageState extends State<AutoColetaPage> {
  int _currentStep = 0;
  final List<String> _steps = [
    'Dados',
    'Amostra',
    'Análise',
    'Evidências',
    'Revisão',
    'Assinatura',
  ];

  // GlobalKeys para validação por step
  final _dadosFormKey = GlobalKey<FormState>();
  final _amostraFormKey = GlobalKey<FormState>();
  final _analiseFormKey = GlobalKey<FormState>();
  final _evidenciasFormKey = GlobalKey<FormState>();
  final _assinaturaFormKey = GlobalKey<FormState>();

  // Estado de revisão confirmada
  bool _revisaoConfirmada = false;

  bool _argsLoaded = false;
  String _numeroColeta = '';
  DateTime _dataColeta = DateTime.now();
  TimeOfDay _horaColeta = TimeOfDay.now();
  String _razaoSocial = '';
  String _nomeFantasia = '';
  String _cnpj = '';
  String _inscricaoMunicipal = '';
  String _endereco = '';
  String _telefone = '';
  String? _responsavelEstabelecimento;
  bool _possuiPastaVisa = false;
  final TextEditingController _numeroPastaVisaCtrl = TextEditingController();

  // Controllers persistentes
  final _fiscalResponsavelCtrl = TextEditingController();
  final _matriculaFiscalCtrl = TextEditingController();
  final _respNomeCtrl = TextEditingController();
  final _respCpfCtrl = TextEditingController();
  final _respCargoCtrl = TextEditingController();
  final _respTelefoneCtrl = TextEditingController();

  final _nomeProdutoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _fabricanteCtrl = TextEditingController();
  final _cnpjFabricanteCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _dataFabricacaoCtrl = TextEditingController();
  final _dataValidadeCtrl = TextEditingController();
  final _quantidadeColetadaCtrl = TextEditingController();
  final _temperaturaCtrl = TextEditingController();
  final _numeroLacreCtrl = TextEditingController();
  final _quantidadeContraprovaCtrl = TextEditingController();

  final _enderecoLaboratorioCtrl = TextEditingController();
  final _observacoesColetaCtrl = TextEditingController();
  final _motivoRecusaCtrl = TextEditingController();

  String _tipoAmostra = 'Alimento';
  final List<String> _tiposAmostra = [
    'Alimento',
    'Água',
    'Bebida',
    'Medicamento',
    'Cosmético',
    'Produto saneante',
    'Outro',
  ];

  String _unidadeMedida = 'unidade';
  final List<String> _unidadesMedida = [
    'unidade',
    'kg',
    'g',
    'L',
    'ml',
    'pacote',
    'caixa',
    'frasco',
  ];

  String _temperatura = '';
  String _condicaoAmostra = 'Ambiente';
  final List<String> _condicoesAmostra = [
    'Ambiente',
    'Refrigerada',
    'Congelada',
    'Lacrada',
    'Violada',
    'Deteriorada',
  ];

  bool _amostraContraprova = false;

  String _motivoColeta = 'Fiscalização de rotina';
  final List<String> _motivosColeta = [
    'Fiscalização de rotina',
    'Denúncia',
    'Suspeita de contaminação',
    'Produto vencido',
    'Análise de qualidade',
    'Surto alimentar',
    'Outro',
  ];

  final List<String> _tiposAnaliseSelecionados = [];
  final List<String> _tiposAnalise = [
    'Microbiológica',
    'Físico-química',
    'Toxicológica',
    'Rotulagem',
    'Potabilidade',
    'Outra',
  ];

  String _laboratorioDestino = 'LACEN';
  final List<String> _laboratorios = [
    'LACEN',
    'Laboratório Municipal',
    'Laboratório credenciado',
    'Outro',
  ];

  DateTime? _dataFabricacao;
  DateTime? _dataValidade;

  final List<Uint8List> _evidencias = [];
  final List<String> _descricoesEvidencias = [];
  double? _latitude;
  double? _longitude;
  String _enderecoGps = '';

  Uint8List? _assinaturaFiscal;
  Uint8List? _assinaturaResponsavel;
  bool _recusouAssinar = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    // Dispose controllers
    _fiscalResponsavelCtrl.dispose();
    _matriculaFiscalCtrl.dispose();
    _respNomeCtrl.dispose();
    _respCpfCtrl.dispose();
    _respCargoCtrl.dispose();
    _respTelefoneCtrl.dispose();
    _numeroPastaVisaCtrl.dispose();
    _nomeProdutoCtrl.dispose();
    _marcaCtrl.dispose();
    _fabricanteCtrl.dispose();
    _cnpjFabricanteCtrl.dispose();
    _loteCtrl.dispose();
    _dataFabricacaoCtrl.dispose();
    _dataValidadeCtrl.dispose();
    _quantidadeColetadaCtrl.dispose();
    _temperaturaCtrl.dispose();
    _numeroLacreCtrl.dispose();
    _quantidadeContraprovaCtrl.dispose();
    _enderecoLaboratorioCtrl.dispose();
    _observacoesColetaCtrl.dispose();
    _motivoRecusaCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dataFabricacao = DateTime.now();
    _dataValidade = DateTime.now();
    _generateNumeroColeta();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _nomeFantasia = args['nome'] as String? ?? '';
        _cnpj = args['cnpj'] as String? ?? '';
        _razaoSocial = args['razaoSocial'] as String? ?? '';
        _endereco = args['endereco'] as String? ?? '';
        _telefone = args['telefone'] as String? ?? '';
        _responsavelEstabelecimento = args['responsavel'] as String?;
        _inscricaoMunicipal = args['inscricaoMunicipal'] as String? ?? '';
      });
    }
    _argsLoaded = true;
  }

  void _generateNumeroColeta() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    setState(() {
      _numeroColeta = 'COL-${now.year}-$seq';
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate(Function(DateTime) onSelected, DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      onSelected(picked);
    }
  }

  Future<void> _pickTime(Function(TimeOfDay) onSelected, TimeOfDay initialTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null && mounted) {
      onSelected(picked);
    }
  }

  Future<void> _captureLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço de localização desativado.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização permanentemente negada.')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _enderecoGps = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lon: ${position.longitude.toStringAsFixed(6)}';
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _evidencias.add(bytes);
        _descricoesEvidencias.add('');
      });
    }
  }

  void _removeEvidence(int index) {
    setState(() {
      _evidencias.removeAt(index);
      _descricoesEvidencias.removeAt(index);
    });
  }

  /// Valida apenas o step atual usando o GlobalKey correspondente
  bool _validateCurrentStep() {
    GlobalKey<FormState>? currentFormKey;

    switch (_currentStep) {
      case 0:
        currentFormKey = _dadosFormKey;
        break;
      case 1:
        currentFormKey = _amostraFormKey;
        break;
      case 2:
        currentFormKey = _analiseFormKey;
        break;
      case 3:
        currentFormKey = _evidenciasFormKey;
        break;
      case 4:
        // Step de revisão não tem validação de campos
        if (!_revisaoConfirmada) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Confirme a revisão antes de continuar'),
              backgroundColor: AppColors.vermelho,
            ),
          );
          return false;
        }
        return true;
      case 5:
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
            backgroundColor: AppColors.vermelho,
          ),
        );
      }
      return isValid;
    }

    return true;
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AUTO DE COLETA PARA AMOSTRA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_numeroColeta.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _numeroColeta,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          OfficialStepper(
            currentStep: _currentStep,
            steps: _steps,
            onStepTapped: (step) {
              if (step <= _currentStep) {
                setState(() {
                  _currentStep = step;
                });
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentStep > 0 ? _previousStep : null,
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
                    onPressed: _currentStep == _steps.length - 1 ? _save : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verde,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_currentStep == _steps.length - 1 ? 'Salvar' : 'Continuar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepDados();
      case 1:
        return _buildStepAmostra();
      case 2:
        return _buildStepAnalise();
      case 3:
        return _buildStepEvidencias();
      case 4:
        return _buildStepRevisao();
      case 5:
        return _buildStepAssinatura();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepDados() {
    return Form(
      key: _dadosFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InspectionHeader(
            prefeitura: 'Prefeitura Municipal de Balneário Camboriú',
            departamento: 'Departamento de Vigilância Sanitária',
          ),
          const SizedBox(height: 16),
          EstablishmentCard(
            razaoSocial: _razaoSocial,
            nomeFantasia: _nomeFantasia,
            cnpj: _cnpj,
            inscricaoMunicipal: _inscricaoMunicipal,
            endereco: _endereco,
            telefone: _telefone,
            responsavel: _responsavelEstabelecimento,
          ),
          const SizedBox(height: 16),
          OfficialSectionCard(
            title: 'Pasta VISA',
            icon: Icons.folder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Possui Pasta VISA?'),
                  value: _possuiPastaVisa,
                  onChanged: (v) {
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
                    label: 'Número da Pasta VISA',
                    controller: _numeroPastaVisaCtrl,
                    required: true,
                    validator: (v) {
                      if (!_possuiPastaVisa) return null;
                      if ((v ?? '').trim().isEmpty) return 'Informe o número da Pasta VISA.';
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          OfficialSectionCard(
            title: 'Dados da Coleta',
            icon: Icons.description,
            child: Column(
              children: [
                OfficialTextField(
                  label: 'Número do Auto de Coleta',
                  controller: TextEditingController(text: _numeroColeta),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialTextField(
                        label: 'Data da Coleta',
                        controller: TextEditingController(text: _formatDate(_dataColeta)),
                        readOnly: true,
                        onTap: () => _pickDate((d) => setState(() => _dataColeta = d), _dataColeta),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OfficialTextField(
                        label: 'Hora da Coleta',
                        controller: TextEditingController(text: _horaColeta.format(context)),
                        readOnly: true,
                        onTap: () => _pickTime((t) => setState(() => _horaColeta = t), _horaColeta),
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OfficialSectionCard(
            title: 'Fiscal Responsável',
            icon: Icons.person,
            child: Column(
              children: [
                OfficialTextField(
                  controller: _fiscalResponsavelCtrl,
                  label: 'Nome do Fiscal',
                  required: true,
                ),
                const SizedBox(height: 12),
                OfficialNumericField(
                  controller: _matriculaFiscalCtrl,
                  label: 'Matrícula',
                  required: true,
                ),
              ],
            ),
          ),
          OfficialSectionCard(
            title: 'Responsável Presente',
            icon: Icons.person_outline,
            child: Column(
              children: [
                OfficialTextField(
                  controller: _respNomeCtrl,
                  label: 'Nome',
                  required: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialCpfField(
                        controller: _respCpfCtrl,
                        label: 'CPF',
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepAmostra() {
    return Form(
      key: _amostraFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialSectionCard(
            title: 'Dados da Amostra',
            icon: Icons.inventory,
            child: Column(
              children: [
                OfficialDropdownField<String>(
                  value: _tipoAmostra,
                  items: _tiposAmostra.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _tipoAmostra = v ?? 'Alimento'),
                  label: 'Tipo de Amostra',
                  required: true,
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _nomeProdutoCtrl,
                  label: 'Nome do Produto/Amostra',
                  required: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialTextField(
                        controller: _marcaCtrl,
                        label: 'Marca',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OfficialTextField(
                        controller: _fabricanteCtrl,
                        label: 'Fabricante',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OfficialCnpjField(
                  controller: _cnpjFabricanteCtrl,
                  label: 'CNPJ do Fabricante',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialTextField(
                        controller: _loteCtrl,
                        label: 'Lote',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OfficialTextField(
                        label: 'Data de Fabricação',
                        readOnly: true,
                        controller: TextEditingController(text: _dataFabricacao != null ? _formatDate(_dataFabricacao!) : ''),
                        onTap: () => _pickDate((d) => setState(() => _dataFabricacao = d), DateTime.now()),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  label: 'Data de Validade',
                  readOnly: true,
                  controller: TextEditingController(text: _dataValidade != null ? _formatDate(_dataValidade!) : ''),
                  onTap: () => _pickDate((d) => setState(() => _dataValidade = d), DateTime.now()),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialTextField(
                        controller: _quantidadeColetadaCtrl,
                        label: 'Quantidade Coletada',
                        required: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OfficialDropdownField<String>(
                        value: _unidadeMedida,
                        items: _unidadesMedida.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _unidadeMedida = v ?? 'unidade'),
                        label: 'Unidade de Medida',
                        required: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_condicaoAmostra == 'Refrigerada' || _condicaoAmostra == 'Congelada')
                  OfficialTextField(
                    controller: _temperaturaCtrl,
                    label: 'Temperatura no Momento da Coleta',
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                if (_condicaoAmostra == 'Refrigerada' || _condicaoAmostra == 'Congelada') const SizedBox(height: 12),
                OfficialDropdownField<String>(
                  value: _condicaoAmostra,
                  items: _condicoesAmostra.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _condicaoAmostra = v ?? 'Ambiente'),
                  label: 'Condição da Amostra',
                  required: true,
                ),
                const SizedBox(height: 12),
                if (_condicaoAmostra == 'Lacrada')
                  OfficialTextField(
                    controller: _numeroLacreCtrl,
                    label: 'Número do Lacre',
                    required: true,
                  ),
                if (_condicaoAmostra == 'Lacrada') const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Amostra em Contraprova?'),
                  value: _amostraContraprova,
                  onChanged: (v) => setState(() => _amostraContraprova = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_amostraContraprova) ...[
                  const SizedBox(height: 12),
                  OfficialTextField(
                    controller: _quantidadeContraprovaCtrl,
                    label: 'Quantidade de Contraprova',
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepAnalise() {
    return Form(
      key: _analiseFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialSectionCard(
            title: 'Motivo e Tipo de Análise',
            icon: Icons.search,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfficialDropdownField<String>(
                  value: _motivoColeta,
                  items: _motivosColeta.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _motivoColeta = v ?? 'Fiscalização de rotina'),
                  label: 'Motivo da Coleta',
                  required: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipo de Análise Solicitada *',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._tiposAnalise.map((tipo) {
                  return CheckboxListTile(
                    title: Text(tipo),
                    value: _tiposAnaliseSelecionados.contains(tipo),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _tiposAnaliseSelecionados.add(tipo);
                        } else {
                          _tiposAnaliseSelecionados.remove(tipo);
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
                const SizedBox(height: 12),
                OfficialDropdownField<String>(
                  value: _laboratorioDestino,
                  items: _laboratorios.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _laboratorioDestino = v ?? 'LACEN'),
                  label: 'Laboratório de Destino',
                  required: true,
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _enderecoLaboratorioCtrl,
                  label: 'Endereço/Identificação do Laboratório',
                ),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: _observacoesColetaCtrl,
                  label: 'Observações da Coleta',
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
            ),
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
          OfficialSectionCard(
            title: 'Evidências',
            icon: Icons.camera_alt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tirar Foto'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galeria'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulClaro),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_evidencias.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _evidencias.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: MemoryImage(_evidencias[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeEvidence(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OfficialSectionCard(
            title: 'Geolocalização',
            icon: Icons.location_on,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _captureLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Capturar Localização Atual'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional),
                ),
                const SizedBox(height: 16),
                if (_latitude != null && _longitude != null) ...[
                  OfficialTextField(
                    label: 'Latitude',
                    controller: TextEditingController(text: _latitude.toString()),
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  OfficialTextField(
                    label: 'Longitude',
                    controller: TextEditingController(text: _longitude.toString()),
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  OfficialTextField(
                    label: 'Endereço Aproximado',
                    controller: TextEditingController(text: _enderecoGps),
                    readOnly: true,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRevisao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.verde, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Revisão do Auto de Coleta',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.azulInstitucional,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildReviewSection('Dados da Coleta', [
                  _buildReviewRow('Número', _numeroColeta),
                  _buildReviewRow('Data', _formatDate(_dataColeta)),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Amostra', [
                  _buildReviewRow('Tipo', _tipoAmostra),
                  _buildReviewRow('Produto', _nomeProdutoCtrl.text),
                  _buildReviewRow('Lote', _loteCtrl.text),
                  if (_dataValidade != null) _buildReviewRow('Validade', _formatDate(_dataValidade!)),
                  _buildReviewRow('Quantidade', '${_quantidadeColetadaCtrl.text} $_unidadeMedida'),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Análise', [
                  _buildReviewRow('Motivo', _motivoColeta),
                  _buildReviewRow('Tipos de Análise', _tiposAnaliseSelecionados.join(', ')),
                  _buildReviewRow('Laboratório', _laboratorioDestino),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Evidências', [
                  _buildReviewRow('Fotos', '${_evidencias.length}'),
                ]),
                const SizedBox(height: 24),
                CheckboxListTile(
                  title: const Text(
                    'Confirmo que os dados acima estão corretos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _revisaoConfirmada,
                  onChanged: (v) => setState(() => _revisaoConfirmada = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
          OfficialSectionCard(
            title: 'Assinatura do Fiscal',
            icon: Icons.edit,
            child: Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _assinaturaFiscal != null
                      ? Image.memory(_assinaturaFiscal!)
                      : const Center(child: Text('Toque para assinar')),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/assinatura').then((result) {
                      if (result != null && result is Uint8List) {
                        setState(() {
                          _assinaturaFiscal = result;
                        });
                      }
                    });
                  },
                  icon: const Icon(Icons.draw),
                  label: const Text('Assinar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OfficialSectionCard(
            title: 'Assinatura do Responsável',
            icon: Icons.person,
            child: Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _assinaturaResponsavel != null
                      ? Image.memory(_assinaturaResponsavel!)
                      : const Center(child: Text('Toque para assinar')),
                ),
                const SizedBox(height: 12),
                if (!_recusouAssinar)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/assinatura').then((result) {
                        if (result != null && result is Uint8List) {
                          setState(() {
                            _assinaturaResponsavel = result;
                          });
                        }
                      });
                    },
                    icon: const Icon(Icons.draw),
                    label: const Text('Assinar'),
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Responsável recusou assinar'),
                  value: _recusouAssinar,
                  onChanged: (v) => setState(() => _recusouAssinar = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_recusouAssinar) ...[
                  const SizedBox(height: 12),
                  OfficialMultilineField(
                    controller: _motivoRecusaCtrl,
                    label: 'Motivo/Observação da Recusa',
                    required: true,
                    minLines: 2,
                    maxLines: 4,
                    validator: (value) {
                      if (_recusouAssinar && (value == null || value.trim().isEmpty)) {
                        return 'Campo obrigatório quando houver recusa';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.azulInstitucional,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildReviewRow(String label, String value, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: multiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
    final estab = <String, dynamic>{
      'nomeFantasia': _nomeFantasia,
      'razaoSocial': _razaoSocial,
      'cnpj': _cnpj,
      'endereco': _endereco,
      'telefone': _telefone,
      'inscricaoMunicipal': _inscricaoMunicipal,
    }..removeWhere((_, v) => (v ?? '').toString().trim().isEmpty);

    await Navigator.pushNamed(
      context,
      '/relatorio-inspecao-sanitario',
      arguments: {
        if (estab.isNotEmpty) 'estabelecimento': estab,
        'documento_vinculado': {
          'tipo_documento': payload['tipo_documento'] ?? 'AUTO_COLETA',
          'numero_ano': payload['numero_ano'] ?? payload['numero_auto'] ?? payload['numero'] ?? _numeroColeta,
          'payload': payload,
        },
      },
    );
  }

  Map<String, dynamic> _buildPayload() {
    return <String, dynamic>{
      'tipo_documento': 'AUTO_COLETA',
      'numero_ano': _numeroColeta,
      'data_lavratura': _dataColeta.toIso8601String().substring(0, 10),
      'dados_estabelecimento': {
        'nome_fantasia': _nomeFantasia,
        'razao_social': _razaoSocial,
        'cnpj': _cnpj,
        'inscricao_municipal': _inscricaoMunicipal,
        'endereco': _endereco,
        'telefone': _telefone,
        'possui_pasta_visa': _possuiPastaVisa,
        'numero_pasta_visa': _possuiPastaVisa ? _numeroPastaVisaCtrl.text.trim() : '',
      },
    };
  }

  Future<void> _save() async {
    // Validar todos os dados obrigatórios antes de salvar
    if (!_validateAllData()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto de Coleta salvo com sucesso!'),
        backgroundColor: AppColors.verde,
      ),
    );
    final payload = _buildPayload();
    final abrir = await _perguntarAbrirRelatorioInspecao();
    if (!mounted) return;
    if (abrir) {
      await _abrirRelatorioInspecao(payload);
      if (!mounted) return;
    }
    Navigator.of(context).pop(true);
  }

  /// Valida todos os dados obrigatórios antes de salvar
  bool _validateAllData() {
    // Validar dados
    if (_fiscalResponsavelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do fiscal é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_matriculaFiscalCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matrícula do fiscal é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_respNomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do responsável é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_possuiPastaVisa && _numeroPastaVisaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número da Pasta VISA é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar amostra
    if (_nomeProdutoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do produto/amostra é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_quantidadeColetadaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade coletada é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_condicaoAmostra == 'Refrigerada' || _condicaoAmostra == 'Congelada') {
      if (_temperaturaCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temperatura é obrigatória para amostras refrigeradas ou congeladas'), backgroundColor: AppColors.vermelho),
        );
        return false;
      }
    }
    if (_condicaoAmostra == 'Lacrada' && _numeroLacreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número do lacre é obrigatório para amostras lacradas'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_amostraContraprova && _quantidadeContraprovaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade de contraprova é obrigatória quando amostra em contraprova'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar análise
    if (_tiposAnaliseSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um tipo de análise'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar evidências
    if (_evidencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos uma foto da amostra'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_condicaoAmostra == 'Violada' || _condicaoAmostra == 'Deteriorada') {
      if (_evidencias.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adicione pelo menos 2 evidências para amostras violadas ou deterioradas'), backgroundColor: AppColors.vermelho),
        );
        return false;
      }
    }

    // Validar assinatura do fiscal
    if (_assinaturaFiscal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura do fiscal é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar assinatura do responsável ou recusa
    if (!_recusouAssinar && _assinaturaResponsavel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura do responsável é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_recusouAssinar && _motivoRecusaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Motivo da recusa é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    return true;
  }
}
