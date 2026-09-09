import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

/// Pill tab bar for the drawer's Cast / Reviews / More Like This sections.
///
/// Only the selected tab's section is built, so the phone never lays out
/// (or fetches images for) the tabs Clair hasn't opened yet. Switching
/// tabs never refetches — the drawer keeps each list once loaded.
class DrawerExtraTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final bool isAnimeSourced;
  final bool cinemaStyle;

  const DrawerExtraTabs({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isAnimeSourced,
    this.cinemaStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      isAnimeSourced ? 'Voice Cast' : 'Cast',
      'Reviews',
      'Mochi says… 🐱',
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, cinemaStyle ? 30 : 26, 20, 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: cinemaStyle
                      ? _cinemaDecoration(isSelected)
                      : _classicDecoration(isSelected),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      color: _textColor(isSelected),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _textColor(bool isSelected) {
    if (cinemaStyle) {
      return isSelected ? Colors.white : AppColors.mutedPurple;
    }
    return isSelected ? Colors.black : AppColors.mutedPurple;
  }

  BoxDecoration _classicDecoration(bool isSelected) {
    return BoxDecoration(
      color: isSelected ? Colors.white : AppColors.shimmerBase,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isSelected
            ? Colors.white
            : AppColors.moonlight.withValues(alpha: 0.14),
        width: 1.2,
      ),
    );
  }

  BoxDecoration _cinemaDecoration(bool isSelected) {
    return BoxDecoration(
      gradient: isSelected
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.auroraRose, AppColors.deepRose],
            )
          : null,
      color: isSelected ? null : AppColors.surfaceGlass,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: isSelected
            ? AppColors.auroraRose.withValues(alpha: 0.9)
            : AppColors.moonlight.withValues(alpha: 0.16),
        width: 1.2,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ]
          : null,
    );
  }
}
