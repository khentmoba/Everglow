import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'roaming_guardian_cat.dart';
import 'roaming_guardian_controller.dart';

/// Flat painted version of the Guardian used for the *behind* paint layer.
///
/// Platform views always composite above the CanvasKit surface, so the 3D
/// model can never be occluded by dashboard content. The sprite is a regular
/// Flutter widget, which means it genuinely walks behind cards and buttons,
/// while the 3D model takes over whenever the cat comes to the front.
Widget buildRoamingCatSprite(BuildContext context, RoamingCatFrame frame) {
  // Slightly translucent so the sprite reads as being in the background,
  // especially when it walks behind the dashboard's glass cards.
  return Opacity(
    opacity: 0.88,
    child: CustomPaint(
      painter: _RoamingCatSpritePainter(frame),
      child: const SizedBox.expand(),
    ),
  );
}

class _RoamingCatSpritePainter extends CustomPainter {
  _RoamingCatSpritePainter(this.frame);

  final RoamingCatFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final scale = s / 96;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(frame.facing * scale, scale);

    final held = frame.held;
    final hovered = frame.hovered;
    final bob = frame.bob * 0.7;
    final breath = frame.breath;
    final tailSway = math.sin(frame.activity == RoamingActivity.idle
            ? frame.elapsed * 2.0
            : frame.elapsed * 6.0) *
        (frame.moving ? 0.5 : 1.0);

    // Ground shadow.
    final shadowPaint = Paint()
      ..color = AppColors.inkDeep.withValues(alpha: held ? 0.5 : 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 34 + bob * 0.2),
        width: 44 * breath,
        height: 9,
      ),
      shadowPaint,
    );

    // Held glow.
    if (held) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.auroraRose.withValues(alpha: 0.30),
            AppColors.auroraRose.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 40));
      canvas.drawCircle(Offset.zero, 40, glowPaint);
    }

    canvas.translate(0, bob);

    // Tail.
    final tailPaint = Paint()
      ..color = AppColors.auroraRose.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final tailPath = Path()
      ..moveTo(-20, 14)
      ..cubicTo(-34, 8, -36 + tailSway * 4, -6, -28 + tailSway * 6, -16);
    canvas.drawPath(tailPath, tailPaint);

    // Body.
    final bodyPaint = Paint()..color = AppColors.auroraRose;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 16), width: 46, height: 40),
      bodyPaint,
    );
    final bellyPaint = Paint()..color = AppColors.petalWhite;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 22), width: 24, height: 22),
      bellyPaint,
    );

    // Head.
    final headPaint = Paint()..color = AppColors.petalWhite;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -12), width: 44, height: 40),
      headPaint,
    );

    // Ears.
    final earPaint = Paint()..color = AppColors.petalWhite;
    final innerEarPaint = Paint()..color = AppColors.auroraRose;
    final leftEar = Path()
      ..moveTo(-20, -26)
      ..lineTo(-8, -40)
      ..lineTo(-2, -26)
      ..close();
    final rightEar = Path()
      ..moveTo(20, -26)
      ..lineTo(8, -40)
      ..lineTo(2, -26)
      ..close();
    canvas.drawPath(leftEar, earPaint);
    canvas.drawPath(rightEar, earPaint);
    final leftInner = Path()
      ..moveTo(-17, -28)
      ..lineTo(-10, -36)
      ..lineTo(-6, -28)
      ..close();
    final rightInner = Path()
      ..moveTo(17, -28)
      ..lineTo(10, -36)
      ..lineTo(6, -28)
      ..close();
    canvas.drawPath(leftInner, innerEarPaint);
    canvas.drawPath(rightInner, innerEarPaint);

    // Face.
    final eyePaint = Paint()..color = AppColors.inkDeep;
    canvas.drawCircle(Offset(-11, -14), 3.2, eyePaint);
    canvas.drawCircle(Offset(11, -14), 3.2, eyePaint);
    final highlightPaint = Paint()..color = AppColors.petalWhite;
    canvas.drawCircle(Offset(-10, -15), 1.1, highlightPaint);
    canvas.drawCircle(Offset(12, -15), 1.1, highlightPaint);

    final nosePaint = Paint()..color = AppColors.deepRose;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -7), width: 5, height: 3.6),
        const Radius.circular(2),
      ),
      nosePaint,
    );

    final whiskerPaint = Paint()
      ..color = AppColors.twilight.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final side in [-1, 1]) {
      for (final dy in [-2.0, 1.0]) {
        canvas.drawLine(
          Offset(side * 9, -4 + dy),
          Offset(side * 20, -6 + dy * 1.4),
          whiskerPaint,
        );
      }
    }

    // Cheek blush.
    final blushPaint = Paint()..color = AppColors.auroraRose.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(-16, -4), 3, blushPaint);
    canvas.drawCircle(Offset(16, -4), 3, blushPaint);

    // Soft rim light when hovered, bright when picked up.
    if (held || hovered) {
      final rimPaint = Paint()
        ..color = AppColors.blushGold.withValues(alpha: held ? 0.75 : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = held ? 2.4 : 1.4;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -12), width: 46, height: 42),
        rimPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoamingCatSpritePainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
