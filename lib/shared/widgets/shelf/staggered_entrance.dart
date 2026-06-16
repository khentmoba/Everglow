import 'package:flutter/material.dart';

import 'motion.dart';

/// Entrance animation that fades + slides a single child in. When
/// nested in a list with the [index] wired up, callers can stagger
/// the section reveals by passing incrementing `delayStep` durations.
class StaggeredEntrance extends StatelessWidget {
  final int index;
  final Duration delayStep;
  final Duration duration;
  final double offsetY;
  final Curve curve;
  final Widget child;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 12,
    this.curve = ShelfMotion.easeOutExpo,
  });

  @override
  Widget build(BuildContext context) {
    if (ShelfMotion.reduced) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
