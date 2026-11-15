import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

class EverglowBackground extends StatefulWidget {
  final Color baseColor;
  final List<RadialGlow> glows;
  final bool showPetals;

  const EverglowBackground({
    super.key,
    this.baseColor = AppColors.twilight,
    this.glows = const [
      RadialGlow(
        color: AppColors.deepRose,
        alignment: Alignment(-0.7, -0.85),
        size: 0.80,
        opacity: 0.06,
      ),
      RadialGlow(
        color: AppColors.softLavender,
        alignment: Alignment(0.85, 0.95),
        size: 0.70,
        opacity: 0.06,
      ),
    ],
    this.showPetals = false,
  });

  const EverglowBackground.cinema({
    super.key,
    this.baseColor = AppColors.animeBackground,
    this.glows = const [
      RadialGlow(
        color: AppColors.deepRose,
        alignment: Alignment(-0.8, -0.9),
        size: 0.7,
        opacity: 0.12,
      ),
      RadialGlow(
        color: AppColors.softLavender,
        alignment: Alignment(0.9, 0.8),
        size: 0.65,
        opacity: 0.08,
      ),
    ],
    this.showPetals = false,
  });

  static Rect glowRect(RadialGlow glow, Size size) {
    final radius = glow.size * math.min(size.width, size.height);
    final center = glow.alignment.withinRect(Offset.zero & size);
    return Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );
  }

  static Decoration glowDecoration(RadialGlow glow) => BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 0.5,
      colors: [
        glow.color.withValues(alpha: glow.opacity),
        glow.color.withValues(alpha: 0),
      ],
      stops: const [0.0, 1.0],
    ),
  );

  @override
  State<EverglowBackground> createState() => _EverglowBackgroundState();
}

class _EverglowBackgroundState extends State<EverglowBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.showPetals) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant EverglowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPetals && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      );
    }
    _syncMotion();
  }

  void _syncMotion() {
    if (!widget.showPetals ||
        AppMotion.reduceAmbientMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller?.stop();
    } else if (!(_controller?.isAnimating ?? true)) {
      _controller?.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Container(
              decoration: BoxDecoration(
                color: widget.baseColor,
                backgroundBlendMode: BlendMode.srcOver,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return Stack(
                    children: [
                      for (final g in widget.glows)
                        Positioned.fromRect(
                          rect: EverglowBackground.glowRect(g, size),
                          child: DecoratedBox(
                            decoration: EverglowBackground.glowDecoration(g),
                          ),
                        ),
                      if (widget.showPetals &&
                          !AppMotion.reduced &&
                          _controller != null)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _controller!,
                            builder: (_, _) => CustomPaint(
                              painter: _PetalPainter(_controller!.value),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RadialGlow {
  final Color color;
  final Alignment alignment;
  final double size;
  final double opacity;

  const RadialGlow({
    required this.color,
    required this.alignment,
    this.size = 0.8,
    this.opacity = 0.15,
  });
}

class _PetalPainter extends CustomPainter {
  final double progress;
  _PetalPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.roseQuartz.withValues(alpha: 0.06);
    for (int i = 0; i < 12; i++) {
      final x = (i * 73.0 + progress * 40) % size.width;
      final y = (i * 137.0 + progress * 30) % size.height;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 8, height: 14),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter old) => old.progress != progress;
}
