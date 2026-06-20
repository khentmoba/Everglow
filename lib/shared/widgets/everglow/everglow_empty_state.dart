import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';

/// Unified empty state for ALL screens.
///
/// Replaces both `ShelfEmpty` and `ShelfEmptyState`.
/// Shows an icon medallion + title + subtitle + optional CTA button.
class EverglowEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EverglowEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon medallion
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.velvet, AppColors.twilight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.0,
                ),
                boxShadow: AppElevation.glowRose,
              ),
              child: Icon(icon, size: 40, color: AppColors.roseQuartz),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              title,
              style: AppTypography.headlineSmall(),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.x2),
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
                  ? (Matrix4.identity()..translate(0.0, -2.0))
                  : Matrix4.identity(),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepRose, AppColors.velvet],
                ),
                borderRadius: AppRadius.radiusXl,
                boxShadow: _hovered ? AppElevation.glowRose : AppElevation.e1,
              ),
              child: Text(
                widget.label,
                style: AppTypography.labelLarge(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
