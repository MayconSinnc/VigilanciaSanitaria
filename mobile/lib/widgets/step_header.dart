import 'package:flutter/material.dart';
import '../ui/theme.dart';

class StepHeader extends StatelessWidget {
  final List<String> labels;
  final int currentStep;
  const StepHeader({super.key, required this.labels, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.azulInstitucional;
    final inactiveColor = Colors.grey.shade400;
    final textActive = AppColors.azulInstitucional;
    final textInactive = Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            _Dot(
              index: i,
              active: i == currentStep,
              done: i < currentStep,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              textActive: textActive,
              textInactive: textInactive,
              label: labels[i],
            ),
            if (i != labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < currentStep ? activeColor : Colors.grey.shade300,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int index;
  final bool active;
  final bool done;
  final Color activeColor;
  final Color inactiveColor;
  final Color textActive;
  final Color textInactive;
  final String label;

  const _Dot({
    required this.index,
    required this.active,
    required this.done,
    required this.activeColor,
    required this.inactiveColor,
    required this.textActive,
    required this.textInactive,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = done || active ? activeColor : inactiveColor;
    final labelColor = done || active ? textActive : textInactive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: labelColor, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }
}

