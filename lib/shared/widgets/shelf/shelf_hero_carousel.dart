import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

/// Item the [ShelfHeroCarousel] can render.
class ShelfHeroItem {
  final String id;
  final String title;
  final String subtitle;
  final String? eyebrow;
  final String imageUrl;
  final Color accent;
  final VoidCallback? onTap;

  /// Cover poster URL for the [AnimeHeroBanner]'s right-side floating poster.
  final String posterUrl;

  /// Rich metadata for the anime hero banner (optional — only used by
  /// [AnimeHeroBanner], ignored by [ShelfHeroCarousel]).
  final String? synopsis;
  final int? episodeCount;
  final String? format;
  final String? airingStatus;
  final String year;

  const ShelfHeroItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.eyebrow,
    this.accent = AppTheme.deepRose,
    this.onTap,
    this.posterUrl = '',
    this.synopsis,
    this.episodeCount,
    this.format,
    this.airingStatus,
    this.year = '',
  });
}

/// Polished auto-rotating hero carousel used by all four inside
/// screens. The active slide is full-bleed; neighbouring slides are
/// scaled down and dimmed to give the strip depth. Each slide
/// shows eyebrow + serif title + subtitle overlaid on a cinematic
/// gradient so the user can read what's playing without tapping.
class ShelfHeroCarousel extends StatefulWidget {
  final List<ShelfHeroItem> items;
  final Duration holdDuration;
  final double viewportFraction;
  final double height;

  const ShelfHeroCarousel({
    super.key,
    required this.items,
    this.holdDuration = const Duration(seconds: 8),
    this.viewportFraction = 0.88,
    this.height = 320,
  });

  @override
  State<ShelfHeroCarousel> createState() => _ShelfHeroCarouselState();
}

class _ShelfHeroCarouselState extends State<ShelfHeroCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);
    if (widget.items.length > 1) _startTimer();
  }

  @override
  void didUpdateWidget(covariant ShelfHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _controller.jumpToPage(0);
      _index = 0;
      _timer?.cancel();
      if (widget.items.length > 1) _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.holdDuration, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _timer?.cancel();
    if (widget.items.length > 1) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _onPageChanged,
            itemCount: widget.items.length,
            itemBuilder: (context, i) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double scale = 1.0;
                  double opacity = 1.0;
                  if (_controller.position.haveDimensions) {
                    final diff = (_controller.page ?? _index) - i;
                    final abs = diff.abs();
                    scale = (1 - (abs * 0.06)).clamp(0.92, 1.0);
                    opacity = (1 - (abs * 0.25)).clamp(0.6, 1.0);
                  } else {
                    scale = i == _index ? 1.0 : 0.94;
                    opacity = i == _index ? 1.0 : 0.6;
                  }
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: _HeroSlide(
                  item: widget.items[i],
                  index: i,
                  isActive: i == _index,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _DotIndicator(
          count: widget.items.length,
          active: _index,
          accent: widget.items[_index].accent,
        ),
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final ShelfHeroItem item;
  final int index;
  final bool isActive;
  const _HeroSlide({
    required this.item,
    required this.index,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: item.accent.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.imageUrl.isNotEmpty)
                  Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 900,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.velvet,
                    ),
                  )
                else
                  Container(color: AppTheme.velvet),

                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppTheme.twilight.withValues(alpha: 0.15),
                        AppTheme.twilight.withValues(alpha: 0.78),
                        AppTheme.twilight.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.28, 0.62, 1.0],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppTheme.twilight.withValues(alpha: 0.45),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 22,
                  left: 22,
                  right: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (item.eyebrow ?? 'TRENDING').toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.petalWhite,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppTheme.roseQuartz
                              .withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.3,
                        ),
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
  final int active;
  final Color accent;
  const _DotIndicator({
    required this.count,
    required this.active,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 5,
          height: 5,
          decoration: BoxDecoration(
            color:
                isActive ? accent : AppTheme.roseQuartz.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
