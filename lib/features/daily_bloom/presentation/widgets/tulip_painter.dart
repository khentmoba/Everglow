import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TulipPainter extends CustomPainter {
  final int stage;
  final double animationValue;

  TulipPainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    _drawPot(canvas, center, size, paint);

    if (stage >= 1) {
      _drawTulip(canvas, center, size, paint);
    }
  }

  void _drawPot(Canvas canvas, Offset center, Size size, Paint paint) {
    final potWidth = 55.0 + (animationValue * 2);
    final potHeight = 38.0;
    final rect = Rect.fromCenter(
      center: center.translate(0, potHeight / 2),
      width: potWidth,
      height: potHeight,
    );

    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)],
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    paint.shader = null;
    paint.color = const Color(0xFF4FC3F7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left - 4, rect.top - 5, rect.width + 8, 8),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _drawTulip(Canvas canvas, Offset center, Size size, Paint paint) {
    final stemHeight = (stage * 20.0) + (animationValue * 4);
    final stemPath = Path();
    stemPath.moveTo(center.dx, center.dy);
    stemPath.quadraticBezierTo(
      center.dx + 3,
      center.dy - stemHeight / 2,
      center.dx,
      center.dy - stemHeight,
    );

    paint
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(stemPath, paint);

    // Long elegant leaf
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF81C784);
    _drawTulipLeaf(canvas, center.translate(3, -8), true, paint);
    if (stage >= 2) {
      _drawTulipLeaf(canvas, center.translate(-3, -22), false, paint);
    }

    _drawBloom(canvas, Offset(center.dx, center.dy - stemHeight), paint);
  }

  void _drawTulipLeaf(Canvas canvas, Offset pos, bool right, Paint paint) {
    final path = Path();
    path.moveTo(pos.dx, pos.dy);
    if (right) {
      path.quadraticBezierTo(pos.dx + 15, pos.dy - 15, pos.dx + 3, pos.dy - 28);
    } else {
      path.quadraticBezierTo(pos.dx - 15, pos.dy - 15, pos.dx - 3, pos.dy - 28);
    }
    path.quadraticBezierTo(
      right ? pos.dx + 2 : pos.dx - 2,
      pos.dy - 15,
      pos.dx,
      pos.dy,
    );
    canvas.drawPath(path, paint);
  }

  void _drawBloom(Canvas canvas, Offset top, Paint paint) {
    paint.style = PaintingStyle.fill;

    if (stage == 1) {
      paint.color = Colors.green[300]!;
      canvas.drawCircle(top, 4, paint);
    } else if (stage <= 3) {
      // Tulip bud — elongated
      paint.color = AppColors.accentPink;
      canvas.drawOval(
        Rect.fromCenter(
          center: top,
          width: 10,
          height: 18 + (stage * 2).toDouble(),
        ),
        paint,
      );
    } else {
      // Tulip cup bloom
      final cupWidth = stage == 4 ? 18.0 : 26.0;
      final cupHeight = stage == 4 ? 22.0 : 30.0;

      // Back petals (darker)
      paint.color = AppColors.deepRose;
      final backPath = Path();
      backPath.moveTo(top.dx - cupWidth / 2, top.dy);
      backPath.quadraticBezierTo(
        top.dx - cupWidth * 0.6,
        top.dy - cupHeight * 0.7,
        top.dx,
        top.dy - cupHeight,
      );
      backPath.quadraticBezierTo(
        top.dx + cupWidth * 0.6,
        top.dy - cupHeight * 0.7,
        top.dx + cupWidth / 2,
        top.dy,
      );
      backPath.close();
      canvas.drawPath(backPath, paint);

      // Front petals (lighter)
      paint.color = AppColors.accentPink;
      final frontPath = Path();
      frontPath.moveTo(top.dx - cupWidth * 0.4, top.dy);
      frontPath.quadraticBezierTo(
        top.dx - cupWidth * 0.3,
        top.dy - cupHeight * 0.5,
        top.dx,
        top.dy - cupHeight * 0.8,
      );
      frontPath.quadraticBezierTo(
        top.dx + cupWidth * 0.3,
        top.dy - cupHeight * 0.5,
        top.dx + cupWidth * 0.4,
        top.dy,
      );
      frontPath.close();
      canvas.drawPath(frontPath, paint);

      if (stage == 5) {
        final glowPaint = Paint()
          ..color = AppColors.accentPink.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(top.translate(0, -cupHeight / 2), 18, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TulipPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
