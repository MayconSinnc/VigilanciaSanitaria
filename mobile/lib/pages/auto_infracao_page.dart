import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import '../ui/theme.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/official_form_fields.dart';
import '../widgets/inspection_header.dart';

class AutoInfracaoPage extends StatefulWidget {
  const AutoInfracaoPage({super.key});

  @override
  State<AutoInfracaoPage> createState() => _AutoInfracaoPageState();
}

class _AutoInfracaoPageState extends State<AutoInfracaoPage> {
  int _currentStep = 0;
  final List<String> _steps = [
    'Dados',
    'Infração',
    'Legal',
    'Medidas',
    'Evidências',
    'Revisão',
    'Assinatura',
  ];

  bool _argsLoaded = false;
  String _numeroAuto = '';
  DateTime _dataLavratura = DateTime.now();
  TimeOfDay _horaLavratura = TimeOfDay.now();
  String _fiscalResponsavel = '';
  String _matriculaFiscal = '';
  String _razaoSocial = '';
  String _nomeFantasia = '';
  String _cnpj = '';
  String _inscricaoMunicipal = '';
  String _endereco = '';
  String _telefone = '';
  String? _responsavelEstabelecimento;
  String _respNome = '';
  String _respCpf = '';
  String _respCargo = '';
  String _respTelefone = '';

  String _tipoInfracao = 'Higiênico-sanitária';
  final List<String> _tiposInfracao = [
    'Higiênico-sanitária',
    'Documental',
    'Estrutural',
    'Produto impróprio',
    'Armazenamento inadequado',
    'Funcionamento irregular',
    'Outro',
  ];
  String _descricaoInfracao = '';
  String _situacaoEncontrada = '';
  String _localOcorrencia = '';
  String _gravidade = 'Leve';
  final List<String> _gravidades = ['Leve', 'Média', 'Grave', 'Gravíssima'];
  bool _reincidencia = false;
  String _autosAnteriores = '';

  String _baseLegal = 'Lei Federal 6.437/1977';
  final List<String> _basesLegais = [
    'Lei Federal 6.437/1977',
    'Código Sanitário Municipal',
    'RDC Anvisa',
    'Decreto Municipal',
    'Outra',
  ];
  String _artigo = '';
  String _inciso = '';
  String _paragrafo = '';
  String _descricaoLegal = '';
  String _observacoesLegais = '';

  final List<String> _medidasAdotadas = [];
  final List<String> _medidasDisponiveis = [
    'Advertência',
    'Apreensão',
    'Interdição cautelar',
    'Inutilização/descarte',
    'Orientação',
    'Encaminhamento para processo administrativo',
  ];
  String _penalidadeSugerida = 'Advertência';
  final List<String> _penalidades = [
    'Advertência',
    'Multa',
    'Interdição',
    'Apreensão',
    'Cancelamento de licença/alvará',
  ];
  String _valorMulta = '';
  String _prazoDefesa = '15';
  String _prazoRegularizacao = '';
  bool _necessitaRetorno = false;
  DateTime? _dataRetorno;

  final List<Uint8List> _evidencias = [];
  final List<String> _descricoesEvidencias = [];
  double? _latitude;
  double? _longitude;
  String _enderecoGps = '';

  Uint8List? _assinaturaFiscal;
  Uint8List? _assinaturaResponsavel;
  bool _recusouAssinar = false;
  String _motivoRecusa = '';

  final _picker = ImagePicker();

  final _dadosFormKey = GlobalKey<FormState>();
  final _infracaoFormKey = GlobalKey<FormState>();
  final _legalFormKey = GlobalKey<FormState>();
  final _medidasFormKey = GlobalKey<FormState>();

  late final TextEditingController _prazoDefesaCtrl;

  @override
  void initState() {
    super.initState();
    _prazoDefesaCtrl = TextEditingController(text: _prazoDefesa);
    _generateNumeroAuto();
  }

