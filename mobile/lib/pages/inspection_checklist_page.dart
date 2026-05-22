import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../storage/db.dart';
import '../ui/theme.dart';
import '../widgets/official_form_fields.dart';

class InspectionChecklistPage extends StatefulWidget {
  const InspectionChecklistPage({super.key});
  @override
  State<InspectionChecklistPage> createState() => _InspectionChecklistPageState();
}

class _InspectionChecklistPageState extends State<InspectionChecklistPage> {
  final _formKey = GlobalKey<FormState>();
  final _observacaoGeralCtrl = TextEditingController();

  // Dados da inspeção (viriam dos argumentos)
  String _numeroInspecao = '';
  String _estabelecimento = '';
  String _fiscalResponsavel = '';
  DateTime _dataInspecao = DateTime.now();

  // Lista de itens do checklist organizada por grupos
  final List<ChecklistGroup> _groups = [
    ChecklistGroup(
      title: 'Higiene',
      items: [
        ChecklistItem(
          id: 1,
          descricao: 'Higiene do ambiente',
          obrigatorio: true,
        ),
        ChecklistItem(
          id: 2,
          descricao: 'Higiene pessoal dos manipuladores',
          obrigatorio: true,
        ),
      ],
    ),
    ChecklistGroup(
      title: 'Estrutura',
      items: [
        ChecklistItem(
          id: 3,
          descricao: 'Piso em bom estado de conservação',
          obrigatorio: true,
        ),
        ChecklistItem(
          id: 4,
          descricao: 'Paredes e teto em bom estado',
          obrigatorio: true,
        ),
        ChecklistItem(
          id: 5,
          descricao: 'Iluminação adequada',
          obrigatorio: false,
        ),
      ],
    ),
    ChecklistGroup(
      title: 'Documentação',
      items: [
        ChecklistItem(
          id: 6,
          descricao: 'Alvará de funcionamento',
          obrigatorio: true,
        ),
        ChecklistItem(
          id: 7,
          descricao: 'Licença sanitária',
          obrigatorio: true,
        ),
      ],
    ),
    ChecklistGroup(
      title: 'Manipulação de Alimentos',
      items: [
        ChecklistItem(
          id: 8,
          descricao: 'Armazenamento correto de alimentos',
          obrigatorio: true,
        ),
        ChecklistItem(
          id: 9,
          descricao: 'Controle de temperatura',
          obrigatorio: true,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInspectionData();
  }

  @override
  void dispose() {
    _observacaoGeralCtrl.dispose();
    super.dispose();
  }

  void _loadInspectionData() {
    // Carregar dados da inspeção dos argumentos
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _numeroInspecao = args['numero'] as String? ?? '';
        _estabelecimento = args['estabelecimento'] as String? ?? '';
        _fiscalResponsavel = args['fiscal'] as String? ?? '';
      });
    }
  }

  /// Calcula o resumo de conformidade
  ChecklistSummary _calculateSummary() {
    int conforme = 0;
    int naoConforme = 0;
    int na = 0;
    int totalRespondido = 0;

    for (final group in _groups) {
      for (final item in group.items) {
        if (item.status != null) {
          totalRespondido++;
          switch (item.status!) {
            case ChecklistStatus.conforme:
              conforme++;
              break;
            case ChecklistStatus.naoConforme:
              naoConforme++;
              break;
            case ChecklistStatus.na:
              na++;
              break;
          }
        }
      }
    }

    final totalAvaliavel = totalRespondido - na;
    final score = totalAvaliavel > 0 ? (conforme / totalAvaliavel * 100).round() : 0;
    final risco = _calculateRisk(score);

    return ChecklistSummary(
      conforme: conforme,
      naoConforme: naoConforme,
      na: na,
      score: score,
      risco: risco,
    );
  }

  String _calculateRisk(int score) {
    if (score >= 90) return 'Baixo risco';
    if (score >= 70) return 'Médio risco';
    return 'Alto risco';
  }

