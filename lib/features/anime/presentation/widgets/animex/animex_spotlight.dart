import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../shared/utils/responsive_image.dart';
import '../../../../../shared/widgets/app_network_image.dart';

import '../../../../cinema/data/models/media_item.dart';
import '../../../../cinema/presentation/widgets/trailer_player.dart';
import '../../../data/services/anilist_service.dart';

import 'animex_buttons.dart';
import 'animex_skeleton.dart';
import 'animex_tokens.dart';

/// Artwork-led spotlight with readable metadata and separate touch controls.
/// Leaves room for the catalog on phones and tablets.
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
  Timer? _armTimer;
  Timer? _fallbackTimer;

  // Shared with the cinema hero and the dashboard memories.
  static const Duration _stillHoldDuration = AppMotion.carouselHold;
  static const Duration _trailerHoldDuration = AppMotion.carouselHoldTrailer;

  bool _active = false;
  bool _muted = true;
  bool _playing = true;
  bool _trailerArmed = false;
  bool _trailerReady = false;

  final Map<String, String?> _trailerCache = {};

  static bool get _inTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  String _cacheKey(MediaItem item) => '${item.anilistId ?? item.tmdbId}';

  String? _resolveTrailerKey(MediaItem item) {
    if (item.trailerYoutubeId != null && item.trailerYoutubeId!.isNotEmpty) {
      return item.trailerYoutubeId;
    }
    return _trailerCache[_cacheKey(item)];
  }

  bool get _hasTrailerForCurrent {
    if (widget.items.isEmpty) return false;
    final item = widget.items[_index % widget.items.length];
    final key = _resolveTrailerKey(item);
    return key != null && key.isNotEmpty;
  }

  void _armTrailerForCurrent({bool immediate = false}) {
    _armTimer?.cancel();
    _fallbackTimer?.cancel();
    if (!_active || widget.items.isEmpty) return;
    final item = widget.items[_index % widget.items.length];
    final key = _cacheKey(item);

    if (!_inTest &&
        (item.trailerYoutubeId == null || item.trailerYoutubeId!.isEmpty) &&
        !_trailerCache.containsKey(key)) {
      _resolveTrailer(item);
    }

    void arm() {
      if (!mounted || !_active) return;
      setState(() {
        _trailerArmed = true;
        if (_inTest) {
          _trailerReady = true;
          if (_hasTrailerForCurrent) {
            _startTimer(duration: _trailerHoldDuration);
          }
        }
      });
      if (!_inTest) {
        _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && !_trailerReady) {
            _onTrailerLoaded();
          }
        });
      }
    }

    // On initial mount or in tests, arm immediately to eliminate dead startup
    // delay. On carousel navigation, use a short 350ms dwell to absorb rapid
    // flicking between dots without mounting unnecessary iframes.
    if (immediate || _inTest) {
      arm();
    } else {
      _armTimer = Timer(const Duration(milliseconds: 350), arm);
    }
  }

  void _onTrailerLoaded() {
    _fallbackTimer?.cancel();
    if (mounted && _active) {
      setState(() => _trailerReady = true);
      // Give Clair 25 full seconds of uninterrupted trailer playback starting
      // only after the video has actually loaded and began playing.
      if (_muted && _playing) {
        _startTimer(duration: _trailerHoldDuration);
      }
    }
  }

  Future<void> _resolveTrailer(MediaItem item) async {
    if (item.source == 'tmdb') return;
    final key = _cacheKey(item);
    if (_trailerCache.containsKey(key)) return;
    try {
      final detail = await AniListService().fetchDetailsWithFallback(
        anilistId: item.anilistId,
        malId: item.tmdbId,
      );
      final ytId = detail?.trailerYoutubeId;
      if (mounted) {
        setState(() {
          _trailerCache[key] = ytId;
          if (_active && _trailerArmed && ytId != null && ytId.isNotEmpty) {
            _trailerReady = _inTest;
            if (!_inTest) {
              _fallbackTimer?.cancel();
              _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
                if (mounted && !_trailerReady) {
                  _onTrailerLoaded();
                }
              });
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _trailerCache[key] = null;
        });
      }
    }
  }

  void _select(int i) {
    if (widget.items.isEmpty) return;
    _fallbackTimer?.cancel();
    setState(() {
      _index = i % widget.items.length;
      _trailerArmed = false;
      _trailerReady = false;
      _playing = true;
    });
    _startTimer();
    _armTrailerForCurrent();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _startTimer();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _startTimer();
  }

  void _pauseTrailer() {
    _timer?.cancel();
    _armTimer?.cancel();
    _fallbackTimer?.cancel();
    if (_playing || !_muted) {
      setState(() {
        _playing = false;
        _muted = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active == active) return;
    _active = active;
    if (active) {
      _startTimer();
      _armTrailerForCurrent(immediate: true);
    } else {
      _timer?.cancel();
      _armTimer?.cancel();
      _fallbackTimer?.cancel();
      _trailerReady = false;
    }
  }

  void _startTimer({Duration? duration}) {
    _timer?.cancel();
    // Do not auto-advance when Clair unmuted to listen or paused playback.
    if (!_active || !_muted || !_playing) return;
    final hold =
        duration ??
        (_hasTrailerForCurrent && _trailerReady
            ? _trailerHoldDuration
            : _stillHoldDuration);
    _timer = Timer(hold, () {
      if (!mounted || widget.items.length < 2) return;
      _select((_index + 1) % widget.items.length);
    });
  }

  @override
  void didUpdateWidget(covariant AnimeXSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length ||
        !_sameItems(widget.items, oldWidget.items)) {
      if (widget.items.isEmpty) {
        _index = 0;
      } else {
        _index = _index % widget.items.length;
      }
      _trailerArmed = false;
      _trailerReady = false;
      _fallbackTimer?.cancel();
      _startTimer();
      _armTrailerForCurrent(immediate: true);
    }
  }

  bool _sameItems(List<MediaItem> a, List<MediaItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tmdbId != b[i].tmdbId) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _armTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (widget.loading || items.isEmpty) {
      return _buildSkeleton();
    }

    final activeIndex = items.isEmpty ? 0 : _index % items.length;
    final active = items[activeIndex];
    final trailerKey = _resolveTrailerKey(active);
    final hasTrailer = trailerKey != null && trailerKey.isNotEmpty;

    return Container(
      constraints: BoxConstraints(minHeight: _heroHeight(context)),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: AnimeXTokens.bg),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Keep only the current backdrop (plus the outgoing fade), not
          // five full-resolution images with four hidden at zero opacity.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              // The default switcher stack loosens constraints, letting banners
              // and poster fallbacks shrink to their decoded image dimensions.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              ),
              child: _SlideLayer(
                key: ValueKey(_cacheKey(active)),
                item: active,
              ),
            ),
          ),

          // 2. Active trailer player, smoothly cross-faded in when loaded.
          if (_active && hasTrailer && _trailerArmed)
            Positioned.fill(
              child: AnimatedOpacity(
                key: ValueKey('hero-trailer-layer-$trailerKey'),
                opacity: (_trailerReady && _playing) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  child: KeyedSubtree(
                    key: ValueKey('hero-trailer-$trailerKey'),
                    child: TrailerPlayer(
                      videoKey: trailerKey,
                      muted: _muted,
                      playing: _playing,
                      autoplay: true,
                      loop: true,
                      onLoaded: _onTrailerLoaded,
                    ),
                  ),
                ),
              ),
            ),

          // Top shade for header legibility, fading into the page bg at the
          // bottom so the hero melts into the ticker below.
          const Positioned.fill(
            child: DecoratedBox(
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
          ),
          const Positioned.fill(
            child: DecoratedBox(
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
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 600 ? 24 : 48,
                80,
                24,
                80,
              ),
              child: Align(
                heightFactor: 1,
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _SlideContent(
                    item: active,
                    key: ValueKey(active.tmdbId),
                    index: activeIndex,
                    hasTrailer: hasTrailer,
                    trailerReady: _trailerReady,
                    muted: _muted,
                    onWatch: (item) {
                      _pauseTrailer();
                      widget.onWatch?.call(item);
                    },
                    onMoreInfo: (item) {
                      _pauseTrailer();
                      widget.onMoreInfo?.call(item);
                    },
                    onTrailer: (item) {
                      if (hasTrailer && _muted) {
                        _toggleMute();
                      } else {
                        _pauseTrailer();
                        widget.onTrailer?.call(item);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          if (items.length > 1)
            Positioned(
              left: MediaQuery.sizeOf(context).width < 600 ? 18 : 42,
              bottom: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _HeroDot(
                      active: i == activeIndex,
                      title: 'Show ${items[i].title}',
                      onTap: () => _select(i),
                    ),
                ],
              ),
            ),
          if (hasTrailer)
            Positioned(
              right: 24,
              top: 16,
              child: _HeroMediaControls(
                playing: _playing,
                muted: _muted,
                onTogglePlay: _togglePlay,
                onToggleMute: _toggleMute,
              ),
            ),
        ],
      ),
    );
  }

  double _heroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < 600;
    final height = (size.height * (phone ? 0.68 : 0.58)).clamp(
      phone ? 500.0 : 440.0,
      phone ? 620.0 : 660.0,
    );
    return height;
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

  const _SlideLayer({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl;
    return TweenAnimationBuilder<double>(
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
    );
  }
}

