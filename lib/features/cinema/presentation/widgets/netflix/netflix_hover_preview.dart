import 'package:flutter/material.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../../shared/utils/tmdb_images.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import '../trailer_player.dart';
import 'netflix_colors.dart';

/// In-memory cache of TMDB detail maps keyed by `tmdbId:mediaType` so the
/// hover popover only fetches each title once per session.
final Map<String, Map<String, dynamic>> _netflixDetailCache = {};

/// Session cache of YouTube trailer keys (`tmdbId:mediaType` -> key).
/// A stored null means "looked up, has no trailer" so repeat hovers
/// never re-request titles without videos.
final Map<String, String?> _netflixTrailerCache = {};

/// Starts fetching the trailer + details for [item] before the preview
/// opens, so hover feels instant. Safe to call repeatedly — cached
/// titles return immediately. Rows and cards call this on hover-enter
/// (before the 260ms popover delay) so the preview usually opens with
/// the key already cached.
Future<void> prefetchNetflixPreview(MediaItem item) async {
  final key = '${item.tmdbId}:${item.mediaType}';
  // Anime items already carry their YouTube id — no TMDB lookup needed.
  final embedded = item.trailerYoutubeId;
  if (embedded != null && embedded.isNotEmpty) {
    _netflixTrailerCache[key] = embedded;
  } else if (!_netflixTrailerCache.containsKey(key)) {
    try {
      final trailerKey = await TMDBService().fetchTrailerKey(
        item.tmdbId,
        item.mediaType,
      );
      // Only cache when the preview hasn't already stored a result —
      // a concurrent _loadTrailer may have finished first.
      _netflixTrailerCache.putIfAbsent(key, () => trailerKey);
    } catch (_) {
      // Leave uncached so the preview itself can retry.
    }
  }
  if (item.synopsis.isEmpty && !_netflixDetailCache.containsKey(key)) {
    try {
      final details = await TMDBService().fetchMediaDetails(
        item.tmdbId,
        item.mediaType,
      );
      _netflixDetailCache.putIfAbsent(key, () => details ?? {});
    } catch (_) {
      // Preview falls back to the row payload when details miss.
    }
  }
}

/// Estimated popover height for a given width. Kept in one place so the
/// row, grid card, and position helper agree.
double netflixPreviewHeight(double width) => width * 0.5625 + 232;

/// Computes a viewport-safe top-left position for the hover popover.
///
/// Netflix-style: the preview grows centered over the anchored card,
/// covering it, clamped inside the viewport with a small margin.
Offset positionHoverPreview({
  required Rect anchor,
  required Size previewSize,
  required Size screen,
}) {
  const margin = 12.0;
  final maxLeft = (screen.width - previewSize.width - margin)
      .clamp(margin, screen.width)
      .toDouble();
  final left = (anchor.center.dx - previewSize.width / 2)
      .clamp(margin, maxLeft)
      .toDouble();
  final maxTop = (screen.height - previewSize.height - margin)
      .clamp(margin, screen.height)
      .toDouble();
  final top = (anchor.center.dy - previewSize.height / 2)
      .clamp(margin, maxTop)
      .toDouble();
  return Offset(left, top);
}

/// Netflix-style hover popover with real title details.
///
/// Order matches Netflix: backdrop art, action row, metadata, title,
/// synopsis, genres. TMDB details are fetched on demand (cached) so the
/// popover never shows placeholder copy when the row payload only has
/// a poster.
class NetflixHoverPreview extends StatefulWidget {
  final MediaItem item;
  final double width;

  /// On-screen width of the card this preview grows out of. Sets the
  /// entrance scale so the popover starts at roughly card size. Null
  /// (touch dialog) keeps a subtle centered pop.
  final double? anchorWidth;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onRestart;
  final ValueChanged<bool>? onToggleList;
  final ValueChanged<double?>? onRate;
  final bool inList;

  const NetflixHoverPreview({
    super.key,
    required this.item,
    required this.width,
    this.anchorWidth,
    this.onTap,
    this.onPlay,
    this.onRestart,
    this.onToggleList,
    this.onRate,
    this.inList = false,
  });

