import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_widgets.dart';

// ============================================================================
// COMPONENTES DE CAMPOS OFICIAIS
// ============================================================================

/// Campo de texto oficial com label flutuante correto
class OfficialTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final bool required;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final bool multiline;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? helperText;
  final String? Function(String?)? validator;

  const OfficialTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    String? hint,
    String? hintText,
    String? placeholder,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.required = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.multiline = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.helperText,
    this.validator,
  }) : hint = hint ?? hintText ?? placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GovColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GovColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          enabled: enabled && !readOnly,
          readOnly: readOnly,
          maxLines: multiline ? (maxLines ?? 4) : 1,
          minLines: multiline ? (minLines ?? 4) : null,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          validator: validator ?? (required ? _requiredValidator : null),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? GovColors.card : GovColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
          ),
          style: const TextStyle(
            fontSize: 15,
            color: GovColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    return null;
  }
}

/// Campo multiline oficial
class OfficialMultilineField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialMultilineField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.minLines = 4,
    this.maxLines = 8,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GovColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GovColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator ?? (required ? _requiredValidator : null),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? GovColors.card : GovColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(
            fontSize: 15,
            color: GovColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    return null;
  }
}

/// Campo dropdown oficial
class OfficialDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final String? Function(T?)? validator;

  const OfficialDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.validator,
  });

  static OfficialDropdownField<String> fromStrings({
    Key? key,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    required String label,
    String? hint,
    bool required = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return OfficialDropdownField<String>(
      key: key,
      value: value,
      items: items
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      label: label,
      hint: hint,
      required: required,
      enabled: enabled,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GovColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GovColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          key: ValueKey<T?>(value),
          initialValue: value,
          items: items,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: validator ?? (required ? _requiredValidator : null),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? GovColors.card : GovColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: GovColors.primary),
          style: const TextStyle(
            fontSize: 15,
            color: GovColors.textPrimary,
          ),
          dropdownColor: GovColors.card,
        ),
      ],
    );
  }

  String? _requiredValidator(T? value) {
    if (value == null) {
      return 'Campo obrigatório';
    }
    return null;
  }
}

/// Campo numérico oficial
class OfficialNumericField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final int? minValue;
  final int? maxValue;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialNumericField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.minValue,
    this.maxValue,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return OfficialTextField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      hint: hint,
      required: required,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: onChanged,
      validator: validator ?? (required ? _numericValidator : null),
    );
  }

  String? _numericValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    final num = int.tryParse(value);
    if (num == null) {
      return 'Valor inválido';
    }
    if (minValue != null && num < minValue!) {
      return 'Mínimo: $minValue';
    }
    if (maxValue != null && num > maxValue!) {
      return 'Máximo: $maxValue';
    }
    return null;
  }
}

/// Campo monetário oficial
class OfficialMoneyField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialMoneyField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return OfficialTextField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      hint: hint,
      required: required,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        MoneyInputFormatter(),
      ],
      onChanged: onChanged,
      validator: validator ?? (required ? _moneyValidator : null),
    );
  }

  String? _moneyValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    final cleanValue = value.replaceAll(RegExp(r'[R$\s.]'), '').replaceAll(',', '.');
    final num = double.tryParse(cleanValue);
    if (num == null || num < 0) {
      return 'Valor inválido';
    }
    return null;
  }
}

/// Campo CPF oficial
class OfficialCpfField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialCpfField({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'CPF',
    this.hint,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return OfficialTextField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      hint: hint,
      required: required,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      inputFormatters: [
        CpfInputFormatter(),
      ],
      onChanged: onChanged,
      validator: validator ?? (required ? _cpfValidator : null),
    );
  }

  String? _cpfValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      return 'CPF inválido';
    }
    if (!_isValidCpf(digits)) {
      return 'CPF inválido';
    }
    return null;
  }

  bool _isValidCpf(String cpf) {
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    
    List<int> numbers = cpf.split('').map(int.parse).toList();
    
    int calcDigit(List<int> numbers, int weight) {
      int sum = 0;
      for (int i = 0; i < weight; i++) {
        sum += numbers[i] * (weight + 1 - i);
      }
      int remainder = sum % 11;
      return remainder < 2 ? 0 : 11 - remainder;
    }
    
    int digit1 = calcDigit(numbers, 9);
    int digit2 = calcDigit(numbers, 10);
    
    return digit1 == numbers[9] && digit2 == numbers[10];
  }
}