class _SlideContent extends StatelessWidget {
  final MediaItem item;
  final int index;
  final bool hasTrailer;
  final bool trailerReady;
  final bool muted;
  final void Function(MediaItem)? onWatch;
  final void Function(MediaItem)? onMoreInfo;
  final void Function(MediaItem)? onTrailer;

  const _SlideContent({
    super.key,
    required this.item,
    required this.index,
    this.hasTrailer = false,
    this.trailerReady = false,
    this.muted = true,
    this.onWatch,
    this.onMoreInfo,
    this.onTrailer,
  });

  @override
  Widget build(BuildContext context) {
    final isAiring =
        item.airingStatus.toUpperCase().contains('RELEASING') ||
        item.airingStatus.toUpperCase().contains('AIRING');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: bebasStyle(
            size: MediaQuery.sizeOf(context).width < 600 ? 38 : 60,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '#${index + 1} TRENDING',
              style: dmSansStyle(
                size: 12,
                color: AnimeXTokens.accentWarm,
                weight: FontWeight.w700,
              ),
            ),
            if (isAiring)
              Text(
                'Airing Now',
                style: dmSansStyle(
                  size: 12,
                  color: AnimeXTokens.success,
                  weight: FontWeight.w600,
                ),
              ),
            if (item.score != null && item.score! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AnimeXTokens.gold,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.score!.toStringAsFixed(1),
                    style: dmSansStyle(size: 13, weight: FontWeight.w700),
                  ),
                ],
              ),
            if (item.year.isNotEmpty) _metadata(item.year),
            if (item.format.isNotEmpty) _metadata(item.format),
            if (item.episodeCount != null && item.episodeCount! > 0)
              _metadata('${item.episodeCount} episodes'),
          ],
        ),
        if (item.genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            item.genres.take(3).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: dmSansStyle(size: 13, color: AnimeXTokens.white85),
          ),
        ],
        if (item.synopsis.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            item.synopsis,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: interBodyStyle(
              size: 14,
              height: 1.55,
              color: AnimeXTokens.white85,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AnimeXWatchNowButton(
              label: 'Watch Now',
              onTap: () => onWatch?.call(item),
            ),
            AnimeXSecondaryButton(
              label: 'More Info',
              icon: Icons.info_outline_rounded,
              onTap: () => onMoreInfo?.call(item),
            ),
            AnimeXGhostButton(
              label: hasTrailer && !muted ? 'Full Trailer' : 'Trailer',
              icon: hasTrailer
                  ? (muted ? Icons.volume_off_rounded : Icons.volume_up_rounded)
                  : Icons.play_circle_outline_rounded,
              color: AnimeXTokens.white85,
              onTap: () => onTrailer?.call(item),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metadata(String label) =>
      Text(label, style: dmSansStyle(size: 13, color: AnimeXTokens.white85));
}

class _HeroDot extends StatelessWidget {
  final bool active;
  final String title;
  final VoidCallback onTap;

  const _HeroDot({
    required this.active,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      child: IconButton(
        tooltip: title,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: active ? 28 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: active
                ? AnimeXTokens.textPrimary
                : AnimeXTokens.textSecondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Trailer controls stay over the artwork, separate from carousel navigation.
class _HeroMediaControls extends StatelessWidget {
  final bool playing;
  final bool muted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;

  const _HeroMediaControls({
    required this.playing,
    required this.muted,
    required this.onTogglePlay,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeroControlButton(
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: playing ? 'Pause trailer' : 'Play trailer',
            onTap: onTogglePlay,
          ),
          const SizedBox(width: 4),
          _HeroControlButton(
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            tooltip: muted ? 'Unmute trailer' : 'Mute trailer',
            highlighted: !muted,
            onTap: onToggleMute,
          ),
        ],
      ),
    );
  }
}

class _HeroControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  const _HeroControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AnimeXTokens.textPrimary,
        backgroundColor: highlighted
            ? AnimeXTokens.accent.withValues(alpha: 0.3)
            : Colors.transparent,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}
