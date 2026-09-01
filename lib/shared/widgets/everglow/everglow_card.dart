import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;
    final effectiveScale = _pressed
        ? AppMotion.pressScale
        : (_hovered ? AppMotion.hoverScale : 1.0);
    final effectiveTranslateY = _hovered && !_pressed
        ? AppMotion.hoverLift
        : 0.0;

    Widget child = AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      curve: AppMotion.easeOutStrong,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, effectiveTranslateY, 0.0, 1.0)
        ..scaleByDouble(effectiveScale, effectiveScale, effectiveScale, 1.0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.fillColor ?? AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: _focused
              ? AppColors.blushGold.withValues(alpha: 0.65)
              : AppColors.moonlight.withValues(alpha: 0.08),
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: widget.boxShadow ?? (_hovered ? AppElevation.e1 : null),
      ),
      child: widget.child,
    );

    if (isInteractive) {
      child = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          onShowHoverHighlight: (h) => setState(() => _hovered = h),
          onShowFocusHighlight: (f) => setState(() => _focused = f),
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.enter):
                const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.space):
                const ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                HapticFeedback.selectionClick();
                widget.onTap!();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
          ),
        ),
      );
    }

    return child;
  }
}
