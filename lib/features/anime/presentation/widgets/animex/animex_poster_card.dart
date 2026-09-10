import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../cinema/data/models/media_item.dart';
import '../../../data/services/anilist_service.dart';

import 'animex_badges.dart';
import 'animex_tokens.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/app_network_image.dart';

/// Poster card used across the anime section rows and grids. Matches the
/// reference UI: 2:3 poster with rounded corners, status/EP/rating badges,
/// a hover scale + glow, and a hover popover with score, genres, synopsis
/// and metadata that flips to the left near the right edge of the screen.
class AnimeXPosterCard extends StatefulWidget {
  final MediaItem item;
  final double width;
  final VoidCallback? onTap;

  /// Score out of 10 (0-10 scale).
  final double? score;

  /// 0..1 playback progress bar shown over the poster.
  final double? progress;

  /// Overrides the EP badge text (e.g. "EP 12").
  final String? episodeLabel;

  /// Small overlay action shown top-right on hover (e.g. remove from list).
  final Widget? hoverAction;

  const AnimeXPosterCard({
    super.key,
    required this.item,
    this.width = 175,
    this.onTap,
    this.score,
    this.progress,
    this.episodeLabel,
    this.hoverAction,
  });

  @visibleForTesting
  static void cacheResolvedForTesting(String key, MediaItem item) {
    _AnimeXPosterCardState._resolvedCache[key] = item;
  }

  @visibleForTesting
  static void clearResolvedCacheForTesting() {
    _AnimeXPosterCardState._resolvedCache.clear();
  }

  @override
  State<AnimeXPosterCard> createState() => _AnimeXPosterCardState();
}

class _AnimeXPosterCardState extends State<AnimeXPosterCard> {
  static _AnimeXPosterCardState? _active;

  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  bool _hover = false;
  bool _popoverLeft = false;
  bool _pointerInPopover = false;
  bool _pointerInsideCard = false;
  Timer? _showTimer;
  Timer? _hideTimer;

  /// Session cache of hover-enriched items, keyed by AniList (`a{id}`) or
  /// MAL (`m{id}`) id, so each anime resolves its details once.
  static final Map<String, MediaItem> _resolvedCache = {};

  /// Item enriched with lazily-fetched details, when the original is slim.
  MediaItem? _resolvedItem;
  bool _resolving = false;

