import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class ProfessionalsPage extends StatefulWidget {
  const ProfessionalsPage({super.key});

  @override
  State<ProfessionalsPage> createState() => _ProfessionalsPageState();
}

class _ProfessionalsPageState extends State<ProfessionalsPage> {
  // Dados
  List<Map<String, dynamic>> _profissionais = [];
  bool _loading = false;
  String? _error;

  // Filtros
  final _searchCtrl = TextEditingController();

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadProfissionais();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfissionais() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _api.init();
        final data = await _api.buscarProfissionais();
        if (!mounted) return;
        setState(() {
          _profissionais = List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _loading = false;
        });
      } else {
        final db = await LocalDb.instance;
        final rows = await db.query('profissionais', orderBy: 'nome');
        if (!mounted) return;
        setState(() {
          _profissionais = rows;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar profissionais.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar profissionais: $e';
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

  /// Formata CPF: 000.000.000-00
  String _formatCpf(String? cpf) {
    if (cpf == null || cpf.isEmpty) return 'Não informado';
    final cleaned = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 11) return cpf;
    return '${cleaned.substring(0, 3)}.${cleaned.substring(3, 6)}.${cleaned.substring(6, 9)}-${cleaned.substring(9, 11)}';
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

  /// Filtra profissionais baseado na busca
  List<Map<String, dynamic>> _getFilteredProfissionais() {
    var filtered = _profissionais;

    if (_searchCtrl.text.trim().isNotEmpty) {
      final search = _searchCtrl.text.trim().toLowerCase();
      filtered = filtered.where((prof) {
        final nome = prof['nome'] ?? '';
        final cargo = prof['cargo'] ?? prof['funcao'] ?? '';
        final matricula = prof['matricula'] ?? '';
        return nome.toString().toLowerCase().contains(search) ||
               cargo.toString().toLowerCase().contains(search) ||
               matricula.toString().toLowerCase().contains(search);
      }).toList();
    }

    return filtered;
  }

  /// Calcula KPIs
  Map<String, int> _getKpis() {
    final filtered = _getFilteredProfissionais();
    final ativos = filtered.where((p) => (p['status'] ?? '').toString().toUpperCase() == 'ATIVO').length;
    final inativos = filtered.where((p) => (p['status'] ?? '').toString().toUpperCase() == 'INATIVO').length;
    final fiscais = filtered.where((p) {
      final cargo = (p['cargo'] ?? p['funcao'] ?? '').toString().toLowerCase();
      return cargo.contains('fiscal');
    }).length;

    return {
      'ativos': ativos,
      'total': filtered.length,
      'inativos': inativos,
      'fiscais': fiscais,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profissionais'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
            onPressed: _loading ? null : _loadProfissionais,
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Busca
          _buildSearchBar(),
          // Cards KPI
          _buildKpiCards(),
          // Lista
          Expanded(
            child: _buildProfissionaisList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfessionalForm(),
        backgroundColor: AppColors.azulInstitucional,
        child: const Icon(Icons.add),
        tooltip: 'Novo Profissional',
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: OfficialTextField(
        controller: _searchCtrl,
        label: 'Buscar por nome, cargo ou matrícula',
        hintText: 'Digite para buscar...',
        prefixIcon: const Icon(Icons.search),
        required: false,
        onChanged: (_) => setState(() {}),
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
    );
  }

  Widget _buildKpiCards() {
    final kpis = _getKpis();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.azulInstitucional.withAlpha(13),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 600;
          if (narrow) {
            return Column(
              children: [
                _KpiCard(title: 'Ativos', value: kpis['ativos'].toString(), icon: Icons.verified_user, color: AppColors.verde),
                const SizedBox(height: 12),
                _KpiCard(title: 'Equipe', value: kpis['total'].toString(), icon: Icons.people, color: AppColors.azulInstitucional),
                const SizedBox(height: 12),
                _KpiCard(title: 'Inativos', value: kpis['inativos'].toString(), icon: Icons.person_off, color: Colors.grey),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: _KpiCard(title: 'Ativos', value: kpis['ativos'].toString(), icon: Icons.verified_user, color: AppColors.verde),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(title: 'Equipe', value: kpis['total'].toString(), icon: Icons.people, color: AppColors.azulInstitucional),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(title: 'Inativos', value: kpis['inativos'].toString(), icon: Icons.person_off, color: Colors.grey),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProfissionaisList() {
    final filtered = _getFilteredProfissionais();

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
                onPressed: _loadProfissionais,
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
        return _buildProfessionalCard(item);
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
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum profissional encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Cadastre um profissional para iniciar as inspeções.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showProfessionalForm(),
              icon: const Icon(Icons.add),
              label: const Text('Novo Profissional'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulInstitucional,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalCard(Map<String, dynamic> item) {
    final nome = _formatEmpty(item['nome']);
    final cargo = _formatEmpty(item['cargo'] ?? item['funcao']);
    final matricula = _formatEmpty(item['matricula']);
    final cpf = _formatCpf(item['cpf']);
    final telefone = _formatPhone(item['telefone']);
    final email = _formatEmpty(item['email']);
    final status = _formatEmpty(item['status']);
    final statusColor = status.toUpperCase() == 'ATIVO' ? AppColors.verde : Colors.grey;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showProfessionalDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withAlpha(26),
                        child: Icon(Icons.person, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('$cargo • $matricula', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
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
              if (cpf != 'Não informado') _buildInfoRow(Icons.badge, 'CPF', cpf),
              if (telefone != 'Não informado') _buildInfoRow(Icons.phone, 'Telefone', telefone),
              if (email != 'Não informado') _buildInfoRow(Icons.email, 'Email', email),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showProfessionalDetail(item),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Visualizar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azulInstitucional,
                      side: BorderSide(color: AppColors.azulInstitucional),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showProfessionalForm(item),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[600])),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
  }

  void _showProfessionalDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes do Profissional'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Nome', _formatEmpty(item['nome'])),
              _detailRow('Cargo', _formatEmpty(item['cargo'] ?? item['funcao'])),
              _detailRow('Matrícula', _formatEmpty(item['matricula'])),
              _detailRow('CPF', _formatCpf(item['cpf'])),
              _detailRow('Telefone', _formatPhone(item['telefone'])),
              _detailRow('Email', _formatEmpty(item['email'])),
              _detailRow('Status', _formatEmpty(item['status'])),
              if (item['conselho'] != null) _detailRow('Conselho', _formatEmpty(item['conselho'])),
              if (item['registro_profissional'] != null) _detailRow('Registro', _formatEmpty(item['registro_profissional'])),
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
              _showProfessionalForm(item);
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

  void _showProfessionalForm([Map<String, dynamic>? item]) {
    Navigator.pushNamed(context, '/professional-form', arguments: item);
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
