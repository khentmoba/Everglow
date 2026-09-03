import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
          color: AppColors.petalWhite.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: AppColors.petalWhite, width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.deepRose,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            // Triangle tail
            Positioned(
              bottom: -25,
              right: 20,
              child: CustomPaint(
                painter: TrianglePainter(
                  color: AppColors.petalWhite.withValues(alpha: 0.92),
                ),
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
