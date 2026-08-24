import 'dart:math';
import 'package:flutter/material.dart';

class LilyPainter extends CustomPainter {
  final int stage;
  final double animationValue; // For breathing effect

  LilyPainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Draw Pot
    _drawPot(canvas, center, size, paint);

    // 2. Draw Plant based on stage
    if (stage >= 1) {
      _drawLily(canvas, center, size, paint);
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

  void _drawLily(Canvas canvas, Offset center, Size size, Paint paint) {
    final stemHeight = (stage * 20.0) + (animationValue * 5);
    final stemPath = Path();
    stemPath.moveTo(center.dx, center.dy);
    stemPath.quadraticBezierTo(
      center.dx + 10,
      center.dy - stemHeight / 2,
      center.dx,
      center.dy - stemHeight,
    );

    paint.color = Colors.green[300]!;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    canvas.drawPath(stemPath, paint);

    // Draw Leaves
    _drawLeaf(canvas, center.translate(5, -10), true, paint);
    if (stage >= 2) {
      _drawLeaf(canvas, center.translate(-5, -25), false, paint);
    }

    // Draw Bloom
    _drawBloom(canvas, Offset(center.dx, center.dy - stemHeight), paint);
  }

  void _drawLeaf(Canvas canvas, Offset pos, bool right, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = Colors.green[400]!;
    final path = Path();
    path.moveTo(pos.dx, pos.dy);
    if (right) {
      path.quadraticBezierTo(pos.dx + 20, pos.dy - 10, pos.dx + 5, pos.dy - 20);
    } else {
      path.quadraticBezierTo(pos.dx - 20, pos.dy - 10, pos.dx - 5, pos.dy - 20);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBloom(Canvas canvas, Offset top, Paint paint) {
    paint.style = PaintingStyle.fill;

    if (stage == 1) {
      // Small sprout/bud
      paint.color = Colors.green[200]!;
      canvas.drawCircle(top, 5, paint);
    } else if (stage <= 3) {
      // Closed Bud
      paint.color = Colors.pink[100]!;
      canvas.drawOval(
        Rect.fromCenter(center: top, width: 15, height: 25),
        paint,
      );
    } else {
      // Opening or Full Bloom
      final petalCount = stage == 4 ? 3 : 6;
      final petalSize = stage == 4 ? 20.0 : 35.0;

      paint.color = Colors.pink[200]!.withValues(alpha: 0.9);
      for (int i = 0; i < petalCount; i++) {
        final angle = (2 * pi / petalCount) * i;
        canvas.save();
        canvas.translate(top.dx, top.dy);
        canvas.rotate(angle);

        final petalPath = Path();
        petalPath.moveTo(0, 0);
        petalPath.quadraticBezierTo(
          petalSize / 2,
          -petalSize,
          0,
          -petalSize * 1.2,
        );
        petalPath.quadraticBezierTo(-petalSize / 2, -petalSize, 0, 0);

        // Add glow if stage 5
        if (stage == 5) {
          final glowPaint = Paint()
            ..color = Colors.pink[50]!.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          canvas.drawPath(petalPath, glowPaint);
        }

        canvas.drawPath(petalPath, paint);
        canvas.restore();
      }

      // Center of lily
      paint.color = Colors.yellow[200]!;
      canvas.drawCircle(top, 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LilyPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
