import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_motion.dart';
import 'circuitry_painter.dart';

/// Atmospheric animated backdrop shared by feature screens.
///
/// A slow drifting gradient over a deep night base with soft glows and
/// a faint petal field. Honors reduced-motion by rendering static.
class GamifiedBackground extends StatefulWidget {
  final Widget child;
  const GamifiedBackground({super.key, required this.child});

  @override
  State<GamifiedBackground> createState() => _GamifiedBackgroundState();
}

class _GamifiedBackgroundState extends State<GamifiedBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _controller;
  Animation<Alignment>? _topAlignmentAnimation;
  Animation<Alignment>? _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!AppMotion.reduced) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    _controller?.dispose();
    final controller = AnimationController(
      duration: const Duration(seconds: 28),
      vsync: this,
    )..repeat(reverse: true);
    _controller = controller;

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: const Alignment(-0.6, -0.9),
          end: const Alignment(0.6, -0.9),
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: const Alignment(0.6, -0.9),
          end: const Alignment(0.6, 0.9),
        ),
        weight: 1,
      ),
    ]).animate(controller);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: const Alignment(0.6, 0.9),
          end: const Alignment(-0.6, 0.9),
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: AlignmentTween(
          begin: const Alignment(-0.6, 0.9),
          end: const Alignment(-0.6, -0.9),
        ),
        weight: 1,
      ),
    ]).animate(controller);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppMotion.reduced) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [
                        AppColors.inkDeep,
                        AppColors.twilight,
                        AppColors.velvet,
                      ],
                      begin:
                          _topAlignmentAnimation?.value ??
                          const Alignment(-0.6, -0.9),
                      end:
                          _bottomAlignmentAnimation?.value ??
                          const Alignment(0.6, 0.9),
                    ),
                  ),
                  child: Stack(
                    children: [
                      child!,
                      // Soft glows.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.7, -0.8),
                              radius: 0.9,
                              colors: [
                                AppColors.velvet.withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: PetalFieldPainter(
                  color: AppColors.roseQuartz,
                  opacity: 0.05,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
