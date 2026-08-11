import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

/// Presence indicator dot — online/last-seen/doodle states.
///
/// Replaces `PartnerPresenceIndicator._Dot` and `PartnerDoodleIndicator._PulsingDot`.
/// Reduced-motion → static dot (no pulse).
class EverglowPresenceDot extends StatefulWidget {
  final PresenceState state;
  final double size;
  final String? label;

  const EverglowPresenceDot({
    super.key,
    required this.state,
    this.size = 10,
    this.label,
  });

  @override
  State<EverglowPresenceDot> createState() => _EverglowPresenceDotState();
}

enum PresenceState { online, lastSeen, doodle, offline }

class _EverglowPresenceDotState extends State<EverglowPresenceDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    final shouldPulse = !AppMotion.reduced &&
        (widget.state == PresenceState.online ||
         widget.state == PresenceState.doodle);
    if (shouldPulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.state) {
      PresenceState.online  => AppColors.success,
      PresenceState.doodle  => AppColors.warmAmber,
      PresenceState.lastSeen => AppColors.roseQuartz.withValues(alpha: 0.5),
      PresenceState.offline => AppColors.textDisabled,
    };

    Widget dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: _controller != null
            ? [
                BoxShadow(
                  blurRadius: 8,
                  color: color.withValues(alpha: 0.4),
                ),
              ]
            : null,
      ),
    );

    if (_controller != null) {
      dot = RepaintBoundary(
        child: AnimatedBuilder(
        animation: _controller!,
        builder: (_, child) {
          final scale = 0.8 + 0.2 * _controller!.value;
          final glowOpacity = 0.2 + 0.6 * _controller!.value;
          return Container(
            width: widget.size * 1.8,
            height: widget.size * 1.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 12 * glowOpacity,
                  color: color.withValues(alpha: 0.3 * glowOpacity),
                ),
              ],
            ),
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        ),
      );
    }

    if (widget.label != null) {
      return Semantics(
        label: widget.label,
        child: dot,
      );
    }

    return ExcludeSemantics(child: dot);
  }
}
