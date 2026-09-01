import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'shelf_hero_carousel.dart';
import 'motion.dart';

/// WatchPeak-inspired hero banner for the anime screen.
///
/// Full-bleed banner background with a floating cover poster on the right,
/// rich metadata on the left (title, synopsis, episode count, format, etc.),
/// and auto-rotating dot navigation. Designed to replace [ShelfHeroCarousel]
/// for the anime hero section specifically.
class AnimeHeroBanner extends StatefulWidget {
  final List<ShelfHeroItem> items;
  final Duration holdDuration;
  final double height;

  const AnimeHeroBanner({
    super.key,
    required this.items,
    this.holdDuration = const Duration(seconds: 18),
    this.height = 520,
  });

  @override
  State<AnimeHeroBanner> createState() => _AnimeHeroBannerState();
}

class _AnimeHeroBannerState extends State<AnimeHeroBanner> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1.0);
    if (widget.items.length > 1) _startTimer();
  }

  @override
  void didUpdateWidget(covariant AnimeHeroBanner oldWidget) {
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

    final isDesktop = AppBreakpoint.isDesktop(context);
    final bannerHeight = isDesktop ? widget.height : widget.height * 0.8;
    final item = widget.items[_index];

    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
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
                    scale = (1 - (abs * 0.05)).clamp(0.95, 1.0);
                    opacity = (1 - (abs * 0.3)).clamp(0.5, 1.0);
                  } else {
                    scale = i == _index ? 1.0 : 0.96;
                    opacity = i == _index ? 1.0 : 0.5;
                  }
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: _HeroBannerSlide(
                  item: widget.items[i],
                  index: i,
                  isActive: i == _index,
                  isDesktop: isDesktop,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _DotIndicator(
          count: widget.items.length,
          active: _index,
          accent: item.accent,
        ),
      ],
    );
  }
}

class _HeroBannerSlide extends StatelessWidget {
  final ShelfHeroItem item;
  final int index;
  final bool isActive;
  final bool isDesktop;

  const _HeroBannerSlide({
    required this.item,
    required this.index,
    required this.isActive,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: item.accent.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred backdrop image
                  if (item.imageUrl.isNotEmpty)
                    Transform.scale(
                      scale: 1.1,
                      child: kIsWeb
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 1200,
                              errorBuilder: (_, _, _) =>
                                  Container(color: AppColors.velvet),
                            )
                          : ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Image.network(
                                item.imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 1200,
                                errorBuilder: (_, _, _) =>
                                    Container(color: AppColors.velvet),
                              ),
                            ),
                    )
                  else
                    Container(color: AppColors.velvet),

                  // Dark wash overlay for contrast
                  Container(color: Colors.black.withValues(alpha: 0.55)),

                  // Bottom gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          AppColors.animeBackground.withValues(alpha: 0.4),
                          AppColors.animeBackground.withValues(alpha: 0.88),
                          AppColors.animeBackground.withValues(alpha: 0.98),
                        ],
                        stops: const [0.0, 0.3, 0.55, 0.78, 1.0],
                      ),
                    ),
                  ),

                  // Left gradient for text legibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.animeBackground.withValues(alpha: 0.65),
                          AppColors.animeBackground.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 0.75],
                      ),
                    ),
                  ),

                  // Content
                  Positioned(
                    bottom: 0,
                    left: isDesktop ? 48 : 24,
                    right: isDesktop ? 260 : 140,
                    top: isDesktop ? 48 : 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Eyebrow
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (item.eyebrow ?? 'TRENDING').toUpperCase(),
                            style: AppTypography.outfitHeading.copyWith(
                              color: AppColors.petalWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 16 : 10),

                        // Title
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cormorantBlackWhite.copyWith(
                            fontSize: isDesktop ? 40 : 28,
                            height: 1.05,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),

                        // Subtitle (English title / year)
                        if (item.subtitle.isNotEmpty) ...[
                          SizedBox(height: isDesktop ? 8 : 4),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppColors.roseQuartz.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: isDesktop ? 15 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        // Synopsis
                        if (item.synopsis != null &&
                            item.synopsis!.isNotEmpty) ...[
                          SizedBox(height: isDesktop ? 16 : 10),
                          Text(
                            item.synopsis!,
                            maxLines: isDesktop ? 4 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppColors.petalWhite.withValues(alpha: 0.6),
                              fontSize: isDesktop ? 13 : 11,
                              height: 1.5,
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Metadata chips
                        _MetadataChips(item: item),

                        SizedBox(height: isDesktop ? 16 : 10),

                        // Action buttons
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _ActionButton(
                              label: 'Watch now',
                              icon: Icons.play_arrow_rounded,
                              primary: true,
                              accent: item.accent,
                              onTap: item.onTap,
                            ),
                            _ActionButton(
                              label: 'Queue',
                              icon: Icons.add_rounded,
                              primary: false,
                              accent: item.accent,
                              onTap: item.onTap,
                            ),
                          ],
                        ),
                        SizedBox(height: isDesktop ? 0 : 8),
                      ],
                    ),
                  ),

                  // Floating cover poster (right side)
                  if (isDesktop)
                    Positioned(
                      right: 48,
                      bottom: 48,
                      child: _FloatingPoster(posterUrl: item.posterUrl),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingPoster extends StatelessWidget {
  final String posterUrl;
  const _FloatingPoster({required this.posterUrl});

  @override
  Widget build(BuildContext context) {
    if (posterUrl.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: 180,
      height: 260,
      child: Stack(
        children: [
          // Glow duplicate behind the poster
          Positioned(
            top: 8,
            left: 4,
            right: -4,
            bottom: -8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                  ? Opacity(
                      opacity: 0.5,
                      child: Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    )
                  : ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
            ),
          ),
          // Main poster
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              posterUrl,
              fit: BoxFit.cover,
              cacheWidth: 500,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.velvet,
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.petalWhite.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
          // Subtle border
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.petalWhite.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataChips extends StatelessWidget {
  final ShelfHeroItem item;
  const _MetadataChips({required this.item});

  @override
  Widget build(BuildContext context) {
    final chips = <_MetaChip>[];

    if (item.episodeCount != null) {
      chips.add(
        _MetaChip(icon: Icons.movie_rounded, label: '${item.episodeCount} eps'),
      );
    }
    if (item.format != null && item.format!.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.tv_rounded, label: item.format!));
    }
    if (item.year.isNotEmpty) {
      chips.add(
        _MetaChip(icon: Icons.calendar_today_rounded, label: item.year),
      );
    }
    if (item.airingStatus != null && item.airingStatus!.isNotEmpty) {
      chips.add(
        _MetaChip(icon: Icons.live_tv_rounded, label: item.airingStatus!),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 6, children: chips);
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.petalWhite.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.petalWhite.withValues(alpha: 0.6)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final Color accent;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: ShelfMotion.orZero(const Duration(milliseconds: 200)),
          curve: ShelfMotion.easeOutStrong,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: primary ? accent : AppColors.petalWhite.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: primary
                ? null
                : Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.2),
                    width: 1,
                  ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.petalWhite),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitHeading.copyWith(fontSize: 13),
                ),
              ),
            ],
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
            color: isActive ? accent : AppColors.petalWhite.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
