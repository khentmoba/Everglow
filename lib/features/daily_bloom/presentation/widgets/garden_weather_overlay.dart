import 'dart:math';
import 'package:flutter/material.dart';

/// Seasonal weather particle overlay for the garden.
/// Uses month-based seasons — no external API needed.
class GardenWeatherOverlay extends StatefulWidget {
  final int season; // 0=winter, 1=spring, 2=summer, 3=autumn

  const GardenWeatherOverlay({super.key, required this.season});

  /// Get current season from month.
  static int currentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 1; // Spring
    if (month >= 6 && month <= 8) return 2; // Summer
    if (month >= 9 && month <= 11) return 3; // Autumn
    return 0; // Winter
  }

  @override
  State<GardenWeatherOverlay> createState() => _GardenWeatherOverlayState();
}

class _GardenWeatherOverlayState extends State<GardenWeatherOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _particles = List.generate(15, (_) => _createParticle());
  }

  _Particle _createParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble() * -1, // Start above viewport
      speed: 0.002 + _random.nextDouble() * 0.003,
      size: 2 + _random.nextDouble() * 4,
      opacity: 0.2 + _random.nextDouble() * 0.4,
      drift: (_random.nextDouble() - 0.5) * 0.001,
      rotation: _random.nextDouble() * pi * 2,
      rotSpeed: (_random.nextDouble() - 0.5) * 0.02,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Update particle positions
          for (final p in _particles) {
            p.y += p.speed;
            p.x += p.drift;
            p.rotation += p.rotSpeed;
            if (p.y > 1.2) {
              p.y = -0.1;
              p.x = _random.nextDouble();
            }
          }

          return CustomPaint(
            size: Size.infinite,
            painter: _WeatherPainter(
              particles: _particles,
              season: widget.season,
            ),
          );
        },
      ),
      ),
    );
  }
}

class _Particle {
  double x, y, speed, size, opacity, drift, rotation, rotSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.drift,
    required this.rotation,
    required this.rotSpeed,
  });
}

class _WeatherPainter extends CustomPainter {
  final List<_Particle> particles;
  final int season;

  _WeatherPainter({required this.particles, required this.season});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final dx = p.x * size.width;
      final dy = p.y * size.height;

      switch (season) {
        case 0: // Winter — snowflakes
          paint.color = Colors.white.withValues(alpha: p.opacity * 0.5);
          canvas.drawCircle(Offset(dx, dy), p.size, paint);
          break;

        case 1: // Spring — falling petals
          paint.color = const Color(0xFFF8BBD0).withValues(alpha: p.opacity);
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(p.rotation);
          final petalPath = Path();
          petalPath.moveTo(0, 0);
          petalPath.quadraticBezierTo(p.size, -p.size * 0.8, 0, -p.size * 1.5);
          petalPath.quadraticBezierTo(-p.size, -p.size * 0.8, 0, 0);
          canvas.drawPath(petalPath, paint);
          canvas.restore();
          break;

        case 2: // Summer — sun rays (subtle)
          paint.color = const Color(0xFFFFD54F).withValues(alpha: p.opacity * 0.3);
          canvas.drawCircle(Offset(dx, dy), p.size * 0.8, paint);
          break;

        case 3: // Autumn — golden leaves
          paint.color = const Color(0xFFFFB74D).withValues(alpha: p.opacity);
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(p.rotation);
          final leafPath = Path();
          leafPath.moveTo(0, -p.size);
          leafPath.quadraticBezierTo(p.size, -p.size * 0.5, 0, p.size);
          leafPath.quadraticBezierTo(-p.size, -p.size * 0.5, 0, -p.size);
          canvas.drawPath(leafPath, paint);
          canvas.restore();
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) => true;
}
