import 'dart:math';
import 'package:flutter/material.dart';

class SunflowerPainter extends CustomPainter {
  final int stage;
  final double animationValue;

  SunflowerPainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    _drawPot(canvas, center, size, paint);

    if (stage >= 1) {
      _drawSunflower(canvas, center, size, paint);
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

    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA1887F), Color(0xFF8D6E63)],
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    paint.shader = null;
    paint.color = const Color(0xFF795548);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left - 4, rect.top - 5, rect.width + 8, 8),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _drawSunflower(Canvas canvas, Offset center, Size size, Paint paint) {
    final stemHeight = (stage * 22.0) + (animationValue * 5);
    final stemPath = Path();
    stemPath.moveTo(center.dx, center.dy);
    stemPath.quadraticBezierTo(
      center.dx + 5,
      center.dy - stemHeight / 2,
      center.dx,
      center.dy - stemHeight,
    );

    paint
      ..color = const Color(0xFF558B2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(stemPath, paint);

    // Leaves
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF7CB342);
    _drawLeaf(canvas, center.translate(6, -12), true, paint);
    if (stage >= 2) {
      _drawLeaf(canvas, center.translate(-6, -28), false, paint);
    }
    if (stage >= 3) {
      _drawLeaf(canvas, center.translate(5, -45), true, paint);
    }

    _drawBloom(canvas, Offset(center.dx, center.dy - stemHeight), paint);
  }

  void _drawLeaf(Canvas canvas, Offset pos, bool right, Paint paint) {
    final path = Path();
    path.moveTo(pos.dx, pos.dy);
    if (right) {
      path.quadraticBezierTo(pos.dx + 22, pos.dy - 12, pos.dx + 6, pos.dy - 22);
    } else {
      path.quadraticBezierTo(pos.dx - 22, pos.dy - 12, pos.dx - 6, pos.dy - 22);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBloom(Canvas canvas, Offset top, Paint paint) {
    paint.style = PaintingStyle.fill;

    if (stage == 1) {
      paint.color = Colors.green[300]!;
      canvas.drawCircle(top, 5, paint);
    } else if (stage <= 3) {
      // Budding head
      paint.color = const Color(0xFF9E9D24);
      canvas.drawCircle(top, stage == 2 ? 8 : 12, paint);
      // Green sepals
      paint.color = const Color(0xFF558B2F);
      for (int i = 0; i < 4; i++) {
        final angle = (pi / 2) * i;
        canvas.save();
        canvas.translate(top.dx, top.dy);
        canvas.rotate(angle);
        final sepalPath = Path();
        sepalPath.moveTo(0, 0);
        sepalPath.quadraticBezierTo(5, -10, 0, -14);
        sepalPath.quadraticBezierTo(-5, -10, 0, 0);
        canvas.drawPath(sepalPath, paint);
        canvas.restore();
      }
    } else {
      // Full sunflower
      final petalCount = stage == 4 ? 10 : 16;
      final petalSize = stage == 4 ? 16.0 : 24.0;

      // Outer petals (yellow)
      paint.color = const Color(0xFFFFD54F);
      for (int i = 0; i < petalCount; i++) {
        final angle = (2 * pi / petalCount) * i;
        canvas.save();
        canvas.translate(top.dx, top.dy);
        canvas.rotate(angle);

        final petalPath = Path();
        petalPath.moveTo(0, 0);
        petalPath.quadraticBezierTo(
          petalSize * 0.3,
          -petalSize * 0.6,
          0,
          -petalSize,
        );
        petalPath.quadraticBezierTo(-petalSize * 0.3, -petalSize * 0.6, 0, 0);
        canvas.drawPath(petalPath, paint);
        canvas.restore();
      }

      // Center disk (brown)
      final centerRadius = stage == 4 ? 10.0 : 14.0;
      paint.color = const Color(0xFF5D4037);
      canvas.drawCircle(top, centerRadius, paint);

      // Center seeds texture
      paint.color = const Color(0xFF795548);
      for (int i = 0; i < 8; i++) {
        final angle = (2 * pi / 8) * i;
        final dx = cos(angle) * centerRadius * 0.5;
        final dy = sin(angle) * centerRadius * 0.5;
        canvas.drawCircle(top.translate(dx, dy), 1.5, paint);
      }

      if (stage == 5) {
        final glowPaint = Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
        canvas.drawCircle(top, 20, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SunflowerPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
