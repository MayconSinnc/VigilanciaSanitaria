import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import '../ui/theme.dart';
import '../widgets/inspection_header.dart';
import '../services/api.dart';

class InspectionFormPage extends StatefulWidget {
  const InspectionFormPage({super.key});
  @override
  State<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends State<InspectionFormPage> {
  final _dataLavratura = TextEditingController();
  final _setor = TextEditingController();
  final _cnpj = TextEditingController();
  final _motivo = TextEditingController();
  final _situacao = TextEditingController();
  String _nomeEstabelecimento = 'Estabelecimento';
  String _razaoSocial = '';
  String _nomeFantasia = '';
  String _endereco = '';
  String _telefone = '';
  String _responsavel = '';
  String _inscricaoMunicipal = '';
  String? _loadedCnpjDigits;
  int? _estabelecimentoId;
  int? _inspecaoId;
  final _api = ApiService();
  String _setorSelecionado = 'Alimentos';
  static const List<String> _setores = ['Alimentos', 'Serviços de Saúde', 'Zoonoses', 'Ambiente', 'Outros'];

  void _voltarOuDashboard() {
    Navigator.of(context).maybePop();
  }

  // #region debug-point B:abrir-evidencias
  void _debugAbrirEvidencias(String stage, Map<String, Object?> data) {
    unawaited(Dio()
        .post(
          'http://127.0.0.1:7777/event',
          data: {
            'sessionId': 'web-evidence-save',
            'runId': 'pre-fix',
            'hypothesisId': 'B',
            'location': 'inspection_form_page.dart:_abrirEvidencias',
            'msg': '[DEBUG] abrir evidencias',
            'data': {'stage': stage, ...data},
            'ts': DateTime.now().millisecondsSinceEpoch,
          },
        )
        .then<void>((_) {}, onError: (_) {}));
  }
  // #endregion

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataLavratura.text = _formatDate(now);
    _setor.text = _setorSelecionado;
  }

