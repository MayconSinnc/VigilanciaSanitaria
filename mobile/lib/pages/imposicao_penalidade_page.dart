import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import '../ui/theme.dart';
import '../widgets/official_components.dart' hide OfficialTextField;
import '../widgets/inspection_header.dart';
import '../widgets/official_form_fields.dart';

class ImposicaoPenalidadePage extends StatefulWidget {
  const ImposicaoPenalidadePage({super.key});

  @override
  State<ImposicaoPenalidadePage> createState() => _ImposicaoPenalidadePageState();
}

class _ImposicaoPenalidadePageState extends State<ImposicaoPenalidadePage> {
  int _currentStep = 0;
  final List<String> _steps = [
    'Identificação',
    'Penalidade',
    'Fundamentação',
    'Evidências',
    'Revisão',
    'Assinatura',
  ];

  // GlobalKeys para validação por step
  final _identificacaoFormKey = GlobalKey<FormState>();
  final _penalidadeFormKey = GlobalKey<FormState>();
  final _fundamentacaoFormKey = GlobalKey<FormState>();
  final _evidenciasFormKey = GlobalKey<FormState>();
  final _assinaturaFormKey = GlobalKey<FormState>();

  // Estado de revisão confirmada
  bool _revisaoConfirmada = false;

  bool _argsLoaded = false;
  String _numeroImposicao = '';
  DateTime _dataEmissao = DateTime.now();
  TimeOfDay _horaEmissao = TimeOfDay.now();
  String _razaoSocial = '';
  String _nomeFantasia = '';
  String _cnpj = '';
  String _inscricaoMunicipal = '';
  String _endereco = '';
  String _telefone = '';
  String? _responsavelEstabelecimento;

  // Controllers persistentes
  final _fiscalResponsavelCtrl = TextEditingController();
  final _matriculaFiscalCtrl = TextEditingController();
  final _autoInfracaoCtrl = TextEditingController();
  final _numeroProcessoCtrl = TextEditingController();
  final _dataProcessoCtrl = TextEditingController();

  final _tipoPenalidadeCtrl = TextEditingController(text: 'Advertência');
  final _descricaoPenalidadeCtrl = TextEditingController();
  final _valorMultaCtrl = TextEditingController();
  final _dataVencimentoMultaCtrl = TextEditingController();
  final _prazoCumprimentoCtrl = TextEditingController();
  final _formaCumprimentoCtrl = TextEditingController();

  final _fundamentacaoLegalCtrl = TextEditingController();
  final _artigoCtrl = TextEditingController();
  final _incisoCtrl = TextEditingController();
  final _decisaoAdministrativaCtrl = TextEditingController();
  final _autoridadeJulgadoraCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  final _motivoRecusaCtrl = TextEditingController();

  String _autoInfracaoSelecionado = '';
  final List<String> _autosDisponiveis = ['INF-2026-000001', 'INF-2026-000002', 'INF-2026-000003'];
  DateTime? _dataProcesso;

  String _tipoPenalidade = 'Advertência';
  final List<String> _tiposPenalidade = [
    'Advertência',
    'Multa',
    'Interdição',
    'Apreensão',
    'Inutilização de produto',
    'Cancelamento de alvará/licença',
    'Suspensão de atividade',
  ];

  DateTime? _dataVencimentoMulta;

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
    _autoInfracaoCtrl.dispose();
    _numeroProcessoCtrl.dispose();
    _dataProcessoCtrl.dispose();
    _tipoPenalidadeCtrl.dispose();
    _descricaoPenalidadeCtrl.dispose();
    _valorMultaCtrl.dispose();
    _dataVencimentoMultaCtrl.dispose();
    _prazoCumprimentoCtrl.dispose();
    _formaCumprimentoCtrl.dispose();
    _fundamentacaoLegalCtrl.dispose();
    _artigoCtrl.dispose();
    _incisoCtrl.dispose();
    _decisaoAdministrativaCtrl.dispose();
    _autoridadeJulgadoraCtrl.dispose();
    _observacoesCtrl.dispose();
    _motivoRecusaCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _generateNumeroImposicao();
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

