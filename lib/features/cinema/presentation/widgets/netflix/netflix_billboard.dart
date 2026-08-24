import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import '../trailer_player.dart';
import 'netflix_colors.dart';

/// Full-bleed billboard hero - the Netflix opening shot.
///
/// A single featured title fills the viewport with its backdrop (or a
/// muted autoplaying trailer), cinematic scrims, a title block with
/// Play / More Info actions, and a soft crossfade cycle between titles.
class NetflixBillboard extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onPlay;
  final void Function(MediaItem) onInfo;

  const NetflixBillboard({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  State<NetflixBillboard> createState() => _NetflixBillboardState();
}

class _NetflixBillboardState extends State<NetflixBillboard> {
  static const _hold = Duration(seconds: 14);
  static final Map<String, String?> _trailerCache = {};
  static final Map<String, Map<String, dynamic>> _detailCache = {};

  TMDBService? _tmdbService;

  TMDBService get _service => _tmdbService ??= TMDBService();
  int _index = 0;
  Timer? _timer;
  bool _muted = true;
  bool _ready = false;

  MediaItem get _item => widget.items[_index];

  String? get _trailerKey =>
      _trailerCache['${_item.tmdbId}:${_item.mediaType}'];

  Map<String, dynamic>? get _details =>
      _detailCache['${_item.tmdbId}:${_item.mediaType}'];

  @override
  void initState() {
    super.initState();
    _startCycle();
    if (widget.items.isNotEmpty) {
      _loadFor(_index);
    }
  }

  @override
  void didUpdateWidget(covariant NetflixBillboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items && widget.items.isNotEmpty) {
      _index = 0;
      _startCycle();
      _loadFor(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCycle() {
    _timer?.cancel();
    _timer = Timer(_hold, () {
      if (!mounted || widget.items.length < 2) return;
      _select((_index + 1) % widget.items.length);
    });
  }

  void _select(int index) {
    setState(() => _index = index);
    _startCycle();
    _loadFor(index);
  }

  Future<void> _loadFor(int index) {
    if (index < 0 || index >= widget.items.length) return Future.value();
    final item = widget.items[index];
    final key = '${item.tmdbId}:${item.mediaType}';
    if (_trailerCache.containsKey(key) && _detailCache.containsKey(key)) {
      setState(() => _ready = true);
      return Future.value();
    }
    return Future.wait([
      _ensureTrailer(item, key),
      _ensureDetails(item, key),
    ]).then((_) {
      if (mounted && index == _index) setState(() => _ready = true);
    });
  }

  Future<void> _ensureTrailer(MediaItem item, String key) async {
    if (_trailerCache.containsKey(key)) return;
    try {
      final k = await _service.fetchTrailerKey(item.tmdbId, item.mediaType);
      _trailerCache[key] = k;
    } catch (_) {
      _trailerCache[key] = null;
    }
  }

  Future<void> _ensureDetails(MediaItem item, String key) async {
    if (_detailCache.containsKey(key)) return;
    try {
      final details = await _service.fetchMediaDetails(
        item.tmdbId,
        item.mediaType,
      );
      _detailCache[key] = details ?? {};
    } catch (_) {
      _detailCache[key] = {};
    }
  }

  String? get _runtime {
    final d = _details;
    if (d == null) return null;
    final movieRuntime = d['runtime'] as num?;
    if (movieRuntime != null && movieRuntime > 0) {
      final hours = movieRuntime ~/ 60;
      final mins = movieRuntime % 60;
      return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }
    final eps = d['episode_run_time'] as List?;
    if (eps is List && eps.isNotEmpty) {
      final runtime = (eps.first as num?)?.toInt() ?? 0;
      if (runtime > 0) return '${runtime}m';
    }
    return null;
  }

  String get _synopsis {
    if (_item.synopsis.isNotEmpty) return _item.synopsis;
    final overview = _details?['overview'] as String?;
    if (overview != null && overview.isNotEmpty) return overview;
    return '';
  }

  double get _voteAverage {
    final v = _details?['vote_average'] as num?;
    if (v == null || v <= 0) return 0;
    return v.toDouble();
  }

  int get _matchPercent {
    final v = _voteAverage;
    if (v <= 0) return 0;
    return (v * 10).round().clamp(50, 99);
  }

  String get _backdropUrl {
    if (_item.backdropUrl.isNotEmpty) return _item.backdropUrl;
    return _item.posterUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final height = isDesktop
        ? 560.0
        : (MediaQuery.sizeOf(context).height * 0.58).clamp(380.0, 540.0);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.orZero(const Duration(milliseconds: 700)),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildMedia(isDesktop),
          ),
          // Bottom scrim into page background.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x33100912),
                    NetflixColors.background,
                  ],
                  stops: [0.0, 0.42, 0.72, 1.0],
                ),
              ),
            ),
          ),
          // Left scrim for text legibility.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xB30A0710),
                    Color(0x590A0710),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.35, 0.75],
                ),
              ),
            ),
          ),
          Positioned(
            left: isDesktop ? 48 : 16,
            right: isDesktop ? 48 : 16,
            bottom: 54,
            child: _buildContent(isDesktop),
          ),
          if (_trailerKey != null)
            Positioned(
              right: isDesktop ? 48 : 16,
              bottom: 62,
              child: _MuteButton(
                muted: _muted,
                onToggle: () => setState(() => _muted = !_muted),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? NetflixColors.accent
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(bool isDesktop) {
    return KeyedSubtree(
      key: ValueKey('billboard-${_item.tmdbId}-$isDesktop'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_trailerKey != null && _ready)
            TrailerPlayer(
              videoKey: _trailerKey!,
              muted: _muted,
              autoplay: true,
              loop: true,
            )
          else if (_backdropUrl.isNotEmpty)
            Image.network(
              _backdropUrl,
              fit: BoxFit.cover,
              cacheWidth: 1600,
              errorBuilder: (_, _, _) =>
                  Container(color: NetflixColors.surface),
            )
          else
            Container(color: NetflixColors.surface),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDesktop) {
    return KeyedSubtree(
      key: ValueKey('billboard-content-${_item.tmdbId}'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 620 : double.infinity,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDesktop)
              Row(
                children: [
                  if (_matchPercent > 0)
                    Text(
                      '$_matchPercent% Match',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 14,
                        color: NetflixColors.match,
                      ),
                    ),
                  if (_item.year.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _MetaText(_item.year),
                  ],
                  if (_runtime != null) ...[
                    const SizedBox(width: 10),
                    _MetaText(_runtime!),
                  ],
                  if (_item.mediaType == 'movie') ...[
                    const SizedBox(width: 10),
                    const _HdBadge(),
                  ],
                  if (_item.mediaType == 'tv') ...[
                    const SizedBox(width: 10),
                    const _MetaText('Series'),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            Text(
              _item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: isDesktop ? 46 : 32,
                height: 1.02,
                letterSpacing: 0.2,
                shadows: const [
                  Shadow(color: Color(0xAA000000), blurRadius: 18),
                ],
                color: NetflixColors.textPrimary,
              ),
            ),
            if (isDesktop && _synopsis.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _synopsis,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitMuted.copyWith(
                  fontSize: 14.5,
                  color: NetflixColors.textSecondary,
                  height: 1.4,
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 10),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BillboardButton.primary(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  onTap: () => widget.onPlay(_item),
                ),
                const SizedBox(width: 12),
                _BillboardButton.secondary(
                  label: 'More Info',
                  icon: Icons.info_outline_rounded,
                  onTap: () => widget.onInfo(_item),
                ),
              ],
            ),
          ],
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
        fontSize: 13,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

class _HdBadge extends StatelessWidget {
  const _HdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'HD',
        style: AppTypography.outfitHeading.copyWith(
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onToggle;
  const _MuteButton({required this.muted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Icon(
          muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _BillboardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _BillboardButton.primary({
    required this.label,
    required this.icon,
    required this.onTap,
  }) : primary = true;

  const _BillboardButton.secondary({
    required this.label,
    required this.icon,
    required this.onTap,
  }) : primary = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 26 : 18,
          vertical: isDesktop ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: primary ? Colors.black : Colors.white,
              size: isDesktop ? 20 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: isDesktop ? 15 : 13.5,
                color: primary ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
