import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../ui/theme.dart';
import '../storage/db.dart';
import '../services/api.dart';

class RiskProfilePage extends StatefulWidget {
  const RiskProfilePage({super.key});

  @override
  State<RiskProfilePage> createState() => _RiskProfilePageState();
}

class _RiskProfilePageState extends State<RiskProfilePage> {
  // Dados
  Map<String, dynamic>? _estabelecimento;
  List<Map<String, dynamic>> _historico = [];
  List<Map<String, dynamic>> _evolucao = [];
  Map<String, int> _indicadores = {};
  bool _loading = false;
  String? _error;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _api.init();
        final data = await _api.buscarPerfilSanitario();
        if (!mounted) return;
        setState(() {
          _estabelecimento = data['estabelecimento'];
          _historico = data['historico'] ?? [];
          _evolucao = data['evolucao'] ?? [];
          _indicadores = data['indicadores'] ?? {};
          _loading = false;
        });
      } else {
        final db = await LocalDb.instance;
        final rows = await db.query('estabelecimentos', limit: 1);
        if (!mounted) return;
        if (rows.isNotEmpty) {
          setState(() {
            _estabelecimento = rows.first;
            _loading = false;
          });
        } else {
          setState(() {
            _loading = false;
            _error = 'Estabelecimento não encontrado.';
          });
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar perfil sanitário.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar perfil sanitário: $e';
      });
    }
  }

  /// Formata campo vazio para "Não informado"
  String _formatEmpty(dynamic value) {
    if (value == null) return 'Não informado';
    final text = '$value'.trim();
    if (text.isEmpty || text == '-' || text == '--' || text == '()' || text == '- - ()') {
      return 'Não informado';
    }
    return text;
  }

  /// Formata CNPJ: 00.000.000/0000-00
  String _formatCnpj(String? cnpj) {
    if (cnpj == null || cnpj.isEmpty) return 'Não informado';
    final cleaned = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 14) return cnpj;
    return '${cleaned.substring(0, 2)}.${cleaned.substring(2, 5)}.${cleaned.substring(5, 8)}/${cleaned.substring(8, 12)}-${cleaned.substring(12, 14)}';
  }

  /// Formata telefone: (00) 00000-0000
  String _formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Não informado';
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6, 10)}';
    } else if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7, 11)}';
    }
    return phone;
  }

  /// Formata data ISO para DD/MM/AAAA HH:mm
  String _formatDateTime(dynamic date) {
    if (date == null) return 'Não informado';
    final text = '$date';
    if (text.isEmpty) return 'Não informado';
    try {
      final dateTime = DateTime.parse(text);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return text;
    }
  }

  /// Formata data ISO para DD/MM/AAAA
  String _formatDate(dynamic date) {
    if (date == null) return 'Não informado';
    final text = '$date';
    if (text.isEmpty) return 'Não informado';
    try {
      final dateTime = DateTime.parse(text);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return text;
    }
  }

  /// Retorna cor baseada no score de risco
  Color _riskColor(int score) {
    if (score <= 30) return AppColors.verde;
    if (score <= 60) return const Color(0xFFFFD600);
    if (score <= 80) return Colors.orange;
    return AppColors.vermelho;
  }

  /// Retorna classificação baseada no score
  String _riskClassification(int score) {
    if (score <= 30) return 'Baixo risco';
    if (score <= 60) return 'Médio risco';
    if (score <= 80) return 'Alto risco';
    return 'Crítico';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Sanitário'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
            onPressed: _loading ? null : _loadData,
            tooltip: 'Atualizar',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(),
            tooltip: 'Compartilhar PDF',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _estabelecimento == null
                  ? _buildEmptyState()
                  : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum estabelecimento encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione um estabelecimento para visualizar o perfil sanitário.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Principal
          _buildEstablishmentCard(),
          const SizedBox(height: 16),
          // Score de Risco
          _buildRiskScoreCard(),
          const SizedBox(height: 16),
          // Indicadores
          _buildIndicatorsCard(),
          const SizedBox(height: 16),
          // Evolução do Risco
          _buildEvolutionCard(),
          const SizedBox(height: 16),
          // Histórico
          _buildHistoryCard(),
          const SizedBox(height: 16),
          // Ações Rápidas
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildEstablishmentCard() {
    final est = _estabelecimento!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.azulInstitucional.withAlpha(26),
                  child: const Icon(Icons.business, color: AppColors.azulInstitucional),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatEmpty(est['nome_fantasia'] ?? est['nome'] ?? est['nomeFantasia']),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatEmpty(est['razao_social'] ?? est['razaoSocial'] ?? ''),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('CNPJ', _formatCnpj(est['cnpj'])),
            _infoRow('CNAE', _formatEmpty(est['cnae'])),
            _infoRow('Endereço', _formatEmpty(est['endereco'] ?? est['logradouro'] ?? est['logradouro'])),
            _infoRow('Bairro', _formatEmpty(est['bairro'])),
            _infoRow('Cidade', _formatEmpty(est['cidade'])),
            _infoRow('Telefone', _formatPhone(est['telefone'])),
            _infoRow('Email', _formatEmpty(est['email'])),
            _infoRow('Responsável', _formatEmpty(est['responsavel'])),
            const SizedBox(height: 8),
            Row(
              children: [
                _statusBadge('Status Sanitário', est['status_sanitario'] ?? est['statusSanitario'] ?? 'REGULAR'),
                const SizedBox(width: 8),
                _statusBadge('Alvará', est['status_alvara'] ?? est['statusAlvara'] ?? 'REGULAR'),
              ],
            ),
            _infoRow('Débito Vencido', (est['debito_vencido'] ?? est['debitoVencido'] ?? false) == true ? 'Sim' : 'Não'),
            _infoRow('Última Inspeção', _formatDateTime(est['ultima_inspecao'] ?? est['ultimaInspecao'])),
            _infoRow('Fiscal Responsável', _formatEmpty(est['fiscal_responsavel'] ?? est['fiscalResponsavel'])),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskScoreCard() {
    final est = _estabelecimento!;
    final score = est['score_risco'] ?? est['scoreRisco'] ?? 0;
    final scoreInt = score is int ? score : int.tryParse('$score') ?? 0;
    final color = _riskColor(scoreInt);
    final classification = _riskClassification(scoreInt);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                const Text('Score de Risco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (scoreInt / 100).clamp(0.0, 1.0),
                      minHeight: 16,
                      backgroundColor: AppColors.cinzaClaro,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$scoreInt/100', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Text(classification, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorsCard() {
    final totalInspecoes = _indicadores['total_inspecoes'] ?? _indicadores['totalInspecoes'] ?? 0;
    final totalAutos = _indicadores['total_autos'] ?? _indicadores['totalAutos'] ?? 0;
    final reincidencias = _indicadores['reincidencias'] ?? 0;
    final infracoesGraves = _indicadores['infracoes_graves'] ?? _indicadores['infracoesGraves'] ?? 0;
    final multas = _indicadores['multas'] ?? 0;
    final coletas = _indicadores['coletas'] ?? 0;
    final interdicoes = _indicadores['interdicoes'] ?? 0;
    final pendencias = _indicadores['pendencias'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                const Text('Indicadores Sanitários', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;
                if (narrow) {
                  return Column(
                    children: [
                      _indicatorItem('Inspeções', totalInspecoes, Icons.assignment, AppColors.azulInstitucional),
                      _indicatorItem('Autos', totalAutos, Icons.gavel, Colors.orange),
                      _indicatorItem('Reincidências', reincidencias, Icons.refresh, Colors.red),
                      _indicatorItem('Infrações Graves', infracoesGraves, Icons.warning, AppColors.vermelho),
                      _indicatorItem('Multas', multas, Icons.attach_money, Colors.green),
                      _indicatorItem('Coletas', coletas, Icons.science, Colors.purple),
                      _indicatorItem('Interdições', interdicoes, Icons.block, Colors.black),
                      _indicatorItem('Pendências', pendencias, Icons.pending, Colors.grey),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _indicatorItem('Inspeções', totalInspecoes, Icons.assignment, AppColors.azulInstitucional)),
                          const SizedBox(width: 12),
                          Expanded(child: _indicatorItem('Autos', totalAutos, Icons.gavel, Colors.orange)),
                          const SizedBox(width: 12),
                          Expanded(child: _indicatorItem('Reincidências', reincidencias, Icons.refresh, Colors.red)),
                          const SizedBox(width: 12),
                          Expanded(child: _indicatorItem('Infrações Graves', infracoesGraves, Icons.warning, AppColors.vermelho)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _indicatorItem('Multas', multas, Icons.attach_money, Colors.green)),
                          const SizedBox(width: 12),
                          Expanded(child: _indicatorItem('Coletas', coletas, Icons.science, Colors.purple)),
                          const SizedBox(width: 12),
                          Expanded(child: _indicatorItem('Interdições', interdicoes, Icons.block, Colors.black)),
                          const SizedBox(width: 12),
                          Expanded(child: _indicatorItem('Pendências', pendencias, Icons.pending, Colors.grey)),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionCard() {
    if (_evolucao.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                const Text('Evolução do Risco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _evolucao.map((e) {
                final periodo = e['periodo'] ?? e['data'] ?? '';
                final score = e['score'] ?? 0;
                final scoreInt = score is int ? score : int.tryParse('$score') ?? 0;
                final color = _riskColor(scoreInt);
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Text('$scoreInt', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  label: Text(_formatDate(periodo)),
                  backgroundColor: color.withOpacity(0.1),
                  side: BorderSide(color: color),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    if (_historico.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: AppColors.azulInstitucional),
                  const SizedBox(width: 8),
                  const Text('Histórico de Inspeções', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Nenhum histórico sanitário encontrado.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                const Text('Histórico de Inspeções', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ..._historico.asMap().entries.map((entry) {
              final index = entry.key;
              final h = entry.value;
              return _TimelineItem(
                isFirst: index == 0,
                isLast: index == _historico.length - 1,
                data: h,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                const Text('Ações Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;
                if (narrow) {
                  return Column(
                    children: [
                      _quickAction('Nova Inspeção', Icons.search, () => _startInspection()),
                      _quickAction('Emitir Documento', Icons.description, () => _emitDocument()),
                      _quickAction('Ver Mapa', Icons.map, () => _viewMap()),
                      _quickAction('Profissionais', Icons.people, () => _viewProfessionals()),
                      _quickAction('Compartilhar PDF', Icons.share, () => _sharePdf()),
                      _quickAction('Atualizar Dados', Icons.sync, () => _loadData()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _quickAction('Nova Inspeção', Icons.search, () => _startInspection())),
                          const SizedBox(width: 12),
                          Expanded(child: _quickAction('Emitir Documento', Icons.description, () => _emitDocument())),
                          const SizedBox(width: 12),
                          Expanded(child: _quickAction('Ver Mapa', Icons.map, () => _viewMap())),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _quickAction('Profissionais', Icons.people, () => _viewProfessionals())),
                          const SizedBox(width: 12),
                          Expanded(child: _quickAction('Compartilhar PDF', Icons.share, () => _sharePdf())),
                          const SizedBox(width: 12),
                          Expanded(child: _quickAction('Atualizar Dados', Icons.sync, () => _loadData())),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, String status) {
    final lower = status.toLowerCase();
    Color color;
    if (lower.contains('regular') || lower.contains('aprovado')) {
      color = AppColors.verde;
    } else if (lower.contains('vencido') || lower.contains('pendente')) {
      color = Colors.orange;
    } else if (lower.contains('interditado')) {
      color = Colors.black;
    } else {
      color = AppColors.azulInstitucional;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _indicatorItem(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.azulInstitucional,
        side: BorderSide(color: AppColors.azulInstitucional),
      ),
    );
  }

  void _startInspection() {
    final est = _estabelecimento!;
    Navigator.pushNamed(context, '/nova-inspecao', arguments: {
      'nome': est['nome_fantasia'] ?? est['nome'] ?? est['nomeFantasia'],
      'cnpj': est['cnpj'],
    });
  }

  void _emitDocument() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de emissão de documento será implementada.')),
    );
  }

  void _viewMap() {
    Navigator.pushNamed(context, '/mapa-sanitario');
  }

  void _viewProfessionals() {
    Navigator.pushNamed(context, '/profissionais');
  }

  void _sharePdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de compartilhamento PDF será implementada.')),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final Map<String, dynamic> data;

  const _TimelineItem({required this.isFirst, required this.isLast, required this.data});

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final dataStr = data['data'] ?? '';
    final tipo = data['tipo'] ?? '';
    final descricao = data['descricao'] ?? '';
    final penalidade = data['penalidade'] ?? '-';
    final fiscal = data['fiscal'] ?? '';
    final status = data['status'] ?? '';
    final observacoes = data['observacoes'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (!isFirst) Container(width: 2, height: 24, color: Colors.grey[300]),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.azulInstitucional,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast) Container(width: 2, height: 24, color: Colors.grey[300]),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$dataStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.azulInstitucional.withAlpha(26),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tipo, style: const TextStyle(color: AppColors.azulInstitucional, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(descricao),
                    const SizedBox(height: 4),
                    Text('Penalidade: $penalidade', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text('Fiscal: $fiscal', style: TextStyle(color: Colors.grey[600])),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Status: $status', style: TextStyle(color: Colors.grey[600])),
                    ],
                    if (observacoes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Observações: $observacoes', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
