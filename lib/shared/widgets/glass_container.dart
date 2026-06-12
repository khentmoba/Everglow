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
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24.0);
    
    // Check for performance fallback
    final bool useBlur = effectiveBlur > 0 && !AppTheme.shouldReduceMotion;

    Widget container = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: useBlur ? effectiveOpacity : 0.22),
        borderRadius: effectiveRadius,
        border: border ?? Border.all(
          color: AppTheme.moonlight.withValues(alpha: 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.deepRose.withValues(alpha: 0.05),
            blurRadius: 25,
            spreadRadius: -10,
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

