import 'package:flutter/material.dart';

import '../services/api.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class VisaSettingsPage extends StatefulWidget {
  const VisaSettingsPage({super.key});

  @override
  State<VisaSettingsPage> createState() => _VisaSettingsPageState();
}

class _VisaSettingsPageState extends State<VisaSettingsPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  String _setor = _setoresVisa.first;
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final setor = (await _api.readPreference('visa_setor'))?.trim() ?? '';
      final telefone = (await _api.readPreference('visa_telefone'))?.trim() ?? '';
      final email = (await _api.readPreference('visa_email'))?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        if (_setoresVisa.contains(setor)) _setor = setor;
        _telefoneCtrl.text = telefone;
        _emailCtrl.text = email;
      });
    } catch (_) {}
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Campo obrigatório';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'E-mail inválido';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _api.savePreference('visa_setor', _setor);
      await _api.savePreference('visa_telefone', _telefoneCtrl.text.trim());
      await _api.savePreference('visa_email', _emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados da VISA salvos.')),
      );
      Navigator.of(context).maybePop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dados da VISA'),
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
              OfficialDropdownField.fromStrings(
                label: 'Nome do setor',
                value: _setor,
                items: _setoresVisa,
                required: true,
                onChanged: _saving ? null : (v) => setState(() => _setor = v ?? _setoresVisa.first),
              ),
              const SizedBox(height: 12),
              OfficialPhoneField(
                controller: _telefoneCtrl,
                label: 'Telefone',
                required: true,
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _emailCtrl,
                label: 'E-mail',
                required: true,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
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

const List<String> _setoresVisa = [
  'Departamento de Fiscalização de Alimentos',
  'Departamento de Fiscalização de Serviços de Saúde e de Interesse à Saúde',
  'Centro de Controle de Pragas Urbanas',
  'Programa Municipal de Controle da Dengue',
];

