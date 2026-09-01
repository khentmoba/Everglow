import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/theme/app_colors.dart';

class RosePainter extends CustomPainter {
  final int stage;
  final double animationValue;

  RosePainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    _drawPot(canvas, center, size, paint);

    if (stage >= 1) {
      _drawRose(canvas, center, size, paint);
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
      colors: [Color(0xFFE8B4B8), Color(0xFFD4899A)],
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    paint.shader = null;
    paint.color = const Color(0xFFC07080);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left - 4, rect.top - 5, rect.width + 8, 8),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _drawRose(Canvas canvas, Offset center, Size size, Paint paint) {
    final stemHeight = (stage * 20.0) + (animationValue * 5);
    final stemPath = Path();
    stemPath.moveTo(center.dx, center.dy);
    stemPath.cubicTo(
      center.dx + 8,
      center.dy - stemHeight * 0.3,
      center.dx - 5,
      center.dy - stemHeight * 0.6,
      center.dx + 2,
      center.dy - stemHeight,
    );

    paint
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(stemPath, paint);

    // Thorns
    if (stage >= 2) {
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF388E3C);
      _drawThorn(canvas, center.translate(6, -15), true, paint);
      _drawThorn(canvas, center.translate(-3, -30), false, paint);
    }

    // Leaves
    _drawLeaf(canvas, center.translate(5, -10), true, paint);
    if (stage >= 3) {
      _drawLeaf(canvas, center.translate(-5, -25), false, paint);
    }

    _drawBloom(canvas, Offset(center.dx + 2, center.dy - stemHeight), paint);
  }

  void _drawThorn(Canvas canvas, Offset pos, bool right, Paint paint) {
    final path = Path();
    path.moveTo(pos.dx, pos.dy);
    if (right) {
      path.lineTo(pos.dx + 6, pos.dy - 3);
    } else {
      path.lineTo(pos.dx - 6, pos.dy - 3);
    }
    path.lineTo(pos.dx, pos.dy - 6);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawLeaf(Canvas canvas, Offset pos, bool right, Paint paint) {
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF66BB6A);
    final path = Path();
    path.moveTo(pos.dx, pos.dy);
    if (right) {
      path.quadraticBezierTo(pos.dx + 18, pos.dy - 8, pos.dx + 5, pos.dy - 18);
    } else {
      path.quadraticBezierTo(pos.dx - 18, pos.dy - 8, pos.dx - 5, pos.dy - 18);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawBloom(Canvas canvas, Offset top, Paint paint) {
    paint.style = PaintingStyle.fill;

    if (stage == 1) {
      paint.color = Colors.green[300]!;
      canvas.drawCircle(top, 4, paint);
    } else if (stage <= 3) {
      // Rose bud
      paint.color = const Color(0xFFE57373);
      canvas.drawOval(
        Rect.fromCenter(center: top, width: 12, height: 20),
        paint,
      );
      // Sepals
      paint.color = const Color(0xFF4CAF50);
      canvas.drawOval(
        Rect.fromCenter(center: top.translate(0, 8), width: 8, height: 6),
        paint,
      );
    } else {
      // Rose bloom — concentric petals
      final layers = stage == 4 ? 2 : 4;
      final baseSize = stage == 4 ? 14.0 : 22.0;

      for (int layer = layers - 1; layer >= 0; layer--) {
        final layerSize = baseSize - (layer * 3);
        final petalCount = 5 + layer;
        final layerAlpha = (0.6 + layer * 0.1).clamp(0.0, 1.0);

        paint.color = Color.lerp(
          const Color(0xFFEF5350),
          AppColors.accentPink,
          layer / layers,
        )!.withValues(alpha: layerAlpha);

        for (int i = 0; i < petalCount; i++) {
          final angle = (2 * pi / petalCount) * i + (layer * 0.3);
          canvas.save();
          canvas.translate(top.dx, top.dy);
          canvas.rotate(angle);

          final petalPath = Path();
          petalPath.moveTo(0, 0);
          petalPath.quadraticBezierTo(
            layerSize * 0.4,
            -layerSize * 0.7,
            0,
            -layerSize,
          );
          petalPath.quadraticBezierTo(-layerSize * 0.4, -layerSize * 0.7, 0, 0);
          canvas.drawPath(petalPath, paint);
          canvas.restore();
        }
      }

      // Center
      paint.color = const Color(0xFFFFCDD2);
      canvas.drawCircle(top, 3, paint);

      // Glow for stage 5
      if (stage == 5) {
        final glowPaint = Paint()
          ..color = AppColors.accentPink.withValues(alpha: 0.3)
          ..maskFilter = kIsWeb ? null : const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(top, 15, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RosePainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
