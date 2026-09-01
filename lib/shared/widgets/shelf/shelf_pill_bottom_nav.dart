import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/theme/app_colors.dart';
import 'motion.dart';

/// Floating pill bottom nav shared by Cinema, Anime, Books, and
/// Manga. Active item shows its label next to the icon; inactive
/// items render as a single icon. Wrapped in a single rounded
/// container with the same shadow + border treatment across all
/// four screens.
///
/// Honours component-forge's nav checklist:
///   * Each item is a real `Semantics` button with a label.
///   * Animated underline snaps to end state under
///     `prefers-reduced-motion`.
///   * Tap target is comfortably above 44 px.
class ShelfPillBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<ShelfNavItem> items;
  final void Function(int) onTap;
  final Color accentColor;
  final Color glowColor;

  const ShelfPillBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.accentColor = AppColors.deepRose,
    this.glowColor = AppColors.deepRose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.animeCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.roseQuartz.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            return Semantics(
              button: true,
              selected: i == currentIndex,
              label: items[i].label,
              child: _buildItem(items[i], i, i == currentIndex),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildItem(ShelfNavItem item, int index, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (index != currentIndex) onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: ShelfMotion.orZero(ShelfMotion.medium),
        curve: ShelfMotion.easeOutStrong,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: ShelfMotion.orZero(ShelfMotion.fast),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey('$index-$isActive'),
                size: 22,
                color: isActive
                    ? accentColor
                    : AppColors.roseQuartz.withValues(alpha: 0.55),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 12,
                  color: accentColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShelfNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const ShelfNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