  @override
  void dispose() {
    _dataLavratura.dispose();
    _setor.dispose();
    _cnpj.dispose();
    _motivo.dispose();
    _situacao.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final cnpj = args['cnpj'] as String?;
      if (cnpj != null) _cnpj.text = cnpj;
      final motivo = args['motivo'] as String?;
      if (motivo != null) _motivo.text = motivo;
      final nome = args['nome'] as String?;
      if (nome != null && nome.trim().isNotEmpty) _nomeEstabelecimento = nome.trim();
    }
    final digits = _digitsOnly(_cnpj.text);
    if (digits.length == 14 && _loadedCnpjDigits != digits) {
      _loadedCnpjDigits = digits;
      Future.microtask(() async {
        try {
          await _api.init();
          final data = await _api.buscarEstabelecimentoPorCnpj(digits);
          if (!mounted || data == null) return;
          setState(() {
            _estabelecimentoId = (data['id'] as num?)?.toInt();
            _razaoSocial = (data['razaoSocial'] ?? data['razao_social'] ?? '')?.toString() ?? '';
            _nomeFantasia = (data['nomeFantasia'] ?? data['nome_fantasia'] ?? data['nome'] ?? '')?.toString() ?? '';
            final rua = (data['endereco'] ?? data['logradouro'] ?? '')?.toString() ?? '';
            final numero = (data['numero'] ?? '')?.toString() ?? '';
            _endereco = rua.isNotEmpty && numero.isNotEmpty ? '$rua, $numero' : (rua.isNotEmpty ? rua : numero);
            _telefone = (data['telefone'] ?? '')?.toString() ?? '';
            _responsavel = (data['responsavel'] ?? '')?.toString() ?? '';
            _inscricaoMunicipal = (data['inscricaoMunicipal'] ?? data['inscricao_municipal'] ?? '')?.toString() ?? '';
            final nome = _nomeFantasia.trim().isNotEmpty ? _nomeFantasia.trim() : _razaoSocial.trim();
            if (nome.isNotEmpty) _nomeEstabelecimento = nome;
          });
        } catch (_) {}
      });
    }
  }

  String _digitsOnly(String v) => v.replaceAll(RegExp(r'\D'), '');

  Future<void> _abrirEvidencias() async {
    _debugAbrirEvidencias('start', {
      'isWeb': kIsWeb,
      'cnpj': _digitsOnly(_cnpj.text),
      'estabelecimentoId': _estabelecimentoId,
      'inspecaoId': _inspecaoId,
    });
    if (!kIsWeb) {
      Navigator.pushNamed(context, '/evidencias');
      return;
    }
    final cnpjDigits = _digitsOnly(_cnpj.text);
    if (cnpjDigits.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um CNPJ válido.')));
      return;
    }
    try {
      await _api.init();
      if (_estabelecimentoId == null) {
        final data = await _api.buscarEstabelecimentoPorCnpj(cnpjDigits);
        _estabelecimentoId = (data?['id'] as num?)?.toInt();
        _debugAbrirEvidencias('loaded-estabelecimento', {
          'cnpj': cnpjDigits,
          'estabelecimentoId': _estabelecimentoId,
        });
      }
      if (_estabelecimentoId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estabelecimento não encontrado.')));
        return;
      }
      if (_inspecaoId == null) {
        final created = await _api.criarInspecao(
          tipoAuto: 'INFRACAO',
          estabelecimentoId: _estabelecimentoId!,
          descricao: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
        );
        _inspecaoId = (created?['id'] as num?)?.toInt();
        _debugAbrirEvidencias('created-inspecao', {
          'estabelecimentoId': _estabelecimentoId,
          'inspecaoId': _inspecaoId,
        });
      }
      if (_inspecaoId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível criar a inspeção.')));
        return;
      }
      if (!mounted) return;
      _debugAbrirEvidencias('push-route', {'inspecaoId': _inspecaoId});
      Navigator.pushNamed(context, '/evidencias', arguments: {'inspecaoId': _inspecaoId});
    } catch (_) {
      _debugAbrirEvidencias('error', {
        'cnpj': cnpjDigits,
        'estabelecimentoId': _estabelecimentoId,
        'inspecaoId': _inspecaoId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir evidências.')));
    }
  }

  Future<void> _abrirHistoricoEPublica() async {
    final cnpjDigits = _digitsOnly(_cnpj.text);
    try {
      await _api.init();
      Map<String, dynamic>? data;
      if (_estabelecimentoId == null && cnpjDigits.length == 14) {
        data = await _api.buscarEstabelecimentoPorCnpj(cnpjDigits);
        _estabelecimentoId = (data?['id'] as num?)?.toInt();
      }
      if (_estabelecimentoId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione um estabelecimento válido para abrir o histórico.')),
        );
        return;
      }
      final estabelecimento = data ??
          {
            'id': _estabelecimentoId,
            'cnpj': cnpjDigits,
            'razaoSocial': _razaoSocial,
            'nomeFantasia': _nomeFantasia,
            'nome_fantasia': _nomeFantasia,
            'razao_social': _razaoSocial,
            'logradouro': _endereco,
            'telefone': _telefone,
            'responsavel': _responsavel,
            'inscricaoMunicipal': _inscricaoMunicipal,
          };
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/ficha-estabelecimento',
        arguments: {
          'id': _estabelecimentoId,
          'estabelecimento': estabelecimento,
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o histórico do E-Pública.')),
      );
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  DateTime? _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _pickLavraturaDate() async {
    final now = DateTime.now();
    final current = _parseDate(_dataLavratura.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dataLavratura.text = _formatDate(picked);
    });
  }

  Widget _buildLavraturaField() {
    return TextField(
      controller: _dataLavratura,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Data da Lavratura',
        suffixIcon: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickLavraturaDate),
      ),
      onTap: _pickLavraturaDate,
    );
  }

  Widget _buildSetorField() {
    return DropdownButtonFormField<String>(
      initialValue: _setorSelecionado,
      items: _setores.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) {
        final next = v ?? _setorSelecionado;
        setState(() {
          _setorSelecionado = next;
          _setor.text = next;
        });
      },
      decoration: const InputDecoration(labelText: 'Setor da Vigilância'),
    );
  }

  void _abrirAuto(String tipo) {
    final cnpjDigits = _digitsOnly(_cnpj.text);
    if (cnpjDigits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o CNPJ para emitir o auto.')));
      return;
    }
    String route;
    switch (tipo) {
      case 'INF':
        route = '/auto-infracao';
        break;
      case 'PEN':
        route = '/imposicao-penalidade';
        break;
      case 'COL':
        route = '/auto-coleta';
        break;
      default:
        route = '/auto';
    }
    Navigator.pushNamed(
      context,
      route,
      arguments: {
        'tipo': tipo,
        'nome': _nomeEstabelecimento,
        'cnpj': cnpjDigits,
        'motivo': _motivo.text,
        'razaoSocial': _razaoSocial,
        'nomeFantasia': _nomeFantasia,
        'endereco': _endereco,
        'telefone': _telefone,
        'responsavel': _responsavel,
        'inscricaoMunicipal': _inscricaoMunicipal,
        'estabelecimentoId': _estabelecimentoId,
        'inspecaoId': _inspecaoId,
        'situacaoEncontrada': _situacao.text,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulário Oficial'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _voltarOuDashboard,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const InspectionHeader(
            prefeitura: 'Prefeitura Municipal de Balneário Camboriú',
            departamento: 'Departamento de Vigilância Sanitária',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _StepDot(label: 'Dados', active: true),
                _StepLine(),
                _StepDot(label: 'Checklist'),
                _StepLine(),
                _StepDot(label: 'Fotos'),
                _StepLine(),
                _StepDot(label: 'Ações'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AUTO DE INFRAÇÃO Nº 001/2026', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (narrow) ...[
                  _buildLavraturaField(),
                  const SizedBox(height: 12),
                  _buildSetorField(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                          onPressed: _abrirEvidencias,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Câmera'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulClaro, foregroundColor: Colors.white),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(child: _buildLavraturaField()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSetorField()),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints.tightFor(width: 160),
                        child: ElevatedButton.icon(
                          onPressed: _abrirEvidencias,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Câmera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azulClaro,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text('INSPEÇÃO SANITÁRIA Nº XXXX', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _cnpj, decoration: const InputDecoration(labelText: 'CNPJ'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _motivo, decoration: const InputDecoration(labelText: 'Motivo da inspeção'))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/checklist'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulClaro, foregroundColor: Colors.white),
                        child: const Text('Checklist'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _abrirHistoricoEPublica,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
                        child: const Text('Histórico E-Pública'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Razão Social: ${_razaoSocial.isEmpty ? '-' : _razaoSocial}'),
                        Text('Nome Fantasia: ${_nomeFantasia.isEmpty ? '-' : _nomeFantasia}'),
                        Text('CNPJ: ${_cnpj.text.trim().isEmpty ? '-' : _cnpj.text.trim()}'),
                        Text('Endereço: ${_endereco.isEmpty ? '-' : _endereco}'),
                        Text('Telefone: ${_telefone.isEmpty ? '-' : _telefone}'),
                        Text('Responsável: ${_responsavel.isEmpty ? '-' : _responsavel}'),
                        Text('Inscrição municipal: ${_inscricaoMunicipal.isEmpty ? '-' : _inscricaoMunicipal}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _situacao,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Situação Encontrada'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _abrirAuto('INT'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
                        child: const Text('AUTO DE INTIMAÇÃO'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _abrirAuto('INF'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.vermelho, foregroundColor: Colors.white),
                        child: const Text('AUTO DE INFRAÇÃO'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _abrirAuto('PEN'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.laranja, foregroundColor: Colors.white),
                        child: const Text('IMPOSIÇÃO DE PENALIDADE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _abrirAuto('COL'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.verde, foregroundColor: Colors.white),
                        child: const Text('AUTO DE COLETA PARA AMOSTRA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: 0,
                  itemBuilder: (ctx, i) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
                        child: const Text('EDITAR'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/assinatura'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulClaro, foregroundColor: Colors.white),
                        child: const Text('SALVAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  const _StepDot({required this.label, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: active ? AppColors.azulInstitucional : Colors.grey.shade400, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.azulInstitucional : Colors.grey.shade600)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(height: 2, color: Colors.grey.shade300));
  }
}
