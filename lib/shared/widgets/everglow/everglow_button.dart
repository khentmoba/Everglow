import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';

/// Unified button for ALL screens.
///
/// Replaces `BouncyButton` and all bare `GestureDetector` circles.
/// Variants: filled (default), glass, ghost, pill.
///
/// Features: 44px min tap target, press scale 0.96, haptic feedback,
/// `Semantics`, `Tooltip`, `FocusableActionDetector`, reduced-motion-aware.
class EverglowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final _Variant _variant;
  final bool enabled;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const EverglowButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.enabled = true,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  }) : _variant = _Variant.filled;

  const EverglowButton.glass({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.enabled = true,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  }) : _variant = _Variant.glass;

  const EverglowButton.ghost({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.enabled = true,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  }) : _variant = _Variant.ghost;

  const EverglowButton.pill({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.enabled = true,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  }) : _variant = _Variant.pill;

  @override
  State<EverglowButton> createState() => _EverglowButtonState();
}

enum _Variant { filled, glass, ghost, pill }

class _EverglowButtonState extends State<EverglowButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _onTapDown(_) => setState(() => _pressed = true);
  void _onTapUp(_) {
    setState(() => _pressed = false);
    if (widget.enabled && widget.onPressed != null) {
      HapticFeedback.selectionClick();
      widget.onPressed!();
    }
  }

  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
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
      padding: _buildPadding(),
      decoration: _buildDecoration(),
      child: _buildContent(),
    );

    child = Semantics(
      button: true,
      label: widget.tooltip ?? widget.label,
      enabled: widget.enabled,
      child: FocusableActionDetector(
        enabled: widget.enabled,
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
              if (!widget.enabled || widget.onPressed == null) return null;
              HapticFeedback.selectionClick();
              widget.onPressed!();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: widget.enabled ? _onTapDown : null,
          onTapUp: widget.enabled ? _onTapUp : null,
          onTapCancel: widget.enabled ? _onTapCancel : null,
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
      child = Tooltip(message: widget.tooltip!, child: child);
    }

    return RepaintBoundary(child: child);
  }

  EdgeInsets _buildPadding() {
    switch (widget._variant) {
      case _Variant.pill:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.sm,
        );
      case _Variant.ghost:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        );
      default:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.md,
        );
    }
  }

  BoxDecoration _buildDecoration() {
    final radius = widget._variant == _Variant.pill
        ? AppRadius.radiusFull
        : AppRadius.radiusX2;
    final focusBorder = Border.all(
      color: AppColors.blushGold.withValues(alpha: 0.65),
      width: 1.4,
    );

    switch (widget._variant) {
      case _Variant.filled:
        final base = widget.backgroundColor ?? AppColors.deepRose;
        return BoxDecoration(
          color: widget.enabled ? base : base.withValues(alpha: 0.5),
          borderRadius: radius,
          border: _focused ? focusBorder : null,
          boxShadow: _hovered ? AppElevation.glowRose : AppElevation.e1,
        );
      case _Variant.glass:
        return BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: radius,
          border: _focused ? focusBorder : Border.all(color: AppColors.border),
          boxShadow: _hovered ? AppElevation.e2 : AppElevation.e1,
        );
      case _Variant.ghost:
        return BoxDecoration(
          color: _hovered
              ? AppColors.moonlight.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: radius,
          border: _focused ? focusBorder : null,
        );
      case _Variant.pill:
        return BoxDecoration(
          color: _hovered
              ? AppColors.deepRose.withValues(alpha: 0.15)
              : AppColors.deepRose.withValues(alpha: 0.08),
          borderRadius: radius,
          border: _focused
              ? focusBorder
              : Border.all(color: AppColors.deepRose.withValues(alpha: 0.22)),
        );
    }
  }

  Widget _buildContent() {
    final color =
        widget.foregroundColor ??
        (widget._variant == _Variant.ghost
            ? AppColors.textMedium
            : AppColors.petalWhite);

    final children = <Widget>[
      if (widget.icon != null) ...[
        Icon(widget.icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
      ],
      Text(
        widget.label,
        style: AppTypography.labelLarge().copyWith(color: color),
      ),
    ];

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
