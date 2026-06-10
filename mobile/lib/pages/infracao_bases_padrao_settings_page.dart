import 'package:flutter/material.dart';

import '../services/api.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class InfracaoBasesPadraoSettingsPage extends StatefulWidget {
  const InfracaoBasesPadraoSettingsPage({super.key});

  @override
  State<InfracaoBasesPadraoSettingsPage> createState() => _InfracaoBasesPadraoSettingsPageState();
}

class _InfracaoBasesPadraoSettingsPageState extends State<InfracaoBasesPadraoSettingsPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  String _base1Id = '';
  String _base2Id = '';
  String _base1Label = '';
  String _base2Label = '';
  final _base1Ctrl = TextEditingController();
  final _base2Ctrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final base1 = (await _api.readPreference('infracao_base_padrao_1_id'))?.trim() ?? '';
      final base2 = (await _api.readPreference('infracao_base_padrao_2_id'))?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _base1Id = base1;
        _base2Id = base2;
      });
      await _refreshLabels();
    } catch (_) {}
  }

  Future<void> _refreshLabels() async {
    Future<String> loadLabel(String id) async {
      if (id.trim().isEmpty) return '';
      try {
        final m = await _api.buscarBaseLegalDetalhe(id.trim());
        if (m == null) return id.trim();
        final tipo = (m['tipo'] ?? '').toString().trim();
        final numero = (m['numero'] ?? '').toString().trim();
        final ano = (m['ano'] ?? '').toString().trim();
        final esfera = (m['esfera'] ?? '').toString().trim();
        final titulo = [tipo, [numero, ano].where((e) => e.isNotEmpty).join('/'), esfera.isEmpty ? '' : '($esfera)']
            .where((e) => e.trim().isNotEmpty)
            .join(' ')
            .trim();
        return titulo.isEmpty ? id.trim() : titulo;
      } catch (_) {
        return id.trim();
      }
    }

    final l1 = await loadLabel(_base1Id);
    final l2 = await loadLabel(_base2Id);
    if (!mounted) return;
    setState(() {
      _base1Label = l1;
      _base2Label = l2;
      _base1Ctrl.text = _base1Label.isNotEmpty ? _base1Label : _base1Id;
      _base2Ctrl.text = _base2Label.isNotEmpty ? _base2Label : _base2Id;
    });
  }

  Future<Map<String, dynamic>?> _selecionarBaseLegal() async {
    final result = await Navigator.pushNamed(context, '/base-legal', arguments: {'selectionMode': true});
    if (!mounted) return null;
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return null;
  }

  String? _requiredBaseIdValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Campo obrigatório';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _api.savePreference('infracao_base_padrao_1_id', _base1Id.trim());
      await _api.savePreference('infracao_base_padrao_2_id', _base2Id.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bases legais padrão salvas.')));
      Navigator.of(context).maybePop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível salvar.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _base1Ctrl.dispose();
    _base2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bases Legais Padrão'),
        backgroundColor: AppColors.azulInstitucional,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OfficialTextField(
                controller: _base1Ctrl,
                label: 'Base Legal Padrão Auto de Infração 1',
                required: true,
                readOnly: true,
                enabled: !_saving,
                validator: (_) => _requiredBaseIdValidator(_base1Id),
                suffixIcon: IconButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final m = await _selecionarBaseLegal();
                          if (!mounted || m == null) return;
                          final id = (m['id'] ?? '').toString().trim();
                          if (id.isEmpty) return;
                          setState(() => _base1Id = id);
                          await _refreshLabels();
                        },
                  icon: const Icon(Icons.search_outlined),
                ),
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _base2Ctrl,
                label: 'Base Legal Padrão Auto de Infração 2',
                required: true,
                readOnly: true,
                enabled: !_saving,
                validator: (_) => _requiredBaseIdValidator(_base2Id),
                suffixIcon: IconButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final m = await _selecionarBaseLegal();
                          if (!mounted || m == null) return;
                          final id = (m['id'] ?? '').toString().trim();
                          if (id.isEmpty) return;
                          setState(() => _base2Id = id);
                          await _refreshLabels();
                        },
                  icon: const Icon(Icons.search_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
