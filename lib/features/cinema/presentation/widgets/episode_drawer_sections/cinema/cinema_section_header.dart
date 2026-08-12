import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_typography.dart';

/// Section header for the enhanced Cinema drawer: a small-caps eyebrow,
/// a Cormorant display title, and a fading hairline rule. Optional
/// [trailing] shows a count pill (e.g. the number of cast members).
class CinemaSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? trailing;

  const CinemaSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: AppTypography.outfitHeading.copyWith(
                    color: AppColors.roseQuartz.withValues(alpha: 0.85),
                    fontSize: 10,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: AppTypography.cormorantExtraBoldWhite.copyWith(
                    fontSize: 27,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.moonlight.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                trailing!,
                style: AppTypography.outfitHeading.copyWith(
                  color: AppColors.blushGold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
