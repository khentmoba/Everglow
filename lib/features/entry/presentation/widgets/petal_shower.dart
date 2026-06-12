import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';

class PetalShower extends StatefulWidget {
  final bool isVisible;

  const PetalShower({super.key, required this.isVisible});

  @override
  State<PetalShower> createState() => _PetalShowerState();
}

class _PetalShowerState extends State<PetalShower> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Petal> _petals = [];
  final int _petalCount = 30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    for (int i = 0; i < _petalCount; i++) {
      _petals.add(Petal());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: PetalPainter(_petals, _controller.value),
        );
      },
    );
  }
}

class Petal {
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble() * -1;
  double size = math.Random().nextDouble() * 15 + 10;
  double speed = math.Random().nextDouble() * 0.5 + 0.5;
  double angle = math.Random().nextDouble() * math.pi * 2;
  double drift = (math.Random().nextDouble() - 0.5) * 0.2;
}

class PetalPainter extends CustomPainter {
  final List<Petal> petals;
  final double progress;

  PetalPainter(this.petals, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.roseQuartz.withOpacity(0.6);

    for (var petal in petals) {
      double currentY = (petal.y + (progress * petal.speed)) % 1.5 - 0.2;
      double currentX = (petal.x + math.sin(progress * math.pi * 2 + petal.angle) * petal.drift) % 1.0;

      double px = currentX * size.width;
      double py = currentY * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(progress * math.pi * 2 + petal.angle);
      
      // Draw a petal shape
      final path = Path();
      path.moveTo(0, 0);
      path.quadraticBezierTo(petal.size / 2, -petal.size, petal.size, 0);
      path.quadraticBezierTo(petal.size / 2, petal.size, 0, 0);
      
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
