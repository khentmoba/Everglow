import 'package:flutter/material.dart';

/// Reusable shimmer placeholder. Pulses a soft highlight across a
/// dark velvet surface so it reads as "loading" without needing
/// structure to be inferred. Used by Cinema, Anime, Books, and Manga
/// to keep the loading state visually consistent.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  final Color base;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
    this.base = const Color(0xFF1C1228),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: false);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.5, 0),
              end: const Alignment(1.5, 0),
              colors: [
                widget.base,
                const Color(0xFF2A1F3A),
                widget.base,
              ],
              stops: [
                (_anim.value - 0.3).clamp(0.0, 1.0),
                _anim.value.clamp(0.0, 1.0),
                (_anim.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Horizontal row of shimmer placeholders sized for poster cards.
class ShimmerPosterRow extends StatelessWidget {
  final double height;
  final double width;
  final int count;
  final EdgeInsets padding;
  final double radius;

  const ShimmerPosterRow({
    super.key,
    this.height = 200,
    this.width = 130,
    this.count = 6,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 20),
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => ShimmerBox(
          width: width,
          height: height,
          radius: radius,
        ),
      ),
    );
  }
}
