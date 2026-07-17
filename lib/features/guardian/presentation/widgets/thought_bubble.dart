import 'package:flutter/material.dart';

class ThoughtBubble extends StatelessWidget {
  final String message;

  const ThoughtBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 150),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.pink[100]!.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.pink[400],
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            // Triangle tail
            Positioned(
              bottom: -25,
              right: 20,
              child: CustomPaint(
                painter: TrianglePainter(color: Colors.white.withValues(alpha: 0.9)),
                size: const Size(15, 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