  /// Valida todos os itens obrigatórios antes de salvar
  bool _validateChecklist() {
    for (final group in _groups) {
      for (final item in group.items) {
        if (item.obrigatorio && item.status == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item obrigatório não respondido: ${item.descricao}'),
              backgroundColor: AppColors.vermelho,
            ),
          );
          return false;
        }

        // Validar observação obrigatória quando item = Não Conforme
        if (item.status == ChecklistStatus.naoConforme && (item.observacao == null || item.observacao!.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Observação obrigatória para item não conforme: ${item.descricao}'),
              backgroundColor: AppColors.vermelho,
            ),
          );
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _save() async {
    if (!_validateChecklist()) {
      return;
    }

    final db = await LocalDb.instance;
    final summary = _calculateSummary();

    // Salvar itens do checklist
    for (final group in _groups) {
      for (final item in group.items) {
        if (item.status != null) {
          await db.insert('itens_inspecao', {
            'inspecao_id': _numeroInspecao,
            'item_id': item.id,
            'descricao': item.descricao,
            'status': item.status!.name.toUpperCase(),
            'observacao': item.observacao ?? '',
          });
        }
      }
    }

    // Salvar observação geral
    if (_observacaoGeralCtrl.text.trim().isNotEmpty) {
      await db.insert('inspecao_observacao', {
        'inspecao_id': _numeroInspecao,
        'observacao': _observacaoGeralCtrl.text.trim(),
      });
    }

    // Salvar resultado
    await db.insert('inspecao_resultado', {
      'inspecao_id': _numeroInspecao,
      'conforme': summary.conforme,
      'nao_conforme': summary.naoConforme,
      'na': summary.na,
      'score': summary.score,
      'risco': summary.risco,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checklist concluído! Score: ${summary.score}% - ${summary.risco}'),
          backgroundColor: AppColors.verde,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _calculateSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Sanitário'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: AppColors.azulInstitucional,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Card de informações da inspeção
            Container(
              color: AppColors.azulClaro.withOpacity(0.1),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_numeroInspecao.isNotEmpty)
                    Text('Inspeção: $_numeroInspecao', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (_estabelecimento.isNotEmpty)
                    Text('Estabelecimento: $_estabelecimento'),
                  if (_fiscalResponsavel.isNotEmpty)
                    Text('Fiscal: $_fiscalResponsavel'),
                ],
              ),
            ),
            // Lista de itens do checklist
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  return ChecklistGroupCard(
                    group: _groups[index],
                    onItemChanged: () => setState(() {}),
                  );
                },
              ),
            ),
            // Resumo de conformidade
            ChecklistSummaryCard(summary: summary),
            const SizedBox(height: 12),
            // Observação geral
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OfficialMultilineField(
                controller: _observacaoGeralCtrl,
                label: 'Observação Geral',
                minLines: 3,
                maxLines: 6,
              ),
            ),
            const SizedBox(height: 16),
            // Botão salvar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verde,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Concluir Checklist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Modelos de dados
enum ChecklistStatus { conforme, naoConforme, na }

class ChecklistItem {
  final int id;
  final String descricao;
  final bool obrigatorio;
  ChecklistStatus? status;
  String? observacao;
  List<String> evidencias;

  ChecklistItem({
    required this.id,
    required this.descricao,
    required this.obrigatorio,
    this.status,
    this.observacao,
    this.evidencias = const [],
  });
}

class ChecklistGroup {
  final String title;
  final List<ChecklistItem> items;

  ChecklistGroup({
    required this.title,
    required this.items,
  });

  int get totalItems => items.length;
  int get respondedItems => items.where((item) => item.status != null).length;
}

class ChecklistSummary {
  final int conforme;
  final int naoConforme;
  final int na;
  final int score;
  final String risco;

  ChecklistSummary({
    required this.conforme,
    required this.naoConforme,
    required this.na,
    required this.score,
    required this.risco,
  });
}

// Componentes reutilizáveis
class ChecklistGroupCard extends StatelessWidget {
  final ChecklistGroup group;
  final VoidCallback onItemChanged;

  const ChecklistGroupCard({
    super.key,
    required this.group,
    required this.onItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(
              group.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Text(
              '${group.respondedItems}/${group.totalItems}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        children: group.items.map((item) => ChecklistItemCard(
          item: item,
          onChanged: onItemChanged,
        )).toList(),
      ),
    );
  }
}

class ChecklistItemCard extends StatefulWidget {
  final ChecklistItem item;
  final VoidCallback onChanged;

  const ChecklistItemCard({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  State<ChecklistItemCard> createState() => _ChecklistItemCardState();
}

class _ChecklistItemCardState extends State<ChecklistItemCard> {
  final _observacaoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _observacaoCtrl.text = widget.item.observacao ?? '';
  }

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.descricao,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (widget.item.obrigatorio)
                const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ChecklistStatus.values.map((status) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_getStatusLabel(status)),
                  selected: widget.item.status == status,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        widget.item.status = status;
                        widget.item.observacao = _observacaoCtrl.text.trim();
                      });
                      widget.onChanged();
                    }
                  },
                  selectedColor: _getStatusColor(status),
                  labelStyle: TextStyle(
                    color: widget.item.status == status ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
          if (widget.item.status == ChecklistStatus.naoConforme) ...[
            const SizedBox(height: 12),
            OfficialMultilineField(
              controller: _observacaoCtrl,
              label: 'Observação (obrigatória)',
              required: true,
              minLines: 3,
              maxLines: 6,
              onChanged: (value) {
                widget.item.observacao = value;
              },
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusLabel(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.conforme:
        return 'Conforme';
      case ChecklistStatus.naoConforme:
        return 'Não Conforme';
      case ChecklistStatus.na:
        return 'N.A.';
    }
  }

  Color _getStatusColor(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.conforme:
        return AppColors.verde;
      case ChecklistStatus.naoConforme:
        return AppColors.vermelho;
      case ChecklistStatus.na:
        return Colors.grey;
    }
  }
}

class ChecklistSummaryCard extends StatelessWidget {
  final ChecklistSummary summary;

  const ChecklistSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.azulClaro.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.azulInstitucional),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Conforme', summary.conforme, AppColors.verde),
              _buildSummaryItem('Não Conforme', summary.naoConforme, AppColors.vermelho),
              _buildSummaryItem('N.A.', summary.na, Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Conformidade:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${summary.score}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.azulInstitucional)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Risco Sanitário:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                summary.risco,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getRiskColor(summary.score),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getRiskColor(int score) {
    if (score >= 90) return AppColors.verde;
    if (score >= 70) return Colors.orange;
    return AppColors.vermelho;
  }
}
