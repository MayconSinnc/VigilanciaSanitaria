import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class EstablishmentDetailPage extends StatefulWidget {
  const EstablishmentDetailPage({super.key});

  @override
  State<EstablishmentDetailPage> createState() => _EstablishmentDetailPageState();
}

class _EstablishmentDetailPageState extends State<EstablishmentDetailPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _editFormKey = GlobalKey<FormState>();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _responsavelLocalCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();

  late final TabController _tabController;
  bool _loaded = false;
  bool _loading = true;
  bool _saving = false;
  bool _capturingLocation = false;
  bool _refreshingEpublica = false;
  int? _estabId;
  Map<String, dynamic>? _estab;
  Map<String, dynamic>? _epublica;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _responsavelLocalCtrl.dispose();
    _observacoesCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  Future<void> _load() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final passed = args?['estabelecimento'];
    final passedMap = passed is Map ? Map<String, dynamic>.from(passed) : <String, dynamic>{};
    final id = (args?['id'] as num?)?.toInt() ?? (passedMap['id'] as num?)?.toInt();

    setState(() => _loading = true);

    Map<String, dynamic> merged = {...passedMap};
    if (id != null && !kIsWeb) {
      final db = await LocalDb.instance;
      final rows = await db.query('estabelecimentos', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isNotEmpty) {
        merged = _mergeMap(merged, rows.first);
      }
    }

    final cnpj = _digitsOnly((merged['cnpj'] ?? '').toString());
    Map<String, dynamic>? detalhe;
    if (cnpj.isNotEmpty) {
      detalhe = await _api.buscarEstabelecimentoDetalhe(cnpj);
      if (detalhe != null) {
        merged = _mergeMap(merged, detalhe);
      }
    }

    if (!mounted) return;
    _estabId = id ?? (merged['id'] as num?)?.toInt();
    _estab = merged.isEmpty ? null : merged;
    _epublica = detalhe;
    _populateEditFields();
    setState(() => _loading = false);
  }

  Map<String, dynamic> _mergeMap(Map<String, dynamic> base, Map<String, dynamic> extra) {
    final merged = Map<String, dynamic>.from(base);
    for (final entry in extra.entries) {
      final value = entry.value;
      if (!_hasValue(merged[entry.key]) && _hasValue(value)) {
        merged[entry.key] = value;
      } else if (!_hasValue(merged[entry.key]) && value == false) {
        merged[entry.key] = value;
      } else if (_hasValue(value) && value is Map && merged[entry.key] is Map) {
        merged[entry.key] = _mergeMap(
          Map<String, dynamic>.from(merged[entry.key] as Map),
          Map<String, dynamic>.from(value),
        );
      } else if (_hasValue(value) || value == false) {
        merged[entry.key] = value;
      }
    }
    return merged;
  }

  bool _hasValue(Object? value) {
    if (value == null) return false;
    if (value is String) {
      final text = value.trim().toLowerCase();
      return text.isNotEmpty && text != 'null' && text != '-' && text != '--' && text != '()';
    }
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }

  void _populateEditFields() {
    final e = _estab ?? {};
    _telefoneCtrl.text = _stringValue([e['telefone']]);
    _emailCtrl.text = _stringValue([e['email']]);
    _responsavelLocalCtrl.text = _stringValue([
      e['responsavel_local'],
      e['complemento'] is Map ? (e['complemento'] as Map)['responsavel_local'] : null,
      e['responsavel'],
    ]);
    _observacoesCtrl.text = _stringValue([
      e['observacoes'],
      e['complemento'] is Map ? (e['complemento'] as Map)['observacoes'] : null,
    ]);
    _latitudeCtrl.text = _decimalString(_firstValue([
      e['latitude'],
      e['lat'],
      e['complemento'] is Map ? (e['complemento'] as Map)['latitude'] : null,
    ]));
    _longitudeCtrl.text = _decimalString(_firstValue([
      e['longitude'],
      e['lng'],
      e['complemento'] is Map ? (e['complemento'] as Map)['longitude'] : null,
    ]));
  }

  String _stringValue(List<dynamic> values) {
    for (final value in values) {
      if (_hasValue(value)) return '$value'.trim();
    }
    return '';
  }

  dynamic _firstValue(List<dynamic> values) {
    for (final value in values) {
      if (_hasValue(value)) return value;
    }
    return null;
  }

  String _displayValue(dynamic value) {
    if (!_hasValue(value)) return 'Não informado';
    return '$value'.trim();
  }

  String _formatCnpj(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length != 14) return _displayValue(value);
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12, 14)}';
  }

  String _formatPhone(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6, 10)}';
    }
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
    }
    return _displayValue(value);
  }

  String _formatCep(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length != 8) return _displayValue(value);
    return '${digits.substring(0, 5)}-${digits.substring(5, 8)}';
  }

  String _formatDateTime(dynamic value) {
    if (!_hasValue(value)) return 'Não informado';
    final raw = '$value'.trim().replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '$value';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _decimalString(dynamic value) {
    if (value == null) return '';
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '';
    return number.toStringAsFixed(6);
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final text = '$value'.trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'sim';
  }

  Future<void> _refreshEpublica() async {
    final cnpj = _digitsOnly((_estab?['cnpj'] ?? '').toString());
    if (cnpj.isEmpty) return;
    setState(() => _refreshingEpublica = true);
    final detalhe = await _api.buscarEstabelecimentoDetalhe(cnpj);
    if (!mounted) return;
    if (detalhe != null) {
      setState(() {
        _epublica = detalhe;
        _estab = _mergeMap(_estab ?? {}, detalhe);
      });
      _populateEditFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados da e-Pública atualizados com sucesso.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar os dados da e-Pública.')),
      );
    }
    setState(() => _refreshingEpublica = false);
  }

  Future<void> _salvarEdicao() async {
    final e = _estab;
    if (e == null || _estabId == null) return;
    if (!_editFormKey.currentState!.validate()) return;

    final cnpj = _digitsOnly((e['cnpj'] ?? '').toString());
    final razao = _stringValue([e['razaoSocial'], e['razao_social']]);
    final fantasia = _stringValue([e['nomeFantasia'], e['nome_fantasia']]);
    if (cnpj.isEmpty || (razao.isEmpty && fantasia.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados principais do estabelecimento estão incompletos.')),
      );
      return;
    }

    final latitude = _latitudeCtrl.text.trim().isEmpty ? null : double.tryParse(_latitudeCtrl.text.trim().replaceAll(',', '.'));
    final longitude = _longitudeCtrl.text.trim().isEmpty ? null : double.tryParse(_longitudeCtrl.text.trim().replaceAll(',', '.'));

    setState(() => _saving = true);
    try {
      final updated = await _api.atualizarEstabelecimentoLocal(
        estabelecimentoId: _estabId!,
        telefone: _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        responsavelLocal: _responsavelLocalCtrl.text.trim().isEmpty ? null : _responsavelLocalCtrl.text.trim(),
        observacoes: _observacoesCtrl.text.trim().isEmpty ? null : _observacoesCtrl.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );

      if (!kIsWeb) {
        final db = await LocalDb.instance;
        await db.update(
          'estabelecimentos',
          {
            'telefone': _telefoneCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'responsavel': _responsavelLocalCtrl.text.trim(),
            'lat': latitude,
            'lng': longitude,
          },
          where: 'id = ?',
          whereArgs: [_estabId],
        );
      }

      if (!mounted) return;
      setState(() {
        _estab = _mergeMap(_estab ?? {}, updated ?? {});
        _estab = {
          ...?_estab,
          'telefone': _telefoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'responsavel_local': _responsavelLocalCtrl.text.trim(),
          'observacoes': _observacoesCtrl.text.trim(),
          'latitude': latitude,
          'longitude': longitude,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados complementares salvos com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar os dados complementares.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _capturarLocalizacaoAtual() async {
    setState(() => _capturingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviço de localização desativado.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitudeCtrl.text = pos.latitude.toStringAsFixed(6);
        _longitudeCtrl.text = pos.longitude.toStringAsFixed(6);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localização atual preenchida nos campos.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível capturar a localização atual.')),
      );
    } finally {
      if (mounted) {
        setState(() => _capturingLocation = false);
      }
    }
  }

  void _showJsonDialog(String title, dynamic data, {String emptyMessage = 'Nenhum dado disponível.'}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Text(
              data == null || (data is Iterable && data.isEmpty) ? emptyMessage : data.toString(),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final e = _estab;
    if (e == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Estabelecimento'),
          backgroundColor: AppColors.azulInstitucional,
        ),
        body: const SafeArea(
          child: Center(child: Text('Estabelecimento não encontrado.')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estabelecimento'),
        backgroundColor: AppColors.azulInstitucional,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _tabController.animateTo(2),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Dados da Empresa'),
            Tab(text: 'Histórico e-Pública'),
            Tab(text: 'Edição'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDadosEmpresaTab(e),
            _buildHistoricoTab(e),
            _buildEdicaoTab(e),
          ],
        ),
      ),
    );
  }

  Widget _buildDadosEmpresaTab(Map<String, dynamic> e) {
    final addressParts = [
      _stringValue([e['endereco'], e['logradouro'], e['rua']]),
      _stringValue([e['numero']]),
    ].where((part) => part.isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Dados da Empresa',
          icon: Icons.business_outlined,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _infoCard('Razão Social', _stringValue([e['razaoSocial'], e['razao_social']])),
              _infoCard('Nome Fantasia', _stringValue([e['nomeFantasia'], e['nome_fantasia']])),
              _infoCard('CNPJ', _formatCnpj((e['cnpj'] ?? '').toString())),
              _infoCard('Inscrição Municipal', _stringValue([e['inscricaoMunicipal'], e['inscricao_municipal']])),
              _infoCard('CNAE / Atividade', _stringValue([e['cnaeDescricao'], e['cnae_fiscal_descricao'], e['cnae']])),
              _infoCard('Endereço', addressParts),
              _infoCard('Número', _stringValue([e['numero']])),
              _infoCard('Bairro', _stringValue([e['bairro']])),
              _infoCard('Cidade', _stringValue([e['cidade'], e['municipio']])),
              _infoCard('UF', _stringValue([e['uf'], e['estado']])),
              _infoCard('CEP', _formatCep(_stringValue([e['cep']]))),
              _infoCard('Telefone', _formatPhone(_stringValue([e['telefone']]))),
              _infoCard('Email', _stringValue([e['email']])),
              _infoCard('Responsável Legal', _stringValue([e['responsavel']])),
              _infoCard('Situação do Alvará', _extractAlvaraLabel(e)),
              _infoCard('Débito vencido', _boolValue(e['possuiDebito'] ?? e['debito_vencido']) ? 'Sim' : 'Não'),
              _infoCard('Última atualização da e-Pública', _formatDateTime(e['ultima_sincronizacao'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricoTab(Map<String, dynamic> e) {
    final economico = _epublica?['economico'];
    final alvaras = _epublica?['alvaras'] is List ? List<Map<String, dynamic>>.from((_epublica?['alvaras'] as List).map((e) => Map<String, dynamic>.from(e as Map))) : <Map<String, dynamic>>[];
    final debitos = _epublica?['debitos'] is List ? List<Map<String, dynamic>>.from((_epublica?['debitos'] as List).map((e) => Map<String, dynamic>.from(e as Map))) : <Map<String, dynamic>>[];
    final hasHistorico = economico != null || alvaras.isNotEmpty || debitos.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Histórico e-Pública',
          icon: Icons.history_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _refreshingEpublica ? null : _refreshEpublica,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulInstitucional,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(_refreshingEpublica ? Icons.sync : Icons.cloud_sync_outlined),
                    label: Text(_refreshingEpublica ? 'Atualizando...' : 'Atualizar dados da e-Pública'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showJsonDialog('Detalhes do alvará', _epublica?['alvara']),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Ver detalhes do alvará'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showJsonDialog('Débitos', debitos, emptyMessage: 'Nenhum débito encontrado.'),
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Ver débitos'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _infoCard('Situação atual do alvará', _extractAlvaraLabel(e)),
                  _infoCard('Débitos vencidos', _boolValue(e['possuiDebito'] ?? e['debito_vencido']) ? 'Sim' : 'Não'),
                  _infoCard('Última sincronização', _formatDateTime(_epublica?['ultima_sincronizacao'])),
                  _infoCard('Origem dos dados', _displayValue(_epublica?['origem_dados'] ?? 'e-Pública')),
                ],
              ),
              const SizedBox(height: 20),
              if (!hasHistorico)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Nenhum histórico encontrado na e-Pública.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else ...[
                _historyBlock(
                  title: 'Dados do econômico',
                  content: economico,
                  emptyMessage: 'Nenhum dado econômico encontrado.',
                ),
                const SizedBox(height: 12),
                _historyBlock(
                  title: 'Histórico de alvarás',
                  content: alvaras,
                  emptyMessage: 'Nenhum histórico de alvarás encontrado.',
                ),
                const SizedBox(height: 12),
                _historyBlock(
                  title: 'Histórico de débitos',
                  content: debitos,
                  emptyMessage: 'Nenhum histórico de débitos encontrado.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEdicaoTab(Map<String, dynamic> e) {
    return Form(
      key: _editFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Editar Dados',
            icon: Icons.edit_note_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB9D4FF)),
                  ),
                  child: const Text(
                    'Dados cadastrais principais são sincronizados pela e-Pública e não podem ser alterados manualmente.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                _responsiveFields([
                  OfficialTextField(
                    initialValue: _stringValue([e['razaoSocial'], e['razao_social']]),
                    label: 'Razão Social',
                    readOnly: true,
                  ),
                  OfficialTextField(
                    initialValue: _stringValue([e['nomeFantasia'], e['nome_fantasia']]),
                    label: 'Nome Fantasia',
                    readOnly: true,
                  ),
                  OfficialTextField(
                    initialValue: _formatCnpj((e['cnpj'] ?? '').toString()),
                    label: 'CNPJ',
                    readOnly: true,
                  ),
                  OfficialTextField(
                    initialValue: _stringValue([e['inscricaoMunicipal'], e['inscricao_municipal']]),
                    label: 'Inscrição Municipal',
                    readOnly: true,
                  ),
                  OfficialTextField(
                    initialValue: _stringValue([e['cnaeDescricao'], e['cnae_fiscal_descricao'], e['cnae']]),
                    label: 'CNAE',
                    readOnly: true,
                  ),
                  const SizedBox.shrink(),
                  OfficialTextField(
                    controller: _telefoneCtrl,
                    label: 'Telefone',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9()\-\s]'))],
                    validator: _validatePhone,
                  ),
                  OfficialTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  OfficialTextField(
                    controller: _responsavelLocalCtrl,
                    label: 'Responsável local',
                  ),
                  SizedBox(
                    width: 320,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _capturingLocation ? null : _capturarLocalizacaoAtual,
                        icon: _capturingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_outlined),
                        label: Text(_capturingLocation ? 'Buscando localização...' : 'Usar localização atual'),
                      ),
                    ),
                  ),
                  OfficialTextField(
                    controller: _latitudeCtrl,
                    label: 'Latitude',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
                    validator: (value) => _validateCoordinate(value, isLatitude: true),
                  ),
                  OfficialTextField(
                    controller: _longitudeCtrl,
                    label: 'Longitude',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
                    validator: (value) => _validateCoordinate(value, isLatitude: false),
                  ),
                ]),
                const SizedBox(height: 16),
                OfficialMultilineField(
                  controller: _observacoesCtrl,
                  label: 'Observações',
                  minLines: 4,
                  maxLines: 8,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _salvarEdicao,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulInstitucional,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(_saving ? Icons.sync : Icons.save_outlined),
                    label: Text(_saving ? 'Salvando...' : 'Salvar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Não informado' : value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _historyBlock({
    required String title,
    required dynamic content,
    required String emptyMessage,
  }) {
    final hasContent = content != null && (content is! Iterable || content.isNotEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            hasContent ? content.toString() : emptyMessage,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _responsiveFields(List<Widget> fields) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: fields
          .map(
            (field) => SizedBox(
              width: 320,
              child: field,
            ),
          )
          .toList(),
    );
  }

  String _extractAlvaraLabel(Map<String, dynamic> e) {
    final alvara = _epublica?['alvara'];
    if (alvara is Map) {
      final descricao = _stringValue([
        alvara['situacao'],
        alvara['status'],
        alvara['descricao'],
        alvara['nome'],
      ]);
      if (descricao.isNotEmpty) return descricao;
    }
    return _displayValue(e['statusAlvara'] ?? e['status_alvara']);
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(text)) return 'Email inválido';
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.isEmpty) return null;
    if (digits.length != 10 && digits.length != 11) return 'Telefone inválido';
    return null;
  }

  String? _validateCoordinate(String? value, {required bool isLatitude}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return 'Valor inválido';
    if (isLatitude && (parsed < -90 || parsed > 90)) return 'Latitude fora do limite';
    if (!isLatitude && (parsed < -180 || parsed > 180)) return 'Longitude fora do limite';
    return null;
  }
}
