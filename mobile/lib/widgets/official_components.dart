import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/theme.dart';

class OfficialSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;

  const OfficialSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, color: AppColors.azulInstitucional, size: 20),
                if (icon != null) const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.azulInstitucional,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class OfficialTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool required;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String)? onChanged;
  final Widget? suffixIcon;
  final Function()? onTap;
  final String? Function(String?)? validator;

  const OfficialTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.suffixIcon,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cinzaCampo,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onTap: onTap,
      validator: validator,
    );
  }
}

class OfficialDropdown extends StatelessWidget {
  final String label;
  final List<String> items;
  final String? value;
  final Function(String?) onChanged;
  final bool required;

  const OfficialDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: required
          ? (value) =>
              value == null || value.isEmpty ? 'Selecione $label' : null
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        filled: true,
        fillColor: AppColors.cinzaCampo,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

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

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 11) return oldValue;

    String formatted = '(${text.substring(0, text.length > 2 ? 2 : text.length)}';
    if (text.length > 2) {
      final hasNine = text.length >= 7 && text[2] == '9';
      final end = hasNine ? 7 : 6;
      formatted += ') ${text.substring(2, text.length > end ? end : text.length)}';
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

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    if (text.length > 4) return oldValue;

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1) formatted += ':';
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class OfficialStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  final Function(int) onStepTapped;

  const OfficialStepper({
    super.key,
    required this.currentStep,
    required this.steps,
    required this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final isActive = index == currentStep;
              final isCompleted = index < currentStep;
              return Expanded(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => onStepTapped(index),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? AppColors.azulInstitucional
                              : isCompleted
                                  ? AppColors.verde
                                  : Colors.grey[300],
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive || isCompleted ? Colors.white : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? AppColors.azulInstitucional : Colors.grey[600],
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(steps.length - 1, (index) {
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: index < currentStep ? AppColors.azulInstitucional : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class EstablishmentCard extends StatelessWidget {
  final String razaoSocial;
  final String nomeFantasia;
  final String cnpj;
  final String inscricaoMunicipal;
  final String endereco;
  final String telefone;
  final String? responsavel;

  const EstablishmentCard({
    super.key,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.cnpj,
    required this.inscricaoMunicipal,
    required this.endereco,
    required this.telefone,
    this.responsavel,
  });

  String _formatCnpj(String cnpj) {
    final digits = cnpj.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return cnpj;
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppColors.azulInstitucional, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Dados do Estabelecimento',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.azulInstitucional,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow('Razão Social', razaoSocial),
            _buildRow('Nome Fantasia', nomeFantasia),
            _buildRow('CNPJ', _formatCnpj(cnpj)),
            _buildRow('Inscrição Municipal', inscricaoMunicipal),
            _buildRow('Endereço', endereco),
            _buildRow('Telefone', telefone),
            if (responsavel != null && responsavel!.isNotEmpty) _buildRow('Responsável', responsavel!),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
