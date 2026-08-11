import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

/// Decorative sparkle/particle layer.
///
/// Replaces `_AnimeSparkles` and `PetalFieldPainter`.
/// `ExcludeSemantics` — purely decorative. Static when reduced.
class EverglowSparkles extends StatefulWidget {
  final int count;
  final Color color;
  final double opacity;

  const EverglowSparkles({
    super.key,
    this.count = 20,
    this.color = AppColors.roseQuartz,
    this.opacity = 0.08,
  });

  @override
  State<EverglowSparkles> createState() => _EverglowSparklesState();
}

class _EverglowSparklesState extends State<EverglowSparkles>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _sparkles = List.generate(widget.count, (_) => _Sparkle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 2 + rng.nextDouble() * 4,
      phase: rng.nextDouble() * 2 * pi,
    ));

    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
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
      child: Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller ?? const AlwaysStoppedAnimation(0),
            builder: (_, __) => CustomPaint(
              painter: _SparklePainter(
                sparkles: _sparkles,
                color: widget.color,
                opacity: widget.opacity,
                time: _controller?.value ?? 0,
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Sparkle {
  final double x;
  final double y;
  final double size;
  final double phase;

  const _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });
}

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final Color color;
  final double opacity;
  final double time;

  _SparklePainter({
    required this.sparkles,
    required this.color,
    required this.opacity,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in sparkles) {
      final twinkle = (sin(s.phase + time * 2 * pi) + 1) / 2;
      paint.color = color.withValues(alpha: opacity * twinkle);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size * twinkle,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.time != time;
}
