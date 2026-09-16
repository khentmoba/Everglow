import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_art.dart';

/// Hand-drawn rose for Khent's garden.
///
/// Stages: 0 = empty pot, 1 = sprout, 2-3 = bud, 4 = half bloom, 5 = full bloom.
/// Web-safe: glow is layered translucent circles, no blur filters.
/// Matches [LilyPainter]'s sway, stem height, and pot size so the two
/// sit evenly side by side in the dual-garden scene.
class RosePainter extends CustomPainter {
  final int stage;
  final double animationValue; // 0..1 breathing loop

  RosePainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    _drawPot(canvas, center, paint);

    if (stage >= 1) {
      _drawRose(canvas, center, paint);
    }
  }

  void _drawPot(Canvas canvas, Offset center, Paint paint) {
    final potWidth = 60.0 + (animationValue * 2);
    const potHeight = 40.0;
    final rect = Rect.fromCenter(
      center: center.translate(0, potHeight / 2),
      width: potWidth,
      height: potHeight,
    );

    // Soil the stem grows out of.
    paint
      ..shader = null
      ..color = AppArt.barkDeep.withValues(alpha: 0.9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + 2),
        width: rect.width * 0.8,
        height: 10,
      ),
      paint,
    );
    paint.color = AppArt.bark.withValues(alpha: 0.9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.center.dx - 3, rect.top + 1),
        width: rect.width * 0.5,
        height: 6,
      ),
      paint,
    );

    // Pot body with gradient.
    paint.color = AppColors.petalWhite;
    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppArt.rosePotLight, AppArt.rosePot],
    ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    // Soft side shade so the pot feels round.
    paint.shader = null;
    paint.color = AppArt.roseRim.withValues(alpha: 0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.right - rect.width * 0.28,
          rect.top + 4,
          rect.width * 0.28,
          rect.height - 4,
        ),
        const Radius.circular(6),
      ),
      paint,
    );

    // Rim + top light-catch.
    paint.color = AppArt.roseRim;
    final rim = Rect.fromLTWH(rect.left - 4, rect.top - 5, rect.width + 8, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rim, const Radius.circular(4)),
      paint,
    );
    paint.color = AppColors.petalWhite.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rim.left + 4, rim.top + 1.2, rim.width - 8, 1.6),
        const Radius.circular(0.8),
      ),
      paint,
    );
  }

  void _drawRose(Canvas canvas, Offset center, Paint paint) {
    // Same sway + height as the lily so both fit the 150px card.
    final sway = (animationValue - 0.5) * 5.0;
    final stemHeight = 20.0 + stage * 11.0 + animationValue * 3.0;
    final base = Offset(center.dx, center.dy);
    final top = Offset(center.dx + sway, center.dy - stemHeight);
    final control = Offset(
      center.dx + 6 + sway * 0.5,
      center.dy - stemHeight * 0.55,
    );

    _drawStem(canvas, base, control, top, paint);
    _drawThorns(canvas, base, control, top, paint);
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

    // Main stem — deeper green than the lily's, roses are woodier.
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = AppArt.stemDark;
    canvas.drawPath(path, paint);

    // Roundness highlight.
    final highlight = Path()
      ..moveTo(base.dx + 1.2, base.dy - 2)
      ..quadraticBezierTo(control.dx + 1.2, control.dy, top.dx + 0.8, top.dy);
    paint
      ..strokeWidth = 1.3
      ..color = AppArt.leaf.withValues(alpha: 0.85);
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

  /// Tangent angle of the stem curve at [t], so thorns stick out sideways.
  double _stemAngle(Offset base, Offset control, Offset top, double t) {
    final dx =
        2 * (1 - t) * (control.dx - base.dx) + 2 * t * (top.dx - control.dx);
    final dy =
        2 * (1 - t) * (control.dy - base.dy) + 2 * t * (top.dy - control.dy);
    return atan2(dy, dx);
  }

  void _drawThorns(
    Canvas canvas,
    Offset base,
    Offset control,
    Offset top,
    Paint paint,
  ) {
    if (stage < 2) return;
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppArt.stemDark.withValues(alpha: 0.9);
    // Small curved prickles, alternating sides, kept tiny at card size.
    const spots = [(0.30, 1.0), (0.48, -1.0), (0.63, 1.0)];
    for (final spot in spots) {
      final t = spot.$1;
      final side = spot.$2;
      if (stage < 4 && t > 0.5) continue;
      final pos = _stemPoint(base, control, top, t);
      final along = _stemAngle(base, control, top, t);
      final out = along + side * (pi / 2.4);
      final tip = pos + Offset(cos(out), sin(out)) * 4.2;
      final back = pos + Offset(cos(along), sin(along)) * 2.6;
      final thorn = Path()
        ..moveTo(pos.dx, pos.dy)
        ..quadraticBezierTo(
          pos.dx + cos(out) * 2.4,
          pos.dy + sin(out) * 2.4 - 0.6,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(back.dx, back.dy, pos.dx, pos.dy);
      canvas.drawPath(thorn, paint);
    }
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
      final length = (24.0 - i * 2.5) * (stage >= 4 ? 1.0 : 0.75);
      _drawRoseLeaf(canvas, pos, right, length, paint);
    }
  }

  /// Glossy oval rose leaf with a pointed tip, toothed hint, and veins.
  void _drawRoseLeaf(
    Canvas canvas,
    Offset pos,
    bool right,
    double length,
    Paint paint,
  ) {
    final dir = right ? 1.0 : -1.0;
    final tip = Offset(pos.dx + dir * length, pos.dy - length * 0.35 + 3);
    final width = length * 0.42;

    final leaf = Path()
      ..moveTo(pos.dx, pos.dy)
      ..cubicTo(
        pos.dx + dir * length * 0.35,
        pos.dy - width * 1.1,
        pos.dx + dir * length * 0.75,
        pos.dy - width * 0.9,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        pos.dx + dir * length * 0.7,
        pos.dy + width * 0.35,
        pos.dx + dir * length * 0.3,
        pos.dy + width * 0.4,
        pos.dx,
        pos.dy,
      );

    // Glossy body: deep base melting into a lighter tip.
    paint
      ..style = PaintingStyle.fill
      ..color = AppColors.petalWhite
      ..shader =
          const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [AppArt.stemDark, AppArt.leaf],
          ).createShader(
            Rect.fromCenter(center: pos, width: length, height: length * 0.9),
          );
    canvas.drawPath(leaf, paint);

    // Thin dark edge.
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppArt.stemDark.withValues(alpha: 0.7);
    canvas.drawPath(leaf, paint);

    // Center vein + two side veins.
    paint
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = AppColors.petalWhite.withValues(alpha: 0.5);
    final mid = Offset(
      pos.dx + (tip.dx - pos.dx) * 0.55,
      pos.dy + (tip.dy - pos.dy) * 0.55,
    );
    canvas.drawLine(pos, tip, paint);
    canvas.drawLine(mid, mid + Offset(dir * -5, -width * 0.5), paint);
    canvas.drawLine(mid, mid + Offset(dir * -4, width * 0.35), paint);

    // Gloss catch near the base.
    paint
      ..style = PaintingStyle.fill
      ..color = AppColors.petalWhite.withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx + dir * length * 0.3, pos.dy - width * 0.3),
        width: length * 0.32,
        height: width * 0.28,
      ),
      paint,
    );
  }

  void _drawBloom(Canvas canvas, Offset top, double sway, Paint paint) {
    if (stage == 1) {
      _drawSprout(canvas, top, paint);
    } else if (stage <= 3) {
      _drawBud(canvas, top, paint);
    } else if (stage == 4) {
      _drawHalfBloom(canvas, top, sway, paint);
    } else {
      _drawFullRose(canvas, top, sway, paint);
    }
  }

  void _drawSprout(Canvas canvas, Offset top, Paint paint) {
    paint
      ..style = PaintingStyle.fill
      ..shader = null;
    _drawRoseLeaf(canvas, top.translate(0, 4), true, 9, paint);
    _drawRoseLeaf(canvas, top.translate(0, 4), false, 9, paint);
    paint.color = AppArt.stemDark;
    canvas.drawCircle(top.translate(0, -2), 3, paint);
  }

  void _drawBud(Canvas canvas, Offset top, Paint paint) {
    final w = 12.0 + stage * 2.0;
    final h = 22.0 + stage * 3.0;

    // Long pointed sepals hugging the bud.
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppArt.stemDark;
    for (final dir in [-1.0, 0.0, 1.0]) {
      final sepal = Path()
        ..moveTo(top.dx, top.dy + 2)
        ..quadraticBezierTo(
          top.dx + dir * w * 0.7,
          top.dy - h * 0.3,
          top.dx + dir * w * (dir == 0 ? 0.1 : 0.55),
          top.dy - h * (dir == 0 ? 0.55 : 0.42),
        )
        ..quadraticBezierTo(
          top.dx + dir * w * 0.25,
          top.dy - h * 0.2,
          top.dx,
          top.dy + 2,
        );
      canvas.drawPath(sepal, paint);
    }

    // Plump teardrop bud: deep base melting into a glowing tip.
    final bud = Path()
      ..moveTo(top.dx, top.dy + 2)
      ..cubicTo(
        top.dx - w * 0.75,
        top.dy - h * 0.25,
        top.dx - w * 0.5,
        top.dy - h * 0.75,
        top.dx,
        top.dy - h + 4,
      )
      ..cubicTo(
        top.dx + w * 0.5,
        top.dy - h * 0.75,
        top.dx + w * 0.75,
        top.dy - h * 0.25,
        top.dx,
        top.dy + 2,
      );
    paint.color = AppColors.petalWhite;
    paint.shader =
        const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.rosePressed, AppColors.accentPink],
        ).createShader(
          Rect.fromCenter(
            center: top.translate(0, -h / 2),
            width: w,
            height: h,
          ),
        );
    canvas.drawPath(bud, paint);

    // Petal seams + highlight.
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1
      ..color = AppColors.roseDark.withValues(alpha: 0.5);
    for (final dx in [-w * 0.25, w * 0.25]) {
      canvas.drawLine(
        Offset(top.dx + dx * 0.4, top.dy - 2),
        Offset(top.dx + dx, top.dy - h * 0.7),
        paint,
      );
    }
    paint
      ..strokeWidth = 1.6
      ..color = AppColors.petalWhite.withValues(alpha: 0.65);
    canvas.drawArc(
      Rect.fromCenter(
        center: top.translate(-w * 0.14, -h / 2 + 4),
        width: w * 0.55,
        height: h * 0.7,
      ),
      pi * 0.9,
      pi * 0.7,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
  }

  /// Half-open rose: a goblet cup with petals unfurling over the rim
  /// and the swirl heart peeking out of the opening.
  void _drawHalfBloom(Canvas canvas, Offset top, double sway, Paint paint) {
    final breathe = 1.0 + animationValue * 0.04;
    final radius = 15.0 * breathe;
    final rimY = top.dy - radius * 1.0;

    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(sway * 0.012);
    canvas.translate(-top.dx, -top.dy);

    // Faint halo.
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.accentPink.withValues(alpha: 0.10);
    canvas.drawCircle(top.translate(0, -radius * 0.5), radius * 1.5, paint);

    // Sepals hugging the cup base.
    paint.color = AppArt.stemDark;
    for (final dir in [-1.0, 1.0]) {
      final sepal = Path()
        ..moveTo(top.dx, top.dy + 2)
        ..quadraticBezierTo(
          top.dx + dir * radius * 0.7,
          top.dy - radius * 0.1,
          top.dx + dir * radius * 0.55,
          top.dy - radius * 0.5,
        )
        ..quadraticBezierTo(
          top.dx + dir * radius * 0.35,
          top.dy - radius * 0.1,
          top.dx,
          top.dy + 2,
        );
      canvas.drawPath(sepal, paint);
    }

    // Goblet cup: deep base melting into a glowing rim.
    final cup = Path()
      ..moveTo(top.dx - radius * 0.55, top.dy + 2)
      ..cubicTo(
        top.dx - radius * 0.75,
        top.dy - radius * 0.4,
        top.dx - radius * 0.72,
        top.dy - radius * 0.8,
        top.dx - radius * 0.62,
        rimY,
      )
      ..quadraticBezierTo(
        top.dx,
        rimY - radius * 0.22,
        top.dx + radius * 0.62,
        rimY,
      )
      ..cubicTo(
        top.dx + radius * 0.72,
        top.dy - radius * 0.8,
        top.dx + radius * 0.75,
        top.dy - radius * 0.4,
        top.dx + radius * 0.55,
        top.dy + 2,
      )
      ..quadraticBezierTo(
        top.dx,
        top.dy + 5,
        top.dx - radius * 0.55,
        top.dy + 2,
      );
    paint.color = AppColors.petalWhite;
    paint.shader =
        const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.rosePressed, AppColors.accentPink],
        ).createShader(
          Rect.fromCenter(
            center: top.translate(0, -radius * 0.5),
            width: radius * 2,
            height: radius * 2,
          ),
        );
    canvas.drawPath(cup, paint);

    // Cup highlight on the left edge.
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = AppColors.petalWhite.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCenter(
        center: top.translate(-radius * 0.3, -radius * 0.4),
        width: radius * 0.7,
        height: radius * 1.2,
      ),
      pi * 0.8,
      pi * 0.8,
      false,
      paint,
    );

    // Dark opening inside the rim.
    paint.style = PaintingStyle.fill;
    paint.color = AppColors.roseDark;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(top.dx, rimY),
        width: radius * 1.1,
        height: radius * 0.34,
      ),
      paint,
    );

    // Three petals unfurling over the rim.
    for (final tilt in [-0.55, 0.0, 0.55]) {
      final h = radius * (tilt == 0.0 ? 0.85 : 0.65);
      final tipX = top.dx + tilt * radius * 1.1;
      final petal = Path()
        ..moveTo(top.dx - radius * 0.28, rimY)
        ..quadraticBezierTo(
          top.dx - radius * 0.3 + tilt * radius * 0.5,
          rimY - h,
          tipX,
          rimY - h,
        )
        ..quadraticBezierTo(
          top.dx + radius * 0.3 + tilt * radius * 0.5,
          rimY - h * 0.9,
          top.dx + radius * 0.28,
          rimY,
        )
        ..close();
      paint.color = AppColors.petalWhite;
      paint.shader =
          const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [AppColors.deepRose, AppColors.accentPink],
          ).createShader(
            Rect.fromCenter(
              center: Offset(top.dx, rimY - h / 2),
              width: radius,
              height: h,
            ),
          );
      canvas.drawPath(petal, paint);
      // Pale lip on the petal tip.
      paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = AppArt.rosePetalLight.withValues(alpha: 0.9);
      canvas.drawLine(
        Offset(tipX - radius * 0.18, rimY - h + 1),
        Offset(tipX + radius * 0.18, rimY - h + 1),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    // The swirl heart peeking out of the middle.
    _drawRoseHeart(canvas, Offset(top.dx, rimY - 1), radius * 0.26, paint);

    canvas.restore();
    paint.style = PaintingStyle.fill;
  }

  void _drawFullRose(Canvas canvas, Offset top, double sway, Paint paint) {
    final breathe = 1.0 + animationValue * 0.04;
    final radius = 22.0 * breathe;

    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(sway * 0.012);
    canvas.translate(-top.dx, -top.dy);

    // Warm halo (layered circles — cheap on web, no blur).
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.accentPink.withValues(alpha: 0.13);
    canvas.drawCircle(top, radius * 1.4, paint);
    paint.color = AppColors.roseQuartz.withValues(alpha: 0.10);
    canvas.drawCircle(top, radius * 1.05, paint);

    // Outer ring: 5 broad open petals, cupped with shaded bases.
    for (var i = 0; i < 5; i++) {
      final angle = (2 * pi / 5) * i - pi / 2 + 0.2;
      _drawOuterPetal(canvas, top, angle, radius, paint);
    }

    // Middle ring: 5 smaller petals, offset, brighter.
    for (var i = 0; i < 5; i++) {
      final angle = (2 * pi / 5) * i - pi / 2 + 0.2 + pi / 5;
      _drawMiddlePetal(canvas, top, angle, radius * 0.68, paint);
    }

    _drawRoseHeart(canvas, top, radius * 0.38, paint);

    // Dew sparkle on one outer petal.
    final sparklePos = top + Offset(radius * 0.62, -radius * 0.35);
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.petalWhite.withValues(
        alpha: 0.65 + animationValue * 0.3,
      );
    canvas.drawCircle(sparklePos, 1.4, paint);
    paint.color = AppColors.petalWhite.withValues(alpha: 0.35);
    canvas.drawCircle(sparklePos.translate(3.2, 2.6), 0.8, paint);

    canvas.restore();
    paint.style = PaintingStyle.fill;
  }

  /// One broad outer petal: shaded cup at the base, glowing curled rim.
  void _drawOuterPetal(
    Canvas canvas,
    Offset center,
    double angle,
    double radius,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + pi / 2);

    final w = radius * 0.62;
    final petal = Path()
      ..moveTo(0, 2)
      ..cubicTo(w, -radius * 0.25, w * 0.9, -radius * 0.75, 0, -radius)
      ..cubicTo(-w * 0.9, -radius * 0.75, -w, -radius * 0.25, 0, 2);

    // Soft offset shadow for depth.
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.roseDark.withValues(alpha: 0.35);
    canvas.drawPath(petal.shift(const Offset(1.4, 2.0)), paint);

    // Petal body: deep cup melting into a glowing rim.
    paint.color = AppColors.petalWhite;
    paint.shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        AppColors.rosePressed,
        AppColors.accentPink,
        AppArt.rosePetalLight,
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(-w, -radius, w * 2, radius));
    canvas.drawPath(petal, paint);

    // Curled rim light.
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.petalWhite.withValues(alpha: 0.7);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -radius * 0.82),
        width: w * 1.1,
        height: radius * 0.4,
      ),
      pi * 1.15,
      pi * 0.7,
      false,
      paint,
    );

    // Cup crease.
    paint
      ..strokeWidth = 1
      ..color = AppColors.roseDark.withValues(alpha: 0.45);
    canvas.drawLine(const Offset(0, -3), Offset(0, -radius * 0.5), paint);

    canvas.restore();
    paint.style = PaintingStyle.fill;
  }

  /// One middle petal: brighter, more upright, hugging the heart.
  void _drawMiddlePetal(
    Canvas canvas,
    Offset center,
    double angle,
    double radius,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + pi / 2);

    final w = radius * 0.66;
    final petal = Path()
      ..moveTo(0, 1)
      ..cubicTo(w, -radius * 0.3, w * 0.8, -radius * 0.7, 0, -radius)
      ..cubicTo(-w * 0.8, -radius * 0.7, -w, -radius * 0.3, 0, 1);

    paint
      ..style = PaintingStyle.fill
      ..color = AppColors.petalWhite
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [AppColors.deepRose, AppColors.accentPink],
      ).createShader(Rect.fromLTWH(-w, -radius, w * 2, radius));
    canvas.drawPath(petal, paint);

    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = AppArt.rosePetalLight.withValues(alpha: 0.8);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, -radius * 0.8),
        width: w,
        height: radius * 0.4,
      ),
      pi * 1.15,
      pi * 0.7,
      false,
      paint,
    );

    canvas.restore();
    paint.style = PaintingStyle.fill;
  }

  /// The signature rose swirl: dark cup with a light spiral unfolding.
  void _drawRoseHeart(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    // Cup.
    paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..color = AppColors.roseDark;
    canvas.drawCircle(center, radius, paint);
    paint.color = AppColors.deepRose;
    canvas.drawCircle(center, radius * 0.8, paint);

    // Spiral unfurling clockwise.
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = AppArt.rosePetalLight.withValues(alpha: 0.95);
    final spiral = Path();
    var a = -pi / 2;
    var r = radius * 0.12;
    spiral.moveTo(center.dx + cos(a) * r, center.dy + sin(a) * r);
    while (a < pi * 2.2) {
      a += 0.25;
      r += radius * 0.035;
      spiral.lineTo(center.dx + cos(a) * r, center.dy + sin(a) * r);
    }
    canvas.drawPath(spiral, paint);

    // Deep center + tiny light-catch.
    paint.style = PaintingStyle.fill;
    paint.color = AppColors.roseDark;
    canvas.drawCircle(center, radius * 0.22, paint);
    paint.color = AppColors.petalWhite.withValues(alpha: 0.9);
    canvas.drawCircle(center.translate(-1, -1), 0.8, paint);
  }

  @override
  bool shouldRepaint(covariant RosePainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
