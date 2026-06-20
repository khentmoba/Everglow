import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

/// Unified atmospheric background for ALL screens.
///
/// Replaces both `GamifiedBackground` and `ShelfAtmosphericBackdrop`.
/// Provides radial glows over a dark base — "atmospheric, never flat."
///
/// Honors `AppMotion.reduced` — renders a static gradient when enabled.
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
        size: 0.85,
        opacity: 0.16,
      ),
      RadialGlow(
        color: AppColors.softLavender,
        alignment: Alignment(0.85, 0.95),
        size: 0.75,
        opacity: 0.10,
      ),
    ],
    this.showPetals = false,
  });

  /// Cinema/anime variant with darker glows.
  const EverglowBackground.cinema({
    super.key,
    this.baseColor = const Color(0xFF080810),
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

  @override
  State<EverglowBackground> createState() => _EverglowBackgroundState();
}

class _EverglowBackgroundState extends State<EverglowBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced && widget.showPetals) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            decoration: BoxDecoration(
              color: widget.baseColor,
              backgroundBlendMode: BlendMode.srcOver,
            ),
            child: Stack(
              children: [
                // Radial glows
                for (final g in widget.glows)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: g.alignment,
                          radius: g.size,
                          colors: [
                            g.color.withValues(alpha: g.opacity),
                            g.color.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                // Optional animated petal overlay (only when not reduced)
                if (widget.showPetals && _controller != null)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller!,
                      builder: (_, __) => CustomPaint(
                        painter: _PetalPainter(_controller!.value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Configuration for a single radial glow.
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

/// Subtle petal field painter (decorative only).
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
  bool shouldRepaint(covariant _PetalPainter old) =>
      old.progress != progress;
}
