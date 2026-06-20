import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';

/// Section header — accent bar + eyebrow + title + count + see-all.
///
/// Replaces `ShelfSectionHeader` and `ShelfHeader`.
/// `Semantics(header: true)` for screen readers.
class EverglowSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final int? count;
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  const EverglowSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.count,
    this.seeAllLabel,
    this.onSeeAll,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '$eyebrow: $title',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Accent bar
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.deepRose, AppColors.blushGold],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Eyebrow + title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow.toUpperCase(), style: AppTypography.labelSmall()),
                  const SizedBox(height: 2),
                  Text(title, style: AppTypography.titleLarge()),
                ],
              ),
            ),
            // Count badge
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall().copyWith(
                    color: AppColors.roseQuartz,
                  ),
                ),
              ),
            if (trailing != null) trailing!,
            // See all
            if (seeAllLabel != null && onSeeAll != null) ...[
              const SizedBox(width: AppSpacing.md),
              _SeeAllButton(label: seeAllLabel!, onPressed: onSeeAll!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _SeeAllButton({required this.label, required this.onPressed});

  @override
  State<_SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<_SeeAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'See all ${widget.label}',
      child: GestureDetector(
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTypography.labelMedium().copyWith(
              color: _hovered
                  ? AppColors.blushGold
                  : AppColors.textMuted,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
