import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double? opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur,
    this.opacity,
    this.borderRadius,
    this.border,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = blur ?? AppTheme.glassBlur;
    final effectiveOpacity = opacity ?? AppTheme.glassOpacity;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(32.0);
    
    // Check for performance fallback
    final bool useBlur = effectiveBlur > 0 && !AppTheme.shouldReduceMotion;

    Widget container = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: useBlur ? effectiveOpacity : 0.3),
        borderRadius: effectiveRadius,
        border: border ?? Border.all(color: Colors.white24, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.peachyMagenta.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: child,
    );

    if (!useBlur) return container;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: container,
        ),
      ),
    );
  }
}
