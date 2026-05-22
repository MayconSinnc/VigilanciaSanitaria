import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../storage/db.dart';
import '../services/api.dart';
import '../ui/theme.dart';

// Constantes de Design
const String _govBlueHex = '1351B4';
const Color _govBlue = Color(0xFF1351B4);
const Color _statusGreen = Color(0xFF27AE60);
const Color _statusYellow = Color(0xFFF39C12);
const Color _statusRed = Color(0xFFE74C3C);
const Color _darkGray = Color(0xFF2C3E50);
const Color _lightBg = Color(0xFFF8FAFC);

class InspectionsPage extends StatefulWidget {
  const InspectionsPage({super.key});
  @override
  State<InspectionsPage> createState() => _InspectionsPageState();
}

class _InspectionsPageState extends State<InspectionsPage> {
  List<Map<String, dynamic>> _inspecoes = [];
  Map<int, Map<String, dynamic>> _estabelecimentosById = {};
  String _filtroEstab = '';
  String _filtroFiscal = '';
  String _filtroData = '';
  DateTime? _filtroDataInicial;
  DateTime? _filtroDataFinal;
  String _filtroStatus = 'Todos';
  bool _loading = false;
  final ApiService _api = ApiService();
  final _filtroEstabCtrl = TextEditingController();
  final _filtroFiscalCtrl = TextEditingController();
  final _filtroDataCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filtroEstabCtrl.dispose();
    _filtroFiscalCtrl.dispose();
    _filtroDataCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await LocalDb.listarInspecoesLocal();
    Map<int, Map<String, dynamic>> estabById = {};
    if (!kIsWeb) {
      try {
        final db = await LocalDb.instance;
        final estab = await db.query('estabelecimentos');
        estabById = {
          for (final e in estab)
            ((e['id'] as num?)?.toInt() ?? -1): Map<String, dynamic>.from(e),
        }..remove(-1);
      } catch (_) {}
    }
    setState(() {
      _inspecoes = list;
      _estabelecimentosById = estabById;
    });
  }

  Future<void> _sync() async {
    setState(() => _loading = true);
    final res = await _api.sincronizarComServidor();
    setState(() => _loading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronização concluída: ${res['sincronizados']} ok, ${res['erros']} erro(s).'))
      );
      _load();
    }
  }

  DateTime? _parseDate(Object? value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return null;
    try {
      if (s.length >= 10) return DateTime.parse(s.substring(0, 10));
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _displayEstabelecimento(Map<String, dynamic> it) {
    final fromRow = (it['estabelecimento'] ?? '').toString().trim();
    if (fromRow.isNotEmpty) return fromRow;
    final id = (it['estabelecimento_id'] ?? it['estabelecimentoId'] ?? it['estabelecimento_id']) as Object?;
    final estabId = (id is num) ? id.toInt() : int.tryParse('$id');
    final e = estabId == null ? null : _estabelecimentosById[estabId];
    final nome = (e?['nome_fantasia'] ?? e?['nomeFantasia'] ?? e?['razao_social'] ?? e?['razaoSocial'] ?? '').toString().trim();
    if (nome.isNotEmpty) return nome;
    return estabId != null ? 'Estabelecimento #$estabId' : 'Estabelecimento';
  }

  String _displayFiscal(Map<String, dynamic> it) {
    final s = (it['fiscal'] ?? it['fiscal_nome'] ?? it['fiscalNome'] ?? '').toString().trim();
    return s.isEmpty ? '-' : s;
  }

  String _displayAuto(Map<String, dynamic> it) {
    final tipo = (it['tipo_auto'] ?? it['tipoAuto'] ?? '').toString().trim();
    return tipo.isEmpty ? '-' : tipo;
  }

  String _displaySituacao(Map<String, dynamic> it) {
    final s = (it['situacao'] ?? it['situacaoSanitaria'] ?? '').toString().trim();
    return s.isEmpty ? '-' : s;
  }

  String _displayRisco(Map<String, dynamic> it) {
    final id = (it['estabelecimento_id'] ?? it['estabelecimentoId']) as Object?;
    final estabId = (id is num) ? id.toInt() : int.tryParse('$id');
    final e = estabId == null ? null : _estabelecimentosById[estabId];
    final risco = (e?['risco'] ?? it['risco'] ?? '').toString().trim();
    return risco.isEmpty ? '-' : risco;
  }

  Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('IRREG')) return AppColors.vermelho;
    if (s.contains('PEND')) return const Color(0xFFF9A825);
    if (s.contains('CONCLU') || s.contains('REGULAR') || s.contains('ENVI')) return AppColors.verde;
    return Colors.blueGrey;
  }

  String _normalizeStatus(Object? value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return 'Pendente';
    return s;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    return items.where((e) {
      final estab = _displayEstabelecimento(e).toLowerCase();
      final fis = _displayFiscal(e).toLowerCase();
      final dat = (e['data'] ?? '').toString();
      if (!estab.contains(_filtroEstab.toLowerCase())) return false;
      if (!fis.contains(_filtroFiscal.toLowerCase())) return false;
      if (!dat.contains(_filtroData)) return false;
      if (_filtroStatus != 'Todos') {
        final st = _normalizeStatus(e['status']).toUpperCase();
        if (st != _filtroStatus.toUpperCase()) return false;
      }
      final d = _parseDate(e['data']);
      if (_filtroDataInicial != null && d != null && d.isBefore(_filtroDataInicial!)) return false;
      if (_filtroDataFinal != null && d != null && d.isAfter(_filtroDataFinal!)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _filtroDataInicial : _filtroDataFinal;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (isStart) {
        _filtroDataInicial = picked;
      } else {
        _filtroDataFinal = picked;
      }
    });
  }

  Map<String, int> _calcKpis(List<Map<String, dynamic>> items) {
    final today = _formatDate(DateTime.now());
    var doDia = 0;
    var pendentes = 0;
    var irregulares = 0;
    var autos = 0;
    for (final it in items) {
      final d = _parseDate(it['data']);
      if (d != null && _formatDate(d) == today) doDia++;
      final st = _normalizeStatus(it['status']).toUpperCase();
      if (st.contains('PEND')) pendentes++;
      if (st.contains('IRREG')) irregulares++;
      final tipo = (it['tipo_auto'] ?? '').toString().trim();
      if (tipo.isNotEmpty) autos++;
    }
    return {
      'doDia': doDia,
      'pendentes': pendentes,
      'irregulares': irregulares,
      'autos': autos,
    };
  }

  void _openActions(Map<String, dynamic> it) {
    final idRaw = it['estabelecimento_id'] ?? it['estabelecimentoId'];
    final estabId = (idRaw is num) ? idRaw.toInt() : int.tryParse('$idRaw');
    final estab = estabId == null ? null : _estabelecimentosById[estabId];
    Navigator.pushNamed(
      context,
      '/acoes-inspecao',
      arguments: {
        'nome': _displayEstabelecimento(it),
        'cnpj': (estab?['cnpj'] ?? it['cnpj'] ?? '-').toString(),
        'estabelecimentoId': estabId,
        'estabelecimento': estab,
      },
    );
  }

  void _openHistory(Map<String, dynamic> it) {
    final idRaw = it['estabelecimento_id'] ?? it['estabelecimentoId'];
    final estabId = (idRaw is num) ? idRaw.toInt() : int.tryParse('$idRaw');
    final estab = estabId == null ? null : _estabelecimentosById[estabId];
    if (estabId == null) return;
    Navigator.pushNamed(
      context,
      '/ficha-estabelecimento',
      arguments: {
        'id': estabId,
        'estabelecimento': estab,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(_inspecoes);
    final kpis = _calcKpis(_inspecoes);
    final statuses = <String>{
      for (final e in _inspecoes) _normalizeStatus(e['status']),
    }.toList()
      ..sort();
    final statusOptions = ['Todos', ...statuses.where((e) => e.trim().isNotEmpty)];
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1200;
    final isDesktop = width >= 1200;

    return Scaffold(
      backgroundColor: _lightBg,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        slivers: [
          // Header com KPIs
          SliverToBoxAdapter(
            child: _ModernHeader(
              totalInspecoes: _inspecoes.length,
              kpis: kpis,
              onSync: _loading ? null : _sync,
              isLoading: _loading,
            ),
          ),
          // Filtros modernos
          SliverToBoxAdapter(
            child: _ModernFilterCard(
              filtroEstabCtrl: _filtroEstabCtrl,
              filtroFiscalCtrl: _filtroFiscalCtrl,
              filtroDataCtrl: _filtroDataCtrl,
              filtroEstab: _filtroEstab,
              filtroFiscal: _filtroFiscal,
              filtroData: _filtroData,
              filtroDataInicial: _filtroDataInicial,
              filtroDataFinal: _filtroDataFinal,
              filtroStatus: _filtroStatus,
              statusOptions: statusOptions,
              onEstabChanged: (v) => setState(() => _filtroEstab = v),
              onFiscalChanged: (v) => setState(() => _filtroFiscal = v),
              onDataChanged: (v) => setState(() => _filtroData = v),
              onStatusChanged: (v) => setState(() => _filtroStatus = v),
              onPickDateStart: () => _pickDate(isStart: true),
              onPickDateEnd: () => _pickDate(isStart: false),
              onClear: _clearFilters,
              onApply: () {
                FocusScope.of(context).unfocus();
                setState(() {});
              },
              formatDate: _formatDate,
            ),
          ),
          // Contagem de inspeções
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Inspeções',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _darkGray,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _govBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _govBlue.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${filtered.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _govBlue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_outlined, color: _darkGray),
                    tooltip: 'Atualizar lista',
                  ),
                ],
              ),
            ),
          ),
          // Lista vazia
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(onNewInspection: () => Navigator.pushNamed(context, '/nova-inspecao')),
            )
          // Lista preenchida
          else if (isMobile)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) => _buildInspectionCard(filtered[idx], context),
              ),
            )
          else if (isTablet)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) => _buildInspectionCard(filtered[idx], context),
                  childCount: filtered.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) => _buildInspectionCard(filtered[idx], context),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildInspectionCard(Map<String, dynamic> item, BuildContext context) {
    return _InspectionCard(
      item: item,
      estabelecimento: _displayEstabelecimento(item),
      fiscal: _displayFiscal(item),
      data: (item['data'] ?? '').toString(),
      hora: (item['hora'] ?? '').toString(),
      status: _normalizeStatus(item['status']),
      risco: _displayRisco(item),
      situacao: _displaySituacao(item),
      autoEmitido: _displayAuto(item),
      statusColor: _statusColor(_normalizeStatus(item['status'])),
      onTap: () => Navigator.pushNamed(context, '/formulario'),
      onActions: () => _openActions(item),
      onHistory: () => _openHistory(item),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _govBlue,
      foregroundColor: Colors.white,
      shadowColor: _govBlue.withOpacity(0.5),
      title: Text(
        'Vigilância Sanitária',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_outlined),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (_loading)
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            ),
          ).marginRight(16)
        else
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: _sync,
            tooltip: 'Sincronizar com servidor',
          ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {},
          tooltip: 'Informações',
        ),
      ],
    );
  }

  FloatingActionButton _buildModernFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/nova-inspecao'),
      backgroundColor: _govBlue,
      foregroundColor: Colors.white,
      elevation: 12,
      icon: const Icon(Icons.add_outlined, size: 24),
      label: const Text(
        'Nova Inspeção',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _clearFilters() {
    _filtroEstabCtrl.clear();
    _filtroFiscalCtrl.clear();
    _filtroDataCtrl.clear();
    setState(() {
      _filtroEstab = '';
      _filtroFiscal = '';
      _filtroData = '';
      _filtroDataInicial = null;
      _filtroDataFinal = null;
      _filtroStatus = 'Todos';
    });
  }
}

