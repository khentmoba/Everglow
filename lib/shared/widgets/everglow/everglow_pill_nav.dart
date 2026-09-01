import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';
import 'everglow_keyboard_activation.dart';

/// Floating pill bottom navigation bar.
///
/// Replaces `ShelfPillBottomNav`. App-wide bottom nav for all screens.
/// `Semantics(button, selected)` on each item. Reduced-motion-aware.
class EverglowPillNav extends StatelessWidget {
  final List<EverglowNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const EverglowPillNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final leftInset = MediaQuery.paddingOf(context).left;
    final rightInset = MediaQuery.paddingOf(context).right;
    return Positioned(
      left: 16 + leftInset,
      right: 16 + rightInset,
      bottom: bottomPadding + 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: AppRadius.radiusX3,
          boxShadow: AppElevation.floating,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final selected = i == currentIndex;
            return _NavItem(
              item: item,
              selected: selected,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(i);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final EverglowNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: EverglowKeyboardActivation(
        onActivate: onTap,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.medium),
              curve: AppMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.deepRose.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: AppRadius.radiusFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.orZero(AppMotion.fast),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      key: ValueKey(selected),
                      size: 22,
                      color: selected
                          ? AppColors.roseQuartz
                          : AppColors.textMuted,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    AnimatedSize(
                      duration: AppMotion.orZero(AppMotion.medium),
                      curve: AppMotion.easeOutExpo,
                      child: Text(
                        item.label,
                        style: AppTypography.labelLarge().copyWith(
                          color: AppColors.roseQuartz,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Configuration for a single navigation item.
class EverglowNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const EverglowNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
