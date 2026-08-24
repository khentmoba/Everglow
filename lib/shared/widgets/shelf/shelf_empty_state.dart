import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Visually consistent empty state for the four inside screens.
/// Combines a soft tinted icon medallion, a one-line headline, an
/// optional supporting line, and a CTA button. Used everywhere the
/// user could land on an empty list (search, library, watchlist).
class ShelfEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final Color accent;

  const ShelfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.accent = AppTheme.roseQuartz,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.15),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: -8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.cormorantBoldWhite.copyWith(
                fontSize: 22,
                height: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 22),
              Semantics(
                button: true,
                label: ctaLabel,
                child: _CtaButton(
                  label: ctaLabel!,
                  icon: ctaIcon,
                  onTap: onCta!,
                  accent: accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color accent;

  const _CtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.accent,
  });

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (show) => setState(() => _focused = show),
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: ShelfMotion.orZero(ShelfMotion.medium),
            curve: ShelfMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(
                0.0,
                _hovered || _focused ? -1.5 : 0.0,
                0.0,
                1.0,
              ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.accent.withValues(alpha: 0.3),
                  AppTheme.deepRose.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _focused
                    ? widget.accent
                    : widget.accent.withValues(alpha: 0.5),
                width: _focused ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: widget.accent, size: 16),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
