import 'package:flutter/material.dart';
import '../ui/theme.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  const DashboardCard({super.key, required this.title, required this.value, this.color = AppColors.azulClaro});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}
