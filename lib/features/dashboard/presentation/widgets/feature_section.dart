import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

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
    this.padding = const EdgeInsets.all(18),
  });

  @override
  State<FeatureSection> createState() => _FeatureSectionState();
}

class _FeatureSectionState extends State<FeatureSection> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final reduceAmbient = AppMotion.reduceAmbientMotion(context);
    final boxDecoration = BoxDecoration(
      color: AppColors.velvet.withValues(alpha: 0.34),
      borderRadius: AppRadius.radiusXl,
      border: Border.all(
        color: _hovered && !reduceAmbient
            ? widget.hue.withValues(alpha: 0.22)
            : AppColors.moonlight.withValues(alpha: 0.07),
        width: 1,
      ),
      boxShadow: reduceAmbient
          ? null
          : [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
    );
    final stack = Stack(
      children: [
              Positioned(
                top: 0,
                left: 22,
                right: 22,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        widget.hue.withValues(alpha: 0.20),
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
                                  fontSize: 20,
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
                                    letterSpacing: 0.25,
                                    color: AppColors.petalWhite.withValues(alpha: 0.48),
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
          );
    final panel = reduceAmbient
        ? DecoratedBox(decoration: boxDecoration, child: stack)
        : AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.medium),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
            decoration: boxDecoration,
            child: stack,
          );
    final interactivePanel = GestureDetector(onTap: widget.onTap, child: panel);
    return RepaintBoundary(
      child: reduceAmbient
          ? interactivePanel
          : MouseRegion(
              cursor: interactive
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: interactivePanel,
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
        color: hue.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.24), width: 1),
      ),
      child: Icon(icon, color: hue, size: 19),
    );
  }
}

class SectionPillLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color hue;

  const SectionPillLink({
    super.key,
    required this.label,
    required this.onTap,
    this.hue = AppColors.blushGold,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hue.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: hue,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, size: 14, color: hue),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionChevron extends StatelessWidget {
  final Color hue;

  const SectionChevron({super.key, this.hue = AppColors.blushGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.withValues(alpha: 0.10),
        border: Border.all(color: hue.withValues(alpha: 0.28)),
      ),
      child: Icon(Icons.chevron_right_rounded, color: hue, size: 16),
    );
  }
}
