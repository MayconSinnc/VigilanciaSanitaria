import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class EstablishmentsPage extends StatefulWidget {
  const EstablishmentsPage({super.key});
  @override
  State<EstablishmentsPage> createState() => _EstablishmentsPageState();
}

class _EstablishmentsPageState extends State<EstablishmentsPage> {
  final _searchCtrl = TextEditingController();
  final _api = ApiService();
  List<Map<String, dynamic>> _local = [];
  List<dynamic> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    Future.microtask(_carregarApi);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    if (kIsWeb) {
      setState(() => _local = []);
      return;
    }
    final db = await LocalDb.instance;
    final rows = await db.query('estabelecimentos', orderBy: 'razao_social ASC');
    setState(() => _local = rows);
  }

  Future<void> _carregarApi() async {
    setState(() {
      _loading = true;
      _results = [];
      _error = null;
    });
    try {
      final data = await _api.buscarEstabelecimentos('');
      if (!mounted) return;
      setState(() {
        _results = data;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar lista.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _buscar() async {
    final query = _searchCtrl.text.trim();
    
    // Validar CNPJ se for numérico
    final digits = query.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty && digits.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CNPJ incompleto. Digite 14 dígitos.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return;
    }

    // Validar busca por texto se não for CNPJ
    if (digits.isEmpty && query.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite pelo menos 2 caracteres para buscar.'),
          backgroundColor: AppColors.vermelho,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _results = [];
      _error = null;
    });

    try {
      if (digits.length == 14) {
        // Busca por CNPJ
        final data = await _api.buscarEstabelecimentoPorCnpj(digits);
        if (!mounted) return;
        if (data != null) {
          setState(() => _loading = false);
          final changed = await Navigator.pushNamed(context, '/cadastro-estabelecimento', arguments: data);
          if (!mounted) return;
          if (changed == true) {
            await _loadLocal();
            await _carregarApi();
          }
          return;
        } else {
          setState(() {
            _loading = false;
            _error = 'CNPJ não encontrado na API/e-Pública.';
          });
          return;
        }
      }

      // Busca por nome/razão social
      final data = await _api.buscarEstabelecimentos(query);
      if (!mounted) return;
      setState(() {
        _results = data;
        _loading = false;
        _error = null;
      });
      if (data.isEmpty) {
        setState(() => _error = 'Nenhum estabelecimento encontrado na API.');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} na busca.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
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

  /// Retorna cor baseada no risco
  Color _getRiskColor(String risco) {
    final lower = risco.toLowerCase();
    if (lower.contains('baixo')) return AppColors.verde;
    if (lower.contains('médio') || lower.contains('medio')) return Colors.orange;
    if (lower.contains('alto')) return AppColors.vermelho;
    return Colors.grey;
  }

  /// Retorna cor baseada no status do alvará
  Color _getAlvaraColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('regular')) return AppColors.verde;
    if (lower.contains('vencido')) return AppColors.vermelho;
    if (lower.contains('não encontrado') || lower.contains('nao encontrado')) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estabelecimentos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
            onPressed: _loading ? null : _carregarApi,
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Card de busca
            _buildSearchCard(),
            // Lista de estabelecimentos
            Expanded(
              child: _buildEstablishmentsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.pushNamed(context, '/cadastro-estabelecimento');
          if (!mounted) return;
          if (changed == true) {
            await _loadLocal();
            await _carregarApi();
          }
        },
        backgroundColor: AppColors.azulInstitucional,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _error = null),
                  )
                ],
              ),
            ),
          OfficialTextField(
            controller: _searchCtrl,
            label: 'Buscar por nome fantasia, razão social ou CNPJ',
            hintText: 'Digite o nome ou CNPJ',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            ),
            const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: narrow ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: _buscar,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.azulInstitucional,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: narrow ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/buscar-cnpj'),
                      icon: const Icon(Icons.add_business),
                      label: const Text('Novo Estabelecimento'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.azulClaro,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: narrow ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/scanner-cnpj'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scanner CNPJ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.azulClaro,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstablishmentsList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasResults = _results.isNotEmpty;
    final hasLocal = !kIsWeb && _local.isNotEmpty;

    if (!hasResults && !hasLocal) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasResults) ...[
            Text('Estabelecimentos na API', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._results.map((e) => _buildApiEstablishmentCard(e)),
            const SizedBox(height: 24),
          ],
          if (hasLocal) ...[
            Text('Cadastro Local', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._local.map((e) => _buildLocalEstablishmentCard(e)),
          ],
        ],
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
            Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum estabelecimento encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Busque pelo nome/CNPJ ou cadastre um novo estabelecimento.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/buscar-cnpj'),
              icon: const Icon(Icons.add_business),
              label: const Text('Buscar na e-Pública'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulInstitucional,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/scanner-cnpj'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner CNPJ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulClaro,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiEstablishmentCard(dynamic e) {
    final nomeFantasia = _formatEmpty(e['nomeFantasia'] ?? e['razaoSocial']);
    final cnpj = _formatEmpty(e['cnpj']);
    final cidade = _formatEmpty(e['cidade']);
    final alvara = _formatEmpty(e['status_alvara'] ?? e['statusAlvara'] ?? 'Regular');
    final risco = _formatEmpty(e['risco_sanitario'] ?? e['riscoSanitario'] ?? 'Não calculado');
    final possuiDebito = e['possui_debito_vencido'] ?? e['possuiDebitoVencido'] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/ficha-estabelecimento',
          arguments: {
            'id': e['id'],
            'estabelecimento': Map<String, dynamic>.from(e as Map),
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business, color: AppColors.azulInstitucional, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nomeFantasia,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text('CNPJ: $cnpj'),
              if (cidade.isNotEmpty) Text('Cidade: $cidade'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusBadge('Alvará', alvara, _getAlvaraColor(alvara)),
                  if (possuiDebito)
                    _buildStatusBadge('Débito', 'Vencido', AppColors.vermelho),
                  _buildStatusBadge('Risco', risco, _getRiskColor(risco)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalEstablishmentCard(Map<String, dynamic> e) {
    final nomeFantasia = _formatEmpty(e['nome_fantasia'] ?? e['razao_social']);
    final cnpj = _formatEmpty(e['cnpj']);
    final alvara = _formatEmpty(e['status_alvara'] ?? e['statusAlvara'] ?? 'Regular');
    final risco = _formatEmpty(e['risco'] ?? 'Indefinido');
    final possuiDebito = e['debito_vencido'] ?? e['debitoVencido'] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, color: AppColors.azulInstitucional, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nomeFantasia,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('CNPJ: $cnpj'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusBadge('Alvará', alvara, _getAlvaraColor(alvara)),
                if (possuiDebito)
                  _buildStatusBadge('Débito', 'Vencido', AppColors.vermelho),
                _buildStatusBadge('Risco', risco, _getRiskColor(risco)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 600;
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/ficha-estabelecimento',
                          arguments: {'id': e['id'], 'estabelecimento': e},
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Ver estabelecimento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.azulInstitucional,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (!narrow) const SizedBox(width: 12),
                    if (!narrow)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/cadastro-estabelecimento', arguments: e),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azulClaro,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (narrow) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/cadastro-estabelecimento', arguments: e),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azulClaro,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
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

  Widget _buildStatusBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
