import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Draws an origami lucky star (wishing star) with 3D faceted folds,
/// radiant glowing halo, crisp creases, and a luminous starlight core.
void drawOrigamiStar(
  Canvas canvas, {
  required Color color,
  required double size,
  double opacity = 1.0,
  double glowIntensity = 1.0,
  double sparkle = 0.0,
}) {
  final effectiveOpacity = opacity.clamp(0.0, 1.0);
  if (effectiveOpacity <= 0.001) return;

  final outerRadius = size * 0.50;
  // Cute, plump ratio for origami lucky stars (valley at 52% of outer radius)
  final innerRadius = size * 0.26;
  final glowRadius = size * 1.25;

  // 1. Soft atmospheric luminous halo (celestial glow)
  if (glowIntensity > 0.05) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(
            alpha: (0.35 * glowIntensity * effectiveOpacity).clamp(0.0, 1.0),
          ),
          color.withValues(
            alpha: (0.12 * glowIntensity * effectiveOpacity).clamp(0.0, 1.0),
          ),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: glowRadius));
    canvas.drawCircle(Offset.zero, glowRadius, glowPaint);
  }

  // 2. Precalculate 5 tips and 5 valleys
  const points = 5;
  final tips = List<Offset>.generate(points, (i) {
    final a = -pi / 2 + i * 2 * pi / points;
    return Offset(cos(a) * outerRadius, sin(a) * outerRadius);
  });
  final valleys = List<Offset>.generate(points, (i) {
    final a = -pi / 2 + i * 2 * pi / points + pi / points;
    return Offset(cos(a) * innerRadius, sin(a) * innerRadius);
  });

  // 3. Draw 10 faceted triangles meeting at center (0, 0)
  // Simulated gentle directional light from top-left gives each fold tactile 3D volume.
  final facetPath = Path();
  final facetPaint = Paint()..style = PaintingStyle.fill;

  for (var i = 0; i < points; i++) {
    final tip = tips[i];
    final nextValley = valleys[i];
    final prevValley = valleys[(i - 1 + points) % points];

    final tipAngle = -pi / 2 + i * 2 * pi / points;
    final tipDirX = cos(tipAngle);
    final tipDirY = sin(tipAngle);
    // Light source from upper-left
    final lightDot = -0.5 * tipDirX - 0.7 * tipDirY;

    // Facet 1 (center -> tip -> next valley): softer side
    final f1Factor = (0.15 + lightDot * 0.18 - 0.10).clamp(-0.20, 0.35);
    final f1Color = f1Factor >= 0
        ? Color.lerp(color, AppColors.petalWhite, f1Factor)!
        : Color.lerp(color, AppColors.inkDeep, -f1Factor * 0.45)!;
    facetPaint.color = f1Color.withValues(alpha: effectiveOpacity);

    facetPath.reset();
    facetPath.moveTo(0, 0);
    facetPath.lineTo(tip.dx, tip.dy);
    facetPath.lineTo(nextValley.dx, nextValley.dy);
    facetPath.close();
    canvas.drawPath(facetPath, facetPaint);

    // Facet 2 (center -> prev valley -> tip): illuminated highlight side
    final f2Factor = (0.28 + lightDot * 0.20 + 0.12).clamp(-0.12, 0.45);
    final f2Color = f2Factor >= 0
        ? Color.lerp(color, AppColors.petalWhite, f2Factor)!
        : Color.lerp(color, AppColors.inkDeep, -f2Factor * 0.45)!;
    facetPaint.color = f2Color.withValues(alpha: effectiveOpacity);

    facetPath.reset();
    facetPath.moveTo(0, 0);
    facetPath.lineTo(prevValley.dx, prevValley.dy);
    facetPath.lineTo(tip.dx, tip.dy);
    facetPath.close();
    canvas.drawPath(facetPath, facetPaint);
  }

  // 4. Subtle crisp origami crease lines from center to each tip
  final creasePaint = Paint()
    ..color = AppColors.petalWhite.withValues(
      alpha: (0.32 * effectiveOpacity).clamp(0.0, 1.0),
    )
    ..strokeWidth = 0.65
    ..style = PaintingStyle.stroke;
  for (var i = 0; i < points; i++) {
    canvas.drawLine(Offset.zero, tips[i], creasePaint);
  }

  // 5. Luminous starlight center highlight / jewel gleam
  final coreRadius = size * 0.16;
  final corePaint = Paint()
    ..shader = RadialGradient(
      colors: [
        AppColors.petalWhite.withValues(
          alpha: (0.95 * effectiveOpacity).clamp(0.0, 1.0),
        ),
        color.withValues(alpha: (0.45 * effectiveOpacity).clamp(0.0, 1.0)),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: coreRadius));
  canvas.drawCircle(Offset.zero, coreRadius, corePaint);

  // Tiny crisp specular pinprick at the central apex
  canvas.drawCircle(
    Offset.zero,
    size * 0.05,
    Paint()
      ..color = AppColors.petalWhite.withValues(
        alpha: (0.90 * effectiveOpacity).clamp(0.0, 1.0),
      ),
  );

  // 6. Delicate 4-pointed sparkle glint (✦) when sparkling
  if (sparkle > 0.05) {
    final sparkleLen = size * 0.55 * sparkle;
    final sparkleWidth = size * 0.11 * sparkle;
    final sparklePaint = Paint()
      ..color = AppColors.petalWhite.withValues(
        alpha: (0.85 * sparkle * effectiveOpacity).clamp(0.0, 1.0),
      );

    final sparklePath = Path()
      ..moveTo(0, -sparkleLen)
      ..quadraticBezierTo(0, 0, sparkleWidth, 0)
      ..quadraticBezierTo(0, 0, 0, sparkleLen)
      ..quadraticBezierTo(0, 0, -sparkleWidth, 0)
      ..quadraticBezierTo(0, 0, 0, -sparkleLen)
      ..close();
    canvas.drawPath(sparklePath, sparklePaint);
  }
}

class StarWidget extends StatelessWidget {
  final Color color;
  final double size;
  final double rotation;
  final Animation<double>? animation;
  final Offset position;
  final double opacity;
  final double sparkle;

  const StarWidget({
    super.key,
    required this.color,
    this.size = 24,
    this.rotation = 0,
    this.animation,
    required this.position,
    this.opacity = 1.0,
    this.sparkle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SingleOrigamiStarPainter(
              color: color,
              size: size,
              rotation: rotation,
              sparkle: sparkle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleOrigamiStarPainter extends CustomPainter {
  final Color color;
  final double size;
  final double rotation;
  final double sparkle;

  const _SingleOrigamiStarPainter({
    required this.color,
    required this.size,
    required this.rotation,
    required this.sparkle,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.save();
    canvas.translate(canvasSize.width / 2, canvasSize.height / 2);
    canvas.rotate(rotation);
    drawOrigamiStar(
      canvas,
      color: color,
      size: size,
      opacity: 1.0,
      glowIntensity: 1.0,
      sparkle: sparkle,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SingleOrigamiStarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.size != size ||
      oldDelegate.rotation != rotation ||
      oldDelegate.sparkle != sparkle;
}
