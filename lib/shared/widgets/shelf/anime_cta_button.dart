import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'motion.dart';

/// Anime-themed CTA button with gradient border and hover glow.
///
/// Used across the anime screen for primary actions (e.g., "Search Anime",
/// "Add to Everglow"). Features:
/// - Gradient border that intensifies on hover
/// - Subtle lift animation on hover
/// - Magenta → purple gradient background
/// - Responsive to both touch and mouse
class AnimeCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AnimeCtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<AnimeCtaButton> createState() => _AnimeCtaButtonState();
}

class _AnimeCtaButtonState extends State<AnimeCtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: ShelfMotion.orZero(ShelfMotion.medium),
          curve: ShelfMotion.easeOutStrong,
          transform: Matrix4.identity()
            ..setTranslationRaw(0.0, _hovered ? -2.0 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.animeMagenta.withValues(
                  alpha: _hovered ? 0.35 : 0.25,
                ),
                AppColors.animeElectricPurple.withValues(
                  alpha: _hovered ? 0.35 : 0.25,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered
                  ? AppColors.animeCyan.withValues(alpha: 0.7)
                  : AppColors.animeMagenta.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.animeMagenta.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: AppColors.animeWhite, size: 18),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: AppTypography.outfitHeading.copyWith(
                  color: AppColors.animeWhite,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
