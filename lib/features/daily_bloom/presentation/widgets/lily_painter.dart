import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Hand-drawn lily for Clair's garden.
///
/// Stages: 0 = empty pot, 1 = sprout, 2-3 = bud, 4 = half bloom, 5 = full bloom.
/// Web-safe: glow is layered translucent circles, no blur filters.
class LilyPainter extends CustomPainter {
  final int stage;
  final double animationValue; // 0..1 breathing loop

  LilyPainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Draw Pot (unchanged — flower is the focus)
    _drawPot(canvas, center, size, paint);

    // 2. Draw Plant based on stage
    if (stage >= 1) {
      _drawLily(canvas, center, paint);
    }
  }

  void _drawPot(Canvas canvas, Offset center, Size size, Paint paint) {
    final potWidth = 60.0 + (animationValue * 2);
    final potHeight = 40.0;
    final rect = Rect.fromCenter(
      center: center.translate(0, potHeight / 2),
      width: potWidth,
      height: potHeight,
    );

    // Soft pink pot with gradient
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.pink[100]!, Colors.pink[200]!],
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    // Pot rim
    paint.shader = null;
    paint.color = Colors.pink[300]!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left - 4, rect.top - 5, rect.width + 8, 8),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _drawLily(Canvas canvas, Offset center, Paint paint) {
    // Gentle sway + breathing. Keeps the bloom inside a 150px card.
    final sway = (animationValue - 0.5) * 5.0;
    final stemHeight = 20.0 + stage * 11.0 + animationValue * 3.0;
    final base = Offset(center.dx, center.dy);
    final top = Offset(center.dx + sway, center.dy - stemHeight);
    final control = Offset(
      center.dx + 6 + sway * 0.5,
      center.dy - stemHeight * 0.55,
    );

    _drawStem(canvas, base, control, top, paint);
    _drawLeaves(canvas, base, control, top, paint);
    _drawBloom(canvas, top, sway, paint);
  }

  void _drawStem(
    Canvas canvas,
    Offset base,
    Offset control,
    Offset top,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(control.dx, control.dy, top.dx, top.dy);

    // Main stem
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = AppColors.cinemaGreen;
    canvas.drawPath(path, paint);

    // Soft highlight so the stem feels round, not flat
    final highlight = Path()
      ..moveTo(base.dx + 1.2, base.dy - 2)
      ..quadraticBezierTo(control.dx + 1.2, control.dy, top.dx + 0.8, top.dy);
    paint
      ..strokeWidth = 1.3
      ..color = AppColors.cinemaMatch.withValues(alpha: 0.8);
    canvas.drawPath(highlight, paint);
  }

  /// Point on the quadratic stem curve at [t] (0 = base, 1 = bloom).
  Offset _stemPoint(Offset base, Offset control, Offset top, double t) {
    final u = 1 - t;
    return Offset(
      u * u * base.dx + 2 * u * t * control.dx + t * t * top.dx,
      u * u * base.dy + 2 * u * t * control.dy + t * t * top.dy,
    );
  }

  void _drawLeaves(
    Canvas canvas,
    Offset base,
    Offset control,
    Offset top,
    Paint paint,
  ) {
    // More leaves as the plant grows: 1 → 4.
    final count = stage.clamp(1, 4);
    const fractions = [0.22, 0.42, 0.58, 0.72];
    for (var i = 0; i < count; i++) {
      final t = fractions[i];
      final pos = _stemPoint(base, control, top, t);
      final right = i.isEven;
      // Lower leaves are longer; upper leaves stay small.
      final length = (26.0 - i * 3.0) * (stage >= 4 ? 1.0 : 0.75);
      _drawLanceLeaf(canvas, pos, right, length, paint);
    }
  }

  /// Long lily leaf with a pointed tip, soft edge, and center vein.
  void _drawLanceLeaf(
    Canvas canvas,
    Offset pos,
    bool right,
    double length,
    Paint paint,
  ) {
    final dir = right ? 1.0 : -1.0;
    final tip = Offset(pos.dx + dir * length, pos.dy - length * 0.45 + 4);
    final width = length * 0.28;

    final leaf = Path()
      ..moveTo(pos.dx, pos.dy)
      ..quadraticBezierTo(
        pos.dx + dir * length * 0.5,
        pos.dy - width,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        pos.dx + dir * length * 0.45,
        pos.dy + width * 0.5,
        pos.dx,
        pos.dy,
      );

    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.cinemaMatch;
    canvas.drawPath(leaf, paint);

    // Edge
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.cinemaGreen.withValues(alpha: 0.6);
    canvas.drawPath(leaf, paint);

    // Vein
    paint
      ..strokeWidth = 1
      ..color = AppColors.petalWhite.withValues(alpha: 0.55);
    canvas.drawLine(pos, tip, paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawBloom(Canvas canvas, Offset top, double sway, Paint paint) {
    if (stage == 1) {
      _drawSprout(canvas, top, paint);
    } else if (stage <= 3) {
      _drawBud(canvas, top, paint);
    } else {
      _drawOpenLily(canvas, top, sway, paint);
    }
  }

  void _drawSprout(Canvas canvas, Offset top, Paint paint) {
    paint
      ..style = PaintingStyle.fill
      ..shader = null;
    // Two tiny leaves + a tip dot instead of a flat circle.
    _drawLanceLeaf(canvas, top.translate(0, 4), true, 10, paint);
    _drawLanceLeaf(canvas, top.translate(0, 4), false, 10, paint);
    paint.color = AppColors.cinemaGreen;
    canvas.drawCircle(top.translate(0, -2), 3, paint);
  }

  void _drawBud(Canvas canvas, Offset top, Paint paint) {
    final w = 11.0 + stage * 2.0;
    final h = 20.0 + stage * 3.0;
    final rect = Rect.fromCenter(
      center: top.translate(0, -h / 2 + 4),
      width: w,
      height: h,
    );

    // Sepals hugging the base
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.cinemaGreen;
    for (final dir in [-1.0, 1.0]) {
      final sepal = Path()
        ..moveTo(top.dx, top.dy + 2)
        ..quadraticBezierTo(
          top.dx + dir * w * 0.6,
          top.dy - h * 0.25,
          top.dx + dir * w * 0.35,
          top.dy - h * 0.45,
        )
        ..quadraticBezierTo(
          top.dx + dir * w * 0.2,
          top.dy - h * 0.2,
          top.dx,
          top.dy + 2,
        );
      canvas.drawPath(sepal, paint);
    }

    // Teardrop bud: pale base melting into a rosy tip.
    final bud = Path()
      ..moveTo(top.dx, top.dy + 2)
      ..cubicTo(
        top.dx - w * 0.7,
        top.dy - h * 0.25,
        top.dx - w * 0.45,
        top.dy - h * 0.75,
        top.dx,
        top.dy - h + 4,
      )
      ..cubicTo(
        top.dx + w * 0.45,
        top.dy - h * 0.75,
        top.dx + w * 0.7,
        top.dy - h * 0.25,
        top.dx,
        top.dy + 2,
      );
    // NOTE: reset color to opaque — a translucent color would dim the shader.
    paint.color = AppColors.petalWhite;
    paint.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [AppColors.roseQuartz, AppColors.auroraRose],
    ).createShader(rect);
    canvas.drawPath(bud, paint);

    // Highlight + blushing tip
    paint.shader = null;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = AppColors.petalWhite.withValues(alpha: 0.7);
    canvas.drawArc(
      Rect.fromCenter(
        center: top.translate(-w * 0.12, -h / 2 + 4),
        width: w * 0.6,
        height: h * 0.7,
      ),
      pi * 0.9,
      pi * 0.7,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
    paint.color = AppColors.deepRose.withValues(alpha: stage == 3 ? 0.75 : 0.4);
    canvas.drawCircle(top.translate(0, -h + 5), stage == 3 ? 2.4 : 1.8, paint);
  }

  void _drawOpenLily(Canvas canvas, Offset top, double sway, Paint paint) {
    final full = stage >= 5;
    final breathe = 1.0 + animationValue * 0.04;
    final length = (full ? 32.0 : 23.0) * breathe;
    final width = full ? 14.5 : 12.0;

    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(sway * 0.012);
    canvas.translate(-top.dx, -top.dy);

    // Soft halo (layered circles — cheap on web, no blur).
    if (full) {
      paint
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = AppColors.auroraRose.withValues(alpha: 0.13);
      canvas.drawCircle(top, length * 1.15, paint);
      paint.color = AppColors.petalWhite.withValues(alpha: 0.08);
      canvas.drawCircle(top, length * 0.85, paint);
    }

    // Six bright tepals; depth comes from a soft offset shadow.
    for (var i = 0; i < 6; i++) {
      _drawPetal(canvas, top, i, length, width, paint);
    }

    _drawHeart(canvas, top, full, paint);
    canvas.restore();
  }

  void _drawPetal(
    Canvas canvas,
    Offset top,
    int index,
    double length,
    double width,
    Paint paint,
  ) {
    final angle = (2 * pi / 6) * index;
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(angle);

    // Elongated petal with a softly recurved tip.
    final petal = Path()
      ..moveTo(0, -2)
      ..cubicTo(
        width * 0.75,
        -length * 0.3,
        width * 0.62,
        -length * 0.72,
        1.2,
        -length,
      )
      ..cubicTo(
        -width * 0.62,
        -length * 0.72,
        -width * 0.75,
        -length * 0.3,
        0,
        -2,
      );

    // Soft offset shadow for depth (cheap, web-safe).
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.deepRose.withValues(alpha: 0.28);
    canvas.drawPath(petal.shift(const Offset(1.6, 2.4)), paint);

    // Bright petal: white throat melting into a rosy tip.
    // NOTE: reset color to opaque — a translucent color would dim the shader.
    paint.color = AppColors.petalWhite;
    paint.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        AppColors.petalWhite,
        AppColors.roseQuartz,
        AppColors.auroraRose,
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(-width, -length, width * 2, length));
    canvas.drawPath(petal, paint);

    // Thin rosy edge
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.deepRose.withValues(alpha: 0.3);
    canvas.drawPath(petal, paint);

    // Pale throat stripe fading toward the tip
    paint
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.petalWhite.withValues(alpha: 0.75);
    canvas.drawLine(const Offset(0, -5), Offset(0, -length * 0.55), paint);
    paint
      ..strokeWidth = 1
      ..color = AppColors.blushGold.withValues(alpha: 0.8);
    canvas.drawLine(const Offset(0, -5), Offset(0, -length * 0.7), paint);

    // Tiny lily speckles near the throat
    paint.style = PaintingStyle.fill;
    paint.color = AppColors.deepRose.withValues(alpha: 0.5);
    canvas.drawCircle(const Offset(-2.5, -9), 0.9, paint);
    canvas.drawCircle(const Offset(2.2, -12), 0.9, paint);
    canvas.drawCircle(const Offset(-1.5, -15), 0.8, paint);

    canvas.restore();
    paint.style = PaintingStyle.fill;
  }

  /// Golden throat, six stamens, and a blushing pistil.
  void _drawHeart(Canvas canvas, Offset top, bool full, Paint paint) {
    paint
      ..style = PaintingStyle.fill
      ..shader = null;

    // Throat
    paint.color = AppColors.auroraGold.withValues(alpha: 0.95);
    canvas.drawCircle(top, full ? 5.5 : 4.2, paint);
    paint.color = AppColors.warmAmber.withValues(alpha: 0.9);
    canvas.drawCircle(top, full ? 3.0 : 2.2, paint);

    // Six stamens peeking between the petals
    final count = full ? 6 : 3;
    for (var i = 0; i < count; i++) {
      final angle = (2 * pi / count) * i + pi / 6;
      final len = (full ? 11.0 : 8.0) + (i % 2) * 2.0;
      final tip = Offset(
        top.dx + cos(angle) * len,
        top.dy + sin(angle) * len * 0.9 - 1,
      );
      // Filament
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.petalWhite.withValues(alpha: 0.95);
      canvas.drawLine(top, tip, paint);
      // Anther
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(angle + pi / 2);
      paint.style = PaintingStyle.fill;
      paint.color = AppColors.warmAmber;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2.6, -1.4, 5.2, 2.8),
          const Radius.circular(1.4),
        ),
        paint,
      );
      paint.color = AppColors.deepRose.withValues(alpha: 0.7);
      canvas.drawCircle(const Offset(0, 0), 0.9, paint);
      canvas.restore();
    }

    // Pistil heart
    paint
      ..style = PaintingStyle.fill
      ..color = AppColors.deepRose;
    canvas.drawCircle(top, 2.1, paint);
    paint.color = AppColors.petalWhite.withValues(alpha: 0.9);
    canvas.drawCircle(top.translate(-0.6, -0.6), 0.7, paint);
  }

  @override
  bool shouldRepaint(covariant LilyPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
