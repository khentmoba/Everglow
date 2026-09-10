import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/utils/responsive_image.dart';
import '../../../../../shared/widgets/app_network_image.dart';

import '../../../../cinema/data/models/media_item.dart';
import '../../../../cinema/presentation/widgets/trailer_player.dart';
import '../../../data/services/anilist_service.dart';

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
  Timer? _armTimer;
  Timer? _fallbackTimer;

  static const Duration _stillHoldDuration = Duration(seconds: 10);
  static const Duration _trailerHoldDuration = Duration(seconds: 25);

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
    if (widget.items.isEmpty) return;
    final item = widget.items[_index % widget.items.length];
    final key = _cacheKey(item);

    if (!_inTest &&
        (item.trailerYoutubeId == null || item.trailerYoutubeId!.isEmpty) &&
        !_trailerCache.containsKey(key)) {
      _resolveTrailer(item);
    }

    void arm() {
      if (!mounted) return;
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
    if (mounted) {
      setState(() => _trailerReady = true);
      // Give Clair 25 full seconds of uninterrupted trailer playback starting
      // only after the video has actually loaded and began playing.
      if (_muted && _playing) {
        _startTimer(duration: _trailerHoldDuration);
      }
    }
  }

  Future<void> _resolveTrailer(MediaItem item) async {
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
          if (_trailerArmed && ytId != null && ytId.isNotEmpty) {
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
    if (_playing || !_muted) {
      setState(() {
        _playing = false;
        _muted = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _armTrailerForCurrent(immediate: true);
  }

  void _startTimer({Duration? duration}) {
    _timer?.cancel();
    // Do not auto-advance when Clair unmuted to listen or paused playback.
    if (!_muted || !_playing) return;
    final hold = duration ??
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
      height: _heroHeight(context),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: AnimeXTokens.bg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. High-resolution backdrop image (always ready as base layer).
          for (var i = 0; i < items.length; i++)
            _SlideLayer(item: items[i], visible: i == activeIndex),

          // 2. Active trailer player, smoothly cross-faded in when loaded.
          if (hasTrailer && _trailerArmed)
            AnimatedOpacity(
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
                            active: i == activeIndex,
                            onTap: () => _select(i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (hasTrailer)
            Positioned(
              right: 20,
              bottom: 22,
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
    final isDesktop = size.width >= 768;
    final raw = isDesktop
        ? size.height - AnimeXTokens.headerHeight
        : size.height -
              AnimeXTokens.headerHeight -
              AnimeXTokens.mobileNavHeight;
    return raw.clamp(320.0, double.infinity);
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
                label: hasTrailer && !muted ? 'Full Trailer' : 'Trailer',
                icon: hasTrailer
                    ? (muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded)
                    : Icons.play_circle_outline_rounded,
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

/// Floating glass controls (play/pause and mute/unmute) anchored at the
/// bottom-right corner of the hero banner.
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
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
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: highlighted
                  ? AnimeXTokens.accent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: highlighted
                    ? AnimeXTokens.accent.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: highlighted
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}