/// Campo CNPJ oficial
class OfficialCnpjField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialCnpjField({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'CNPJ',
    this.hint,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return OfficialTextField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      hint: hint,
      required: required,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        CnpjInputFormatter(),
      ],
      onChanged: onChanged,
      validator: validator ?? (required ? _cnpjValidator : null),
    );
  }

  String? _cnpjValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) {
      return 'CNPJ inválido';
    }
    if (!_isValidCnpj(digits)) {
      return 'CNPJ inválido';
    }
    return null;
  }

  bool _isValidCnpj(String cnpj) {
    if (cnpj.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;
    
    List<int> numbers = cnpj.split('').map(int.parse).toList();
    
    int calcDigit(List<int> numbers, List<int> weights) {
      int sum = 0;
      for (int i = 0; i < weights.length; i++) {
        sum += numbers[i] * weights[i];
      }
      int remainder = sum % 11;
      return remainder < 2 ? 0 : 11 - remainder;
    }
    
    List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    List<int> weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    
    int digit1 = calcDigit(numbers, weights1);
    int digit2 = calcDigit(numbers, weights2);
    
    return digit1 == numbers[12] && digit2 == numbers[13];
  }
}

/// Campo telefone oficial
class OfficialPhoneField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialPhoneField({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'Telefone',
    this.hint,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return OfficialTextField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      hint: hint,
      required: required,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        PhoneInputFormatter(),
      ],
      onChanged: onChanged,
      validator: validator ?? (required ? _phoneValidator : null),
    );
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 11) {
      return 'Telefone inválido';
    }
    return null;
  }
}

/// Campo data oficial
class OfficialDateField extends StatelessWidget {
  final DateTime? value;
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final ValueChanged<DateTime?>? onChanged;
  final String? Function(DateTime?)? validator;

  const OfficialDateField({
    super.key,
    this.value,
    this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return OfficialTextField(
        controller: controller,
        label: label,
        hint: hint ?? 'DD/MM/AAAA',
        required: required,
        enabled: enabled,
        keyboardType: TextInputType.datetime,
        inputFormatters: [DateInputFormatter()],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GovColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GovColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    onChanged?.call(picked);
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: enabled ? GovColors.card : GovColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: enabled ? GovColors.primary : Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value != null
                        ? '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
                        : (hint ?? 'Selecione a data'),
                    style: TextStyle(
                      fontSize: 15,
                      color: value != null ? GovColors.textPrimary : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo hora oficial
class OfficialTimeField extends StatelessWidget {
  final TimeOfDay? value;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final ValueChanged<TimeOfDay?>? onChanged;
  final String? Function(TimeOfDay?)? validator;

  const OfficialTimeField({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GovColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GovColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: value ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    onChanged?.call(picked);
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: enabled ? GovColors.card : GovColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_outlined,
                  color: enabled ? GovColors.primary : Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value != null
                        ? '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
                        : (hint ?? 'Selecione a hora'),
                    style: TextStyle(
                      fontSize: 15,
                      color: value != null ? GovColors.textPrimary : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

typedef OfficialDecimalField = OfficialNumericField;

class OfficialCepField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialCepField({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'CEP',
    this.hint,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return OfficialTextField(
      controller: controller,
      initialValue: initialValue,
      label: label,
      hint: hint ?? '00000-000',
      required: required,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [CepInputFormatter()],
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class OfficialPasswordField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const OfficialPasswordField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.required = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          required ? '$label *' : label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: GovColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: true,
          onChanged: onChanged,
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
                  : null),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            filled: true,
            fillColor: enabled ? GovColors.card : GovColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
      ],
    );
  }
}

/// Formatter para valores monetários
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    
    final value = int.tryParse(text) ?? 0;
    final formatted = 'R\$ ${(value / 100).toStringAsFixed(2)}';
    
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
