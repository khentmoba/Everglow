import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Staggered entrance animation for content sections.
///
/// Replaces `StaggeredEntrance` from shelf/ AND all `animate_do`
/// `FadeInUp`/`FadeInDown`/`FadeInLeft`/`FadeInRight` usage.
///
/// When `AppMotion.reduced` is true, returns the child instantly.
class EverglowStaggeredEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;
  final Offset direction;

  const EverglowStaggeredEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 12,
    this.direction = const Offset(0, 1), // bottom-to-top
  });

  /// Slide up variant (replaces `FadeInUp`).
  const EverglowStaggeredEntrance.up({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 12,
  }) : direction = const Offset(0, 1);

  /// Slide down variant (replaces `FadeInDown`).
  const EverglowStaggeredEntrance.down({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 12,
  }) : direction = const Offset(0, -1);

  /// Slide left variant (replaces `FadeInLeft`).
  const EverglowStaggeredEntrance.left({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 12,
  }) : direction = const Offset(-1, 0);

  /// Slide right variant (replaces `FadeInRight`).
  const EverglowStaggeredEntrance.right({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 12,
  }) : direction = const Offset(1, 0);

  @override
  State<EverglowStaggeredEntrance> createState() =>
      _EverglowStaggeredEntranceState();
}

class _EverglowStaggeredEntranceState extends State<EverglowStaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (AppMotion.reduced) {
      _visible = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced) return widget.child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _visible ? 1.0 : 0.0),
      duration: widget.duration,
      curve: AppMotion.easeOutExpo,
      builder: (_, value, child) {
        final dx = widget.direction.dx * widget.offsetY * (1 - value);
        final dy = widget.direction.dy * widget.offsetY * (1 - value);
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
      child: widget.child,
    );
  }
}
