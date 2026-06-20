import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';

/// Token-driven card with hover lift and press feedback.
///
/// `Semantics` + `FocusableActionDetector` + 44px min target when tappable.
class EverglowCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double radius;
  final EdgeInsets padding;
  final Color? fillColor;
  final List<BoxShadow>? boxShadow;

  const EverglowCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.radius = AppRadius.x2,
    this.padding = const EdgeInsets.all(20),
    this.fillColor,
    this.boxShadow,
  });

  @override
  State<EverglowCard> createState() => _EverglowCardState();
}

class _EverglowCardState extends State<EverglowCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;
    final effectiveScale = _pressed
        ? AppMotion.pressScale
        : (_hovered ? AppMotion.hoverScale : 1.0);
    final effectiveTranslateY = _hovered && !_pressed ? AppMotion.hoverLift : 0.0;

    Widget child = AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      curve: AppMotion.easeOutStrong,
      transform: Matrix4.identity()
        ..translate(0.0, effectiveTranslateY, 0.0)
        ..scale(effectiveScale),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.fillColor ?? AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: widget.boxShadow ??
            (_hovered ? AppElevation.e3 : AppElevation.e2),
      ),
      child: widget.child,
    );

    if (isInteractive) {
      child = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          onShowHoverHighlight: (h) => setState(() => _hovered = h),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: child,
            ),
          ),
        ),
      );
    }

    return child;
  }
}
