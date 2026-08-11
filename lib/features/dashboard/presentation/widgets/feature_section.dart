import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Shared dashboard panel: gradient glass body, accent icon chip,
/// title/subtitle header and an optional trailing affordance.
class FeatureSection extends StatefulWidget {
  final IconData icon;
  final Color hue;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const FeatureSection({
    super.key,
    required this.icon,
    required this.hue,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<FeatureSection> createState() => _FeatureSectionState();
}

class _FeatureSectionState extends State<FeatureSection> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.medium),
          curve: AppMotion.easeOutStrong,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.72),
                AppColors.inkDeep.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: _hovered
                  ? widget.hue.withValues(alpha: 0.55)
                  : AppColors.moonlight.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              if (_hovered)
                BoxShadow(
                  color: widget.hue.withValues(alpha: 0.16),
                  blurRadius: 26,
                  spreadRadius: -6,
                ),
            ],
          ),
          child: Stack(
            children: [
              // Accent hairline across the top.
              Positioned(
                top: 0,
                left: 22,
                right: 22,
                child: Container(
                  height: 1.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        widget.hue.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: widget.padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _IconChip(icon: widget.icon, hue: widget.hue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: AppTypography.cormorantBold.copyWith(
                                  fontSize: 21,
                                  height: 1.0,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.trailing != null) widget.trailing!,
                      ],
                    ),
                    const SizedBox(height: 14),
                    widget.child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final Color hue;

  const _IconChip({required this.icon, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hue.withValues(alpha: 0.26), hue.withValues(alpha: 0.08)],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: hue, size: 20),
    );
  }
}

/// Small chevron affordance used by tappable sections.
class SectionChevron extends StatelessWidget {
  final Color hue;

  const SectionChevron({super.key, this.hue = AppColors.blushGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.withValues(alpha: 0.10),
        border: Border.all(color: hue.withValues(alpha: 0.35)),
      ),
      child: Icon(Icons.chevron_right_rounded, color: hue, size: 18),
    );
  }
}