  void _generateNumeroImposicao() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    setState(() {
      _numeroImposicao = 'PEN-${now.year}-$seq';
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
        currentFormKey = _identificacaoFormKey;
        break;
      case 1:
        currentFormKey = _penalidadeFormKey;
        break;
      case 2:
        currentFormKey = _fundamentacaoFormKey;
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
        title: const Text('IMPOSIÇÃO DE PENALIDADE'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_numeroImposicao.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _numeroImposicao,
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
                      backgroundColor: AppColors.laranja,
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
        return _buildStepIdentificacao();
      case 1:
        return _buildStepPenalidade();
      case 2:
        return _buildStepFundamentacao();
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

  Widget _buildStepIdentificacao() {
    return Form(
      key: _identificacaoFormKey,
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
            title: 'Dados da Imposição',
            icon: Icons.description,
            child: Column(
              children: [
                OfficialTextField(
                  label: 'Número da Imposição',
                  controller: TextEditingController(text: _numeroImposicao),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialTextField(
                        label: 'Data da Emissão',
                        controller: TextEditingController(text: _formatDate(_dataEmissao)),
                        readOnly: true,
                        onTap: () => _pickDate((d) => setState(() => _dataEmissao = d), _dataEmissao),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OfficialTextField(
                        label: 'Hora',
                        controller: TextEditingController(text: _horaEmissao.format(context)),
                        readOnly: true,
                        onTap: () => _pickTime((t) => setState(() => _horaEmissao = t), _horaEmissao),
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OfficialSectionCard(
            title: 'Fiscal/Autoridade Responsável',
            icon: Icons.person,
            child: Column(
              children: [
                OfficialTextField(
                  controller: _fiscalResponsavelCtrl,
                  label: 'Nome',
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
            title: 'Auto de Infração Vinculado',
            icon: Icons.link,
            child: Column(
              children: [
                OfficialDropdownField<String>(
                  value: _autoInfracaoSelecionado.isEmpty ? null : _autoInfracaoSelecionado,
                  items: _autosDisponiveis.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _autoInfracaoSelecionado = v ?? ''),
                  label: 'Selecione o Auto',
                  required: true,
                ),
              ],
            ),
          ),
          OfficialSectionCard(
            title: 'Processo Administrativo',
            icon: Icons.folder,
            child: Column(
              children: [
                OfficialTextField(
                  controller: _numeroProcessoCtrl,
                  label: 'Número do Processo',
                  required: true,
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  label: 'Data do Processo',
                  readOnly: true,
                  controller: TextEditingController(text: _dataProcesso != null ? _formatDate(_dataProcesso!) : ''),
                  onTap: () => _pickDate((d) => setState(() => _dataProcesso = d), DateTime.now()),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPenalidade() {
    return Form(
      key: _penalidadeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialSectionCard(
            title: 'Penalidade Aplicada',
            icon: Icons.gavel,
            child: Column(
              children: [
                OfficialDropdownField<String>(
                  value: _tipoPenalidade,
                  items: _tiposPenalidade.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _tipoPenalidade = v ?? 'Advertência'),
                  label: 'Tipo de Penalidade',
                  required: true,
                ),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: _descricaoPenalidadeCtrl,
                  label: 'Descrição da Penalidade',
                  required: true,
                  minLines: 3,
                  maxLines: 5,
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
                if (_tipoPenalidade == 'Multa') ...[
                  OfficialMoneyField(
                    controller: _valorMultaCtrl,
                    label: 'Valor da Multa',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  OfficialTextField(
                    label: 'Data de Vencimento',
                    required: true,
                    readOnly: true,
                    controller: TextEditingController(text: _dataVencimentoMulta != null ? _formatDate(_dataVencimentoMulta!) : ''),
                    onTap: () => _pickDate((d) => setState(() => _dataVencimentoMulta = d), DateTime.now().add(const Duration(days: 30))),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  const SizedBox(height: 12),
                ],
                OfficialNumericField(
                  controller: _prazoCumprimentoCtrl,
                  label: 'Prazo para Cumprimento (dias)',
                  required: true,
                  minValue: 1,
                ),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: _formaCumprimentoCtrl,
                  label: 'Forma de Cumprimento',
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepFundamentacao() {
    return Form(
      key: _fundamentacaoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OfficialSectionCard(
            title: 'Fundamentação e Decisão',
            icon: Icons.balance,
            child: Column(
              children: [
                OfficialMultilineField(
                  controller: _fundamentacaoLegalCtrl,
                  label: 'Fundamentação Legal',
                  required: true,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OfficialTextField(
                        controller: _artigoCtrl,
                        label: 'Artigo',
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OfficialTextField(
                        controller: _incisoCtrl,
                        label: 'Inciso',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: _decisaoAdministrativaCtrl,
                  label: 'Decisão Administrativa',
                  required: true,
                  minLines: 4,
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (value.trim().length < 20) {
                      return 'Mínimo de 20 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: _autoridadeJulgadoraCtrl,
                  label: 'Autoridade Julgadora/Responsável',
                  required: true,
                ),
                const SizedBox(height: 12),
                OfficialMultilineField(
                  controller: _observacoesCtrl,
                  label: 'Observações',
                  minLines: 2,
                  maxLines: 4,
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
            title: 'Evidências e Anexos',
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
                      'Revisão da Imposição de Penalidade',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.azulInstitucional,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildReviewSection('Dados da Imposição', [
                  _buildReviewRow('Número', _numeroImposicao),
                  _buildReviewRow('Data', _formatDate(_dataEmissao)),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Auto de Infração', [
                  _buildReviewRow('Auto Vinculado', _autoInfracaoSelecionado),
                  _buildReviewRow('Processo', _numeroProcessoCtrl.text),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Penalidade', [
                  _buildReviewRow('Tipo', _tipoPenalidade),
                  _buildReviewRow('Descrição', _descricaoPenalidadeCtrl.text, multiline: true),
                  if (_valorMultaCtrl.text.isNotEmpty) _buildReviewRow('Valor Multa', 'R\$ ${_valorMultaCtrl.text}'),
                  _buildReviewRow('Prazo Cumprimento', '${_prazoCumprimentoCtrl.text} dias'),
                ]),
                const SizedBox(height: 16),
                _buildReviewSection('Fundamentação', [
                  _buildReviewRow('Fundamentação', _fundamentacaoLegalCtrl.text, multiline: true),
                  _buildReviewRow('Decisão', _decisaoAdministrativaCtrl.text, multiline: true),
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
            title: 'Assinatura da Autoridade/Fiscal',
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

  void _save() {
    // Validar todos os dados obrigatórios antes de salvar
    if (!_validateAllData()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imposição de Penalidade salva com sucesso!'),
        backgroundColor: AppColors.verde,
      ),
    );
    Navigator.of(context).pop();
  }

  /// Valida todos os dados obrigatórios antes de salvar
  bool _validateAllData() {
    // Validar identificação
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
    if (_autoInfracaoSelecionado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto de infração vinculado é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_numeroProcessoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número do processo é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar penalidade
    if (_descricaoPenalidadeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descrição da penalidade é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_descricaoPenalidadeCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descrição deve ter no mínimo 10 caracteres'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_tipoPenalidade == 'Multa' && _valorMultaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor da multa é obrigatório quando a penalidade é Multa'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_prazoCumprimentoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prazo para cumprimento é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    // Validar fundamentação
    if (_fundamentacaoLegalCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fundamentação legal é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_artigoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artigo é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_decisaoAdministrativaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Decisão administrativa é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_decisaoAdministrativaCtrl.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Decisão administrativa deve ter no mínimo 20 caracteres'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_autoridadeJulgadoraCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autoridade julgadora é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
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

    // Validar evidências para interdição
    if (_tipoPenalidade == 'Interdição' && _evidencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos uma evidência para interdição'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }

    return true;
  }
}
