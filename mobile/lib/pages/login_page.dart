import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api.dart';
import '../services/api_base_url.dart';
import '../services/app_storage.dart';
import '../ui/theme.dart';
import '../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _cpfCtrl = TextEditingController(text: '00000000000');
  final _senhaCtrl = TextEditingController(text: 'senha123');
  final _baseUrlCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  String? _error;
  bool _remember = true;
  String _ambiente = 'Homologação';

  @override
  void initState() {
    super.initState();
    _baseUrlCtrl.text =
        ApiService.mockMode ? 'mock' : resolveDefaultApiBaseUrl();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    if (!ApiService.mockMode && kIsWeb) {
      await AppStorage.delete('base_url');
      await _api.setBaseUrl(resolveDefaultApiBaseUrl());
    }
    await _api.init();
    final savedCpf = await _api.readPreference('cpf');
    final savedAmb = await _api.readPreference('ambiente');
    final savedBase = await _api.readPreference('base_url');
    final normalizedBase = normalizeSavedApiBaseUrl(savedBase);
    if (!ApiService.mockMode && savedBase != normalizedBase) {
      await _api.setBaseUrl(normalizedBase);
    }
    setState(() {
      if (savedCpf != null) _cpfCtrl.text = savedCpf;
      if (savedAmb != null) _ambiente = savedAmb;
      if (!ApiService.mockMode) {
        _baseUrlCtrl.text = normalizedBase;
      }
    });
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final baseUrl = normalizeSavedApiBaseUrl(_baseUrlCtrl.text);
    if (baseUrl != _baseUrlCtrl.text) {
      _baseUrlCtrl.text = baseUrl;
    }
    try {
      await _api.setBaseUrl(baseUrl);
      final ok = await _api.login(_cpfCtrl.text, _senhaCtrl.text).timeout(const Duration(seconds: 20));
      setState(() {
        _loading = false;
        _error = ok ? null : 'CPF ou senha inválidos';
      });
      if (_remember) {
        await _api.savePreference('cpf', _cpfCtrl.text);
        await _api.savePreference('ambiente', _ambiente);
      }
      if (ok && mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
      return;
    } on TimeoutException {
      setState(() {
        _loading = false;
        _error = 'Tempo esgotado ao conectar ($baseUrl)';
      });
    } on DioException catch (e) {
      final detail = e.response?.statusCode != null
          ? 'HTTP ${e.response!.statusCode}'
          : (e.message ?? e.type.name);
      setState(() {
        _loading = false;
        _error = 'Não foi possível conectar ao servidor ($baseUrl). $detail';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erro ao entrar: $e';
      });
    }
  }

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _senhaCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.azulInstitucional, AppColors.azulClaro], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 140,
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(14),
                            child: Image.asset('public/brasao.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Prefeitura de Balneário Camboriú', textAlign: TextAlign.center),
                      const Text('Vigilância Sanitária', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Text('Login do Fiscal', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextField(controller: _cpfCtrl, decoration: const InputDecoration(labelText: 'CPF')),
                      const SizedBox(height: 12),
                      TextField(controller: _senhaCtrl, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
                      const SizedBox(height: 12),
                      if (!ApiService.mockMode) ...[
                        TextField(
                          controller: _baseUrlCtrl,
                          decoration: InputDecoration(
                            labelText: 'Servidor',
                            hintText: resolveDefaultApiBaseUrl(),
                            helperText: 'Use a mesma URL do navegador (ex.: ${resolveDefaultApiBaseUrl()})',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 8),
                      ],
                      SwitchListTile(
                        value: _remember,
                        onChanged: (v) => setState(() => _remember = v),
                        title: const Text('Lembrar login'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Entrar',
                        loading: _loading,
                        onPressed: _loading || _cpfCtrl.text.isEmpty || _senhaCtrl.text.isEmpty || (!ApiService.mockMode && _baseUrlCtrl.text.isEmpty) ? null : _login,
                      ),
                      const SizedBox(height: 8),
                      const Text('Versão 1.0.0', textAlign: TextAlign.center),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
