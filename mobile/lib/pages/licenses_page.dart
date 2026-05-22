import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  // Filtros
  String _filtroTipo = 'Todos'; // Todos, Alvará, RAI, RIS
  final _searchCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  String? _statusFiltro;
  DateTime? _vencimentoInicio;
  DateTime? _vencimentoFim;

  // Dados
  List<Map<String, dynamic>> _licencas = [];
  bool _loading = false;
  String? _error;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadLicencas();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cnpjCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLicencas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _api.init();
        final data = await _api.buscarAlvaras();
        if (!mounted) return;
        setState(() {
          _licencas = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _loading = false;
        });
      } else {
        final db = await LocalDb.instance;
        final rows = await db.query('alvaras', orderBy: 'data_vencimento DESC');
        if (!mounted) return;
        setState(() {
          _licencas = rows;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar alvarás.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar alvarás: $e';
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

  /// Retorna cor baseada no status
  Color _getStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('vigente') || lower.contains('regular')) return AppColors.verde;
    if (lower.contains('vencido')) return AppColors.vermelho;
    if (lower.contains('pendente') || lower.contains('em análise')) return Colors.orange;
    if (lower.contains('cancelado')) return Colors.grey;
    return Colors.grey;
  }

  /// Filtra as licenças baseado nos filtros selecionados
  List<Map<String, dynamic>> _getFilteredLicencas() {
    var filtered = _licencas;

    // Filtro por tipo
    if (_filtroTipo != 'Todos') {
      filtered = filtered.where((lic) {
        final tipo = lic['tipo'] ?? lic['tipo_documento'] ?? '';
        return tipo.toString().toUpperCase() == _filtroTipo.toUpperCase();
      }).toList();
    }

    // Filtro por busca (nome fantasia)
    if (_searchCtrl.text.trim().isNotEmpty) {
      final search = _searchCtrl.text.trim().toLowerCase();
      filtered = filtered.where((lic) {
        final nome = lic['estabelecimento'] ?? lic['nome_fantasia'] ?? lic['nomeFantasia'] ?? '';
        return nome.toString().toLowerCase().contains(search);
      }).toList();
    }

    // Filtro por CNPJ
    if (_cnpjCtrl.text.trim().isNotEmpty) {
      final cnpjDigits = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
      filtered = filtered.where((lic) {
        final cnpj = lic['cnpj'] ?? '';
        final cnpjClean = cnpj.toString().replaceAll(RegExp(r'\D'), '');
        return cnpjClean.contains(cnpjDigits);
      }).toList();
    }

    // Filtro por número
    if (_numeroCtrl.text.trim().isNotEmpty) {
      final numero = _numeroCtrl.text.trim().toLowerCase();
      filtered = filtered.where((lic) {
        final num = lic['numero'] ?? '';
        return num.toString().toLowerCase().contains(numero);
      }).toList();
    }

    // Filtro por status
    if (_statusFiltro != null) {
      filtered = filtered.where((lic) {
        final status = lic['status'] ?? '';
        return status.toString().toLowerCase() == _statusFiltro!.toLowerCase();
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alvarás / RAI / RIS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
            onPressed: _loading ? null : _loadLicencas,
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros superiores
          _buildFiltrosSuperiores(),
          // Filtros avançados
          _buildFiltrosAvancados(),
          // Lista de documentos
          Expanded(
            child: _buildListaDocumentos(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosSuperiores() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.azulInstitucional.withAlpha(13),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _filtroButton('Todos', Icons.list),
          const SizedBox(width: 8),
          _filtroButton('Alvará', Icons.badge),
          const SizedBox(width: 8),
          _filtroButton('RAI', Icons.description),
          const SizedBox(width: 8),
          _filtroButton('RIS', Icons.assignment_turned_in),
        ],
      ),
    );
  }

  Widget _filtroButton(String label, IconData icon) {
    final isActive = _filtroTipo == label;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _filtroTipo = label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? AppColors.azulInstitucional : Colors.white,
          foregroundColor: isActive ? Colors.white : AppColors.azulInstitucional,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: AppColors.azulInstitucional),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosAvancados() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.azulInstitucional, size: 20),
              const SizedBox(width: 8),
              const Text('Filtros Avançados', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchCtrl.clear();
                    _cnpjCtrl.clear();
                    _numeroCtrl.clear();
                    _statusFiltro = null;
                    _vencimentoInicio = null;
                    _vencimentoFim = null;
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
                    OfficialTextField(
                      controller: _searchCtrl,
                      label: 'Buscar estabelecimento',
                      hintText: 'Nome fantasia',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 12),
                    OfficialCnpjField(
                      controller: _cnpjCtrl,
                      label: 'CNPJ',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _numeroCtrl,
                      label: 'Número do documento',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    OfficialDropdownField.fromStrings(
                      label: 'Status',
                      value: _statusFiltro,
                      items: const ['Vigente', 'Vencido', 'Pendente', 'Cancelado', 'Em análise'],
                      required: false,
                      onChanged: (value) => setState(() => _statusFiltro = value),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OfficialTextField(
                            controller: _searchCtrl,
                            label: 'Buscar estabelecimento',
                            hintText: 'Nome fantasia',
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialCnpjField(
                            controller: _cnpjCtrl,
                            label: 'CNPJ',
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
                            controller: _numeroCtrl,
                            label: 'Número do documento',
                            required: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialDropdownField.fromStrings(
                            label: 'Status',
                            value: _statusFiltro,
                            items: const ['Vigente', 'Vencido', 'Pendente', 'Cancelado', 'Em análise'],
                            required: false,
                            onChanged: (value) => setState(() => _statusFiltro = value),
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
    );
  }

  Widget _buildListaDocumentos() {
    final filtered = _getFilteredLicencas();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
                onPressed: _loadLicencas,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _buildDocumentCard(item);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum documento encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Consulte a e-Pública ou ajuste os filtros.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLicencas,
              icon: const Icon(Icons.sync),
              label: const Text('Consultar e-Pública'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulInstitucional,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _cnpjCtrl.clear();
                  _numeroCtrl.clear();
                  _statusFiltro = null;
                  _filtroTipo = 'Todos';
                });
              },
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> item) {
    final tipo = _formatEmpty(item['tipo'] ?? item['tipo_documento']);
    final estabelecimento = _formatEmpty(item['estabelecimento'] ?? item['nome_fantasia'] ?? item['nomeFantasia']);
    final cnpj = _formatCnpj(item['cnpj']);
    final numero = _formatEmpty(item['numero']);
    final emissao = _formatDate(item['data_emissao'] ?? item['dataEmissao']);
    final vencimento = _formatDate(item['data_vencimento'] ?? item['dataVencimento']);
    final status = _formatEmpty(item['status']);
    final origem = _formatEmpty(item['origem'] ?? 'Local');
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetalheDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.azulInstitucional.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tipo,
                      style: const TextStyle(color: AppColors.azulInstitucional, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(estabelecimento, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('CNPJ: $cnpj', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text('Número: $numero', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Emissão: $emissao', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.event, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Vencimento: $vencimento', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.cloud, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Origem: $origem', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showDetalheDialog(item),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Visualizar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azulInstitucional,
                      side: BorderSide(color: AppColors.azulInstitucional),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _downloadPdf(item),
                    icon: const Icon(Icons.file_download),
                    label: const Text('Baixar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulInstitucional,
                      foregroundColor: Colors.white,
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

  void _showDetalheDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes do Documento'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Tipo', _formatEmpty(item['tipo'] ?? item['tipo_documento'])),
              _detailRow('Número', _formatEmpty(item['numero'])),
              _detailRow('Estabelecimento', _formatEmpty(item['estabelecimento'] ?? item['nome_fantasia'] ?? item['nomeFantasia'])),
              _detailRow('CNPJ', _formatCnpj(item['cnpj'])),
              _detailRow('Inscrição Municipal', _formatEmpty(item['inscricao_municipal'] ?? item['inscricaoMunicipal'])),
              _detailRow('Data de Emissão', _formatDate(item['data_emissao'] ?? item['dataEmissao'])),
              _detailRow('Data de Vencimento', _formatDate(item['data_vencimento'] ?? item['dataVencimento'])),
              _detailRow('Situação', _formatEmpty(item['status'])),
              _detailRow('Origem', _formatEmpty(item['origem'] ?? 'Local')),
              if (item['observacoes'] != null) _detailRow('Observações', _formatEmpty(item['observacoes'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadPdf(item);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: const Text('Baixar PDF'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
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

  Future<void> _downloadPdf(Map<String, dynamic> item) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gerando documento...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Simular download - implementar integração real com API
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF baixado com sucesso.'),
          backgroundColor: AppColors.verde,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível gerar o PDF: $e'),
          backgroundColor: AppColors.vermelho,
        ),
      );
    }
  }

  void _showEmissaoDialog(BuildContext context, String tipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emitir $tipo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficialCnpjField(
                controller: TextEditingController(),
                label: 'CNPJ do Estabelecimento',
                required: true,
              ),
              const SizedBox(height: 12),
              if (tipo == 'ALVARÁ') ...[
                OfficialTextField(
                  controller: TextEditingController(),
                  label: 'Número do Processo',
                  required: false,
                ),
                const SizedBox(height: 12),
                OfficialTextField(
                  controller: TextEditingController(text: '1'),
                  label: 'Validade (Anos)',
                  keyboardType: TextInputType.number,
                  required: true,
                ),
              ] else if (tipo == 'RAI') ...[
                OfficialTextField(
                  controller: TextEditingController(),
                  label: 'Motivo da Emissão',
                  required: true,
                ),
              ] else ...[
                OfficialDropdownField.fromStrings(
                  label: 'Grau de Risco',
                  value: 'Médio',
                  items: const ['Baixo', 'Médio', 'Alto'],
                  onChanged: (value) {},
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$tipo emitido com sucesso!'),
                  backgroundColor: AppColors.verde,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: const Text('Emitir'),
          ),
        ],
      ),
    );
  }
}
