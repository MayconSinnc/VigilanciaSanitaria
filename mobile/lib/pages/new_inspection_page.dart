import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api.dart';
import '../widgets/inspection_widgets.dart';

class NewInspectionPage extends StatefulWidget {
  const NewInspectionPage({super.key});

  @override
  State<NewInspectionPage> createState() => _NewInspectionPageState();
}

class _NewInspectionPageState extends State<NewInspectionPage> {
  final _api = ApiService();
  final _estabSearchCtrl = TextEditingController();

  String? _tipoInspecao;
  Map<String, dynamic>? _estabelecimentoSelecionado;
  bool _isOnline = true;
  bool _hasPendingSync = false;
  bool _estabLoading = false;
  String? _estabError;
  List<dynamic> _estabResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRouteArgs());
  }

  @override
  void dispose() {
    _estabSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRouteArgs() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final estab = args['estabelecimento'];
    if (estab is Map) {
      setState(() {
        _estabelecimentoSelecionado = normalizeEstablishmentForInspection(Map<String, dynamic>.from(estab));
      });
      return;
    }

    final cnpj = args['cnpj']?.toString();
    if (cnpj != null && cnpj.trim().isNotEmpty) {
      _estabSearchCtrl.text = cnpj;
      await _buscarEstabelecimento(autoSelectIfSingle: true);
    }
  }

  void _selecionarEstabelecimento(Map<String, dynamic> raw) {
    setState(() {
      _estabelecimentoSelecionado = normalizeEstablishmentForInspection(raw);
      _estabResults = [];
      _estabError = null;
    });
  }

  Future<void> _buscarEstabelecimento({bool autoSelectIfSingle = false}) async {
    final query = _estabSearchCtrl.text.trim();
    final digits = query.replaceAll(RegExp(r'\D'), '');

    if (digits.isNotEmpty && digits.length != 14) {
      setState(() => _estabError = 'CNPJ incompleto. Digite 14 dígitos.');
      return;
    }
    if (digits.isEmpty && query.length < 2) {
      setState(() => _estabError = 'Digite pelo menos 2 caracteres para buscar.');
      return;
    }

    setState(() {
      _estabLoading = true;
      _estabError = null;
      _estabResults = [];
    });

    try {
      await _api.init();
      if (digits.length == 14) {
        final data = await _api.buscarEstabelecimentoPorCnpj(digits);
        if (!mounted) return;
        if (data == null) {
          setState(() {
            _estabLoading = false;
            _estabError = 'CNPJ não encontrado.';
          });
          return;
        }
        setState(() => _estabLoading = false);
        _selecionarEstabelecimento(data);
        return;
      }

      final data = await _api.buscarEstabelecimentos(query);
      if (!mounted) return;
      setState(() {
        _estabResults = data;
        _estabLoading = false;
        _estabError = data.isEmpty ? 'Nenhum estabelecimento encontrado.' : null;
      });
      if (autoSelectIfSingle && data.length == 1 && data.first is Map) {
        _selecionarEstabelecimento(Map<String, dynamic>.from(data.first as Map));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode ?? 0;
      setState(() {
        _estabLoading = false;
        _estabError = code == 401
            ? 'Sessão expirada. Faça login novamente.'
            : 'Erro ao buscar estabelecimento.';
      });
      if (code == 401) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estabLoading = false;
        _estabError = 'Erro ao buscar: $e';
      });
    }
  }

  Future<void> _abrirScannerCnpj() async {
    final cnpj = await Navigator.pushNamed<String>(context, '/scanner-cnpj');
    if (!mounted || cnpj == null || cnpj.trim().isEmpty) return;
    _estabSearchCtrl.text = cnpj;
    await _buscarEstabelecimento(autoSelectIfSingle: true);
  }

  final List<String> _tiposInspecao = const [
    'Auto de Intimação',
    'Auto de Infração',
    'Imposição de Penalidade',
    'Auto de Coleta para Amostra',
    'Inspeção de Rotina',
    'Denúncia',
    'Retorno de Fiscalização',
    'Licenciamento Sanitário',
    'Habite-se',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: GovColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Nova Inspeção',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth < 1024;
        final actionColumns = isMobile ? 1 : (isTablet ? 2 : 3);
        final resourceColumns = isMobile ? 2 : (isTablet ? 2 : 4);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InspectionHeaderCard(
                title: 'Nova fiscalização sanitária',
                subtitle: 'Selecione o tipo de inspeção e preencha as informações necessárias para iniciar o atendimento.',
                isOnline: _isOnline,
                hasPendingSync: _hasPendingSync,
              ),
              const SizedBox(height: 20),
              InspectionTypeDropdown(
                value: _tipoInspecao,
                options: _tiposInspecao,
                onChanged: (value) => setState(() => _tipoInspecao = value),
                errorText: _tipoInspecao == null ? 'Informe o tipo de inspeção.' : null,
              ),
              const SizedBox(height: 20),
              if (_estabelecimentoSelecionado == null)
                _buildEstablishmentSearch()
              else
                SelectedEstablishmentCard(
                  razaoSocial: _estabelecimentoSelecionado!['razao_social'] ?? '',
                  nomeFantasia: _estabelecimentoSelecionado!['nome_fantasia'] ?? '',
                  cnpj: _estabelecimentoSelecionado!['cnpj'] ?? '',
                  inscricaoMunicipal: _estabelecimentoSelecionado!['inscricao_municipal'],
                  endereco: _estabelecimentoSelecionado!['endereco'] ?? '',
                  statusAlvara: _estabelecimentoSelecionado!['status_alvara'] ?? 'Desconhecido',
                  debitoVencido: _estabelecimentoSelecionado!['debito_vencido'] ?? false,
                  onClear: () => setState(() {
                    _estabelecimentoSelecionado = null;
                    _estabResults = [];
                    _estabError = null;
                  }),
                ),
              const SizedBox(height: 20),
              _buildSectionTitle('Ações da Inspeção'),
              const SizedBox(height: 12),
              _buildCardGrid(
                crossAxisCount: actionColumns,
                itemHeight: isMobile ? null : 130,
                children: [
                  _buildActionCard(
                    icon: Icons.description_outlined,
                    title: 'Abrir Formulário Oficial',
                    description: 'Preencha a situação encontrada e selecione a ação sanitária.',
                    route: '/formulario',
                    enabled: _tipoInspecao != null,
                    disabledReason: 'Selecione o tipo de inspeção primeiro',
                  ),
                  _buildActionCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Evidências Fotográficas',
                    description: 'Capture fotos e documentos da fiscalização.',
                    route: '/evidencias',
                  ),
                  _buildActionCard(
                    icon: Icons.draw_outlined,
                    title: 'Assinatura Digital',
                    description: 'Colete assinatura do fiscal e responsável.',
                    route: '/assinatura',
                    enabled: _tipoInspecao != null,
                    disabledReason: 'Selecione o tipo de inspeção primeiro',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Recursos de Apoio'),
              const SizedBox(height: 12),
              _buildCardGrid(
                crossAxisCount: resourceColumns,
                itemHeight: 130,
                children: [
                  SupportResourceCard(
                    icon: Icons.map_outlined,
                    title: 'Mapa Sanitário',
                    description: 'Visualize estabelecimentos fiscalizados e risco sanitário.',
                    onTap: () => _navigateTo('/mapa'),
                  ),
                  SupportResourceCard(
                    icon: Icons.text_snippet_outlined,
                    title: 'OCR de Nota Fiscal',
                    description: 'Capture dados de notas fiscais e documentos.',
                    onTap: () => _navigateTo('/ocr-nota'),
                  ),
                  SupportResourceCard(
                    icon: Icons.qr_code_2_outlined,
                    title: 'Ler QR Code',
                    description: 'Leia QR Codes para localizar cadastros ou documentos.',
                    onTap: () => _navigateTo('/qr'),
                  ),
                  SupportResourceCard(
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'Scanner de CNPJ',
                    description: 'Use a câmera para localizar o estabelecimento pelo CNPJ.',
                    onTap: _abrirScannerCnpj,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStartInspectionFooter(),
            ],
          ),
        );
      }),
    );
  }

  /// Grade com altura fixa por item — evita GridView com altura 0 dentro de scroll.
  Widget _buildCardGrid({
    required int crossAxisCount,
    required List<Widget> children,
    double? itemHeight,
  }) {
    if (crossAxisCount <= 1) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += crossAxisCount) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < crossAxisCount; j++) {
        final index = i + j;
        if (index < children.length) {
          rowChildren.add(Expanded(child: children[index]));
        } else {
          rowChildren.add(const Expanded(child: SizedBox()));
        }
        if (j < crossAxisCount - 1) rowChildren.add(const SizedBox(width: 12));
      }
      rows.add(
        SizedBox(
          height: itemHeight,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: rowChildren),
        ),
      );
      if (i + crossAxisCount < children.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(children: rows);
  }

  Widget _buildStartInspectionFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GovColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_tipoInspecao != null && _estabelecimentoSelecionado != null)
                  ? _handleStartInspection
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: (_tipoInspecao != null && _estabelecimentoSelecionado != null)
                    ? GovColors.primary
                    : Colors.grey[300],
                foregroundColor: (_tipoInspecao != null && _estabelecimentoSelecionado != null)
                    ? Colors.white
                    : Colors.grey[500],
                disabledBackgroundColor: Colors.grey[300],
                elevation: (_tipoInspecao != null && _estabelecimentoSelecionado != null) ? 2 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Iniciar Inspeção',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (_tipoInspecao == null || _estabelecimentoSelecionado == null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: GovColors.warning, size: 14),
                const SizedBox(width: 4),
                Text(
                  _tipoInspecao == null
                      ? 'Selecione o tipo de inspeção'
                      : 'Selecione um estabelecimento para continuar',
                  style: const TextStyle(fontSize: 12, color: GovColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstablishmentSearch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GovColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store_outlined, color: GovColors.primary, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Estabelecimento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GovColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _estabSearchCtrl,
            decoration: InputDecoration(
              labelText: 'Nome fantasia, razão social ou CNPJ',
              hintText: 'Digite para buscar',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _estabSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _estabSearchCtrl.clear();
                        setState(() {
                          _estabResults = [];
                          _estabError = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onSubmitted: (_) => _buscarEstabelecimento(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _estabLoading ? null : _buscarEstabelecimento,
                  icon: _estabLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: Text(_estabLoading ? 'Buscando...' : 'Buscar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GovColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _estabLoading ? null : _abrirScannerCnpj,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GovColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ],
          ),
          if (_estabError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GovColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GovColors.error.withOpacity(0.3)),
              ),
              child: Text(_estabError!, style: const TextStyle(color: GovColors.error, fontSize: 13)),
            ),
          ],
          if (_estabResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Selecione o estabelecimento',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _estabResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = _estabResults[index] as Map<String, dynamic>;
                  final nome = (e['nome_fantasia'] ?? e['nomeFantasia'] ?? e['nome'] ?? e['razao_social'] ?? e['razaoSocial'] ?? 'Sem nome').toString();
                  final cnpj = (e['cnpj'] ?? '').toString();
                  final cidade = (e['cidade'] ?? e['municipio'] ?? '').toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business, color: GovColors.primary),
                    title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([cnpj, cidade].where((s) => s.isNotEmpty).join(' • ')),
                    trailing: const Icon(Icons.check_circle_outline, color: GovColors.primary),
                    onTap: () => _selecionarEstabelecimento(e),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: GovColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String route,
    bool enabled = true,
    String? disabledReason,
  }) {
    return InspectionActionCard(
      icon: icon,
      title: title,
      description: description,
      onTap: () => _navigateTo(route),
      enabled: enabled,
      disabledReason: disabledReason,
    );
  }

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        _selecionarEstabelecimento(result);
      }
    });
  }

  void _handleStartInspection() {
    if (_tipoInspecao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o tipo de inspeção.')),
      );
      return;
    }

    if (_estabelecimentoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um estabelecimento para continuar.')),
      );
      return;
    }

    // Mapear tipo de inspeção para o código usado no sistema
    final tipoCodigo = _mapTipoToCodigo(_tipoInspecao!);
    
    Navigator.pushNamed(
      context,
      '/auto-form',
      arguments: {
        'tipo': tipoCodigo,
        'nome': _estabelecimentoSelecionado!['nome_fantasia'] ?? '',
        'cnpj': _estabelecimentoSelecionado!['cnpj'] ?? '',
        'estabelecimento': _estabelecimentoSelecionado,
        'estabelecimentoId': _estabelecimentoSelecionado!['id'],
      },
    );
  }

  String _mapTipoToCodigo(String tipo) {
    switch (tipo) {
      case 'Auto de Intimação':
        return 'INT';
      case 'Auto de Infração':
        return 'INF';
      case 'Imposição de Penalidade':
        return 'PEN';
      case 'Auto de Coleta para Amostra':
        return 'COL';
      default:
        return 'INT';
    }
  }
}
