import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';

import 'animex_badges.dart';
import 'animex_tokens.dart';

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

  void _enter() {
    _pointerInsideCard = true;
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
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_active == this) _active = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final episodeCount = item.episodeCount;

    // The overlay portal renders the popover in the app overlay so it never
    // gets clipped by the horizontal scrollable it lives inside. The overlay
    // hands its children tight full-screen constraints, so the popover is
    // wrapped in an Align: Align keeps its own full-size box (for positioning)
    // but lays out the popover with loose constraints, letting the panel keep
    // its compact 190px size instead of stretching across the screen.
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
            child: _CardPopover(item: item, score: widget.score),
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
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                      boxShadow: const [],
                    ),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _posterImage(item),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x66000000),
                                    Color(0xB3000000),
                                  ],
                                  stops: [0.45, 0.8, 1],
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
                                      label: widget.episodeLabel ??
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
                                      dot: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (widget.score != null && widget.hoverAction == null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: AnimeXBadge(
                                  label: _formatScore(widget.score!),
                                  kind: AnimeXBadgeKind.rating,
                                ),
                              ),
                            if (widget.hoverAction != null && _hover)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: widget.hoverAction!,
                              ),
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.airingStatus.isNotEmpty &&
                                      _isAiring(item.airingStatus))
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 6),
                                      child: AnimeXBadge(
                                        label: 'Airing',
                                        kind: AnimeXBadgeKind.airing,
                                        dot: true,
                                      ),
                                    ),
                                  if (widget.progress != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: widget.progress!.clamp(0.0, 1.0),
                                        minHeight: 3,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.15),
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
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: dmSansStyle(
                  size: 13,
                  color: AnimeXTokens.textPrimary,
                  weight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _metaLine(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dmSansStyle(
                  size: 11.5,
                  color: AnimeXTokens.textSecondary,
                  weight: FontWeight.w400,
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
        child: Icon(
          Icons.movie_creation_outlined,
          color: AnimeXTokens.textMuted,
          size: 28,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 400,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
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
        );
      },
      errorBuilder: (_, _, _) => Container(
        color: AnimeXTokens.surfaceRaised,
        alignment: Alignment.center,
        child: Icon(
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
  static const double width = 190;

  final MediaItem item;
  final double? score;

  const _CardPopover({required this.item, this.score});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: width, maxHeight: 220),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AnimeXTokens.surfaceRaised,
          border: Border.all(color: AnimeXTokens.border),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusXl),
          boxShadow: const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: dmSansStyle(
              size: 13,
              color: AnimeXTokens.textPrimary,
              weight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          if (score != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AnimeXTokens.accentWarm,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatScore(score!),
                  style: dmSansStyle(
                    size: 13.5,
                    color: AnimeXTokens.accentWarm,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (item.genres.isNotEmpty) ...[
            Text(
              item.genres.take(3).join(' · ').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dmSansStyle(
                size: 10.5,
                color: AnimeXTokens.textMuted,
                weight: FontWeight.w600,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (item.synopsis.isNotEmpty) ...[
            Text(
              item.synopsis,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: interBodyStyle(size: 11.5, height: 1.5),
            ),
            const SizedBox(height: 6),
          ],
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AnimeXTokens.border)),
            ),
            child: Text(
              _popoverMeta(),
              style: dmSansStyle(
                size: 10.5,
                color: AnimeXTokens.textMuted,
                weight: FontWeight.w500,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  String _popoverMeta() {
    final parts = <String>[
      if (item.episodeCount != null && item.episodeCount! > 0)
        'EP ${item.episodeCount}',
      if (item.year.isNotEmpty) item.year,
      if (item.format.isNotEmpty) item.format,
    ];
    return parts.join(' · ');
  }
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

String _formatScore(double score) {
  final v = score.toStringAsFixed(1);
  return '$v / 10';
}