// ============================================================================
// WIDGETS MODERNOS
// ============================================================================

/// Header moderno com KPIs destacados
class _ModernHeader extends StatelessWidget {
  final int totalInspecoes;
  final Map<String, int> kpis;
  final VoidCallback? onSync;
  final bool isLoading;

  const _ModernHeader({
    required this.totalInspecoes,
    required this.kpis,
    this.onSync,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [_govBlue, _govBlue.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _govBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título e ícone
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INSPEÇÕES SANITÁRIAS',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sistema de Vigilância Municipal',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSync != null)
                  IconButton(
                    onPressed: isLoading ? null : onSync,
                    icon: const Icon(Icons.cloud_sync_outlined, color: Colors.white),
                    tooltip: 'Sincronizar com servidor',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Resumo em texto
            Wrap(
              spacing: 16,
              children: [
                _SummaryChip(label: 'Total', value: '$totalInspecoes'),
                _SummaryChip(label: 'Pendentes', value: '${kpis['pendentes']}', color: _statusYellow),
                _SummaryChip(label: 'Irregulares', value: '${kpis['irregulares']}', color: _statusRed),
              ],
            ),
            const SizedBox(height: 18),
            // Cards de KPI — 4 na mesma linha em telas largas
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final kpiCards = [
                  _KpiCard(
                    label: 'Do Dia',
                    value: '${kpis['doDia']}',
                    icon: Icons.today_outlined,
                    color: const Color(0xFFE3F2FD),
                    accent: const Color(0xFF1976D2),
                  ),
                  _KpiCard(
                    label: 'Irregulares',
                    value: '${kpis['irregulares']}',
                    icon: Icons.warning_outlined,
                    color: const Color(0xFFFFEBEE),
                    accent: _statusRed,
                  ),
                  _KpiCard(
                    label: 'Autos',
                    value: '${kpis['autos']}',
                    icon: Icons.description_outlined,
                    color: const Color(0xFFFFF3E0),
                    accent: const Color(0xFFE65100),
                  ),
                  _KpiCard(
                    label: 'Pendentes',
                    value: '${kpis['pendentes']}',
                    icon: Icons.hourglass_top_outlined,
                    color: const Color(0xFFFFFDE7),
                    accent: _statusYellow,
                  ),
                ];

                if (constraints.maxWidth < 520) {
                  final itemWidth = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: kpiCards
                        .map((card) => SizedBox(width: itemWidth, child: card))
                        .toList(),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < kpiCards.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(child: kpiCards[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de resumo (chip) para o header
class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card com KPI individual - estilo moderno
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color accent;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de filtros modernos e elegantes
class _ModernFilterCard extends StatefulWidget {
  final TextEditingController filtroEstabCtrl;
  final TextEditingController filtroFiscalCtrl;
  final TextEditingController filtroDataCtrl;
  final String filtroEstab;
  final String filtroFiscal;
  final String filtroData;
  final DateTime? filtroDataInicial;
  final DateTime? filtroDataFinal;
  final String filtroStatus;
  final List<String> statusOptions;
  final Function(String) onEstabChanged;
  final Function(String) onFiscalChanged;
  final Function(String) onDataChanged;
  final Function(String) onStatusChanged;
  final VoidCallback onPickDateStart;
  final VoidCallback onPickDateEnd;
  final VoidCallback onClear;
  final VoidCallback onApply;
  final String Function(DateTime) formatDate;

  const _ModernFilterCard({
    required this.filtroEstabCtrl,
    required this.filtroFiscalCtrl,
    required this.filtroDataCtrl,
    required this.filtroEstab,
    required this.filtroFiscal,
    required this.filtroData,
    required this.filtroDataInicial,
    required this.filtroDataFinal,
    required this.filtroStatus,
    required this.statusOptions,
    required this.onEstabChanged,
    required this.onFiscalChanged,
    required this.onDataChanged,
    required this.onStatusChanged,
    required this.onPickDateStart,
    required this.onPickDateEnd,
    required this.onClear,
    required this.onApply,
    required this.formatDate,
  });

  @override
  State<_ModernFilterCard> createState() => _ModernFilterCardState();
}

class _ModernFilterCardState extends State<_ModernFilterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do card de filtros
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _govBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_outlined, color: _govBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Filtros de Busca',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _darkGray,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less_outlined : Icons.expand_more_outlined,
                    color: _govBlue,
                  ),
                  iconSize: 20,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 14),
              // Filtros em grid responsivo
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 500;
                  final cols = isMobile ? 1 : 2;
                  final spacing = 12.0;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - spacing) / cols,
                        child: _FilterTextField(
                          label: 'Estabelecimento',
                          icon: Icons.store_outlined,
                          controller: widget.filtroEstabCtrl,
                          onChanged: widget.onEstabChanged,
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - spacing) / cols,
                        child: _FilterTextField(
                          label: 'Fiscal',
                          icon: Icons.person_outline,
                          controller: widget.filtroFiscalCtrl,
                          onChanged: widget.onFiscalChanged,
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - spacing) / cols,
                        child: _FilterTextField(
                          label: 'Data (YYYY-MM-DD)',
                          icon: Icons.calendar_today_outlined,
                          controller: widget.filtroDataCtrl,
                          onChanged: widget.onDataChanged,
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - spacing) / cols,
                        child: _FilterDateButton(
                          label: 'Data Inicial',
                          icon: Icons.date_range_outlined,
                          date: widget.filtroDataInicial,
                          formatDate: widget.formatDate,
                          onTap: widget.onPickDateStart,
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - spacing) / cols,
                        child: _FilterDateButton(
                          label: 'Data Final',
                          icon: Icons.event_outlined,
                          date: widget.filtroDataFinal,
                          formatDate: widget.formatDate,
                          onTap: widget.onPickDateEnd,
                        ),
                      ),
                      SizedBox(
                        width: isMobile
                            ? constraints.maxWidth
                            : (constraints.maxWidth - spacing) / cols,
                        child: _FilterDropdown(
                          label: 'Status',
                          icon: Icons.check_circle_outline,
                          value: widget.filtroStatus,
                          items: widget.statusOptions,
                          onChanged: widget.onStatusChanged,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onClear,
                      icon: const Icon(Icons.clear_all_outlined, size: 18),
                      label: const Text('Limpar'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black26),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onApply,
                      icon: const Icon(Icons.search_outlined, size: 18),
                      label: const Text('Aplicar Filtros'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _govBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Campo de texto para filtro com ícone
class _FilterTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final Function(String) onChanged;

  const _FilterTextField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _govBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

/// Botão para selecionar data no filtro
class _FilterDateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? date;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _FilterDateButton({
    required this.label,
    required this.icon,
    required this.date,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _govBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null ? '-' : formatDate(date!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkGray,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown para filtro de status
class _FilterDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final Function(String) onChanged;

  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => onChanged(v ?? 'Todos'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _govBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

/// Estado vazio - quando não há inspeções
class _EmptyState extends StatelessWidget {
  final VoidCallback onNewInspection;

  const _EmptyState({required this.onNewInspection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _govBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.search_off_outlined, size: 40, color: _govBlue),
              ),
              const SizedBox(height: 20),
              Text(
                'Nenhuma inspeção encontrada',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _darkGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tente ajustar os filtros ou crie uma nova inspeção',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onNewInspection,
                icon: const Icon(Icons.add_outlined),
                label: const Text('Nova Inspeção'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card moderno de inspeção com todas as informações
class _InspectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String estabelecimento;
  final String data;
  final String hora;
  final String fiscal;
  final String status;
  final Color statusColor;
  final String risco;
  final String autoEmitido;
  final String situacao;
  final VoidCallback onTap;
  final VoidCallback onActions;
  final VoidCallback onHistory;

  const _InspectionCard({
    required this.item,
    required this.estabelecimento,
    required this.data,
    required this.hora,
    required this.fiscal,
    required this.status,
    required this.statusColor,
    required this.risco,
    required this.autoEmitido,
    required this.situacao,
    required this.onTap,
    required this.onActions,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com nome do estabelecimento e status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  estabelecimento,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _darkGray,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 12),
                // Informações: data, hora, fiscal
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      icon: Icons.event_outlined,
                      label: data.isEmpty ? '-' : data,
                      color: _govBlue,
                    ),
                    _InfoChip(
                      icon: Icons.schedule_outlined,
                      label: hora.isEmpty ? '-' : hora,
                      color: _govBlue,
                    ),
                    _InfoChip(
                      icon: Icons.person_outline,
                      label: fiscal,
                      color: _govBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tags de informações adicionais
                Row(
                  children: [
                    Expanded(
                      child: _InfoTag(label: 'Risco', value: risco),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoTag(label: 'Auto', value: autoEmitido),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoTag(label: 'Situação', value: situacao),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Botões de ação
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onHistory,
                        icon: const Icon(Icons.history_outlined, size: 16),
                        label: const Text('Histórico'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onActions,
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Autos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _govBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge de status com cores fortes
class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Chip de informação no card
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Tag de informação adicional no card
class _InfoTag extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _lightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _darkGray,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXTENSÃO DE UTILIDADE
// ============================================================================

extension _PaddingExtension on Widget {
  Widget marginRight(double value) {
    return Padding(padding: EdgeInsets.only(right: value), child: this);
  }
}
