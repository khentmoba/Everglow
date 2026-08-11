import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;
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
  final List<PetalData> _petals = [];
  late final Picture _petalShapePicture;
  static const int _petalCount = 30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Pre-render a single petal shape into a Picture so every frame
    // replays it with a simple translate+rotate instead of allocating
    // new Path objects on the UI thread.
    _petalShapePicture = _createPetalShapePicture(15.0);

    final rng = math.Random();
    for (int i = 0; i < _petalCount; i++) {
      _petals.add(PetalData(
        x: rng.nextDouble(),
        y: rng.nextDouble() * -1,
        size: rng.nextDouble() * 15 + 10,
        speed: rng.nextDouble() * 0.5 + 0.5,
        angle: rng.nextDouble() * math.pi * 2,
        drift: (rng.nextDouble() - 0.5) * 0.2,
      ));
    }
  }

  /// Pre-renders one canonical petal shape into a [Picture] so it can be
  /// replayed cheaply per petal per frame.
  static Picture _createPetalShapePicture(double maxSize) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = AppTheme.roseQuartz.withValues(alpha: 0.6);

    // Petal shape: two quadratic curves forming an eye-like leaf.
    // Scaled so the caller can adjust size via canvas.scale().
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(maxSize / 2, -maxSize, maxSize, 0)
      ..quadraticBezierTo(maxSize / 2, maxSize, 0, 0);
    canvas.drawPath(path, paint);

    return recorder.endRecording();
  }

  @override
  void dispose() {
    _controller.dispose();
    _petalShapePicture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: PetalPainter(
              petals: _petals,
              progress: _controller.value,
              shapePicture: _petalShapePicture,
            ),
          );
        },
      ),
    );
  }
}

class PetalData {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double angle;
  final double drift;

  const PetalData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.drift,
  });
}

class PetalPainter extends CustomPainter {
  final List<PetalData> petals;
  final double progress;
  final Picture shapePicture;

  PetalPainter({
    required this.petals,
    required this.progress,
    required this.shapePicture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final petal in petals) {
      final currentY = (petal.y + (progress * petal.speed)) % 1.5 - 0.2;
      final currentX = (petal.x + math.sin(progress * math.pi * 2 + petal.angle) * petal.drift) % 1.0;

      final px = currentX * size.width;
      final py = currentY * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(progress * math.pi * 2 + petal.angle);
      canvas.scale(petal.size / 15.0);
      canvas.drawPicture(shapePicture);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PetalPainter oldDelegate) {
    // Only repaint when the animation frame actually advances.
    // The old code returned true unconditionally, repainting 60×/s
    // even when the widget was occluded or the controller paused.
    return oldDelegate.progress != progress || oldDelegate.petals != petals;
  }
}
