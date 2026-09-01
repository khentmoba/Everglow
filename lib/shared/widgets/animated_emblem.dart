import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AnimatedEmblem extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final bool glow;

  const AnimatedEmblem({
    super.key,
    required this.icon,
    this.color,
    this.size = 40.0,
    this.glow = true,
  });

  @override
  State<AnimatedEmblem> createState() => _AnimatedEmblemState();
}

class _AnimatedEmblemState extends State<AnimatedEmblem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 2.0,
      end: 10.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.deepRose;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.glow
                  ? [
                      BoxShadow(
                        color: effectiveColor.withValues(alpha: 0.3),
                        blurRadius: _glowAnimation.value * 2,
                        spreadRadius: _glowAnimation.value / 2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              size: widget.size,
              color: effectiveColor,
              shadows: [
                Shadow(
                  color: AppColors.blushGold.withValues(alpha: 0.65),
                  blurRadius: _glowAnimation.value,
                ),
                Shadow(
                  color: AppColors.petalWhite.withValues(alpha: 0.24),
                  blurRadius: 1,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}