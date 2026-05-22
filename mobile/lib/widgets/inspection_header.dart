import 'package:flutter/material.dart';
import '../ui/theme.dart';

class InspectionHeader extends StatelessWidget {
  final String prefeitura;
  final String departamento;
  const InspectionHeader({super.key, required this.prefeitura, required this.departamento});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.azulInstitucional,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prefeitura, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(departamento, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
