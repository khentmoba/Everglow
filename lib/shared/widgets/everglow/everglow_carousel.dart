import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_motion.dart';

/// Auto-rotating hero carousel with parallax and reduced-motion dots.
///
/// Replaces `ShelfHeroCarousel`. Reduced-motion → no auto-rotate,
/// instant dots.
class EverglowCarousel extends StatefulWidget {
  final List<EverglowCarouselItem> items;
  final double height;
  final Duration holdDuration;
  final ValueChanged<int>? onTap;

  const EverglowCarousel({
    super.key,
    required this.items,
    this.height = 320,
    this.holdDuration = const Duration(seconds: 8),
    this.onTap,
  });

  @override
  State<EverglowCarousel> createState() => _EverglowCarouselState();
}

class _EverglowCarouselState extends State<EverglowCarousel> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    if (!AppMotion.reduced) _autoAdvance();
  }

  void _autoAdvance() {
    Future.delayed(widget.holdDuration, () {
      if (!mounted || AppMotion.reduced) return;
      final next = (_currentPage + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: AppMotion.carousel,
        curve: AppMotion.easeOutExpo,
      );
      _autoAdvance();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _CarouselSlide(
                item: item,
                isActive: index == _currentPage,
                controller: _controller,
                index: index,
                onTap: widget.onTap != null
                    ? () => widget.onTap!(index)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _DotIndicator(
          count: widget.items.length,
          current: _currentPage,
        ),
      ],
    );
  }
}

class _CarouselSlide extends StatelessWidget {
  final EverglowCarouselItem item;
  final bool isActive;
  final PageController controller;
  final int index;
  final VoidCallback? onTap;

  const _CarouselSlide({
    required this.item,
    required this.isActive,
    required this.controller,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double scale = 1.0;
        double opacity = 1.0;
        if (controller.position.haveDimensions) {
          final page = controller.page ?? 0;
          final diff = (page - index).abs();
          scale = (1 - diff * 0.08).clamp(0.92, 1.0);
          opacity = (1 - diff * 0.4).clamp(0.6, 1.0);
        }

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusX2,
              boxShadow: AppElevation.e3,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                if (item.imageUrl != null)
                  Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.velvet,
                      child: Center(
                        child: Icon(Icons.movie_outlined,
                            size: 48, color: AppColors.textDisabled),
                      ),
                    ),
                  )
                else
                  Container(color: AppColors.velvet),
                // Gradient overlays for legibility
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0x99000000),
                      ],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                // Title
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.eyebrow != null)
                        Text(
                          item.eyebrow!.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blushGold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.roseQuartz,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: AppMotion.orZero(const Duration(milliseconds: 350)),
          curve: AppMotion.easeOutExpo,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: active
                ? AppColors.deepRose
                : AppColors.moonlight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// Carousel item configuration.
class EverglowCarouselItem {
  final String title;
  final String? eyebrow;
  final String? imageUrl;

  const EverglowCarouselItem({
    required this.title,
    this.eyebrow,
    this.imageUrl,
  });
}
