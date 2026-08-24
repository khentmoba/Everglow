import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_motion.dart';
import 'everglow_keyboard_activation.dart';

/// Clean segmented control for feature screens.
///
/// Replaces duplicated tab-bar containers in Budget, Cookbook, Journal,
/// Gallery, Wellness, etc. Token-driven, 44px min target, reduced-motion
/// aware, single source of truth for 'pill' tabs.
class EverglowSegmentedControl extends StatelessWidget {
  final List<SegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color activeColor;

  const EverglowSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor = AppColors.blushGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isSel = i == selectedIndex;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSel,
              label: item.label,
              child: EverglowKeyboardActivation(
                onActivate: () => onChanged(i),
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: AppMotion.orZero(AppMotion.fast),
                    curve: AppMotion.easeOutStrong,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSel
                          ? activeColor.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSel
                            ? activeColor.withValues(alpha: 0.42)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 14,
                          color: isSel
                              ? activeColor
                              : AppColors.petalWhite.withValues(alpha: 0.58),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.label,
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 11.5,
                              letterSpacing: 0.15,
                              color: isSel
                                  ? activeColor
                                  : AppColors.petalWhite.withValues(
                                      alpha: 0.62,
                                    ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
}

class SegmentItem {
  final String label;
  final IconData icon;
  const SegmentItem(this.label, this.icon);
}
