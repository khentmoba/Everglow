import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'netflix_colors.dart';
import 'netflix_hover_preview.dart';

/// Tells the owning row where this card sits on screen so a floating
/// preview can be anchored to it (Netflix-style hover popover).
typedef NetflixHoverCallback =
    void Function(bool hovered, Rect globalRect, MediaItem item);

/// Poster-only card used across the cinema rails and grids.
///
/// Mirrors Netflix's visual language:
/// * Posters are near-square-cornered artwork with no text overlays.
/// * On desktop the card scales up and casts a shadow while hovered; in
///   row mode the owner renders a floating preview popover above it.
/// * On touch it behaves like a simple pressable tile that opens details.
class NetflixPosterCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final NetflixHoverCallback? onHover;

  /// Renders a thin progress bar at the bottom (continue watching).
  final double? progress;

  /// Optional rank numeral drawn to the left of the poster (Top 10 rows).
  final int? rank;

  /// Grid/compact mode - no floating preview, gentler hover scale.
  final bool compact;

  /// Lets the card manage its own floating preview on desktop (used by
  /// grids). Rows keep [onHover] so they can position previews themselves.
  final bool selfPreview;

  const NetflixPosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.onHover,
    this.progress,
    this.rank,
    this.compact = false,
    this.selfPreview = false,
  });

  @override
  State<NetflixPosterCard> createState() => _NetflixPosterCardState();
}

class _NetflixPosterCardState extends State<NetflixPosterCard> {
  bool _hovered = false;
  bool _pressed = false;
  OverlayEntry? _previewEntry;
  Timer? _previewTimer;
  bool _pointerInPreview = false;

  bool get _isDesktop => MediaQuery.sizeOf(context).width >= 1024;

  String get _posterUrl {
    final url = widget.item.posterUrl;
    if (url.isNotEmpty) return url;
    if (widget.item.posterPath.isNotEmpty) return widget.item.posterPath;
    return '';
  }

  void _onHover(bool hovered) {
    if (widget.selfPreview) {
      setState(() => _hovered = hovered);
      if (!hovered) {
        _previewTimer?.cancel();
        if (!_pointerInPreview) _removeSelfPreview();
        return;
      }
      if (!_isDesktop) return;
      _previewTimer?.cancel();
      _previewTimer = Timer(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        _showSelfPreview(box.localToGlobal(Offset.zero) & box.size);
      });
      return;
    }
    if (widget.onHover == null) {
      setState(() => _hovered = hovered);
      return;
    }
    if (hovered == _hovered) return;
    setState(() => _hovered = hovered);
    if (hovered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = context.findRenderObject() as RenderBox?;
        if (!mounted || box == null || !box.hasSize) return;
        widget.onHover?.call(
          true,
          box.localToGlobal(Offset.zero) & box.size,
          widget.item,
        );
      });
    } else {
      widget.onHover?.call(false, Rect.zero, widget.item);
    }
  }

  void _showSelfPreview(Rect rect) {
    if (_previewEntry != null) return;
    final overlay = Overlay.of(context);
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width * 0.26).clamp(300.0, 360.0);
    final height = width * 0.5625 + 178;
    final offset = positionHoverPreview(
      anchor: rect,
      previewSize: Size(width, height),
      screen: screen,
    );
    _previewEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy,
        width: width,
        height: height,
        child: MouseRegion(
          onEnter: (_) => _pointerInPreview = true,
          onExit: (_) {
            _pointerInPreview = false;
            _previewTimer?.cancel();
            _removeSelfPreview();
          },
          child: NetflixHoverPreview(
            item: widget.item,
            width: width,
            onTap: () {
              _removeSelfPreview();
              widget.onTap?.call();
            },
          ),
        ),
      ),
    );
    overlay.insert(_previewEntry!);
  }

  void _removeSelfPreview() {
    _previewEntry?.remove();
    _previewEntry = null;
    _pointerInPreview = false;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _removeSelfPreview();
    super.dispose();
  }

  Widget _buildPoster(double width, double height) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final scale = _pressed
        ? 0.96
        : (_hovered && isDesktop ? (widget.compact ? 1.06 : 1.25) : 1.0);
    final lift = _hovered && isDesktop && !widget.compact ? -18.0 : 0.0;

    final transform = Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(0.0, lift, 0.0);

    return AnimatedContainer(
      duration: AppMotion.orZero(const Duration(milliseconds: 220)),
      curve: AppMotion.easeOutStrong,
      transform: transform,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          if (_hovered && isDesktop)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 24,
              offset: const Offset(0, 14),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_posterUrl.isNotEmpty)
                Image.network(
                  _posterUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 420,
                  errorBuilder: (_, _, _) =>
                      _PosterFallback(title: widget.item.title),
                )
              else
                _PosterFallback(title: widget.item.title),
              if (_hovered && isDesktop)
                Container(color: NetflixColors.hoverScrim),
              if (widget.progress != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    value: widget.progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(
                      NetflixColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop;
    final width = widget.rank != null ? 118.0 : (isDesktop ? 172.0 : 124.0);
    final height = width * 1.5;

    final poster = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: isDesktop ? _onHover : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: _buildPoster(width, height),
      ),
    );

    if (widget.rank == null) return SizedBox(width: width, child: poster);

    // Top-10 numeral treatment: oversized outlined number beside the poster.
    return SizedBox(
      width: width + 96,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 92,
            height: height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  '${widget.rank}',
                  style: GoogleFonts.outfit(
                    fontSize: 150,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = _rankColor(widget.rank!),
                  ),
                ),
              ),
            ),
          ),
          poster,
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.white.withValues(alpha: 0.95);
      case 2:
        return Colors.white.withValues(alpha: 0.85);
      case 3:
        return Colors.white.withValues(alpha: 0.78);
      default:
        return Colors.white.withValues(alpha: 0.82);
    }
  }
}