  @override
  State<NetflixHoverPreview> createState() => _NetflixHoverPreviewState();
}

class _NetflixHoverPreviewState extends State<NetflixHoverPreview> {
  Map<String, dynamic>? _details;
  String? _trailerKey;
  bool _trailerVisible = false;
  bool _muted = true;
  late bool _inList = widget.inList;
  late double? _rating = widget.item.userRating;

  String get _cacheKey => '${widget.item.tmdbId}:${widget.item.mediaType}';

  @override
  void initState() {
    super.initState();
    if (_netflixDetailCache.containsKey(_cacheKey)) {
      _details = _netflixDetailCache[_cacheKey];
    } else if (widget.item.synopsis.isEmpty) {
      _loadDetails();
    }
    // Anime rows already know their YouTube id — play instantly.
    final embedded = widget.item.trailerYoutubeId;
    if (embedded != null && embedded.isNotEmpty) {
      _trailerKey = embedded;
      _netflixTrailerCache[_cacheKey] = embedded;
    } else if (_netflixTrailerCache.containsKey(_cacheKey)) {
      _trailerKey = _netflixTrailerCache[_cacheKey];
    } else {
      _loadTrailer();
    }
  }

  Future<void> _loadDetails() async {
    Map<String, dynamic> result = {};
    try {
      final details = await TMDBService().fetchMediaDetails(
        widget.item.tmdbId,
        widget.item.mediaType,
      );
      result = details ?? {};
    } catch (_) {
      result = {};
    }
    _netflixDetailCache[_cacheKey] = result;
    if (mounted) setState(() => _details = result);
  }

  Future<void> _loadTrailer() async {
    final embedded = widget.item.trailerYoutubeId;
    if (embedded != null && embedded.isNotEmpty) {
      _netflixTrailerCache[_cacheKey] = embedded;
      if (mounted) setState(() => _trailerKey = embedded);
      return;
    }
    String? key;
    try {
      key = await TMDBService().fetchTrailerKey(
        widget.item.tmdbId,
        widget.item.mediaType,
      );
    } catch (_) {
      key = null;
    }
    _netflixTrailerCache[_cacheKey] = key;
    if (mounted) setState(() => _trailerKey = key);
  }

  String get _backdropUrl {
    if (widget.item.backdropUrl.isNotEmpty) return widget.item.backdropUrl;
    final path = _details?['backdrop_path'];
    if (path is String && path.isNotEmpty) {
      return TmdbImages.backdropFor(path);
    }
    return widget.item.posterUrl;
  }

  double get _voteAverage =>
      (_details?['vote_average'] as num?)?.toDouble() ?? 0;

  String get _year {
    if (widget.item.year.isNotEmpty) return widget.item.year;
    final date = _details?['release_date'] ?? _details?['first_air_date'];
    if (date is String && date.length >= 4) return date.substring(0, 4);
    return '';
  }

  String? get _runtime {
    final movieRuntime = _details?['runtime'] as num?;
    if (movieRuntime != null && movieRuntime > 0) {
      final hours = movieRuntime ~/ 60;
      final mins = movieRuntime % 60;
      return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }
    final episodeTimes = _details?['episode_run_time'] as List?;
    if (episodeTimes is List && episodeTimes.isNotEmpty) {
      final runtime = (episodeTimes.first as num?)?.toInt() ?? 0;
      if (runtime > 0) return '${runtime}m';
    }
    return null;
  }

  String? get _seriesInfo {
    if (widget.item.mediaType != 'tv') return null;
    final seasons = _details?['number_of_seasons'] as num?;
    final episodes = _details?['number_of_episodes'] as num?;
    if (seasons != null && seasons > 0 && episodes != null && episodes > 0) {
      return '$seasons Season${seasons == 1 ? '' : 's'}';
    }
    if (seasons != null && seasons > 0) {
      return '$seasons Season${seasons == 1 ? '' : 's'}';
    }
    return null;
  }

