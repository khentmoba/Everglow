import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

/// Unified skeleton/loading placeholder.
///
/// The ONE loading pattern for the entire app. Replaces `ShimmerBox`,
/// `ShimmerPosterRow`, and all `CircularProgressIndicator` usage in
/// content areas.
///
/// Shows a pulsing shimmer when motion is allowed, or a static dim
/// fill when `AppMotion.reduced` is true.
class EverglowSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const EverglowSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 12,
  });

  @override
  State<EverglowSkeleton> createState() => _EverglowSkeletonState();
}

class _EverglowSkeletonState extends State<EverglowSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced || _controller == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _controller!,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _controller!.value, 0),
            end: Alignment(-0.5 + 2.0 * _controller!.value, 0),
            colors: const [
              AppColors.shimmerBase,
              AppColors.shimmerHighlight,
              AppColors.shimmerBase,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
      ),
    );
  }
}

/// A row of shimmer poster placeholders.
///
/// Use for horizontal scrolling content (cinema shelves, anime rows, etc.)
/// while data is loading.
class EverglowSkeletonRow extends StatelessWidget {
  final int count;
  final double itemWidth;
  final double itemHeight;
  final double spacing;

  const EverglowSkeletonRow({
    super.key,
    this.count = 6,
    this.itemWidth = 110,
    this.itemHeight = 165,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (_, _) => EverglowSkeleton(
          width: itemWidth,
          height: itemHeight,
          radius: 14,
        ),
      ),
    );
  }
}

/// A shimmer grid placeholder.
class EverglowSkeletonGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final double? maxCrossAxisExtent;
  final double itemHeight;
  final double spacing;
  final double childAspectRatio;

  const EverglowSkeletonGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 3,
    this.maxCrossAxisExtent,
    this.itemHeight = 200,
    this.spacing = 12,
    this.childAspectRatio = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: maxCrossAxisExtent != null
          ? SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxCrossAxisExtent!,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            )
          : SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
      itemCount: count,
      itemBuilder: (_, _) => const EverglowSkeleton(
        radius: 14,
      ),
    );
  }
}
