import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  const ActionButton({super.key, required this.label, required this.color, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(60)),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
