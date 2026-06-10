import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_card.dart';
import '../ui/theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _historico = [];
  int _hoje = 0;
  int _autos = 0;
  int _pendentes = 0;

  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pendentes = await LocalDb.listarAutosSanitariosPendentesSync();
      if (kIsWeb) {
        final resumo = await _api.dashboardResumo();
        final historicoRaw = resumo['historico'];
        final historico = historicoRaw is List
            ? historicoRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _historico = historico;
          _hoje = (resumo['hoje'] as num?)?.toInt() ?? 0;
          _autos = (resumo['autos_emitidos'] as num?)?.toInt() ?? 0;
          _pendentes = pendentes.length;
        });
        return;
      }

      final autos = await LocalDb.listarAutosTermosLocal();
      final hoje = DateTime.now();
      bool isTodayFromRow(Map<String, dynamic> row) {
        final dataHora = (row['data_hora'] ?? '').toString().trim();
        if (dataHora.isNotEmpty) {
          try {
            final dt = DateTime.parse(dataHora);
            return dt.year == hoje.year && dt.month == hoje.month && dt.day == hoje.day;
          } catch (_) {}
        }
        final data = (row['data'] ?? row['data_documento'] ?? '').toString().trim();
        if (data.isEmpty) return false;
        if (data.length >= 10 && data[4] == '-' && data[7] == '-') {
          return data.startsWith(hoje.toIso8601String().substring(0, 10));
        }
        final dd = hoje.day.toString().padLeft(2, '0');
        final mm = hoje.month.toString().padLeft(2, '0');
        final yyyy = hoje.year.toString();
        return data.startsWith('$dd/$mm/$yyyy');
      }

      bool isInspecao(Map<String, dynamic> row) {
        final tipo = (row['tipo_auto'] ?? row['tipo_documento'] ?? '').toString().trim().toUpperCase();
        return tipo.contains('INSPECAO');
      }

      final historico = autos.take(10).toList();
      setState(() {
        _historico = historico;
        _hoje = autos.where((e) => isInspecao(e) && isTodayFromRow(e)).length;
        final statusEmitido = {'FINALIZADO', 'SEM_EFEITO', 'SEM EFEITO'};
        _autos = autos.where((e) => statusEmitido.contains((e['status'] ?? '').toString().trim().toUpperCase())).length;
        _pendentes = pendentes.length;
      });
    } catch (_) {
      setState(() {
        _historico = [];
        _hoje = 0;
        _autos = 0;
        _pendentes = 0;
      });
    }
  }

  String _tipoLabel(Map<String, dynamic> row) {
    final raw = (row['tipo'] ?? row['tipo_auto'] ?? row['tipo_documento'] ?? '').toString().trim();
    if (raw.isEmpty) return 'Documento';
    final up = raw.toUpperCase();
    if (up.contains('AUTO') && up.contains('INFR')) return 'Auto de Infração';
    if (up.contains('AUTO') && up.contains('INTIM')) return 'Auto de Intimação';
    if (up.contains('IMPOS')) return 'Auto de Imposição de Penalidade';
    if (up.contains('COLETA')) return 'Auto de Coleta de Amostra';
    if (up.contains('INSPECAO')) return 'Relatório de Inspeção Sanitária';
    return raw;
  }

  String _relativeDayLabel(String? value) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return '';
    DateTime? dt;
    try {
      if (s.length >= 10 && s[4] == '-' && s[7] == '-') {
        dt = DateTime.parse(s.length > 10 ? s : '${s}T00:00:00');
      } else if (s.length >= 10 && s[2] == '/' && s[5] == '/') {
        final parts = s.substring(0, 10).split('/');
        dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    if (dt == null) return s;
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final d1 = DateTime(dt.year, dt.month, dt.day);
    final diff = d0.difference(d1).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Column(
        children: [
          const AppHeader(fiscal: 'João Silva'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // opções removidas do dashboard; usar menu do Header (ícone de três riscos)
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: DashboardCard(title: 'Inspeções hoje', value: _hoje)),
                      const SizedBox(width: 12),
                      Expanded(child: DashboardCard(title: 'Autos emitidos', value: _autos, color: AppColors.vermelho)),
                      const SizedBox(width: 12),
                      Expanded(child: DashboardCard(title: 'Pendentes de sincronização', value: _pendentes, color: AppColors.laranja)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Histórico recente', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_historico.isEmpty)
                    Column(
                      children: const [
                        ListTile(title: Text('Padaria Central'), subtitle: Text('Auto de Infração • Hoje 14:22')),
                        ListTile(title: Text('Restaurante Mar Azul'), subtitle: Text('Auto de Intimação • Ontem')),
                      ],
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _historico.length,
                      itemBuilder: (ctx, i) {
                        final it = _historico[i];
                        final estab = (it['estabelecimento_nome'] ?? it['estabelecimentoNome'] ?? '').toString().trim();
                        final dataLabel = _relativeDayLabel((it['updated_at'] ?? it['data_hora'] ?? it['data_documento'] ?? it['data'])?.toString());
                        final status = (it['status'] ?? '').toString().trim();
                        return ListTile(
                          title: Text(estab.isEmpty ? '-' : estab),
                          subtitle: Text('${_tipoLabel(it)} • $dataLabel'),
                          trailing: Text(status),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
