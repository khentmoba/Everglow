import 'dart:math';
import 'package:flutter/material.dart';

class PetalFieldPainter extends CustomPainter {
  final Color color;
  final double opacity;

  PetalFieldPainter({
    required this.color,
    this.opacity = 0.08,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(1337); // Consistent seed for design
    
    // Draw 35 organic petal/sparkle shapes drifting subtly
    for (int i = 0; i < 35; i++) {
      final double cx = random.nextDouble() * size.width;
      final double cy = random.nextDouble() * size.height;
      final double scale = 4.0 + random.nextDouble() * 10.0;
      final double rotation = random.nextDouble() * pi * 2;
      
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (0.3 + random.nextDouble() * 0.7))
        ..style = PaintingStyle.fill;
        
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotation);
      
      // Draw a sleek almond/petal shape
      final path = Path()
        ..moveTo(0, -scale)
        ..quadraticBezierTo(scale * 0.6, -scale * 0.5, 0, scale)
        ..quadraticBezierTo(-scale * 0.6, -scale * 0.5, 0, -scale)
        ..close();
        
      canvas.drawPath(path, paint);
      
      // Draw an inner glowing core/sparkle for a premium look
      if (random.nextDouble() > 0.6) {
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 1.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(const Offset(0, 0), scale * 0.25, glowPaint);
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
