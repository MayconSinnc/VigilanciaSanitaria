import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _cpfCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  bool _saving = false;
  String? _error;
  String? _success;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _api.init();
      final cpf = await _api.readPreference('cpf');
      final email = await _api.readPreference('email');
      if (!mounted) return;
      setState(() {
        _cpfCtrl.text = cpf ?? '';
        _emailCtrl.text = email ?? '';
      });
    } catch (e) {
      if (kDebugMode) print('Erro ao carregar perfil: $e');
    }
  }

  /// Valida CPF
  bool _validateCpf(String cpf) {
    final cleaned = cpf.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 11) return false;
    
    // Validação básica de CPF
    if (cleaned.split('').every((c) => c == cleaned[0])) return false;
    
    final digits = cleaned.split('').map(int.parse).toList();
    
    // Valida primeiro dígito
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += digits[i] * (10 - i);
    }
    var remainder = sum % 11;
    final digit1 = remainder < 2 ? 0 : 11 - remainder;
    if (digit1 != digits[9]) return false;
    
    // Valida segundo dígito
    sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += digits[i] * (11 - i);
    }
    remainder = sum % 11;
    final digit2 = remainder < 2 ? 0 : 11 - remainder;
    if (digit2 != digits[10]) return false;
    
    return true;
  }

  /// Valida email
  bool _validateEmail(String email) {
    if (email.trim().isEmpty) return true; // Opcional
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    // Validar CPF
    final cpfDigits = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cpfDigits.length != 11 || !_validateCpf(_cpfCtrl.text)) {
      setState(() {
        _saving = false;
        _error = 'CPF inválido.';
      });
      return;
    }

    // Validar email se preenchido
    if (!_validateEmail(_emailCtrl.text)) {
      setState(() {
        _saving = false;
        _error = 'Email inválido.';
      });
      return;
    }

    // Validar senha se preenchida
    if (_novaSenhaCtrl.text.trim().isNotEmpty) {
      if (_novaSenhaCtrl.text.length < 6) {
        setState(() {
          _saving = false;
          _error = 'A senha deve ter pelo menos 6 caracteres.';
        });
        return;
      }
      if (_novaSenhaCtrl.text != _confirmarSenhaCtrl.text) {
        setState(() {
          _saving = false;
          _error = 'As senhas não conferem.';
        });
        return;
      }
    }

    try {
      // Salvar email
      await _api.savePreference('email', _emailCtrl.text.trim());
      
      // Salvar senha se preenchida
      if (_novaSenhaCtrl.text.trim().isNotEmpty) {
        await _api.savePreference('prof_senha', _novaSenhaCtrl.text);
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = 'Perfil atualizado com sucesso.';
        _novaSenhaCtrl.clear();
        _confirmarSenhaCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso.'),
          backgroundColor: AppColors.verde,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Erro ao salvar perfil: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OfficialCpfField(
                controller: _cpfCtrl,
                label: 'CPF',
                required: true,
                readOnly: true,
              ),
              const SizedBox(height: 16),
              OfficialTextField(
                controller: _emailCtrl,
                label: 'Email',
                required: false,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              OfficialPasswordField(
                controller: _novaSenhaCtrl,
                label: 'Nova senha',
                required: false,
                helperText: 'Deixe em branco para manter a senha atual',
              ),
              const SizedBox(height: 16),
              OfficialPasswordField(
                controller: _confirmarSenhaCtrl,
                label: 'Confirmar senha',
                required: false,
                helperText: 'Obrigatório apenas se informar nova senha',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azulInstitucional,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar alterações'),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.vermelho.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.vermelho),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.vermelho),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.vermelho))),
                    ],
                  ),
                ),
              ],
              if (_success != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.verde.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.verde),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.verde),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_success!, style: const TextStyle(color: AppColors.verde))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
