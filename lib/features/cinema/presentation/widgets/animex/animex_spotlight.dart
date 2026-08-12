import 'dart:async';

import 'package:flutter/material.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';

import 'animex_buttons.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';

/// Full-bleed hero carousel with crossfading slides, slow Ken Burns zoom,
/// title/synopsis/buttons and dot navigation, matching the reference
/// spotlight section.
class AnimeXSpotlight extends StatefulWidget {
  final List<MediaItem> items;
  final bool loading;
  final void Function(MediaItem)? onWatch;
  final void Function(MediaItem)? onMoreInfo;
  final void Function(MediaItem)? onTrailer;

  const AnimeXSpotlight({
    super.key,
    required this.items,
    this.loading = false,
    this.onWatch,
    this.onMoreInfo,
    this.onTrailer,
  });

  @override
  State<AnimeXSpotlight> createState() => _AnimeXSpotlightState();
}

class _AnimeXSpotlightState extends State<AnimeXSpotlight> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || widget.items.length < 2) return;
      setState(() => _index = (_index + 1) % widget.items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (widget.loading || items.isEmpty) {
      return _buildSkeleton();
    }

    final active = items[_index % items.length];
    return Container(
      height: _heroHeight(context),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: AnimeXTokens.bg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < items.length; i++)
            _SlideLayer(
              item: items[i],
              visible: i == _index,
            ),
          // Left-to-right darkening so the bottom-left content stays legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59000000),
                  Colors.transparent,
                  Color(0xE6000000),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE6000000),
                  Color(0x8C000000),
                  Colors.transparent,
                ],
                stops: [0, 0.35, 0.7],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 64),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _SlideContent(
                    item: active,
                    key: ValueKey(active.tmdbId),
                    onWatch: widget.onWatch,
                    onMoreInfo: widget.onMoreInfo,
                    onTrailer: widget.onTrailer,
                  ),
                ),
              ),
            ),
          ),
          if (items.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _HeroDot(
                      active: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        _startTimer();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _heroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 768;
    return isDesktop
        ? size.height - AnimeXTokens.headerHeight
        : size.height - AnimeXTokens.headerHeight - AnimeXTokens.mobileNavHeight;
  }

  Widget _buildSkeleton() {
    return Container(
      height: _heroHeight(context),
      decoration: const BoxDecoration(color: AnimeXTokens.surface),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x8C000000),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 64),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: AnimeXSpotlightSkeleton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideLayer extends StatelessWidget {
  final MediaItem item;
  final bool visible;

  const _SlideLayer({required this.item, required this.visible});

  @override
  Widget build(BuildContext context) {
    final url = item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 700),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.04, end: 1.0),
        duration: const Duration(seconds: 7),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: url.isEmpty
            ? Container(color: AnimeXTokens.surfaceRaised)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AnimeXTokens.surfaceRaised),
              ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  final MediaItem item;
  final void Function(MediaItem)? onWatch;
  final void Function(MediaItem)? onMoreInfo;
  final void Function(MediaItem)? onTrailer;

  const _SlideContent({
    super.key,
    required this.item,
    this.onWatch,
    this.onMoreInfo,
    this.onTrailer,
  });

  @override
  Widget build(BuildContext context) {
    final isAiring = item.airingStatus.toUpperCase().contains('RELEASING') ||
        item.airingStatus.toUpperCase().contains('AIRING');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: const BoxDecoration(
            color: AnimeXTokens.accent,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            if (isAiring) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AnimeXTokens.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              isAiring
                  ? 'Airing Today'
                  : (item.year.isNotEmpty ? item.year : 'Trending'),
              style: dmSansStyle(
                size: 12,
                color: isAiring
                    ? AnimeXTokens.success
                    : AnimeXTokens.textSecondary,
                weight: FontWeight.w600,
                letterSpacing: 0.08,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: bebasStyle(
            size: _titleSize(context),
            color: AnimeXTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (item.synopsis.isNotEmpty)
          Text(
            item.synopsis,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: interBodyStyle(size: 13.5, height: 1.55),
          ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            AnimeXWatchNowButton(
              label: 'Watch Now',
              onTap: () => onWatch?.call(item),
            ),
            AnimeXSecondaryButton(
              label: 'More Info',
              icon: Icons.info_outline_rounded,
              strong: true,
              onTap: () => onMoreInfo?.call(item),
            ),
            AnimeXGhostButton(
              label: 'Trailer',
              icon: Icons.play_circle_outline_rounded,
              onTap: () => onTrailer?.call(item),
            ),
          ],
        ),
      ],
    );
  }

  double _titleSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.055).clamp(32.0, 64.0);
  }
}

class _HeroDot extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _HeroDot({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 32 : 8,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
