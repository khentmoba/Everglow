import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_motion.dart';

/// Selectable filter chip with full accessibility.
///
/// Replaces `_AnimeFilterChip`, bucket chips, language chips, etc.
/// `FocusableActionDetector` + `MouseRegion` hover + haptic.
class EverglowChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const EverglowChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });

  @override
  State<EverglowChip> createState() => _EverglowChipState();
}

class _EverglowChipState extends State<EverglowChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: FocusableActionDetector(
        onShowHoverHighlight: (h) => setState(() => _hovered = h),
        child: GestureDetector(
          onTap: () {
            if (widget.onTap != null) {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.deepRose.withValues(alpha: 0.2)
                    : _hovered
                        ? AppColors.moonlight.withValues(alpha: 0.08)
                        : Colors.transparent,
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: selected
                      ? AppColors.deepRose.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 14,
                      color: selected
                          ? AppColors.roseQuartz
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.label,
                    style: AppTypography.labelMedium().copyWith(
                      color: selected
                          ? AppColors.roseQuartz
                          : AppColors.textMuted,
                    ),
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
