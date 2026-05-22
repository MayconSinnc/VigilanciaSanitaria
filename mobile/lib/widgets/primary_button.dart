import 'package:flutter/material.dart';
import '../ui/theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.azulInstitucional, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}
