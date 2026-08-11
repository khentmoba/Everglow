import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Consistent section header used across the four inside screens
/// (Cinema, Anime, Books, Manga). Composes a small uppercase eyebrow,
/// a serif display title, an optional item count, and a "See all"
/// affordance — so every rail in the app reads with the same rhythm.
///
/// Honours component-forge's a11y checklist:
///   * Wrapped in a `Semantics` header so screen readers announce
///     "section, <title>".
///   * "See all" chip has a `tooltip` + `Semantics` label.
///   * Tap target is 36+ px and respects the medium motion duration.
class ShelfSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final int? count;
  final String? countLabel;
  final VoidCallback? onSeeAll;

  const ShelfSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent = AppTheme.roseQuartz,
    this.count,
    this.countLabel,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: 0.25)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...[
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 9,
                    color: accent.withValues(alpha: 0.75),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTypography.cormorantExtraBoldWhite.copyWith(fontSize: 22, letterSpacing: 0.2, height: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                  subtitle!,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: AppTheme.roseQuartz.withValues(alpha: 0.55),
                  ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Text(
                countLabel != null
                    ? '$count $countLabel'
                    : '$count',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 10,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.4,
        ),
              ),
            ),
          ],
          if (onSeeAll != null) ...[
            const SizedBox(width: 8),
            _SeeAllChip(accent: accent, onTap: onSeeAll!),
          ],
        ],
      ),
    );
  }
}

class _SeeAllChip extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;
  const _SeeAllChip({required this.accent, required this.onTap});

  @override
  State<_SeeAllChip> createState() => _SeeAllChipState();
}

class _SeeAllChipState extends State<_SeeAllChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'See all',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (show) => setState(() => _hovered = show),
        child: Tooltip(
          message: 'See all',
          textStyle: AppTypography.outfitBold.copyWith(
            fontSize: 11,
          ),
          decoration: BoxDecoration(
            color: AppTheme.velvet,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.3),
            ),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: ShelfMotion.orZero(ShelfMotion.medium),
              curve: ShelfMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.accent
                      .withValues(alpha: _hovered ? 0.55 : 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 11,
                      color: widget.accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: widget.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
