import 'dart:math';
import 'package:flutter/material.dart';

class SakuraPainter extends CustomPainter {
  final int stage;
  final double animationValue;

  SakuraPainter({required this.stage, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.8);
    final paint = Paint()..style = PaintingStyle.fill;

    _drawPot(canvas, center, size, paint);

    if (stage >= 1) {
      _drawTree(canvas, center, size, paint);
    }
  }

  void _drawPot(Canvas canvas, Offset center, Size size, Paint paint) {
    final potWidth = 65.0 + (animationValue * 2);
    final potHeight = 40.0;
    final rect = Rect.fromCenter(
      center: center.translate(0, potHeight / 2),
      width: potWidth,
      height: potHeight,
    );

    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    paint.shader = null;
    paint.color = const Color(0xFF8D6E63);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left - 4, rect.top - 5, potWidth + 8, 8),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _drawTree(Canvas canvas, Offset center, Size size, Paint paint) {
    final trunkHeight = (stage * 18.0) + (animationValue * 4);

    // Main trunk
    paint
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final trunkPath = Path();
    trunkPath.moveTo(center.dx, center.dy);
    trunkPath.cubicTo(
      center.dx + 8,
      center.dy - trunkHeight * 0.3,
      center.dx - 5,
      center.dy - trunkHeight * 0.6,
      center.dx + 3,
      center.dy - trunkHeight,
    );
    canvas.drawPath(trunkPath, paint);

    // Branches (stage 2+)
    if (stage >= 2) {
      paint.strokeWidth = 3;
      final branchBase = Offset(center.dx + 3, center.dy - trunkHeight);

      // Right branch
      final rightBranch = Path();
      rightBranch.moveTo(branchBase.dx, branchBase.dy);
      rightBranch.quadraticBezierTo(
        branchBase.dx + 20,
        branchBase.dy - 10,
        branchBase.dx + 30,
        branchBase.dy - 20,
      );
      canvas.drawPath(rightBranch, paint);

      // Left branch
      final leftBranch = Path();
      leftBranch.moveTo(branchBase.dx, branchBase.dy);
      leftBranch.quadraticBezierTo(
        branchBase.dx - 18,
        branchBase.dy - 12,
        branchBase.dx - 28,
        branchBase.dy - 18,
      );
      canvas.drawPath(leftBranch, paint);

      if (stage >= 3) {
        // Sub-branches
        paint.strokeWidth = 2;
        final rightSub = Path();
        rightSub.moveTo(branchBase.dx + 15, branchBase.dy - 10);
        rightSub.quadraticBezierTo(
          branchBase.dx + 25,
          branchBase.dy - 25,
          branchBase.dx + 22,
          branchBase.dy - 35,
        );
        canvas.drawPath(rightSub, paint);

        final leftSub = Path();
        leftSub.moveTo(branchBase.dx - 12, branchBase.dy - 10);
        leftSub.quadraticBezierTo(
          branchBase.dx - 22,
          branchBase.dy - 22,
          branchBase.dx - 20,
          branchBase.dy - 32,
        );
        canvas.drawPath(leftSub, paint);
      }
    }

    // Blossoms (stage 3+)
    if (stage >= 3) {
      final branchTop = Offset(center.dx + 3, center.dy - trunkHeight);
      final blossomPositions = <Offset>[
        branchTop,
        branchTop.translate(28, -18),
        branchTop.translate(-26, -16),
      ];

      if (stage >= 4) {
        blossomPositions.addAll([
          branchTop.translate(20, -33),
          branchTop.translate(-18, -30),
        ]);
      }

      if (stage >= 5) {
        blossomPositions.addAll([
          branchTop.translate(0, -10),
          branchTop.translate(15, -5),
          branchTop.translate(-12, -8),
        ]);
      }

      for (final pos in blossomPositions) {
        _drawBlossom(canvas, pos, paint, stage >= 5 ? 8 : 6);
      }

      if (stage == 5) {
        // Falling petals effect
        final glowPaint = Paint()
          ..color = const Color(0xFFF8BBD0).withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
        canvas.drawCircle(branchTop.translate(5, -15), 35, glowPaint);
      }
    }
  }

  void _drawBlossom(Canvas canvas, Offset center, Paint paint, double size) {
    const petalCount = 5;
    final petalColor = const Color(0xFFF8BBD0);

    for (int i = 0; i < petalCount; i++) {
      final angle = (2 * pi / petalCount) * i;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      paint.color = petalColor;
      final petalPath = Path();
      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(size * 0.4, -size * 0.6, 0, -size);
      petalPath.quadraticBezierTo(-size * 0.4, -size * 0.6, 0, 0);
      canvas.drawPath(petalPath, paint);
      canvas.restore();
    }

    // Center pistil
    paint.color = const Color(0xFFE91E63);
    canvas.drawCircle(center, 2, paint);
  }

  @override
  bool shouldRepaint(covariant SakuraPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.animationValue != animationValue;
  }
}
