import 'dart:math';
import 'package:flutter/material.dart';

class CircuitryPainter extends CustomPainter {
  final Color color;
  final double opacity;

  CircuitryPainter({
    this.color = Colors.white,
    this.opacity = 0.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = Random(42); // Seeded for consistency
    
    for (int i = 0; i < 15; i++) {
      double startX = random.nextDouble() * size.width;
      double startY = random.nextDouble() * size.height;
      
      final path = Path()..moveTo(startX, startY);
      
      // Draw 3-5 connected segments
      for (int j = 0; j < 3 + random.nextInt(3); j++) {
        bool horizontal = random.nextBool();
        double length = 20.0 + random.nextDouble() * 50.0;
        
        if (horizontal) {
          startX += length * (random.nextBool() ? 1 : -1);
        } else {
          startY += length * (random.nextBool() ? 1 : -1);
        }
        
        path.lineTo(startX, startY);
        
        // Add a small node at the joint
        if (random.nextDouble() > 0.5) {
          canvas.drawCircle(Offset(startX, startY), 2.0, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