  String get _synopsis {
    if (widget.item.synopsis.isNotEmpty) return widget.item.synopsis;
    final overview = _details?['overview'] as String?;
    if (overview != null && overview.trim().isNotEmpty) return overview.trim();
    return '${widget.item.mediaType == 'movie' ? 'Movie' : 'Series'}'
        '${_year.isNotEmpty ? ' from $_year' : ''}. '
        'Tap for details, episodes, cast and more.';
  }

  List<String> get _genres {
    if (widget.item.genres.isNotEmpty) return widget.item.genres;
    final genres = _details?['genres'] as List?;
    if (genres == null) return const [];
    return genres
        .whereType<Map>()
        .map((g) => (g['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  /// True while TMDB details are still resolving and the row payload has
  /// no synopsis to show yet. The popover renders animated shimmer
  /// placeholders instead of the fallback copy so hover never looks dead.
  bool get _loadingDetails =>
      _details == null && widget.item.synopsis.isEmpty;

  @override
  Widget build(BuildContext context) {
    // Netflix grow: the preview starts at roughly the card's size and
    // expands to full size, centered over the card (the overlay position
    // keeps the centers aligned, so scaling from the center reads as
    // growing out of the poster itself).
    final anchorWidth = widget.anchorWidth;
    final begin =
        (anchorWidth == null || anchorWidth <= 0 || widget.width <= 0
                ? 0.92
                : (anchorWidth / widget.width).clamp(0.45, 0.8))
            .toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Opacity(
          opacity: ((scale - begin) / (1.0 - begin)).clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          explicitChildNodes: true,
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: NetflixColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Backdrop art melts into the card body ──
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_backdropUrl.isNotEmpty)
                        AppNetworkImage(
                          imageUrl: _backdropUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 720,
                          errorWidget: Container(color: NetflixColors.surface),
                        )
                      else
                        Container(color: NetflixColors.surface),
                      // Muted trailer fades in over the still once it is
                      // ready, Netflix-style. The still stays mounted
                      // underneath as the loading/fallback frame.
                      if (_trailerKey != null)
                        AnimatedOpacity(
                          opacity: _trailerVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 450),
                          child: TrailerPlayer(
                            videoKey: _trailerKey!,
                            muted: _muted,
                            autoplay: true,
                            loop: true,
                            onLoaded: () {
                              if (mounted) {
                                setState(() => _trailerVisible = true);
                              }
                            },
                          ),
                        ),
                      // Blend image into the body so there is no hard cut.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                              NetflixColors.surfaceElevated.withValues(
                                alpha: 0.0,
                              ),
                              NetflixColors.surfaceElevated,
                            ],
                            stops: const [0.0, 0.45, 0.82, 1.0],
                          ),
                        ),
                      ),
                      // Title treatment over the art, like Netflix. Steps
                      // aside once the trailer fades in.
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 10,
                        child: AnimatedOpacity(
                          opacity: _trailerVisible ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 16,
                              letterSpacing: 0.2,
                              shadows: const [
                                Shadow(
                                  color: Color(0xCC000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_trailerKey != null && _trailerVisible)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _HoverActionButton(
                            icon: _muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            tooltip: _muted ? 'Unmute' : 'Mute',
                            onTap: () => setState(() => _muted = !_muted),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Actions first: Play leads, info docks right ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HoverActionButton.play(onTap: widget.onPlay),
                          _HoverActionButton(
                            icon: _inList
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            tooltip: _inList ? 'In My List' : 'Add to My List',
                            onTap: widget.onToggleList == null
                                ? null
                                : () {
                                    final next = !_inList;
                                    setState(() => _inList = next);
                                    widget.onToggleList?.call(next);
                                  },
                          ),
                          _HoverActionButton(
                            icon: _rating == 1
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            selected: _rating == 1,
                            tooltip: 'I like this',
                            onTap: widget.onRate == null
                                ? null
                                : () {
                                    final next = _rating == 1 ? null : 1.0;
                                    setState(() => _rating = next);
                                    widget.onRate?.call(next);
                                  },
                          ),
                          _HoverActionButton(
                            icon: _rating == -1
                                ? Icons.thumb_down_rounded
                                : Icons.thumb_down_outlined,
                            selected: _rating == -1,
                            tooltip: 'Not for me',
                            onTap: widget.onRate == null
                                ? null
                                : () {
                                    final next = _rating == -1 ? null : -1.0;
                                    setState(() => _rating = next);
                                    widget.onRate?.call(next);
                                  },
                          ),
                          _HoverActionButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            tooltip: 'Details for ${widget.item.title}',
                            onTap: widget.onTap,
                          ),
                        ],
                      ),
                      if (widget.onRestart != null)
                        TextButton.icon(
                          onPressed: widget.onRestart,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: NetflixColors.textPrimary,
                          ),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Restart'),
                        ),
                      const SizedBox(height: 12),
                      // ── Metadata ──
                      if (_loadingDetails &&
                          _voteAverage == 0 &&
                          _year.isEmpty &&
                          _runtime == null &&
                          _seriesInfo == null)
                        const Row(
                          children: [
                            EverglowSkeleton(
                              width: 70,
                              height: 12,
                              radius: 6,
                            ),
                            SizedBox(width: 8),
                            EverglowSkeleton(
                              width: 50,
                              height: 12,
                              radius: 6,
                            ),
                            SizedBox(width: 8),
                            _HdBadge(),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_voteAverage > 0)
                              Text(
                                'TMDB ${_voteAverage.toStringAsFixed(1)}/10',
                                style: AppTypography.outfitHeading.copyWith(
                                  fontSize: 13,
                                  color: NetflixColors.textSecondary,
                                ),
                              ),
                            if (_year.isNotEmpty) _MetaText(_year),
                            if (_runtime != null) _MetaText(_runtime!),
                            if (_seriesInfo != null) _MetaText(_seriesInfo!),
                            const _HdBadge(),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (_loadingDetails)
                        const EverglowLoadingBars()
                      else
                        Text(
                          _synopsis,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitMedium.copyWith(
                            fontSize: 12.5,
                            color: NetflixColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      if (_loadingDetails) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            EverglowSkeleton(
                              width: 52,
                              height: 10,
                              radius: 5,
                            ),
                            SizedBox(width: 8),
                            EverglowSkeleton(
                              width: 68,
                              height: 10,
                              radius: 5,
                            ),
                            SizedBox(width: 8),
                            EverglowSkeleton(
                              width: 44,
                              height: 10,
                              radius: 5,
                            ),
                          ],
                        ),
                      ] else if (_genres.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (
                              var i = 0;
                              i < _genres.take(3).length;
                              i++
                            ) ...[
                              if (i > 0)
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: NetflixColors.textMuted.withValues(
                                      alpha: 0.7,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                _genres[i],
                                style: AppTypography.outfitMuted.copyWith(
                                  fontSize: 11,
                                  color: NetflixColors.textSecondary.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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

class _MetaText extends StatelessWidget {
  final String text;
  const _MetaText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.outfitMedium.copyWith(
        fontSize: 12,
        color: NetflixColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _HdBadge extends StatelessWidget {
  const _HdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        border: Border.all(
          color: NetflixColors.textSecondary.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'HD',
        style: AppTypography.outfitHeading.copyWith(
          fontSize: 9,
          color: NetflixColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HoverActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final bool isPlay;
  final VoidCallback? onTap;

  const _HoverActionButton({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.onTap,
  }) : isPlay = false;

  const _HoverActionButton.play({this.onTap})
    : icon = Icons.play_arrow_rounded,
      tooltip = 'Play',
      isPlay = true,
      selected = false;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    style: IconButton.styleFrom(
      fixedSize: const Size(48, 48),
      backgroundColor: isPlay || selected ? NetflixColors.textPrimary : null,
      foregroundColor: isPlay || selected
          ? NetflixColors.background
          : NetflixColors.textPrimary,
      side: const BorderSide(color: NetflixColors.textSecondary),
    ),
    icon: Icon(icon, size: isPlay ? 26 : 22),
  );
}
