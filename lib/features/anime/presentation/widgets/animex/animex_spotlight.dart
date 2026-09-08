import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../shared/utils/responsive_image.dart';
import '../../../../../shared/widgets/app_network_image.dart';

import '../../../../cinema/data/models/media_item.dart';

import 'animex_buttons.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';
import '../../../../../core/theme/app_colors.dart';

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
            _SlideLayer(item: items[i], visible: i == _index),
          // Top shade for header legibility, fading into the page bg at the
          // bottom so the hero melts into the ticker below.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.scrimMedium,
                  Colors.transparent,
                  Color(0xD90A0A0F),
                  AnimeXTokens.bg,
                ],
                stops: [0, 0.4, 0.82, 1],
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
                    index: _index % items.length,
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
              bottom: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
        : size.height -
              AnimeXTokens.headerHeight -
              AnimeXTokens.mobileNavHeight;
  }

  Widget _buildSkeleton() {
    return Container(
      height: _heroHeight(context),
      decoration: const BoxDecoration(color: AnimeXTokens.surface),
      child: const Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.scrimLight, Color(0x8C000000)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 64),
              child: Align(
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
            : AppNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                cacheWidth: heroCacheWidth(context),
                errorWidget: Container(color: AnimeXTokens.surfaceRaised),
              ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  final MediaItem item;
  final int index;
  final void Function(MediaItem)? onWatch;
  final void Function(MediaItem)? onMoreInfo;
  final void Function(MediaItem)? onTrailer;

  const _SlideContent({
    super.key,
    required this.item,
    required this.index,
    this.onWatch,
    this.onMoreInfo,
    this.onTrailer,
  });

  @override
  Widget build(BuildContext context) {
    final isAiring =
        item.airingStatus.toUpperCase().contains('RELEASING') ||
        item.airingStatus.toUpperCase().contains('AIRING');
    // Replays on every slide change: the parent keys this widget by item.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AnimeXTokens.accent,
                      AnimeXTokens.accentHover,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    AnimeXTokens.radiusMd,
                  ),
                  boxShadow: AnimeXTokens.accentGlowShadow(0.4),
                ),
                child: Text(
                  '#${index + 1} TRENDING',
                  style: dmSansStyle(
                    size: 11,
                    color: Colors.white,
                    weight: FontWeight.w800,
                    letterSpacing: 0.08,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isAiring) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AnimeXTokens.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AnimeXTokens.success,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Airing Now',
                  style: dmSansStyle(
                    size: 12,
                    color: AnimeXTokens.success,
                    weight: FontWeight.w700,
                    letterSpacing: 0.06,
                  ),
                ),
              ] else
                Text(
                  item.year.isNotEmpty ? item.year : 'Spotlight',
                  style: dmSansStyle(
                    size: 12,
                    color: AnimeXTokens.textSecondary,
                    weight: FontWeight.w600,
                    letterSpacing: 0.08,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
          _MetaRow(item: item),
          const SizedBox(height: 12),
          if (item.synopsis.isNotEmpty)
            Text(
              item.synopsis,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: interBodyStyle(size: 13.5, height: 1.55),
            ),
          const SizedBox(height: 22),
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
      ),
    );
  }

  double _titleSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.055).clamp(32.0, 64.0);
  }
}

/// Score / year / format / episode glass chips under the hero title.
class _MetaRow extends StatelessWidget {
  final MediaItem item;

  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (item.score != null && item.score! > 0)
          _chip(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AnimeXTokens.gold,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  item.score!.toStringAsFixed(1),
                  style: dmSansStyle(
                    size: 12.5,
                    color: AnimeXTokens.gold,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        if (item.year.isNotEmpty) _chip(_label(item.year)),
        if (item.format.isNotEmpty) _chip(_label(item.format)),
        if (item.episodeCount != null && item.episodeCount! > 0)
          _chip(_label('EP ${item.episodeCount}')),
        for (final genre in item.genres.take(3)) _chip(_label(genre), ghost: true),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: dmSansStyle(
        size: 12,
        color: AnimeXTokens.textPrimary,
        weight: FontWeight.w600,
      ),
    );
  }

  Widget _chip(Widget child, {bool ghost = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ghost
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: ghost ? 0.16 : 0.1),
        ),
      ),
      child: child,
    );
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
