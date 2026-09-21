import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';

/// Ambient shimmer controller shared across ALL skeletons in the app.
///
/// Instead of every skeleton running its own 60fps [AnimationController]
/// (which previously meant dozens of discordant tickers and gradient allocations
/// when loading shelves or search results), this single ref-counted ticker runs
/// only when at least one active skeleton is mounted.
///
/// All skeletons pulse in unified harmony, and frame overhead drops to near zero.
class EverglowShimmerScope {
  EverglowShimmerScope._();

  static final _AmbientShimmerTickerProvider _tickerProvider =
      const _AmbientShimmerTickerProvider();
  static AnimationController? _controller;
  static int _activeCount = 0;

  @visibleForTesting
  static int get activeCount => _activeCount;

  static Listenable attach() {
    _activeCount++;
    if (_controller == null && !AppMotion.reduced) {
      _controller = AnimationController(
        vsync: _tickerProvider,
        duration: const Duration(milliseconds: 1300),
      )..repeat();
    }
    return _controller ?? const AlwaysStoppedAnimation<double>(0.0);
  }

  static void detach() {
    _activeCount--;
    if (_activeCount <= 0) {
      _activeCount = 0;
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
    }
  }

  static double get value => _controller?.value ?? 0.0;
  static AnimationController? get controller => _controller;

  @visibleForTesting
  static void resetForTesting() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    _activeCount = 0;
  }
}

class _AmbientShimmerTickerProvider implements TickerProvider {
  const _AmbientShimmerTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick, debugLabel: 'kEverglowShimmerTicker');
  }
}

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

class _EverglowSkeletonState extends State<EverglowSkeleton> {
  Listenable? _shimmer;

  @override
  void initState() {
    super.initState();
    if (!AppMotion.reduced) {
      _shimmer = EverglowShimmerScope.attach();
    }
  }

  @override
  void dispose() {
    if (!AppMotion.reduced) {
      EverglowShimmerScope.detach();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced || _shimmer == null) {
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
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _EverglowSkeletonPainter(
            shimmer: _shimmer!,
            radius: widget.radius,
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
          ),
        ),
      ),
    );
  }
}

class _EverglowSkeletonPainter extends CustomPainter {
  _EverglowSkeletonPainter({
    required this.shimmer,
    required this.radius,
    required this.baseColor,
    required this.highlightColor,
  }) : super(repaint: shimmer);

  final Listenable shimmer;
  final double radius;
  final Color baseColor;
  final Color highlightColor;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final t = shimmer is Animation<double>
        ? (shimmer as Animation<double>).value
        : EverglowShimmerScope.value;

    final gradient = LinearGradient(
      begin: Alignment(-1.0 + 2.0 * t, 0),
      end: Alignment(-0.5 + 2.0 * t, 0),
      colors: [baseColor, highlightColor, baseColor],
      stops: const [0.0, 0.5, 1.0],
    );

    _paint.shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, _paint);
  }

  @override
  bool shouldRepaint(_EverglowSkeletonPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.highlightColor != highlightColor;
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
        itemBuilder: (_, _) =>
            EverglowSkeleton(width: itemWidth, height: itemHeight, radius: 14),
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
      itemBuilder: (_, _) => const EverglowSkeleton(radius: 14),
    );
  }
}

/// Centered loading spinner with optional message.
///
/// The ONE spinner for the entire app. Use this instead of raw
/// `CircularProgressIndicator` in content areas so every screen shows
/// the same deep-rose spinner.
class EverglowLoadingState extends StatelessWidget {
  final String? message;
  const EverglowLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepRose,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: AppColors.roseQuartz.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
