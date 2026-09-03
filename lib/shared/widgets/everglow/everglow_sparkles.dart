import "dart:math";
import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_motion.dart";

/// Decorative sparkle/particle layer.
///
/// Replaces `_AnimeSparkles` and `PetalFieldPainter`.
/// `ExcludeSemantics` — purely decorative. Static when reduced.
///
/// Performance notes:
/// - Default [count] is 12 (was 20). Each sparkle is one canvas circle per
///   frame, so this halves the decorative fill cost on dashboards that stack
///   sparkles + background glows + glass cards. Pass an explicit count only
///   for hero moments; keep ambient instances at or below the default.
/// - The ticker now pauses when the app backgrounds ([WidgetsBindingObserver])
///   and when [TickerMode] is off (paused routes). Previously every mounted
///   sparkle layer repainted at 60fps even when its route was covered.
/// - Static fallback when [AppMotion.reduced]: paints once, no controller.
class EverglowSparkles extends StatefulWidget {
  final int count;
  final Color color;
  final double opacity;

  const EverglowSparkles({
    super.key,
    this.count = 12,
    this.color = AppColors.roseQuartz,
    this.opacity = 0.08,
  });

  @override
  State<EverglowSparkles> createState() => _EverglowSparklesState();
}

class _EverglowSparklesState extends State<EverglowSparkles>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _controller;
  late final List<_Sparkle> _sparkles;

  int get _cappedCount => widget.count.clamp(0, 24);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final rng = Random(42);
    _sparkles = List.generate(
      _cappedCount,
      (_) => _Sparkle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 2 + rng.nextDouble() * 4,
        phase: rng.nextDouble() * 2 * pi,
      ),
    );

    if (!AppMotion.reduced && _cappedCount > 0) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    if (state == AppLifecycleState.resumed) {
      if (!c.isAnimating) c.repeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      c.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No ticker (reduced motion or count 0): single static paint, zero
    // per-frame cost. TickerMode handles paused routes automatically since
    // the controller is driven by this State's TickerProvider.
    final animation = _controller ?? const AlwaysStoppedAnimation(0);
    return RepaintBoundary(
      child: TickerMode(
        enabled: _controller != null,
        child: Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: animation,
                builder: (_, _) => CustomPaint(
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
    if (sparkles.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in sparkles) {
      final twinkle = (sin(s.phase + time * 2 * pi) + 1) / 2;
      // Skip fully-faded sparkles instead of painting zero-alpha circles.
      if (twinkle <= 0.01) continue;
      paint.color = color.withValues(alpha: opacity * twinkle);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size * twinkle,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.time != time;
}