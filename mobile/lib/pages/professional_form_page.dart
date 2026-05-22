import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class ProfessionalFormPage extends StatefulWidget {
  const ProfessionalFormPage({super.key});

  @override
  State<ProfessionalFormPage> createState() => _ProfessionalFormPageState();
}

class _ProfessionalFormPageState extends State<ProfessionalFormPage> {
  // GlobalKey para validação
  final _formKey = GlobalKey<FormState>();

  // Controllers persistentes
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _conselhoCtrl = TextEditingController();
  final _registroCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _perfilCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();

  // Dropdowns
  String _status = 'ATIVO';
  String _perfilAcesso = 'FISCAL';

  // State
  bool _saving = false;
  Map<String, dynamic>? _editData;

  final _api = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _editData == null) {
      setState(() {
        _editData = args;
        _populateForm(args);
      });
    }
  }

  void _populateForm(Map<String, dynamic> data) {
    _nomeCtrl.text = data['nome'] ?? '';
    _cpfCtrl.text = data['cpf'] ?? '';
    _matriculaCtrl.text = data['matricula'] ?? '';
    _cargoCtrl.text = data['cargo'] ?? data['funcao'] ?? '';
    _conselhoCtrl.text = data['conselho'] ?? '';
    _registroCtrl.text = data['registro_profissional'] ?? '';
    _telefoneCtrl.text = data['telefone'] ?? '';
    _emailCtrl.text = data['email'] ?? '';
    _perfilCtrl.text = data['perfil_acesso'] ?? '';
    _observacoesCtrl.text = data['observacoes'] ?? '';
    _status = data['status'] ?? 'ATIVO';
    _perfilAcesso = data['perfil_acesso'] ?? 'FISCAL';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _matriculaCtrl.dispose();
    _cargoCtrl.dispose();
    _conselhoCtrl.dispose();
    _registroCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _perfilCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  /// Valida todos os dados obrigatórios
  bool _validateAllData() {
    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_matriculaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matrícula é obrigatória'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_cargoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargo/Função é obrigatório'), backgroundColor: AppColors.vermelho),
      );
      return false;
    }
    if (_status.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status é obrigatório'), backgroundColor: AppColors.vermelho),
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
        'nome': _nomeCtrl.text.trim(),
        'cpf': _cpfCtrl.text.trim().isEmpty ? null : _cpfCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        'matricula': _matriculaCtrl.text.trim(),
        'cargo': _cargoCtrl.text.trim(),
        'funcao': _cargoCtrl.text.trim(),
        'conselho': _conselhoCtrl.text.trim().isEmpty ? null : _conselhoCtrl.text.trim(),
        'registro_profissional': _registroCtrl.text.trim().isEmpty ? null : _registroCtrl.text.trim(),
        'telefone': _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'status': _status,
        'perfil_acesso': _perfilAcesso,
        'observacoes': _observacoesCtrl.text.trim().isEmpty ? null : _observacoesCtrl.text.trim(),
        'status_sincronizacao': kIsWeb ? 'SINCRONIZADO' : 'PENDENTE_SINCRONIZACAO',
      };

      if (kIsWeb) {
        await _api.init();
        if (_editData != null) {
          await _api.atualizarProfissional(_editData!['id'], payload);
        } else {
          await _api.criarProfissional(payload);
        }
      } else {
        final db = await LocalDb.instance;
        final data = {
          ...payload,
          'data_cadastro': DateTime.now().toIso8601String(),
        };
        if (_editData != null) {
          await db.update('profissionais', data, where: 'id = ?', whereArgs: [_editData!['id']]);
        } else {
          await db.insert('profissionais', data);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) print('Erro ao salvar profissional: $e');
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
        title: Text(_editData != null ? 'Editar Profissional' : 'Novo Profissional'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dados Pessoais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _nomeCtrl,
                label: 'Nome Completo',
                required: true,
              ),
              const SizedBox(height: 12),
              OfficialCpfField(
                controller: _cpfCtrl,
                label: 'CPF',
                required: false,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _matriculaCtrl,
                label: 'Matrícula',
                required: true,
              ),
              const SizedBox(height: 16),
              const Text('Dados Profissionais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _cargoCtrl,
                label: 'Cargo/Função',
                required: true,
              ),
              const SizedBox(height: 12),
              OfficialDropdownField.fromStrings(
                label: 'Perfil de Acesso',
                value: _perfilAcesso,
                items: const ['FISCAL', 'SUPERVISOR', 'ADMINISTRADOR', 'VISUALIZADOR'],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _perfilAcesso = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _conselhoCtrl,
                label: 'Conselho Profissional',
                required: false,
              ),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _registroCtrl,
                label: 'Número do Registro',
                required: false,
              ),
              const SizedBox(height: 16),
              const Text('Contato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 16),
              const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OfficialDropdownField.fromStrings(
                label: 'Status',
                value: _status,
                items: const ['ATIVO', 'INATIVO'],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Observações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OfficialTextField(
                controller: _observacoesCtrl,
                label: 'Observações',
                required: false,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