  @override
  void dispose() {
    _prazoDefesaCtrl.dispose();
    super.dispose();
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
        _situacaoEncontrada = args['situacaoEncontrada'] as String? ?? '';
      });
    }
    _argsLoaded = true;
  }

  void _generateNumeroAuto() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    setState(() {
      _numeroAuto = 'INF-${now.year}-$seq';
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

  String? _validateDescricaoInfracao(String? value) {
    final descricao = (value ?? _descricaoInfracao).trim();
    final situacao = _situacaoEncontrada.trim();
    if (descricao.length >= 5) return null;
    if (situacao.length >= 5) return null;
    return 'Preencha a descrição detalhada (mín. 5 caracteres) ou a situação encontrada';
  }

  bool _validateCurrentStep() {
    GlobalKey<FormState>? formKey;
    String? extraMessage;

    switch (_currentStep) {
      case 0:
        formKey = _dadosFormKey;
        break;
      case 1:
        formKey = _infracaoFormKey;
        extraMessage =
            'Preencha a descrição detalhada ou a situação encontrada (mín. 5 caracteres).';
        break;
      case 2:
        formKey = _legalFormKey;
        break;
      case 3:
        formKey = _medidasFormKey;
        if (_penalidadeSugerida == 'Multa' && _valorMulta.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informe o valor estimado da multa.'),
              backgroundColor: AppColors.vermelho,
            ),
          );
          return false;
        }
        break;
      case 4:
        return true;
      case 5:
        return true;
      case 6:
        if (_assinaturaFiscal == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assinatura do fiscal é obrigatória.'),
              backgroundColor: AppColors.vermelho,
            ),
          );
          return false;
        }
        return true;
      default:
        return true;
    }

    if (formKey != null) {
      final isValid = formKey.currentState?.validate() ?? false;
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              extraMessage ?? 'Corrija os campos destacados antes de continuar.',
            ),
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AUTO DE INFRAÇÃO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_numeroAuto.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _numeroAuto,
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
              if (step < _currentStep) {
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
                      backgroundColor: AppColors.vermelho,
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
        return _buildStepInfracao();
      case 2:
        return _buildStepLegal();
      case 3:
        return _buildStepMedidas();
      case 4:
        return _buildStepEvidencias();
      case 5:
        return _buildStepRevisao();
      case 6:
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
          title: 'Dados do Auto',
          icon: Icons.description,
          child: Column(
            children: [
              OfficialTextField(
                label: 'Número do Auto',
                controller: TextEditingController(text: _numeroAuto),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      label: 'Data da Lavratura',
                      controller: TextEditingController(text: _formatDate(_dataLavratura)),
                      readOnly: true,
                      onTap: () => _pickDate((d) => setState(() => _dataLavratura = d), _dataLavratura),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      label: 'Hora da Lavratura',
                      controller: TextEditingController(text: _horaLavratura.format(context)),
                      readOnly: true,
                      onTap: () => _pickTime((t) => setState(() => _horaLavratura = t), _horaLavratura),
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
                label: 'Nome do Fiscal',
                required: true,
                onChanged: (v) => setState(() => _fiscalResponsavel = v),
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Matrícula',
                required: true,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _matriculaFiscal = v),
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
                label: 'Nome',
                required: true,
                onChanged: (v) => setState(() => _respNome = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      label: 'CPF',
                      keyboardType: TextInputType.number,
                      inputFormatters: [CpfInputFormatter()],
                      onChanged: (v) => setState(() => _respCpf = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      label: 'Cargo/Função',
                      onChanged: (v) => setState(() => _respCargo = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Telefone',
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                onChanged: (v) => setState(() => _respTelefone = v),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildStepInfracao() {
    return Form(
      key: _infracaoFormKey,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OfficialSectionCard(
          title: 'Descrição da Infração',
          icon: Icons.report_problem,
          child: Column(
            children: [
              OfficialDropdown(
                label: 'Tipo de Infração',
                items: _tiposInfracao,
                value: _tipoInfracao,
                onChanged: (v) => setState(() => _tipoInfracao = v!),
                required: true,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Descrição Detalhada',
                required: true,
                maxLines: 5,
                hint: 'Descreva a infração (mín. 5 caracteres)',
                onChanged: (v) => setState(() => _descricaoInfracao = v),
                validator: _validateDescricaoInfracao,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Situação Encontrada',
                maxLines: 3,
                hint: 'Alternativa à descrição detalhada (mín. 5 caracteres)',
                onChanged: (v) {
                  setState(() => _situacaoEncontrada = v);
                  _infracaoFormKey.currentState?.validate();
                },
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Local da Ocorrência',
                hint: 'Ex: cozinha, depósito, área de manipulação',
                onChanged: (v) => setState(() => _localOcorrencia = v),
              ),
              const SizedBox(height: 12),
              OfficialDropdown(
                label: 'Gravidade',
                items: _gravidades,
                value: _gravidade,
                onChanged: (v) => setState(() => _gravidade = v!),
                required: true,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Reincidência?'),
                value: _reincidencia,
                onChanged: (v) => setState(() => _reincidencia = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_reincidencia) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  label: 'Autos Anteriores Relacionados',
                  maxLines: 3,
                  onChanged: (v) => setState(() => _autosAnteriores = v),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildStepLegal() {
    return Form(
      key: _legalFormKey,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OfficialSectionCard(
          title: 'Fundamentação Legal',
          icon: Icons.gavel,
          child: Column(
            children: [
              OfficialDropdown(
                label: 'Base Legal',
                items: _basesLegais,
                value: _baseLegal,
                onChanged: (v) => setState(() => _baseLegal = v!),
                required: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OfficialTextField(
                      label: 'Artigo',
                      required: true,
                      onChanged: (v) => setState(() => _artigo = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      label: 'Inciso',
                      onChanged: (v) => setState(() => _inciso = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OfficialTextField(
                      label: 'Parágrafo',
                      onChanged: (v) => setState(() => _paragrafo = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Descrição da Fundamentação Legal',
                maxLines: 4,
                onChanged: (v) => setState(() => _descricaoLegal = v),
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Observações Legais',
                maxLines: 3,
                onChanged: (v) => setState(() => _observacoesLegais = v),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildStepMedidas() {
    return Form(
      key: _medidasFormKey,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OfficialSectionCard(
          title: 'Medidas Adotadas no Ato',
          icon: Icons.assignment_turned_in,
          child: Column(
            children: _medidasDisponiveis.map((medida) {
              return CheckboxListTile(
                title: Text(medida),
                value: _medidasAdotadas.contains(medida),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _medidasAdotadas.add(medida);
                    } else {
                      _medidasAdotadas.remove(medida);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        OfficialSectionCard(
          title: 'Penalidade Sugerida',
          icon: Icons.balance,
          child: Column(
            children: [
              OfficialDropdown(
                label: 'Tipo de Penalidade',
                items: _penalidades,
                value: _penalidadeSugerida,
                onChanged: (v) => setState(() => _penalidadeSugerida = v!),
                required: true,
              ),
              const SizedBox(height: 12),
              if (_penalidadeSugerida == 'Multa')
                OfficialTextField(
                  label: 'Valor Estimado da Multa',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() => _valorMulta = v),
                ),
              if (_penalidadeSugerida == 'Multa') const SizedBox(height: 12),
              OfficialTextField(
                label: 'Prazo para Defesa (dias)',
                required: true,
                keyboardType: TextInputType.number,
                controller: _prazoDefesaCtrl,
                onChanged: (v) => setState(() => _prazoDefesa = v),
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                label: 'Prazo para Regularização (dias)',
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _prazoRegularizacao = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Necessita retorno de fiscalização?'),
                value: _necessitaRetorno,
                onChanged: (v) => setState(() => _necessitaRetorno = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_necessitaRetorno) ...[
                const SizedBox(height: 12),
                OfficialTextField(
                  label: 'Data Prevista para Retorno',
                  readOnly: true,
                  controller: TextEditingController(text: _dataRetorno != null ? _formatDate(_dataRetorno!) : ''),
                  onTap: () => _pickDate((d) => setState(() => _dataRetorno = d), DateTime.now()),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildStepEvidencias() {
    return Column(
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
                      'Revisão do Auto de Infração',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.azulInstitucional,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildReviewSection('Dados do Auto', [
                  _buildReviewRow('Número', _numeroAuto),
                  _buildReviewRow('Data', _formatDate(_dataLavratura)),
                  _buildReviewRow('Hora', _horaLavratura.format(context)),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Fiscal', [
                  _buildReviewRow('Nome', _fiscalResponsavel),
                  _buildReviewRow('Matrícula', _matriculaFiscal),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Responsável Presente', [
                  _buildReviewRow('Nome', _respNome),
                  _buildReviewRow('CPF', _respCpf),
                  _buildReviewRow('Cargo', _respCargo),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Infração', [
                  _buildReviewRow('Tipo', _tipoInfracao),
                  _buildReviewRow('Gravidade', _gravidade),
                  _buildReviewRow('Descrição', _descricaoInfracao, multiline: true),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Fundamentação Legal', [
                  _buildReviewRow('Base Legal', _baseLegal),
                  _buildReviewRow('Artigo', _artigo),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Medidas e Penalidade', [
                  _buildReviewRow('Penalidade', _penalidadeSugerida),
                  if (_valorMulta.isNotEmpty) _buildReviewRow('Valor Multa', 'R\$ $_valorMulta'),
                  _buildReviewRow('Prazo Defesa', '$_prazoDefesa dias'),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Evidências', [
                  _buildReviewRow('Fotos', '${_evidencias.length}'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepAssinatura() {
    return Column(
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
                OfficialTextField(
                  label: 'Motivo/Observação da Recusa',
                  maxLines: 3,
                  onChanged: (v) => setState(() => _motivoRecusa = v),
                ),
              ],
            ],
          ),
        ),
      ],
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
            width: 120,
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

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto de Infração salvo com sucesso!'),
        backgroundColor: AppColors.verde,
      ),
    );
    Navigator.of(context).pop();
  }
}
