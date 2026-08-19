import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VinylRecord extends StatefulWidget {
  const VinylRecord({super.key, this.isPlaying = true});

  final bool isPlaying;

  @override
  State<VinylRecord> createState() => _VinylRecordState();
}

class _VinylRecordState extends State<VinylRecord>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VinylRecord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF1E1E1E), Color(0xFF050505), Colors.black],
              stops: [0.3, 0.65, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(4, (i) {
                return Container(
                  width: 34.0 + (i * 7),
                  height: 34.0 + (i * 7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.035 + (i == 0 ? 0.02 : 0),
                      ),
                      width: 0.7,
                    ),
                  ),
                );
              }),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.18, 0.32, 0.62, 1.0],
                    transform: const GradientRotation(-0.6),
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.deepRose,
                      AppColors.deepRose.withValues(alpha: 0.85),
                      const Color(0xFF8E0E3A),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 14,
                child: Container(
                  width: 10,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  transform: Matrix4.rotationZ(-0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VinylShimmerOverlay extends StatelessWidget {
  const VinylShimmerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(62, 62),
      painter: _GrooveHighlightPainter(),
    );
  }
}

class _GrooveHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.06);
    final center = Offset(size.width / 2, size.height / 2);
    for (var r = 18.0; r < 27; r += 3.5) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
