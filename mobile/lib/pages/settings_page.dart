import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/epublica_integration_service.dart';
import '../ui/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = ApiService();
  late final EpublicaIntegrationService _integrationService;

  bool _loadingEmpresas = false;
  bool _loadingPenalidades = false;
  bool _loadingAutos = false;

  ImportResult? _resultadoEmpresas;
  ImportResult? _resultadoPenalidades;
  ImportResult? _resultadoAutos;

  String? _ultimaSincronizacao;
  String _ambiente = 'Desenvolvimento';
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _integrationService = EpublicaIntegrationService(apiService: _api);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      await _api.init();
      final ultima = await _api.readPreference('ultima_sincronizacao');
      final ambiente = await _api.readPreference('ambiente');
      if (!mounted) return;
      setState(() {
        _ultimaSincronizacao = ultima;
        _ambiente = ambiente ?? 'Desenvolvimento';
        _online = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _online = false);
    }
  }

  Future<void> _importEmpresas() async {
    setState(() {
      _loadingEmpresas = true;
      _resultadoEmpresas = null;
    });
    final result = await _integrationService.importarEstabelecimentos();
    if (!mounted) return;
    setState(() {
      _loadingEmpresas = false;
      _resultadoEmpresas = result;
    });
    await _afterImport(
      result,
      successMessage: 'Importação de estabelecimentos concluída.',
      warningMessage: 'Importação concluída com avisos.',
      errorMessage: 'Não foi possível importar estabelecimentos.',
    );
  }

  Future<void> _importPenalidades() async {
    setState(() {
      _loadingPenalidades = true;
      _resultadoPenalidades = null;
    });
    final result = await _integrationService.importarPenalidades();
    if (!mounted) return;
    setState(() {
      _loadingPenalidades = false;
      _resultadoPenalidades = result;
    });
    await _afterImport(
      result,
      successMessage: 'Importação de penalidades concluída.',
      warningMessage: 'Importação concluída com avisos.',
      errorMessage: 'Não foi possível importar penalidades.',
    );
  }

  Future<void> _importAutos() async {
    setState(() {
      _loadingAutos = true;
      _resultadoAutos = null;
    });
    final result = await _integrationService.importarAutosExternos();
    if (!mounted) return;
    setState(() {
      _loadingAutos = false;
      _resultadoAutos = result;
    });
    await _afterImport(
      result,
      successMessage: 'Importação de autos externos concluída.',
      warningMessage: 'Importação concluída com avisos.',
      errorMessage: 'Não foi possível importar autos externos.',
    );
  }

  Future<void> _afterImport(
    ImportResult result, {
    required String successMessage,
    required String warningMessage,
    required String errorMessage,
  }) async {
    if (result.ultimaSincronizacao != null && result.ultimaSincronizacao!.isNotEmpty) {
      _ultimaSincronizacao = result.ultimaSincronizacao;
      await _api.savePreference('ultima_sincronizacao', result.ultimaSincronizacao!);
    }

    if (!mounted) return;

    setState(() => _online = !result.connectionError);

    final snackMessage = result.message?.trim().isNotEmpty == true
        ? result.message!
        : result.hasWarnings
            ? warningMessage
            : result.success
                ? successMessage
                : errorMessage;

    final snackColor = result.success
        ? (result.hasWarnings ? Colors.orange.shade700 : AppColors.verde)
        : AppColors.vermelho;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackMessage),
        backgroundColor: snackColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações e Integração'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatus,
            tooltip: 'Atualizar status',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            const Text(
              'Dados da VISA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.azulInstitucional,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_phone_outlined, color: AppColors.azulInstitucional),
                title: const Text('Dados da VISA'),
                subtitle: const Text('Setor, telefone e e-mail utilizados automaticamente nos documentos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/configuracoes/dados-visa'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.gavel_outlined, color: AppColors.azulInstitucional),
                title: const Text('Bases Legais Padrão (Infração)'),
                subtitle: const Text('Define 2 bases legais padrão para o Auto de Infração'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/configuracoes/bases-padrao-infracao'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Integração e-Pública',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.azulInstitucional,
              ),
            ),
            const SizedBox(height: 16),
            _IntegrationActionCard(
              icon: Icons.business,
              label: 'Importar Estabelecimentos',
              description: 'Consulta econômicos, alvarás e débitos pela integração do backend.',
              loading: _loadingEmpresas,
              result: _resultadoEmpresas,
              onPressed: _loadingEmpresas ? null : _importEmpresas,
              formatDate: _formatDate,
            ),
            const SizedBox(height: 12),
            _IntegrationActionCard(
              icon: Icons.gavel,
              label: 'Importar Penalidades',
              description: 'Importa penalidades disponíveis ou informa indisponibilidade do endpoint.',
              loading: _loadingPenalidades,
              result: _resultadoPenalidades,
              onPressed: _loadingPenalidades ? null : _importPenalidades,
              formatDate: _formatDate,
            ),
            const SizedBox(height: 12),
            _IntegrationActionCard(
              icon: Icons.assignment_turned_in,
              label: 'Importar Autos Externos',
              description: 'Importa autos externos quando houver endpoint compatível na e-Pública.',
              loading: _loadingAutos,
              result: _resultadoAutos,
              onPressed: _loadingAutos ? null : _importAutos,
              formatDate: _formatDate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
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
                Icon(Icons.info_outline, color: AppColors.azulInstitucional),
                const SizedBox(width: 8),
                const Text(
                  'Status da Integração',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statusRow('Ambiente', _ambiente),
            _statusRow('Conexão', _online ? 'Online' : 'Offline'),
            _statusRow('Última Sincronização', _formatDate(_ultimaSincronizacao)),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Nunca sincronizado';
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }
}

class _IntegrationActionCard extends StatelessWidget {
  const _IntegrationActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.loading,
    required this.onPressed,
    required this.formatDate,
    this.result,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool loading;
  final ImportResult? result;
  final VoidCallback? onPressed;
  final String Function(String?) formatDate;

  @override
  Widget build(BuildContext context) {
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
                Icon(icon, color: AppColors.azulInstitucional, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(description, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download),
              label: loading ? const Text('Importando...') : const Text('Importar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulInstitucional,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _buildResultBox(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultBox() {
    final current = result!;
    final successColor = current.success ? AppColors.verde : AppColors.vermelho;
    final boxColor = successColor.withValues(alpha: 0.08);
    final title = current.success
        ? (current.hasErrors ? 'Importação concluída com avisos' : 'Importação concluída')
        : 'Importação não concluída';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: successColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                current.success ? Icons.check_circle : Icons.error_outline,
                color: successColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
              ),
            ],
          ),
          if (current.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(current.message!),
          ],
          const SizedBox(height: 8),
          Text('Importados: ${current.importados}'),
          Text('Atualizados: ${current.atualizados}'),
          Text('Ignorados: ${current.ignorados}'),
          Text('Última sincronização: ${formatDate(current.ultimaSincronizacao)}'),
          if (current.erros.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Erros/avisos:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            ...current.erros.take(5).map(Text.new),
          ],
        ],
      ),
    );
  }
}
