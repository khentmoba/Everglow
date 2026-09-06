import 'package:flutter/material.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import 'netflix_colors.dart';

/// In-memory cache of TMDB detail maps keyed by `tmdbId:mediaType` so the
/// hover popover only fetches each title once per session.
final Map<String, Map<String, dynamic>> _netflixDetailCache = {};

/// Estimated popover height for a given width. Kept in one place so the
/// row, grid card, and position helper agree.
double netflixPreviewHeight(double width) => width * 0.5625 + 232;

/// Computes a viewport-safe top-left position for the hover popover.
///
/// Prefers floating above the anchored card (Netflix behavior). When there
/// is not enough room above (first rail, near the billboard) it drops
/// below the card instead of clamping over the hero text.
Offset positionHoverPreview({
  required Rect anchor,
  required Size previewSize,
  required Size screen,
}) {
  var left = anchor.center.dx - previewSize.width / 2;
  final maxLeft =
      (screen.width - previewSize.width - 12).clamp(12.0, screen.width)
          .toDouble();
  left = left.clamp(12.0, maxLeft);

  const topChrome = 76.0;
  final above = anchor.top - previewSize.height - 10;
  final below = anchor.bottom + 10;
  double top;
  if (above >= topChrome) {
    top = above;
  } else if (below + previewSize.height <= screen.height - 8) {
    top = below;
  } else {
    top = (screen.height - previewSize.height - 8).clamp(8.0, screen.height);
  }
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
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final ValueChanged<bool>? onToggleList;
  final ValueChanged<double?>? onRate;
  final bool inList;

  const NetflixHoverPreview({
    super.key,
    required this.item,
    required this.width,
    this.onTap,
    this.onPlay,
    this.onToggleList,
    this.onRate,
    this.inList = false,
  });

  @override
  State<NetflixHoverPreview> createState() => _NetflixHoverPreviewState();
}

class _NetflixHoverPreviewState extends State<NetflixHoverPreview> {
  Map<String, dynamic>? _details;
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

  String get _backdropUrl {
    if (widget.item.backdropUrl.isNotEmpty) return widget.item.backdropUrl;
    final path = _details?['backdrop_path'];
    if (path is String && path.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w780$path';
    }
    return widget.item.posterUrl;
  }

  int get _matchPercent {
    final vote = _details?['vote_average'] as num?;
    if (vote == null || vote <= 0) return 0;
    return (vote * 10).round().clamp(50, 99);
  }

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

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Opacity(
          opacity: ((scale - 0.96) / 0.04).clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
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
                          errorWidget: Container(
                            color: NetflixColors.surface,
                          ),
                        )
                      else
                        Container(color: NetflixColors.surface),
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
                      // Title treatment over the art, like Netflix.
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 10,
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
                      Row(
                        children: [
                          _HoverActionButton.play(
                            onTap: () {
                              widget.onTap?.call();
                              widget.onPlay?.call();
                            },
                          ),
                          const SizedBox(width: 8),
                          _HoverActionButton(
                            icon: _inList
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            tooltip: _inList ? 'In My List' : 'Add to My List',
                            onTap: () {
                              final next = !_inList;
                              setState(() => _inList = next);
                              widget.onToggleList?.call(next);
                            },
                          ),
                          const SizedBox(width: 8),
                          _HoverActionButton(
                            icon: _rating == 1
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            selected: _rating == 1,
                            tooltip: 'I like this',
                            onTap: () {
                              final next = _rating == 1 ? null : 1.0;
                              setState(() => _rating = next);
                              widget.onRate?.call(next);
                            },
                          ),
                          const SizedBox(width: 8),
                          _HoverActionButton(
                            icon: _rating == -1
                                ? Icons.thumb_down_rounded
                                : Icons.thumb_down_outlined,
                            selected: _rating == -1,
                            tooltip: 'Not for me',
                            onTap: () {
                              final next = _rating == -1 ? null : -1.0;
                              setState(() => _rating = next);
                              widget.onRate?.call(next);
                            },
                          ),
                          const Spacer(),
                          _HoverActionButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            tooltip: 'More Info',
                            onTap: widget.onTap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ── Metadata ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_matchPercent > 0)
                            Text(
                              '$_matchPercent% Match',
                              style: AppTypography.outfitHeading.copyWith(
                                fontSize: 13,
                                color: NetflixColors.match,
                              ),
                            ),
                          if (_year.isNotEmpty)
                            _MetaText(_year),
                          if (_runtime != null) _MetaText(_runtime!),
                          if (_seriesInfo != null) _MetaText(_seriesInfo!),
                          const _HdBadge(),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                      if (_genres.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0;
                                i < _genres.take(3).length;
                                i++) ...[
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

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final bool isPlay;
  final VoidCallback? onTap;

  const _HoverActionButton({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.isPlay = false,
    this.onTap,
  });

  factory _HoverActionButton.play({VoidCallback? onTap}) =>
      const _HoverActionButton(
        icon: Icons.play_arrow_rounded,
        tooltip: 'Play',
        isPlay: true,
      )._withTap(onTap);

  _HoverActionButton _withTap(VoidCallback? tap) => _HoverActionButton(
    icon: icon,
    tooltip: tooltip,
    selected: selected,
    isPlay: isPlay,
    onTap: tap,
  );

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isPlay = widget.isPlay;
    final size = isPlay ? 38.0 : 34.0;
    final bg = isPlay
        ? (_hovered
              ? AppColors.petalWhite.withValues(alpha: 0.92)
              : AppColors.petalWhite)
        : (widget.selected || _pressed
              ? AppColors.petalWhite
              : (_hovered
                    ? AppColors.petalWhite.withValues(alpha: 0.14)
                    : Colors.transparent));
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: widget.onTap == null
              ? null
              : (_) {
                  setState(() => _pressed = false);
                  widget.onTap?.call();
                },
          onTapCancel: widget.onTap == null
              ? null
              : () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: isPlay
                  ? Border.all(color: AppColors.petalWhite, width: 2)
                  : Border.all(
                      color: AppColors.petalWhite.withValues(
                        alpha: widget.selected || _hovered ? 0.9 : 0.45,
                      ),
                      width: 1.5,
                    ),
              boxShadow: isPlay
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: isPlay ? 24 : 17,
              color: isPlay || widget.selected || _pressed
                  ? Colors.black.withValues(alpha: 0.9)
                  : AppColors.petalWhite,
            ),
          ),
        ),
      ),
    );
  }
}