  void _enter() {
    _pointerInsideCard = true;
    _maybeResolveDetails();
    _hideTimer?.cancel();
    _showTimer?.cancel();
    if (_hover) return;
    _showTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted || !_pointerInsideCard || _hover) return;
      if (_active != null && _active != this) _active!._forceHide();
      _active = this;
      setState(() => _hover = true);
      _popoverLeft = _isNearRightEdge();
      _portal.show();
    });
  }

  void _exit() {
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _pointerInPopover = false;
    _pointerInsideCard = false;
    if (_hover) {
      setState(() => _hover = false);
      if (_portal.isShowing) _portal.hide();
      if (_active == this) _active = null;
    }
  }

  void _forceHide() {
    _hideTimer?.cancel();
    _showTimer?.cancel();
    _pointerInPopover = false;
    _pointerInsideCard = false;
    if (_hover) {
      if (mounted) {
        setState(() => _hover = false);
      } else {
        _hover = false;
      }
      if (_portal.isShowing) _portal.hide();
    }
    if (_active == this) _active = null;
  }

  /// Lazily fills in missing hover details (synopsis, genres, score) for
  /// items from slim sources — history, playlists, old watchlist entries,
  /// fallbacks. Starts the moment the pointer enters so the data is
  /// usually ready by the time the popover appears.
  void _maybeResolveDetails() {
    final item = widget.item;
    if (item.synopsis.isNotEmpty && item.genres.isNotEmpty) return;
    final key = _resolveKey(item);
    if (key == null) return;
    final cached = _resolvedCache[key];
    if (cached != null) {
      if (_resolvedItem == null && mounted) {
        setState(() => _resolvedItem = cached);
      } else {
        _resolvedItem = cached;
      }
      return;
    }
    if (_resolving) return;
    _resolving = true;
    _resolveAsync(item, key);
  }

  Future<void> _resolveAsync(MediaItem item, String key) async {
    try {
      final detail = await AniListService().fetchDetailsWithFallback(
        anilistId: item.anilistId,
        malId: item.tmdbId != 0 ? item.tmdbId : null,
      );
      if (!mounted || detail == null) return;
      final enriched = item.copyWith(
        synopsis: item.synopsis.isNotEmpty ? item.synopsis : detail.synopsis,
        genres: item.genres.isNotEmpty ? item.genres : detail.genres,
        episodeCount: item.episodeCount ?? detail.episodeCount,
        airingStatus: item.airingStatus.isNotEmpty
            ? item.airingStatus
            : detail.airingStatus,
        format: item.format.isNotEmpty ? item.format : detail.format,
        studio: item.studio.isNotEmpty
            ? item.studio
            : (detail.studios.isNotEmpty
                  ? detail.studios.first
                  : item.studio),
        score: item.score ?? detail.averageScore,
        year: item.year.isNotEmpty
            ? item.year
            : (detail.seasonYear?.toString() ?? item.year),
        anilistId: item.anilistId ?? (detail.id != 0 ? detail.id : null),
      );
      _resolvedCache[key] = enriched;
      if (_hover) {
        setState(() => _resolvedItem = enriched);
      } else {
        _resolvedItem = enriched;
      }
    } catch (_) {
      // Hover keeps the slim item; the watch page retries on tap.
    } finally {
      _resolving = false;
    }
  }

  static String? _resolveKey(MediaItem item) {
    if (item.anilistId != null) return 'a${item.anilistId}';
    if (item.tmdbId != 0) return 'm${item.tmdbId}';
    return null;
  }

  void _onCardExit() {
    _pointerInsideCard = false;
    _showTimer?.cancel();
    if (!_hover) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 90), () {
      if (!_pointerInPopover) _exit();
    });
  }

  void _onPopoverEnter() {
    _pointerInPopover = true;
    _hideTimer?.cancel();
    _showTimer?.cancel();
  }

  void _onPopoverExit() {
    _pointerInPopover = false;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 80), () {
      if (!_pointerInsideCard) _exit();
    });
  }

  bool _isNearRightEdge() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final globalX = box.localToGlobal(Offset.zero).dx;
    return globalX + widget.width + _CardPopover.width + 12 > screenWidth;
  }

  @override
  void didUpdateWidget(covariant AnimeXPosterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.anilistId != widget.item.anilistId ||
        oldWidget.item.tmdbId != widget.item.tmdbId) {
      _resolvedItem = null;
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_active == this) _active = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _resolvedItem ?? widget.item;
    final episodeCount = item.episodeCount;
    final score = widget.score ?? item.score;

    // The overlay portal renders the popover in the app overlay so it never
    // gets clipped by the horizontal scrollable it lives inside. The overlay
    // hands its children tight full-screen constraints, so the popover is
    // wrapped in an Align: Align keeps its own full-size box (for positioning)
    // but lays out the popover with loose constraints, letting the panel keep
    // its compact size instead of stretching across the screen.
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (_) => CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(
          _popoverLeft ? -(_CardPopover.width + 12.0) : widget.width + 12.0,
          0,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: MouseRegion(
            onEnter: (_) => _onPopoverEnter(),
            onExit: (_) => _onPopoverExit(),
            child: _PopoverEntrance(
              fromLeft: _popoverLeft,
              child: _CardPopover(
                item: item,
                score: score,
                loadingDetails: _resolving && _resolvedItem == null,
              ),
            ),
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => _enter(),
        onExit: (_) => _onCardExit(),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CompositedTransformTarget(
                  link: _link,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                      0,
                      _hover ? -4 : 0,
                      0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AnimeXTokens.radiusCard,
                      ),
                      border: Border.all(
                        color: _hover
                            ? AnimeXTokens.accent.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: _hover
                          ? [
                              const BoxShadow(
                                color: Color(0xB3000000),
                                blurRadius: 28,
                                offset: Offset(0, 14),
                              ),
                              BoxShadow(
                                color: AnimeXTokens.accent.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AnimeXTokens.radiusCard - 1,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedScale(
                              scale: _hover ? 1.06 : 1.0,
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                              child: _posterImage(item),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.transparent,
                                    AppColors.scrimStrong,
                                    const Color(0xD9000000),
                                  ],
                                  stops: const [0, 0.4, 0.78, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Row(
                                children: [
                                  if (episodeCount != null && episodeCount > 0)
                                    AnimeXBadge(
                                      label:
                                          widget.episodeLabel ??
                                          (episodeCount >= 100
                                              ? '$episodeCount EP'
                                              : 'EP $episodeCount'),
                                      kind: AnimeXBadgeKind.episodes,
                                    ),
                                  if (item.airingStatus.isNotEmpty &&
                                      _isAiring(item.airingStatus)) ...[
                                    const SizedBox(width: 6),
                                    const AnimeXBadge(
                                      label: 'NEW',
                                      kind: AnimeXBadgeKind.newBadge,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (score != null &&
                                score > 0 &&
                                widget.hoverAction == null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimeXBadge(
                                  label: score.toStringAsFixed(1),
                                  kind: AnimeXBadgeKind.rating,
                                  icon: Icons.star_rounded,
                                ),
                              ),
                            if (widget.hoverAction != null && _hover)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: widget.hoverAction!,
                              ),
                            Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.airingStatus.isNotEmpty &&
                                      _isAiring(item.airingStatus))
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: AnimeXBadge(
                                        label: 'Airing',
                                        kind: AnimeXBadgeKind.airing,
                                        dot: true,
                                      ),
                                    ),
                                  if (widget.progress != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: widget.progress!.clamp(0.0, 1.0),
                                        minHeight: 4,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.18),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              AnimeXTokens.accent,
                                            ),
                                      ),
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
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: dmSansStyle(
                    size: 13.5,
                    color: _hover
                        ? Colors.white
                        : AnimeXTokens.textPrimary,
                    weight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _metaLine(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dmSansStyle(
                    size: 11.5,
                    color: AnimeXTokens.textSecondary,
                    weight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _posterImage(MediaItem item) {
    final url = item.posterUrl;
    if (url.isEmpty) {
      return Container(
        color: AnimeXTokens.surfaceRaised,
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_creation_outlined,
          color: AnimeXTokens.textMuted,
          size: 28,
        ),
      );
    }
    return AppNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      cacheWidth: 400,
      placeholder: Container(
        color: AnimeXTokens.surfaceRaised,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AnimeXTokens.textMuted,
          ),
        ),
      ),
      errorWidget: Container(
        color: AnimeXTokens.surfaceRaised,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AnimeXTokens.textMuted,
          size: 26,
        ),
      ),
    );
  }
}

/// The hover detail panel anchored beside the card.
class _CardPopover extends StatelessWidget {
  static double get width => AnimeXTokens.popoverWidth;

  final MediaItem item;
  final double? score;
  final bool loadingDetails;

  const _CardPopover({
    required this.item,
    this.score,
    this.loadingDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final airing =
        item.airingStatus.isNotEmpty && _isAiring(item.airingStatus);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: AnimeXTokens.popoverMaxHeight,
      ),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF23232F), Color(0xFF13131A)],
          ),
          border: Border.all(color: AnimeXTokens.glassBorder),
          borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl + 4),
          boxShadow: AnimeXTokens.popoverShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AnimeXTokens.radius2xl + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AnimeXTokens.accent,
                      AnimeXTokens.accentWarm,
                      AnimeXTokens.gold,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dmSansStyle(
                          size: 15,
                          color: Colors.white,
                          weight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (score != null && score! > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: AnimeXTokens.gold,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              score!.toStringAsFixed(1),
                              style: dmSansStyle(
                                size: 13,
                                color: AnimeXTokens.gold,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ 10',
                              style: dmSansStyle(
                                size: 11,
                                color: AnimeXTokens.textMuted,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              _popoverMeta(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: dmSansStyle(
                                size: 11.5,
                                color: AnimeXTokens.textSecondary,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.genres.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final genre in item.genres.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  genre.toUpperCase(),
                                  style: dmSansStyle(
                                    size: 9.5,
                                    color: AnimeXTokens.textSecondary,
                                    weight: FontWeight.w700,
                                    letterSpacing: 0.06,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (loadingDetails && item.synopsis.isEmpty) ...[
                        const SizedBox(height: 10),
                        const _DetailBar(widthFactor: 1),
                        const SizedBox(height: 6),
                        const _DetailBar(widthFactor: 0.82),
                        const SizedBox(height: 6),
                        const _DetailBar(widthFactor: 0.6),
                      ],
                      if (item.synopsis.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.synopsis,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: interBodyStyle(size: 12, height: 1.55),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AnimeXTokens.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: airing
                                    ? AnimeXTokens.success
                                    : AnimeXTokens.textMuted,
                                shape: BoxShape.circle,
                                boxShadow: airing
                                    ? [
                                        BoxShadow(
                                          color: AnimeXTokens.success
                                              .withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                airing
                                    ? 'Airing now'
                                    : _statusLabel(item.airingStatus),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: dmSansStyle(
                                  size: 11.5,
                                  color: airing
                                      ? AnimeXTokens.success
                                      : AnimeXTokens.textMuted,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Details →',
                              style: dmSansStyle(
                                size: 11.5,
                                color: AnimeXTokens.accentWarm,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _popoverMeta() {
    final parts = <String>[
      if (item.episodeCount != null && item.episodeCount! > 0)
        (item.episodeCount! >= 100
            ? '${item.episodeCount} EP'
            : 'EP ${item.episodeCount}'),
      if (item.year.isNotEmpty) item.year,
      if (item.format.isNotEmpty) item.format,
    ];
    return parts.join(' · ');
  }
}

/// Placeholder synopsis lines while hover details load.
class _DetailBar extends StatelessWidget {
  final double widthFactor;

  const _DetailBar({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

/// Fades + slides the popover in the moment the overlay shows it.
class _PopoverEntrance extends StatelessWidget {
  final bool fromLeft;
  final Widget child;

  const _PopoverEntrance({required this.fromLeft, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((fromLeft ? 8 : -8) * (1 - t), 0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

String _statusLabel(String status) {
  final s = status.toUpperCase();
  if (s.contains('FINISH')) return 'Completed';
  if (s.contains('NOT_YET') || s.contains('UPCOMING')) return 'Upcoming';
  if (status.isEmpty) return 'Anime';
  return status;
}

String _metaLine(MediaItem item) {
  final parts = <String>[
    if (item.year.isNotEmpty) item.year,
    if (item.format.isNotEmpty) item.format,
  ];
  if (parts.isEmpty) return 'Anime';
  return parts.join(' · ');
}

bool _isAiring(String status) {
  final s = status.toUpperCase();
  return s.contains('RELEASING') || s.contains('AIRING');
}
