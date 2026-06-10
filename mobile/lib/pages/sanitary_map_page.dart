import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../ui/theme.dart';
import '../storage/db.dart';
import '../services/api.dart';
import '../widgets/official_form_fields.dart';

class SanitaryMapPage extends StatefulWidget {
  const SanitaryMapPage({super.key});

  @override
  State<SanitaryMapPage> createState() => _SanitaryMapPageState();
}

class _SanitaryMapPageState extends State<SanitaryMapPage> {
  // Filtros
  final _searchCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  String? _statusSanitario;
  String? _riscoSanitario;
  String? _bairro;
  String? _situacaoAlvara;
  bool _debitoVencido = false;

  // Dados
  List<Map<String, dynamic>> _estabelecimentos = [];
  bool _loading = false;
  String? _error;

  final _api = ApiService();
  final MapController _mapController = MapController();

  // Coordenadas de Balneário Camboriú
  static const LatLng _balnearioCamboriu = LatLng(-26.9926, -48.6352);

  @override
  void initState() {
    super.initState();
    _loadEstabelecimentos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cnpjCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadEstabelecimentos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _api.init();
        final data = await _api.buscarMapaSanitario();
        if (!mounted) return;
        final lista = data['estabelecimentos'];
        setState(() {
          _estabelecimentos = lista is List
              ? List<Map<String, dynamic>>.from(
                  lista.map((e) => Map<String, dynamic>.from(e as Map)),
                )
              : [];
          _loading = false;
        });
      } else {
        final db = await LocalDb.instance;
        final rows = await db.query('estabelecimentos', where: 'latitude IS NOT NULL AND longitude IS NOT NULL');
        if (!mounted) return;
        setState(() {
          _estabelecimentos = rows;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _loading = false;
        _error = code == 401 ? 'Sessão expirada. Faça login novamente.' : 'Erro ${code >= 500 ? 'no servidor' : 'na API'} ao carregar mapa sanitário.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar mapa sanitário: $e';
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

  /// Retorna cor baseada no status sanitário
  Color _colorForStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('regular') || lower.contains('aprovado')) return AppColors.verde;
    if (lower.contains('irregular') || lower.contains('médio') || lower.contains('medio')) return const Color(0xFFFFD600);
    if (lower.contains('grave') || lower.contains('alto') || lower.contains('interditado')) return AppColors.vermelho;
    if (lower.contains('interditado')) return Colors.black;
    return AppColors.azulClaro;
  }

  /// Filtra estabelecimentos baseado nos filtros selecionados
  List<Map<String, dynamic>> _getFilteredEstabelecimentos() {
    var filtered = _estabelecimentos;

    // Filtro por busca (nome fantasia/razão social)
    if (_searchCtrl.text.trim().isNotEmpty) {
      final search = _searchCtrl.text.trim().toLowerCase();
      filtered = filtered.where((est) {
        final nome = est['nome_fantasia'] ?? est['nome'] ?? est['nomeFantasia'] ?? '';
        final razao = est['razao_social'] ?? est['razaoSocial'] ?? '';
        return nome.toString().toLowerCase().contains(search) || razao.toString().toLowerCase().contains(search);
      }).toList();
    }

    // Filtro por CNPJ
    if (_cnpjCtrl.text.trim().isNotEmpty) {
      final cnpjDigits = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
      filtered = filtered.where((est) {
        final cnpj = est['cnpj'] ?? '';
        final cnpjClean = cnpj.toString().replaceAll(RegExp(r'\D'), '');
        return cnpjClean.contains(cnpjDigits);
      }).toList();
    }

    // Filtro por status sanitário
    if (_statusSanitario != null) {
      filtered = filtered.where((est) {
        final status = est['status_sanitario'] ?? est['statusSanitario'] ?? '';
        return status.toString().toUpperCase() == _statusSanitario!.toUpperCase();
      }).toList();
    }

    // Filtro por risco sanitário
    if (_riscoSanitario != null) {
      filtered = filtered.where((est) {
        final risco = est['risco_sanitario'] ?? est['riscoSanitario'] ?? '';
        return risco.toString().toUpperCase() == _riscoSanitario!.toUpperCase();
      }).toList();
    }

    // Filtro por bairro
    if (_bairro != null) {
      filtered = filtered.where((est) {
        final bairro = est['bairro'] ?? '';
        return bairro.toString().toUpperCase() == _bairro!.toUpperCase();
      }).toList();
    }

    // Filtro por situação do alvará
    if (_situacaoAlvara != null) {
      filtered = filtered.where((est) {
        final alvara = est['status_alvara'] ?? est['statusAlvara'] ?? '';
        return alvara.toString().toUpperCase() == _situacaoAlvara!.toUpperCase();
      }).toList();
    }

    // Filtro por débito vencido
    if (_debitoVencido) {
      filtered = filtered.where((est) {
        final debito = est['possui_debito_vencido'] ?? est['possuiDebitoVencido'] ?? false;
        return debito == true;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredEstabelecimentos();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Sanitário'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
            onPressed: _loading ? null : _loadEstabelecimentos,
            tooltip: 'Atualizar',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => _mapController.move(_balnearioCamboriu, 13),
            tooltip: 'Centralizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          _buildFilters(),
          // Mapa
          Expanded(
            child: _buildMap(filtered),
          ),
          // Legenda
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      _cnpjCtrl.clear();
                      _statusSanitario = null;
                      _riscoSanitario = null;
                      _bairro = null;
                      _situacaoAlvara = null;
                      _debitoVencido = false;
                    });
                  },
                  child: const Text('Limpar'),
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
                        placeholder: 'Nome fantasia ou razão social',
                        prefixIcon: const Icon(Icons.search),
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      OfficialCnpjField(
                        controller: _cnpjCtrl,
                        label: 'CNPJ',
                        required: false,
                      ),
                      const SizedBox(height: 12),
                      OfficialDropdownField.fromStrings(
                        label: 'Status Sanitário',
                        value: _statusSanitario,
                        items: const ['REGULAR', 'IRREGULAR', 'INTERDITADO'],
                        required: false,
                        onChanged: (value) => setState(() => _statusSanitario = value),
                      ),
                      const SizedBox(height: 12),
                      OfficialDropdownField.fromStrings(
                        label: 'Risco Sanitário',
                        value: _riscoSanitario,
                        items: const ['BAIXO', 'MÉDIO', 'ALTO'],
                        required: false,
                        onChanged: (value) => setState(() => _riscoSanitario = value),
                      ),
                      const SizedBox(height: 12),
                      OfficialDropdownField.fromStrings(
                        label: 'Situação do Alvará',
                        value: _situacaoAlvara,
                        items: const ['REGULAR', 'VENCIDO', 'PENDENTE'],
                        required: false,
                        onChanged: (value) => setState(() => _situacaoAlvara = value),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _debitoVencido,
                        onChanged: (value) => setState(() => _debitoVencido = value ?? false),
                        title: const Text('Débito Vencido'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
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
                              placeholder: 'Nome fantasia ou razão social',
                              prefixIcon: const Icon(Icons.search),
                              required: false,
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
                            child: OfficialDropdownField.fromStrings(
                              label: 'Status Sanitário',
                              value: _statusSanitario,
                              items: const ['REGULAR', 'IRREGULAR', 'INTERDITADO'],
                              required: false,
                              onChanged: (value) => setState(() => _statusSanitario = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OfficialDropdownField.fromStrings(
                              label: 'Risco Sanitário',
                              value: _riscoSanitario,
                              items: const ['BAIXO', 'MÉDIO', 'ALTO'],
                              required: false,
                              onChanged: (value) => setState(() => _riscoSanitario = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OfficialDropdownField.fromStrings(
                              label: 'Situação do Alvará',
                              value: _situacaoAlvara,
                              items: const ['REGULAR', 'VENCIDO', 'PENDENTE'],
                              required: false,
                              onChanged: (value) => setState(() => _situacaoAlvara = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _debitoVencido,
                        onChanged: (value) => setState(() => _debitoVencido = value ?? false),
                        title: const Text('Débito Vencido'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
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

  Widget _buildMap(List<Map<String, dynamic>> filtered) {
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
                onPressed: _loadEstabelecimentos,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Nenhum estabelecimento com coordenadas encontrado',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ajuste os filtros ou atualize os dados.',
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadEstabelecimentos,
                icon: const Icon(Icons.sync),
                label: const Text('Atualizar dados'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azulInstitucional,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final markers = filtered.map((est) {
      final lat = est['latitude'] ?? est['lat'];
      final lng = est['longitude'] ?? est['lng'];
      final status = est['status_sanitario'] ?? est['statusSanitario'] ?? 'REGULAR';
      
      if (lat == null || lng == null) return null;
      
      return Marker(
        width: 40,
        height: 40,
        point: LatLng(lat as double, lng as double),
        child: InkWell(
          onTap: () => _showMarkerBottomSheet(est),
          child: Icon(Icons.location_on, color: _colorForStatus(status), size: 32),
        ),
      );
    }).whereType<Marker>().toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _balnearioCamboriu,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'vigilancia.sanitaria',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            _LegendItem(color: AppColors.verde, label: 'Regular'),
            SizedBox(width: 16),
            _LegendItem(color: Color(0xFFFFD600), label: 'Irregularidades anteriores'),
            SizedBox(width: 16),
            _LegendItem(color: AppColors.vermelho, label: 'Infrações graves'),
            SizedBox(width: 16),
            _LegendItem(color: Colors.black, label: 'Interditado'),
          ],
        ),
      ),
    );
  }

  void _showMarkerBottomSheet(Map<String, dynamic> est) {
    final screen = MediaQuery.sizeOf(context);
    final isWide = screen.width >= 720;
    final maxPanelHeight = screen.height * (isWide ? 0.5 : 0.65);

    if (isWide) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black26,
        builder: (dialogContext) => Stack(
          children: [
            Positioned(
              right: 16,
              bottom: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxPanelHeight),
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
                          child: _buildMarkerDetailContent(dialogContext, est),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + MediaQuery.viewPaddingOf(sheetContext).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              child: SingleChildScrollView(
                child: _buildMarkerDetailContent(sheetContext, est),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarkerDetailContent(BuildContext context, Map<String, dynamic> est) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatEmpty(est['razao_social'] ?? est['razaoSocial'] ?? est['nome_fantasia'] ?? est['nome'] ?? est['nomeFantasia']),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _formatEmpty(est['nome_fantasia'] ?? est['nome'] ?? est['nomeFantasia'] ?? ''),
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 12),
        _detailRow('CNPJ', _formatCnpj(est['cnpj'])),
        _detailRow('Endereço', _formatEmpty(est['endereco'] ?? est['logradouro'])),
        _detailRow('Bairro', _formatEmpty(est['bairro'])),
        _detailRow('Status Sanitário', _formatEmpty(est['status_sanitario'] ?? est['statusSanitario'])),
        _detailRow('Risco Sanitário', _formatEmpty(est['risco_sanitario'] ?? est['riscoSanitario'])),
        _detailRow('Situação do Alvará', _formatEmpty(est['status_alvara'] ?? est['statusAlvara'])),
        _detailRow('Débito Vencido', (est['possui_debito_vencido'] ?? est['possuiDebitoVencido'] ?? false) == true ? 'Sim' : 'Não'),
        _detailRow('Última Inspeção', _formatDate(est['ultima_inspecao'] ?? est['ultimaInspecao'])),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToFicha(est);
                },
                icon: const Icon(Icons.description, size: 18),
                label: const Text('Ver ficha'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azulInstitucional,
                  side: const BorderSide(color: AppColors.azulInstitucional),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startInspection(est);
                },
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Nova inspeção'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.azulInstitucional,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funcionalidade de atualização de localização será implementada.')),
              );
            },
            icon: const Icon(Icons.edit_location, size: 18),
            label: const Text('Atualizar localização'),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _navigateToFicha(Map<String, dynamic> est) async {
    final cnpjDigits = (est['cnpj'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    int? id;
    
    if (ApiService.mockMode) {
      try {
        final db = await LocalDb.instance;
        final rows = await db.query('estabelecimentos', columns: ['id'], where: 'cnpj = ?', whereArgs: [cnpjDigits], limit: 1);
        id = rows.isNotEmpty ? rows.first['id'] as int? : null;
      } catch (_) {}
    }
    
    if (!mounted) return;
    if (id != null) {
      Navigator.pushNamed(context, '/ficha-estabelecimento', arguments: {'id': id});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Histórico indisponível neste modo.')),
      );
    }
  }

  void _startInspection(Map<String, dynamic> est) {
    final cnpjDigits = (est['cnpj'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    Navigator.pushNamed(context, '/nova-inspecao', arguments: {
      'nome': est['razao_social'] ?? est['razaoSocial'] ?? est['nome_fantasia'] ?? est['nome'] ?? est['nomeFantasia'],
      'cnpj': cnpjDigits,
    });
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}


