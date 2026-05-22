import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _inspecoes = [];
  int _hoje = 0;
  int _autos = 0;
  int _pendentes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await LocalDb.listarInspecoesLocal();
      setState(() {
        _inspecoes = list;
        final hojeStr = DateTime.now().toIso8601String().substring(0, 10);
        _hoje = list.where((e) => (e['data'] ?? '').toString().startsWith(hojeStr)).length;
        _autos = list.length;
        _pendentes = list.where((e) => (e['status'] ?? '') == 'PENDENTE').length;
      });
    } catch (_) {
      setState(() {
        _inspecoes = [];
        _hoje = 0;
        _autos = 0;
        _pendentes = 0;
      });
    }
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
                      Expanded(child: DashboardCard(title: 'Pendentes Sinc de sincronização', value: _pendentes, color: AppColors.laranja)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Histórico recente', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_inspecoes.isEmpty)
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
                      itemCount: _inspecoes.length,
                      itemBuilder: (ctx, i) {
                        final it = _inspecoes[i];
                        return ListTile(
                          title: Text('${it['tipo_auto'] ?? ''}'),
                          subtitle: Text('${it['data'] ?? ''} ${it['hora'] ?? ''}'),
                          trailing: Text('${it['status'] ?? ''}'),
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
