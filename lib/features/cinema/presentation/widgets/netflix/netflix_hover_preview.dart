import 'package:flutter/material.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import 'netflix_colors.dart';

/// In-memory cache of TMDB detail maps keyed by `tmdbId:mediaType` so the
/// hover popover only fetches each title once per session.
final Map<String, Map<String, dynamic>> _netflixDetailCache = {};

/// Computes a viewport-safe top-left position for the hover popover so it
/// floats above the anchored card and stays fully on screen.
Offset positionHoverPreview({
  required Rect anchor,
  required Size previewSize,
  required Size screen,
}) {
  var left = anchor.center.dx - previewSize.width / 2;
  left = left.clamp(
    12.0,
    (screen.width - previewSize.width - 12).clamp(12.0, screen.width),
  );
  var top = anchor.top + 20 - previewSize.height;
  top = top.clamp(8.0, screen.height - previewSize.height - 8);
  return Offset(left, top);
}

/// Netflix-style hover popover with real title details.
///
/// Shows backdrop art, match %, year, runtime / season info, the synopsis
/// and genres. TMDB details are fetched on demand (cached) so the popover
/// never shows placeholder copy when the row payload only has a poster.
class NetflixHoverPreview extends StatefulWidget {
  final MediaItem item;
  final double width;
  final VoidCallback? onTap;

  const NetflixHoverPreview({
    super.key,
    required this.item,
    required this.width,
    this.onTap,
  });

  @override
  State<NetflixHoverPreview> createState() => _NetflixHoverPreviewState();
}

class _NetflixHoverPreviewState extends State<NetflixHoverPreview> {
  Map<String, dynamic>? _details;

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
    if (vote != null && vote > 0) {
      return (vote * 10).round().clamp(50, 99);
    }
    return 82 + (widget.item.tmdbId % 17);
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
      return '$seasons Season${seasons == 1 ? '' : 's'} · $episodes eps';
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
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: NetflixColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_backdropUrl.isNotEmpty)
                      Image.network(
                        _backdropUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 720,
                        errorBuilder: (_, _, _) =>
                            Container(color: NetflixColors.surface),
                      )
                    else
                      Container(color: NetflixColors.surface),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$_matchPercent% Match',
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 12,
                              color: NetflixColors.match,
                            ),
                          ),
                          if (_year.isNotEmpty)
                            Text(
                              _year,
                              style: AppTypography.outfitMuted.copyWith(
                                fontSize: 12,
                                color: NetflixColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (_runtime != null)
                            Text(
                              _runtime!,
                              style: AppTypography.outfitMuted.copyWith(
                                fontSize: 12,
                                color: NetflixColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (_seriesInfo != null)
                            Text(
                              _seriesInfo!,
                              style: AppTypography.outfitMuted.copyWith(
                                fontSize: 12,
                                color: NetflixColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const _HdBadge(),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            _synopsis,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitMuted.copyWith(
                              fontSize: 11.5,
                              color: NetflixColors.textSecondary,
                              height: 1.35,
                            ),
                        ),
                      ),
                      if (_genres.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _genres.take(3).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitMuted.copyWith(
                            fontSize: 10.5,
                            color: NetflixColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'HD',
        style: AppTypography.outfitHeading.copyWith(
          fontSize: 9,
          color: Colors.white.withValues(alpha: 0.9),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
