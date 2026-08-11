import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// Accessible circular icon button used in the inside-screen headers.
/// Defaults to a 44×44 tap target (the iOS HIG / WCAG minimum) and
/// surfaces a `tooltip` + `Semantics` label so screen readers and
/// keyboard users can both reach it.
class ShelfIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final String? tooltip;
  final double size;
  final Color? iconColor;
  final Color? background;

  const ShelfIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.tooltip,
    this.size = 44,
    this.iconColor,
    this.background,
  });

  @override
  State<ShelfIconButton> createState() => _ShelfIconButtonState();
}

class _ShelfIconButtonState extends State<ShelfIconButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final btn = AnimatedContainer(
      duration: ShelfMotion.orZero(ShelfMotion.medium),
      curve: ShelfMotion.easeOutStrong,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.background ??
            AppTheme.moonlight.withValues(alpha: 0.06),
        border: Border.all(
          color: (_focused || _hovered)
              ? AppTheme.roseQuartz.withValues(alpha: 0.55)
              : AppTheme.roseQuartz.withValues(alpha: 0.15),
          width: _focused ? 1.4 : 0.8,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.4),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        widget.icon,
        color: widget.iconColor ??
            AppTheme.roseQuartz.withValues(alpha: enabled ? 1 : 0.5),
        size: widget.size * 0.45,
      ),
    );

    final content = GestureDetector(
      onTap: enabled ? widget.onTap : null,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: btn,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (show) =>
            setState(() => _focused = show && enabled),
        child: widget.tooltip != null
            ? Tooltip(
                message: widget.tooltip!,
                textStyle: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.velvet,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.3),
                  ),
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}
