import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/step_header.dart';
import '../widgets/official_form_fields.dart';

class HabiteSePage extends StatefulWidget {
  const HabiteSePage({super.key});

  @override
  State<HabiteSePage> createState() => _HabiteSePageState();
}

class _HabiteSePageState extends State<HabiteSePage> {
  // Dados da lista
  List<Map<String, dynamic>> _solicitacoes = [];
  bool _loading = false;
  String? _error;

  // Filtros de busca
  final _searchCtrl = TextEditingController();
  final _protocoloCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSolicitacoes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _protocoloCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSolicitacoes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _api.init();
        final data = await _api.buscarHabiteSe();
        if (!mounted) return;
        setState(() {
          _solicitacoes = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _loading = false;
        });
      } else {
        final db = await LocalDb.instance;
        final rows = await db.query('habite_se', orderBy: 'data_solicitacao DESC');
        if (!mounted) return;
        setState(() {
          _solicitacoes = rows;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar solicitações.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar solicitações: $e';
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

  /// Formata CPF: 000.000.000-00
  String _formatCpf(String? cpf) {
    if (cpf == null || cpf.isEmpty) return 'Não informado';
    final cleaned = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 11) return cpf;
    return '${cleaned.substring(0, 3)}.${cleaned.substring(3, 6)}.${cleaned.substring(6, 9)}-${cleaned.substring(9, 11)}';
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
    if (lower.contains('aprovado')) return AppColors.verde;
    if (lower.contains('reprovado')) return AppColors.vermelho;
    if (lower.contains('em análise') || lower.contains('pendente')) return Colors.orange;
    if (lower.contains('vistoria') || lower.contains('agendada')) return AppColors.azulInstitucional;
    return Colors.grey;
  }

  /// Filtra as solicitações baseado nos filtros selecionados
  List<Map<String, dynamic>> _getFilteredSolicitacoes() {
    var filtered = _solicitacoes;

    // Filtro por busca (nome empreendimento)
    if (_searchCtrl.text.trim().isNotEmpty) {
      final search = _searchCtrl.text.trim().toLowerCase();
      filtered = filtered.where((sol) {
        final nome = sol['requerente'] ?? sol['empreendimento'] ?? sol['nome_empreendimento'] ?? '';
        return nome.toString().toLowerCase().contains(search);
      }).toList();
    }

    // Filtro por protocolo
    if (_protocoloCtrl.text.trim().isNotEmpty) {
      final protocolo = _protocoloCtrl.text.trim().toLowerCase();
      filtered = filtered.where((sol) {
        final prot = sol['protocolo'] ?? '';
        return prot.toString().toLowerCase().contains(protocolo);
      }).toList();
    }

    // Filtro por CNPJ
    if (_cnpjCtrl.text.trim().isNotEmpty) {
      final cnpjDigits = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
      filtered = filtered.where((sol) {
        final cnpj = sol['cnpj'] ?? '';
        final cnpjClean = cnpj.toString().replaceAll(RegExp(r'\D'), '');
        return cnpjClean.contains(cnpjDigits);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habite-se Sanitário'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
            onPressed: _loading ? null : _loadSolicitacoes,
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Ações rápidas
          _buildAcoesRapidas(),
          // Filtros avançados
          _buildFiltrosAvancados(),
          // Lista de solicitações
          Expanded(
            child: _buildListaSolicitacoes(),
          ),
        ],
      ),
    );
  }

  Widget _buildAcoesRapidas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.azulInstitucional.withAlpha(13),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/habite-se-form'),
              icon: const Icon(Icons.add),
              label: const Text('Nova Solicitação'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showConsultarProtocoloDialog(),
              icon: const Icon(Icons.search),
              label: const Text('Consultar Protocolo'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulClaro, foregroundColor: Colors.white),
            ),
          ),
        ],
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
              const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchCtrl.clear();
                    _protocoloCtrl.clear();
                    _cnpjCtrl.clear();
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
                      label: 'Buscar empreendimento',
                      hintText: 'Nome do empreendimento',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 12),
                    OfficialTextField(
                      controller: _protocoloCtrl,
                      label: 'Protocolo',
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    OfficialCnpjField(
                      controller: _cnpjCtrl,
                      label: 'CNPJ',
                      required: false,
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
                            label: 'Buscar empreendimento',
                            hintText: 'Nome do empreendimento',
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OfficialTextField(
                            controller: _protocoloCtrl,
                            label: 'Protocolo',
                            required: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OfficialCnpjField(
                      controller: _cnpjCtrl,
                      label: 'CNPJ',
                      required: false,
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

  Widget _buildListaSolicitacoes() {
    final filtered = _getFilteredSolicitacoes();

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
                onPressed: _loadSolicitacoes,
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
        return _buildSolicitacaoCard(item);
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
            Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma solicitação encontrada',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie uma nova solicitação ou ajuste os filtros.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/habite-se-form'),
              icon: const Icon(Icons.add),
              label: const Text('Nova Solicitação'),
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
                  _protocoloCtrl.clear();
                  _cnpjCtrl.clear();
                });
              },
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolicitacaoCard(Map<String, dynamic> item) {
    final protocolo = _formatEmpty(item['protocolo']);
    final requerente = _formatEmpty(item['requerente'] ?? item['empreendimento'] ?? item['nome_empreendimento']);
    final endereco = _formatEmpty(item['endereco']);
    final data = _formatDate(item['data'] ?? item['data_solicitacao']);
    final status = _formatEmpty(item['status']);
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
                      protocolo,
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
              Row(
                children: [
                  Icon(Icons.business, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(requerente, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(child: Text(endereco, style: TextStyle(color: Colors.grey[600]))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Data: $data', style: TextStyle(color: Colors.grey[600])),
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
                    onPressed: () => _showDetalheDialog(item),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
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

  void _showConsultarProtocoloDialog() {
    final protocoloCtrl = TextEditingController();
    final cnpjCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultar Protocolo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficialTextField(
                controller: protocoloCtrl,
                label: 'Protocolo',
                required: false,
              ),
              const SizedBox(height: 12),
              OfficialCnpjField(
                controller: cnpjCtrl,
                label: 'CNPJ',
                required: false,
              ),
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
              // Implementar busca por protocolo
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funcionalidade de consulta por protocolo será implementada.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: const Text('Consultar'),
          ),
        ],
      ),
    );
  }

  void _showDetalheDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes da Solicitação'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Protocolo', _formatEmpty(item['protocolo'])),
              _detailRow('Requerente', _formatEmpty(item['requerente'] ?? item['empreendimento'] ?? item['nome_empreendimento'])),
              _detailRow('Endereço', _formatEmpty(item['endereco'])),
              _detailRow('Data', _formatDate(item['data'] ?? item['data_solicitacao'])),
              _detailRow('Status', _formatEmpty(item['status'])),
              if (item['cnpj'] != null) _detailRow('CNPJ', _formatCnpj(item['cnpj'])),
              if (item['responsavel'] != null) _detailRow('Responsável', _formatEmpty(item['responsavel'])),
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
              // Implementar edição
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funcionalidade de edição será implementada.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white),
            child: const Text('Editar'),
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
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