/// Landscape "continue watching" card with a progress bar.
class NetflixContinueCard extends StatefulWidget {
  final MediaItem item;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onTap;
  final NetflixHoverCallback? onHover;

  const NetflixContinueCard({
    super.key,
    required this.item,
    this.subtitle,
    this.progress,
    this.onTap,
    this.onHover,
  });

  @override
  State<NetflixContinueCard> createState() => _NetflixContinueCardState();
}

class _NetflixContinueCardState extends State<NetflixContinueCard> {
  bool _hovered = false;

  String get _backdropUrl {
    final b = widget.item.backdropUrl;
    if (b.isNotEmpty) return b;
    return widget.item.posterUrl;
  }

  void _onHover(bool hovered) {
    if (widget.onHover == null) {
      setState(() => _hovered = hovered);
      return;
    }
    if (hovered == _hovered) return;
    setState(() => _hovered = hovered);
    if (hovered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = context.findRenderObject() as RenderBox?;
        if (!mounted || box == null || !box.hasSize) return;
        widget.onHover?.call(
          true,
          box.localToGlobal(Offset.zero) & box.size,
          widget.item,
        );
      });
    } else {
      widget.onHover?.call(false, Rect.zero, widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final width = isDesktop ? 230.0 : 170.0;

    return SizedBox(
      width: width,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: isDesktop ? _onHover : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.orZero(const Duration(milliseconds: 220)),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.diagonal3Values(
              _hovered ? 1.08 : 1.0,
              _hovered ? 1.08 : 1.0,
              1.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: _hovered ? 20 : 8,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
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
                            cacheWidth: 520,
                            errorBuilder: (_, _, _) =>
                                _PosterFallback(title: widget.item.title),
                          )
                        else
                          _PosterFallback(title: widget.item.title),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                        if (widget.progress != null)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: widget.progress!.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.25,
                              ),
                              valueColor: const AlwaysStoppedAnimation(
                                NetflixColors.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: NetflixColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final String title;
  const _PosterFallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NetflixColors.surfaceElevated,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          color: NetflixColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
