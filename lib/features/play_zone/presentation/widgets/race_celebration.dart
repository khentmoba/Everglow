import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';

class RaceCelebration extends StatefulWidget {
  final bool isVisible;

  const RaceCelebration({super.key, required this.isVisible});

  @override
  State<RaceCelebration> createState() => _RaceCelebrationState();
}

class _RaceCelebrationState extends State<RaceCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<CelebrationParticle> _particles = [];
  final int _particleCount = 40;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    for (int i = 0; i < _particleCount; i++) {
      _particles.add(CelebrationParticle());
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

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: CelebrationPainter(_particles, _controller.value),
          );
        },
      ),
    );
  }
}

class CelebrationParticle {
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble() * -1;
  double size = math.Random().nextDouble() * 12 + 8;
  double speed = math.Random().nextDouble() * 0.4 + 0.4;
  double angle = math.Random().nextDouble() * math.pi * 2;
  double drift = (math.Random().nextDouble() - 0.5) * 0.15;
  int type = math.Random().nextInt(3);
}

class CelebrationPainter extends CustomPainter {
  final List<CelebrationParticle> particles;
  final double progress;

  CelebrationPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      AppTheme.deepRose,
      AppTheme.roseQuartz,
      AppTheme.blushGold,
      AppTheme.softLavender,
    ];

    for (var p in particles) {
      double currentY = (p.y + (progress * p.speed)) % 1.5 - 0.2;
      double currentX =
          (p.x + math.sin(progress * math.pi * 2 + p.angle) * p.drift) % 1.0;

      double px = currentX * size.width;
      double py = currentY * size.height;

      final paint = Paint()
        ..color = colors[p.type % colors.length].withValues(alpha: 0.5 + math.sin(progress * math.pi + p.angle) * 0.3)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(progress * math.pi * 2 + p.angle);

      final half = p.size / 2;
      if (p.type == 0) {
        final path = Path();
        path.moveTo(0, 0);
        path.quadraticBezierTo(half, -p.size, p.size, 0);
        path.quadraticBezierTo(half, p.size, 0, 0);
        canvas.drawPath(path, paint);
      } else if (p.type == 1) {
        final path = Path();
        path.moveTo(0, -half);
        path.cubicTo(half, -half, half, half, 0, half);
        path.cubicTo(-half, half, -half, -half, 0, -half);
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(Offset.zero, half * 0.6, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
