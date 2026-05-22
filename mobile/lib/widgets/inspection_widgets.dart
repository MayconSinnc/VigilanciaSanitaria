import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// CONSTANTES DE DESIGN GOV.BR
// ============================================================================
/// Normaliza dados da API/local para o card de nova inspeção.
Map<String, dynamic> normalizeEstablishmentForInspection(Map<String, dynamic> e) {
  String endereco = (e['endereco'] ?? '').toString().trim();
  if (endereco.isEmpty) {
    final parts = [
      e['logradouro'] ?? e['rua'],
      e['numero'],
      e['bairro'],
      e['cidade'] ?? e['municipio'],
      e['uf'] ?? e['estado'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).map((v) => '$v'.trim());
    endereco = parts.join(', ');
  }
  return {
    'id': e['id'],
    'razao_social': (e['razao_social'] ?? e['razaoSocial'] ?? '').toString(),
    'nome_fantasia': (e['nome_fantasia'] ?? e['nomeFantasia'] ?? e['nome'] ?? '').toString(),
    'cnpj': (e['cnpj'] ?? '').toString(),
    'inscricao_municipal': e['inscricao_municipal'] ?? e['inscricaoMunicipal'],
    'endereco': endereco.isEmpty ? 'Não informado' : endereco,
    'status_alvara': (e['status_alvara'] ?? e['statusAlvara'] ?? 'Desconhecido').toString(),
    'debito_vencido': e['possui_debito_vencido'] == true || e['possuiDebitoVencido'] == true,
  };
}

class GovColors {
  static const Color primary = Color(0xFF1351B4);
  static const Color primaryDark = Color(0xFF0B5FA5);
  static const Color background = Color(0xFFF5F7FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}

// ============================================================================
// COMPONENTES REUTILIZÁVEIS
// ============================================================================

/// Card de header/resumo da inspeção
class InspectionHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isOnline;
  final bool hasPendingSync;

  const InspectionHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.isOnline = true,
    this.hasPendingSync = false,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: GovColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: GovColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: GovColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusBadge(
                icon: isOnline ? Icons.wifi : Icons.wifi_off,
                label: isOnline ? 'Online' : 'Offline',
                color: isOnline ? GovColors.success : GovColors.warning,
              ),
              if (hasPendingSync) ...[
                const SizedBox(width: 8),
                _buildStatusBadge(
                  icon: Icons.sync,
                  label: 'Pendente de sincronização',
                  color: GovColors.warning,
                ),
              ],
            ],
          ),
          if (!isOnline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GovColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GovColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: GovColors.warning, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modo offline ativo. Os dados serão sincronizados posteriormente.',
                      style: TextStyle(
                        fontSize: 12,
                        color: GovColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown moderno para tipo de inspeção
class InspectionTypeDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const InspectionTypeDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: GovColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tipo de Inspeção',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GovColors.textPrimary,
                  ),
                ),
                const Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GovColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: value,
              items: options
                  .map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ))
                  .toList(),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Selecione o tipo de inspeção',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: GovColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: GovColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: GovColors.error, width: 2),
                ),
                filled: true,
                fillColor: GovColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: GovColors.primary),
              style: const TextStyle(
                fontSize: 15,
                color: GovColors.textPrimary,
              ),
              dropdownColor: GovColors.card,
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline, color: GovColors.error, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GovColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card de estabelecimento selecionado
class SelectedEstablishmentCard extends StatelessWidget {
  final String razaoSocial;
  final String nomeFantasia;
  final String cnpj;
  final String? inscricaoMunicipal;
  final String endereco;
  final String statusAlvara;
  final bool debitoVencido;
  final VoidCallback onClear;

  const SelectedEstablishmentCard({
    super.key,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.cnpj,
    this.inscricaoMunicipal,
    required this.endereco,
    required this.statusAlvara,
    required this.debitoVencido,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(
                Icons.store_outlined,
                color: GovColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Estabelecimento Selecionado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GovColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: GovColors.textSecondary),
                onPressed: onClear,
                tooltip: 'Limpar seleção',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Razão Social', razaoSocial),
          const SizedBox(height: 8),
          _buildInfoRow('Nome Fantasia', nomeFantasia),
          const SizedBox(height: 8),
          _buildInfoRow('CNPJ', _formatCNPJ(cnpj)),
          if (inscricaoMunicipal != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Inscrição Municipal', inscricaoMunicipal!),
          ],
          const SizedBox(height: 8),
          _buildInfoRow('Endereço', endereco),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBadge('Alvará: $statusAlvara', _getStatusColor(statusAlvara)),
              const SizedBox(width: 8),
              if (debitoVencido)
                _buildBadge('Débito Vencido', GovColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: GovColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: GovColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatCNPJ(String cnpj) {
    final digits = cnpj.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return cnpj;
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12, 14)}';
  }

  Color _getStatusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('regular') || lower.contains('ativo') || lower.contains('vigente')) {
      return GovColors.success;
    } else if (lower.contains('vencido') || lower.contains('irregular') || lower.contains('suspenso')) {
      return GovColors.error;
    } else {
      return GovColors.warning;
    }
  }
}

/// Card de estabelecimento vazio
class EmptyEstablishmentCard extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onScanCNPJ;

  const EmptyEstablishmentCard({
    super.key,
    required this.onSearch,
    required this.onScanCNPJ,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(
                Icons.store_outlined,
                color: GovColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GovColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: GovColors.textSecondary,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nenhum estabelecimento selecionado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: GovColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Busque pelo cadastro, CNPJ ou utilize o scanner.',
                  style: TextStyle(
                    fontSize: 12,
                    color: GovColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar Estabelecimento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GovColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScanCNPJ,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scanner CNPJ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GovColors.primary,
                    side: const BorderSide(color: GovColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card de ação principal
class InspectionActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledReason;

  const InspectionActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.enabled = true,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          border: Border.all(
            color: enabled ? GovColors.primary.withOpacity(0.2) : Colors.grey[300]!,
            width: enabled ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enabled ? GovColors.primary.withOpacity(0.1) : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: enabled ? GovColors.primary : Colors.grey[400],
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enabled ? GovColors.textPrimary : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? GovColors.textSecondary : Colors.grey[400],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!enabled && disabledReason != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, color: GovColors.warning, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      disabledReason!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GovColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card de recurso de apoio
class SupportResourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const SupportResourceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Icon(
              icon,
              color: GovColors.primary,
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GovColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: GovColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de status
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Botão de ação principal inferior
class BottomPrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final String? disabledReason;

  const BottomPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GovColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: enabled ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: enabled ? GovColors.primary : Colors.grey[300],
                  foregroundColor: enabled ? Colors.white : Colors.grey[500],
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: enabled ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!enabled && disabledReason != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: GovColors.warning, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    disabledReason!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GovColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FORMATTERS
// ============================================================================

/// Formatter para CNPJ
class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 14) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 4) formatted += '.';
      if (i == 7) formatted += '/';
      if (i == 11) formatted += '-';
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter para CPF
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 11) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 2 || i == 5) formatted += '.';
      if (i == 8) formatted += '-';
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter para telefone
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 11) return oldValue;

    String formatted = '(${text.substring(0, (text.length > 2 ? 2 : text.length))}';
    if (text.length > 2) {
      final hasNine = text.length >= 7 && text[2] == '9';
      final end = hasNine ? 7 : 6;
      formatted += ') ${text.substring(2, (text.length > end ? end : text.length))}';
      if (text.length > end) {
        formatted += '-${text.substring(end)}';
      }
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter para CEP
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 8) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 4) formatted += '-';
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter para data
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 8) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 || i == 3) formatted += '/';
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
