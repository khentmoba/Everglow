import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';

/// 44px circular icon button with full accessibility.
///
/// Replaces `ShelfIconButton` and all bare `IconButton`/`GestureDetector`
/// circles. Features: `Semantics(button, label)`, `Tooltip`,
/// `FocusableActionDetector` focus glow, haptic, reduced-motion-aware.
class EverglowIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? tooltip;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enabled;

  const EverglowIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tooltip,
    this.size = 44,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.enabled = true,
  });

  /// Back arrow variant (for screen headers).
  const EverglowIconButton.back({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Go back',
    this.tooltip = 'Back',
    this.size = 44,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.enabled = true,
  }) : icon = Icons.arrow_back_ios_new;

  /// Close variant.
  const EverglowIconButton.close({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Close',
    this.tooltip = 'Close',
    this.size = 44,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.enabled = true,
  }) : icon = Icons.close;

  @override
  State<EverglowIconButton> createState() => _EverglowIconButtonState();
}

class _EverglowIconButtonState extends State<EverglowIconButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveScale =
        _pressed ? AppMotion.pressScale : (_hovered ? AppMotion.hoverScale : 1.0);
    final bg = widget.backgroundColor ?? AppColors.surfaceGlass;
    final borderColor = widget.borderColor ?? AppColors.border;
    final iconColor = widget.iconColor ?? AppColors.roseQuartz;

    Widget child = AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      curve: AppMotion.easeOutStrong,
      width: widget.size,
      height: widget.size,
      transform: Matrix4.identity()..scaleByDouble(effectiveScale),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
        boxShadow: _focused
            ? [BoxShadow(blurRadius: 12, color: AppColors.deepRose.withValues(alpha: 0.4))]
            : _hovered
                ? AppElevation.e1
                : null,
      ),
      child: Center(
        child: Icon(widget.icon, size: 20, color: iconColor),
      ),
    );

    child = Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: widget.enabled,
      child: FocusableActionDetector(
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        onShowHoverHighlight: (h) => setState(() => _hovered = h),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            if (widget.enabled && widget.onPressed != null) {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip!,
        decoration: BoxDecoration(
          color: AppColors.velvet,
          borderRadius: AppRadius.radiusSm,
          border: Border.all(color: AppColors.border),
        ),
        textStyle: TextStyle(
          color: AppColors.textMedium,
          fontSize: 12,
        ),
        child: child,
      );
    }

    return child;
  }
}
