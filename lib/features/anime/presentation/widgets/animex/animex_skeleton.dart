import 'package:flutter/material.dart';

import 'animex_tokens.dart';

/// Shimmer loading placeholder matching the reference skeleton look.
class AnimeXSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const AnimeXSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AnimeXTokens.radiusLg,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AnimeXTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A single skeleton poster card (image + two text lines).
class AnimeXSkeletonCard extends StatelessWidget {
  final double width;

  const AnimeXSkeletonCard({super.key, this.width = 175});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimeXSkeletonBox(
            width: width,
            height: width * 1.5,
            radius: AnimeXTokens.radiusLg,
          ),
          const SizedBox(height: 8),
          AnimeXSkeletonBox(width: width * 0.75, height: 12, radius: 4),
          const SizedBox(height: 6),
          AnimeXSkeletonBox(width: width * 0.5, height: 10, radius: 4),
        ],
      ),
    );
  }
}

/// Horizontal row of skeleton cards.
class AnimeXSkeletonRow extends StatelessWidget {
  final int count;
  final double cardWidth;

  const AnimeXSkeletonRow({super.key, this.count = 8, this.cardWidth = 175});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardWidth * 1.5 + 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, _) => AnimeXSkeletonCard(width: cardWidth),
      ),
    );
  }
}

/// Grid of skeleton cards.
class AnimeXSkeletonGrid extends StatelessWidget {
  final int count;

  const AnimeXSkeletonGrid({super.key, this.count = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 140).floor().clamp(2, 8);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 28,
            childAspectRatio: 0.66,
          ),
          itemBuilder: (_, _) => const AnimeXSkeletonCard(width: 140),
        );
      },
    );
  }
}

/// Spotlight skeleton: eyebrow, big title, synopsis lines and buttons.
class AnimeXSpotlightSkeleton extends StatelessWidget {
  const AnimeXSpotlightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimeXSkeletonBox(width: 120, height: 20, radius: 4),
              SizedBox(height: 12),
              AnimeXSkeletonBox(width: 380, height: 60, radius: 4),
              SizedBox(height: 12),
              AnimeXSkeletonBox(width: 280, height: 14, radius: 4),
              SizedBox(height: 8),
              AnimeXSkeletonBox(width: 210, height: 14, radius: 4),
              SizedBox(height: 24),
              Row(
                children: [
                  AnimeXSkeletonBox(width: 130, height: 42, radius: 6),
                  SizedBox(width: 12),
                  AnimeXSkeletonBox(
                    width: 100,
                    height: 42,
                    radius: AnimeXTokens.radiusMd,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (_ctrl.value * 2 - 1) * bounds.width * 2;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AnimeXTokens.surfaceRaised,
                Color(0xFF26263A),
                AnimeXTokens.surfaceRaised,
              ],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}
