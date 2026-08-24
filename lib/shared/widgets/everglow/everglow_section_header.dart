import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Minimal section header with hairline rule, icon badge and label.
///
/// Used on Dashboard (Quick Access, Jump, etc.) and could be reused
/// elsewhere for consistent vertical rhythm.
class EverglowSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color hue;

  const EverglowSectionHeader({
    super.key,
    required this.label,
    required this.icon,
    this.hue = AppColors.blushGold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, hue.withValues(alpha: 0.5)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: hue.withValues(alpha: 0.92)),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 10,
                  letterSpacing: 2.0,
                  color: hue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.moonlight.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

