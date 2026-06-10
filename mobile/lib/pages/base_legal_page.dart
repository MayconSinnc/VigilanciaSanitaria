import 'package:flutter/material.dart';

import '../services/base_legal_repository.dart';
import '../ui/theme.dart';
import '../widgets/official_components.dart';

class BaseLegalPage extends StatefulWidget {
  const BaseLegalPage({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  State<BaseLegalPage> createState() => _BaseLegalPageState();
}

class _BaseLegalPageState extends State<BaseLegalPage> {
  final _repo = BaseLegalRepository();

  List<BaseLegalEntry> _selecionadas = const [];

  bool _loadingGrupos = true;
  String? _errorGrupos;
  List<BaseLegalGrupo> _grupos = const [];
  BaseLegalGrupo? _grupoSelecionado;

  bool _loadingSubgrupos = false;
  String? _errorSubgrupos;
  List<BaseLegalSubgrupo> _subgrupos = const [];
  BaseLegalSubgrupo? _subgrupoSelecionado;

  final _structuredSearchCtrl = TextEditingController();
  bool _loadingEntries = false;
  String? _errorEntries;
  List<BaseLegalEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadGrupos();
  }

  @override
  void dispose() {
    _structuredSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGrupos() async {
    setState(() {
      _loadingGrupos = true;
      _errorGrupos = null;
    });
    try {
      final grupos = await _repo.listarGrupos();
      if (!mounted) return;
      setState(() {
        _grupos = grupos;
        _loadingGrupos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGrupos = false;
        _errorGrupos = 'Não foi possível carregar os grupos da Base Legal.';
      });
    }
  }

  Future<void> _loadSubgrupos(String grupoId) async {
    setState(() {
      _loadingSubgrupos = true;
      _errorSubgrupos = null;
      _subgrupos = const [];
      _subgrupoSelecionado = null;
      _entries = const [];
      _errorEntries = null;
    });
    try {
      final subs = await _repo.listarSubgrupos(grupoId);
      if (!mounted) return;
      setState(() {
        _subgrupos = subs;
        _loadingSubgrupos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSubgrupos = false;
        _errorSubgrupos = 'Não foi possível carregar os subgrupos.';
      });
    }
  }

  Future<void> _loadEntries() async {
    final q = _structuredSearchCtrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _loadingEntries = false;
        _errorEntries = null;
        _entries = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos 3 caracteres para buscar.')),
      );
      return;
    }
    setState(() {
      _loadingEntries = true;
      _errorEntries = null;
    });
    try {
      final items = await _repo.buscarInteligente(
        query: q,
        grupoId: _grupoSelecionado?.id,
        subgrupoId: _subgrupoSelecionado?.id,
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _entries = items;
        _loadingEntries = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingEntries = false;
        _errorEntries = 'Não foi possível buscar bases legais.';
      });
    }
  }

  Future<void> _openDetail(BaseLegalEntry entry) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return _BaseLegalDetailSheet(entryId: entry.id, repo: _repo);
      },
    );
  }

  void _selectEntry(BaseLegalEntry entry) {
    Navigator.of(context).pop(entry.toVinculoJson());
  }

  void _addSelecionada(BaseLegalEntry entry) {
    if ((entry.id).trim().isEmpty) return;
    if (_selecionadas.any((e) => e.id == entry.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base legal já adicionada.')),
      );
      return;
    }
    setState(() => _selecionadas = [..._selecionadas, entry]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Base legal adicionada.')),
    );
  }

  void _removerSelecionada(String id) {
    setState(() => _selecionadas = _selecionadas.where((e) => e.id != id).toList());
  }

  Future<void> _usarNoAutoTermo(List<BaseLegalEntry> entries) async {
    final payload = entries.map((e) => e.toVinculoJson()).toList();
    await Navigator.pushNamed(
      context,
      '/auto-termo',
      arguments: {'bases_legais_vinculadas': payload},
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectionMode = widget.selectionMode;
    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? 'Selecionar Base Legal' : 'Base Legal'),
        backgroundColor: AppColors.azulInstitucional,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _repo.offlineMode,
        builder: (context, offline, _) {
          return Column(
            children: [
              if (offline) _OfflineBanner(repo: _repo),
              Expanded(
                child: _buildQuickSearchView(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickSearchView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTaxonomiaCard(),
          if (!widget.selectionMode) ...[
            const SizedBox(height: 16),
            _buildSelecionadasCard(),
          ],
          const SizedBox(height: 16),
          OfficialSectionCard(
            title: 'Busca rápida',
            icon: Icons.search,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _structuredSearchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descreva a irregularidade encontrada',
                    hintText: 'Ex: cozinha suja, alimento vencido, falta de higiene...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadingEntries ? null : _loadEntries,
                    icon: _loadingEntries
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: Text(_loadingEntries ? 'Buscando...' : 'Buscar Base Legal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulInstitucional,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorEntries != null)
                  Text(_errorEntries!, style: const TextStyle(color: AppColors.vermelho, fontWeight: FontWeight.w600)),
                if (!_loadingEntries) _buildEntriesList(_entries),
                if (_loadingEntries) const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxonomiaCard() {
    return OfficialSectionCard(
      title: 'Filtro (opcional)',
      icon: Icons.filter_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingGrupos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorGrupos != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_errorGrupos!, style: const TextStyle(color: AppColors.vermelho, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loadGrupos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchablePickerField<BaseLegalGrupo>(
                  label: 'Grupo',
                  value: _grupoSelecionado,
                  items: _grupos,
                  itemLabel: (g) => g.codigoDescricao,
                  hint: 'Selecione o grupo',
                  onChanged: (g) {
                    setState(() {
                      _grupoSelecionado = g;
                      _subgrupoSelecionado = null;
                      _subgrupos = const [];
                      _entries = const [];
                      _errorEntries = null;
                    });
                    if (g != null) _loadSubgrupos(g.id);
                  },
                ),
                const SizedBox(height: 12),
                _SearchablePickerField<BaseLegalSubgrupo>(
                  label: 'Subgrupo',
                  value: _subgrupoSelecionado,
                  items: _subgrupos,
                  enabled: _grupoSelecionado != null && !_loadingSubgrupos,
                  itemLabel: (s) => s.codigoDescricao,
                  hint: _grupoSelecionado == null ? 'Selecione o grupo primeiro' : 'Selecione o subgrupo',
                  onChanged: (s) {
                    setState(() {
                      _subgrupoSelecionado = s;
                      _entries = const [];
                      _errorEntries = null;
                    });
                    if (s != null) _loadEntries();
                  },
                ),
                if (_loadingSubgrupos)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (_errorSubgrupos != null) ...[
                  const SizedBox(height: 10),
                  Text(_errorSubgrupos!, style: const TextStyle(color: AppColors.vermelho, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(List<BaseLegalEntry> items) {
    final q = _structuredSearchCtrl.text.trim();
    if (q.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Digite um termo e clique em Buscar Base Legal.', style: TextStyle(color: Colors.black54)),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nenhuma base legal encontrada para o filtro atual.', style: TextStyle(color: Colors.black54)),
      );
    }

    return Column(
      children: items.map(_buildEntryCard).toList(),
    );
  }

  Widget _buildEntryCard(BaseLegalEntry entry) {
    final selectionMode = widget.selectionMode;
    final score = (entry.score ?? 0).clamp(0, 200);
    final scorePct = ((score / 200) * 100).round();
    final desc = (entry.descricao ?? entry.ementa ?? '').trim();
    final descShort = desc.length > 160 ? '${desc.substring(0, 160)}...' : desc;
    final artigoLabel = [
      if ((entry.artigo ?? '').trim().isNotEmpty) 'Art. ${entry.artigo}',
      if ((entry.complemento ?? '').trim().isNotEmpty) entry.complemento,
    ].join(' ').trim();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.grupoResumo.isNotEmpty)
              Text(entry.grupoResumo, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(entry.normaTitulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (artigoLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(artigoLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (descShort.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(descShort),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.azulInstitucional.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Score: $scorePct%'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openDetail(entry),
                  child: const Text('Ver detalhes'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: selectionMode ? () => _selectEntry(entry) : () => _addSelecionada(entry),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulInstitucional,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(selectionMode ? 'Usar' : 'Usar esta base legal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelecionadasCard() {
    return OfficialSectionCard(
      title: 'Selecionadas',
      icon: Icons.playlist_add_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selecionadas.isEmpty)
            const Text(
              'Nenhuma base legal selecionada ainda.',
              style: TextStyle(color: Colors.black54),
            )
          else ...[
            ..._selecionadas.map((e) {
              final artigoLabel = [
                if ((e.artigo ?? '').trim().isNotEmpty) 'Art. ${e.artigo}',
                if ((e.complemento ?? '').trim().isNotEmpty) e.complemento,
              ].where((x) => (x ?? '').trim().isNotEmpty).join(' ').trim();

              return Card(
                elevation: 0,
                color: AppColors.azulInstitucional.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.azulInstitucional.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.grupoResumo.isNotEmpty)
                        Text(
                          e.grupoResumo,
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(height: 6),
                      Text(e.normaTitulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (artigoLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(artigoLabel),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _openDetail(e),
                            child: const Text('Ver detalhes'),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Remover',
                            onPressed: () => _removerSelecionada(e.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _usarNoAutoTermo([e]),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.azulInstitucional,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Usar no Auto/Termo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (_selecionadas.length > 1) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _usarNoAutoTermo(_selecionadas),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Usar todas no Auto/Termo'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.repo});

  final BaseLegalRepository repo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3CD),
      child: FutureBuilder<String?>(
        future: repo.getUltimaSincronizacao(),
        builder: (context, snap) {
          final last = (snap.data ?? '').trim();
          final suffix = last.isEmpty ? '' : ' Última sincronização: $last';
          return Text(
            'Modo offline: exibindo última base legal sincronizada.$suffix',
            style: const TextStyle(color: Color(0xFF664D03), fontWeight: FontWeight.w600),
          );
        },
      ),
    );
  }
}

class _BaseLegalDetailSheet extends StatefulWidget {
  const _BaseLegalDetailSheet({required this.entryId, required this.repo});

  final String entryId;
  final BaseLegalRepository repo;

  @override
  State<_BaseLegalDetailSheet> createState() => _BaseLegalDetailSheetState();
}

class _BaseLegalDetailSheetState extends State<_BaseLegalDetailSheet> {
  bool _loading = true;
  BaseLegalEntry? _entry;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry = await widget.repo.buscarDetalhe(widget.entryId);
      if (!mounted) return;
      setState(() {
        _entry = entry;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar detalhes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('Detalhe da Base Legal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _entry == null
                          ? const Center(child: Text('Base legal não encontrada.'))
                          : _buildContent(_entry!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BaseLegalEntry e) {
    String label(String v) => v.trim().isEmpty ? 'Não informado' : v.trim();

    final artigoLabel = [
      if ((e.artigo ?? '').trim().isNotEmpty) 'Art. ${e.artigo}',
      if ((e.complemento ?? '').trim().isNotEmpty) e.complemento!,
    ].join(' ').trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Grupo', label(e.grupoResumo)),
          _kv('Norma', label(e.normaTitulo)),
          _kv('Situação', label(e.situacao ?? '')),
          _kv('Artigo', label(artigoLabel)),
          const SizedBox(height: 12),
          const Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(label(e.descricao ?? e.ementa ?? '')),
          if ((e.observacoes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Observações', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(e.observacoes!.trim()),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _SearchablePickerField<T> extends StatelessWidget {
  const _SearchablePickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.hint,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final String hint;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '' : itemLabel(value as T);
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: enabled ? Colors.white : AppColors.cinzaCampo.withValues(alpha: 0.2),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(display.isEmpty ? hint : display),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return _SearchablePickerSheet<T>(
          title: label,
          items: items,
          itemLabel: itemLabel,
          selected: value,
          onSelect: (v) {
            Navigator.of(ctx).pop();
            onChanged(v);
          },
        );
      },
    );
  }
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? selected;
  final ValueChanged<T> onSelect;

  @override
  State<_SearchablePickerSheet<T>> createState() => _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T> extends State<_SearchablePickerSheet<T>> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    final q = _ctrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((e) => widget.itemLabel(e).toLowerCase().contains(q)).toList();

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: [
                Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Pesquisar...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  final selected = widget.selected != null && widget.itemLabel(item) == widget.itemLabel(widget.selected as T);
                  return ListTile(
                    title: Text(widget.itemLabel(item)),
                    trailing: selected ? const Icon(Icons.check, color: AppColors.azulInstitucional) : null,
                    onTap: () => widget.onSelect(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
