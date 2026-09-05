import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';

/// Unified page-level empty state for ALL screens.
///
/// Replaces `ShelfEmptyState`. (Dashboard preview strips use a smaller
/// inline-row style on purpose — different job, different widget.)
/// Shows an icon medallion + title + subtitle + optional CTA button.
class EverglowEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool compact;

  const EverglowEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.x2 : AppSpacing.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon medallion
            Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.velvet.withValues(alpha: 0.9), AppColors.inkDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.border, width: 1.0),
                boxShadow: compact ? null : [BoxShadow(color: AppColors.deepRose.withValues(alpha: 0.12), blurRadius: 12)],
              ),
              child: Icon(icon, size: compact ? 28 : 34, color: AppColors.roseQuartz),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: AppTypography.headlineSmall(),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                subtitle!,
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _CtaButton(label: ctaLabel!, onPressed: onCta!),
            ],
          ],
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _CtaButton({required this.label, required this.onPressed});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: FocusableActionDetector(
        onShowFocusHighlight: (_) {},
        onShowHoverHighlight: (h) => setState(() => _hovered = h),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2,
                vertical: AppSpacing.md,
              ),
              transform: _hovered
                  ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
                  : Matrix4.identity(),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepRose, AppColors.velvet],
                ),
                borderRadius: AppRadius.radiusXl,
                boxShadow: _hovered ? [BoxShadow(color: AppColors.deepRose.withValues(alpha: 0.18), blurRadius: 14)] : AppElevation.e1,
              ),
              child: Text(widget.label, style: AppTypography.labelLarge()),
            ),
          ),
        ),
      ),
    );
  }
}
