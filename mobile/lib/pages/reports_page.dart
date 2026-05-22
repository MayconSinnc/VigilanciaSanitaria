import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Dados
  Map<String, int> _kpiData = {};
  bool _loading = false;
  String? _error;

  // Filtros
  final _periodoInicialCtrl = TextEditingController();
  final _periodoFinalCtrl = TextEditingController();
  final _fiscalCtrl = TextEditingController();
  final _estabelecimentoCtrl = TextEditingController();
  String? _tipoAuto;
  String? _situacao;
  String? _bairro;
  String? _risco;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _periodoInicialCtrl.dispose();
    _periodoFinalCtrl.dispose();
    _fiscalCtrl.dispose();
    _estabelecimentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _api.init();
        final data = await _api.buscarEstatisticas();
        if (!mounted) return;
        setState(() {
          _kpiData = data;
          _loading = false;
        });
      } else {
        final db = await LocalDb.instance;
        final inspCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM inspecoes')) ?? 0;
        final autoCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM autos')) ?? 0;
        final estabCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM estabelecimentos')) ?? 0;
        final pendentes = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM inspecoes WHERE status = "PENDENTE"')) ?? 0;
        if (!mounted) return;
        setState(() {
          _kpiData = {
            'inspecoes': inspCount,
            'autos': autoCount,
            'estabelecimentos': estabCount,
            'pendentes': pendentes,
          };
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar estatísticas.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar estatísticas: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios e Estatísticas'),
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
            icon: const Icon(Icons.download),
            onPressed: () => _showExportDialog(),
            tooltip: 'Exportar Geral',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtros
            _buildFilters(),
            const SizedBox(height: 24),
            // Cards Resumo
            _sectionHeader('Resumo de Atividades'),
            const SizedBox(height: 12),
            _buildKpiCards(),
            const SizedBox(height: 24),
            // Relatórios Disponíveis
            _sectionHeader('Relatórios Disponíveis'),
            const SizedBox(height: 12),
            _buildReportsList(),
            const SizedBox(height: 24),
            // Estatísticas
            _sectionHeader('Evolução Mensal'),
            const SizedBox(height: 12),
            _buildMonthlyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: AppColors.azulInstitucional, size: 20),
                const SizedBox(width: 8),
                const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _periodoInicialCtrl.clear();
                      _periodoFinalCtrl.clear();
                      _fiscalCtrl.clear();
                      _estabelecimentoCtrl.clear();
                      _tipoAuto = null;
                      _situacao = null;
                      _bairro = null;
                      _risco = null;
                    });
                  },
                  child: const Text('Limpar filtros'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;
                if (narrow) {
                  return Column(
                    children: [
                      OfficialDateField(
                        controller: _periodoInicialCtrl,
                        label: 'Período Inicial',
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      OfficialDateField(
                        controller: _periodoFinalCtrl,
                        label: 'Período Final',
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      OfficialTextField(
                        controller: _fiscalCtrl,
                        label: 'Fiscal Responsável',
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      OfficialTextField(
                        controller: _estabelecimentoCtrl,
                        label: 'Estabelecimento',
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      OfficialDropdownField(
                        label: 'Tipo de Auto',
                        value: _tipoAuto,
                        items: const ['INFRAÇÃO', 'INTIMAÇÃO', 'ADVERTÊNCIA', 'MULTA']
                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                        required: false,
                        onChanged: (value) => setState(() => _tipoAuto = value),
                      ),
                      const SizedBox(height: 12),
                      OfficialDropdownField(
                        label: 'Situação',
                        value: _situacao,
                        items: const ['CONCLUÍDO', 'PENDENTE', 'CANCELADO']
                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                        required: false,
                        onChanged: (value) => setState(() => _situacao = value),
                      ),
                      const SizedBox(height: 12),
                      OfficialDropdownField(
                        label: 'Risco Sanitário',
                        value: _risco,
                        items: const ['ALTO', 'MÉDIO', 'BAIXO']
                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                        required: false,
                        onChanged: (value) => setState(() => _risco = value),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OfficialDateField(
                              controller: _periodoInicialCtrl,
                              label: 'Período Inicial',
                              required: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OfficialDateField(
                              controller: _periodoFinalCtrl,
                              label: 'Período Final',
                              required: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OfficialTextField(
                              controller: _fiscalCtrl,
                              label: 'Fiscal Responsável',
                              required: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OfficialTextField(
                              controller: _estabelecimentoCtrl,
                              label: 'Estabelecimento',
                              required: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OfficialDropdownField(
                              label: 'Tipo de Auto',
                              value: _tipoAuto,
                              items: const ['INFRAÇÃO', 'INTIMAÇÃO', 'ADVERTÊNCIA', 'MULTA']
                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                              required: false,
                              onChanged: (value) => setState(() => _tipoAuto = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OfficialDropdownField(
                              label: 'Situação',
                              value: _situacao,
                              items: const ['CONCLUÍDO', 'PENDENTE', 'CANCELADO']
                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                              required: false,
                              onChanged: (value) => setState(() => _situacao = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OfficialDropdownField(
                              label: 'Risco Sanitário',
                              value: _risco,
                              items: const ['ALTO', 'MÉDIO', 'BAIXO']
                        .map((String e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                              required: false,
                              onChanged: (value) => setState(() => _risco = value),
                            ),
                          ),
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

  Widget _buildKpiCards() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
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

    final inspecoes = _kpiData['inspecoes'] ?? 0;
    final autos = _kpiData['autos'] ?? 0;
    final estabelecimentos = _kpiData['estabelecimentos'] ?? 0;
    final pendentes = _kpiData['pendentes'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;
        if (narrow) {
          return Column(
            children: [
              _reportCard('Inspeções', '$inspecoes', Icons.assignment, AppColors.azulInstitucional),
              const SizedBox(height: 12),
              _reportCard('Autos', '$autos', Icons.gavel, Colors.orange),
              const SizedBox(height: 12),
              _reportCard('Estabelecimentos', '$estabelecimentos', Icons.business, AppColors.verde),
              const SizedBox(height: 12),
              _reportCard('Pendentes', '$pendentes', Icons.sync, AppColors.vermelho),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _reportCard('Inspeções', '$inspecoes', Icons.assignment, AppColors.azulInstitucional)),
                  const SizedBox(width: 12),
                  Expanded(child: _reportCard('Autos', '$autos', Icons.gavel, Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _reportCard('Estabelecimentos', '$estabelecimentos', Icons.business, AppColors.verde)),
                  const SizedBox(width: 12),
                  Expanded(child: _reportCard('Pendentes', '$pendentes', Icons.sync, AppColors.vermelho)),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildReportsList() {
    final reports = [
      {'title': 'Inspeções por Período', 'description': 'PDF com inspeções realizadas no período selecionado.', 'icon': Icons.picture_as_pdf, 'type': 'PDF'},
      {'title': 'Produtividade do Fiscal', 'description': 'Ranking por período e equipe.', 'icon': Icons.trending_up, 'type': 'PDF'},
      {'title': 'Mapa de Risco por Bairro', 'description': 'Consolidação por região.', 'icon': Icons.map, 'type': 'PDF'},
      {'title': 'Arrecadação de Multas', 'description': 'Resumo financeiro.', 'icon': Icons.attach_money, 'type': 'PDF'},
      {'title': 'Autos Emitidos', 'description': 'Lista de autos por tipo e situação.', 'icon': Icons.gavel, 'type': 'PDF'},
      {'title': 'Pendências Sanitárias', 'description': 'Lista de pendências por estabelecimento.', 'icon': Icons.warning, 'type': 'PDF'},
      {'title': 'Estabelecimentos por CNAE', 'description': 'Classificação por atividade econômica.', 'icon': Icons.business, 'type': 'PDF'},
      {'title': 'Ranking de Risco Sanitário', 'description': 'Ordenação por nível de risco.', 'icon': Icons.bar_chart, 'type': 'PDF'},
      {'title': 'Histórico de Fiscalizações', 'description': 'Timeline de ações fiscais.', 'icon': Icons.history, 'type': 'PDF'},
      {'title': 'Vistorias Pendentes', 'description': 'Lista de vistorias agendadas.', 'icon': Icons.calendar_today, 'type': 'PDF'},
      {'title': 'Habite-se Sanitário', 'description': 'Solicitações e status.', 'icon': Icons.home_work, 'type': 'PDF'},
      {'title': 'Alvarás Vencidos', 'description': 'Lista de documentos vencidos.', 'icon': Icons.badge, 'type': 'PDF'},
    ];

    return Column(
      children: reports.map((report) => _reportListTile(
        report['title'] as String,
        report['description'] as String,
        report['icon'] as IconData,
        report['type'] as String,
      )).toList(),
    );
  }

  Widget _buildMonthlyChart() {
    final monthly = [
      {'m': 'Jan', 'inspecoes': 8, 'autos': 2},
      {'m': 'Fev', 'inspecoes': 11, 'autos': 4},
      {'m': 'Mar', 'inspecoes': 15, 'autos': 5},
      {'m': 'Abr', 'inspecoes': 12, 'autos': 3},
      {'m': 'Mai', 'inspecoes': 18, 'autos': 6},
      {'m': 'Jun', 'inspecoes': 14, 'autos': 4},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Evolução Mensal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...monthly.map((e) {
              final insp = (e['inspecoes'] as int?) ?? 0;
              final autos = (e['autos'] as int?) ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 36, child: Text('${e['m']}')),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (insp / 20).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: AppColors.cinzaClaro,
                          valueColor: const AlwaysStoppedAnimation(AppColors.azulInstitucional),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 34, child: Text('$insp')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (autos / 10).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: AppColors.cinzaClaro,
                          valueColor: const AlwaysStoppedAnimation(Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 34, child: Text('$autos')),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Text('Inspeções', style: TextStyle(color: AppColors.azulInstitucional))),
                Expanded(child: Text('Autos', style: TextStyle(color: Colors.orange))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.azulInstitucional),
    );
  }

  Widget _reportCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _reportListTile(String title, String subtitle, IconData icon, String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.azulInstitucional),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.azulInstitucional.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(type, style: const TextStyle(color: AppColors.azulInstitucional, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _showReportDialog(title, type),
      ),
    );
  }

  void _showReportDialog(String title, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gerar relatório com os filtros atuais?'),
            const SizedBox(height: 12),
            if (_periodoInicialCtrl.text.isNotEmpty || _periodoFinalCtrl.text.isNotEmpty) ...[
              Text('Período: ${_periodoInicialCtrl.text} a ${_periodoFinalCtrl.text}', style: const TextStyle(color: Colors.grey)),
            ],
            if (_fiscalCtrl.text.isNotEmpty) ...[
              Text('Fiscal: ${_fiscalCtrl.text}', style: const TextStyle(color: Colors.grey)),
            ],
            if (_estabelecimentoCtrl.text.isNotEmpty) ...[
              Text('Estabelecimento: ${_estabelecimentoCtrl.text}', style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateReport(title, type);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Geral'),
        content: const Text('Exportar todos os dados consolidados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateReport('Relatório Geral', 'PDF');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: const Text('Exportar PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReport(String title, String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gerando relatório...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Simular geração de relatório
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title gerado com sucesso.'),
          backgroundColor: AppColors.verde,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar relatório: $e'),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }
}

