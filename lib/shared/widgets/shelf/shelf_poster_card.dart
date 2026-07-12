import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_breakpoints.dart';
import 'motion.dart';
import 'shelf_hover_preview.dart';

/// Shared poster card used across the four inside screens.
///
/// On desktop hover:
///   * Lifts 6px and scales 1.05 (stronger than default)
///   * Shows a play icon overlay and brighter accent glow
///   * After 400ms, shows a rich [ShelfHoverPreview] overlay card
///   * Smooth 200ms ease-out transitions
///
/// On mobile / touch:
///   * Gentle press scale (0.96)
///   * No hover effects
class ShelfPosterCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final IconData? badgeIcon;
  final double? rankNumber;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Rich metadata for the hover preview card (desktop only).
  final String? bannerUrl;
  final String? synopsis;
  final String? episodeCount;
  final String? format;
  final String? airingStatus;
  final List<String> genres;
  final int? currentEpisode;

  const ShelfPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.badgeIcon,
    this.rankNumber,
    this.onTap,
    this.semanticLabel,
    this.bannerUrl,
    this.synopsis,
    this.episodeCount,
    this.format,
    this.airingStatus,
    this.genres = const [],
    this.currentEpisode,
  });

  @override
  State<ShelfPosterCard> createState() => _ShelfPosterCardState();
}

class _ShelfPosterCardState extends State<ShelfPosterCard> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  // Hover preview overlay
  Timer? _hoverDelayTimer;
  Timer? _dismissDelayTimer;
  OverlayEntry? _hoverOverlay;
  bool _isHoveringOverlay = false;
  final LayerLink _layerLink = LayerLink();

  static const _tmdbImageBase = 'https://image.tmdb.org/t/p/w342';

  bool get _isDesktop => AppBreakpoint.isDesktop(context);

  bool get _hasHoverData =>
      widget.synopsis != null ||
      widget.episodeCount != null ||
      widget.format != null ||
      widget.bannerUrl != null;

  String get _resolvedImageUrl {
    final url = widget.imageUrl;
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$_tmdbImageBase$url';
  }

  void _showHoverPreview() {
    if (_hoverOverlay != null || !_hasHoverData) return;
    final badgeColor = widget.badgeColor ?? AppTheme.deepRose;

    _hoverOverlay = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(-10, -10),
        child: MouseRegion(
          onEnter: (_) {
            _isHoveringOverlay = true;
            _dismissDelayTimer?.cancel();
            _dismissDelayTimer = null;
          },
          onExit: (_) {
            _isHoveringOverlay = false;
            _dismissHoverPreview();
          },
          child: ShelfHoverPreview(
            title: widget.title,
            synopsis: widget.synopsis,
            episodeCount: widget.episodeCount,
            format: widget.format,
            airingStatus: widget.airingStatus,
            year: widget.subtitle,
            genres: widget.genres,
            currentEpisode: widget.currentEpisode,
            accent: badgeColor,
            onWatch: () {
              _dismissHoverPreview();
              widget.onTap?.call();
            },
            onQueue: () => _dismissHoverPreview(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_hoverOverlay!);
  }

  void _dismissHoverPreview() {
    _hoverDelayTimer?.cancel();
    _hoverDelayTimer = null;
    if (_isHoveringOverlay) return;
    _hoverOverlay?.remove();
    _hoverOverlay = null;
  }

  @override
  void dispose() {
    _hoverDelayTimer?.cancel();
    _dismissDelayTimer?.cancel();
    _hoverOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.badgeColor ?? AppTheme.deepRose;
    final disabled = widget.onTap == null;
    final isDesktop = _isDesktop;

    // Compose the announcement: "Movie, title, year, badge"
    final announcement = [
      if (widget.badge != null) widget.badge!,
      widget.title,
      if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
        widget.subtitle!,
    ].join(', ');

    final liftY = _hovered && !_pressed && !disabled && isDesktop ? -6.0 : 0.0;
    final scaleVal = _pressed
        ? 0.96
        : (_hovered && !disabled && isDesktop ? 1.05 : 1.0);

    final card = AnimatedContainer(
      duration: ShelfMotion.orZero(const Duration(milliseconds: 200)),
      curve: ShelfMotion.easeOutStrong,
      transform: Matrix4.identity()
        ..translate(0.0, liftY, 0.0)
        ..scale(scaleVal),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.55),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : _hovered && !disabled && isDesktop
                ? [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.5),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_resolvedImageUrl.isNotEmpty)
              Image.network(
                _resolvedImageUrl,
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, _, _) => _Placeholder(
                  title: widget.title,
                  accent: badgeColor,
                ),
              )
            else
              _Placeholder(title: widget.title, accent: badgeColor),

            // Hover overlay — play button + accent border on desktop
            if (isDesktop)
              AnimatedOpacity(
                duration: ShelfMotion.orZero(ShelfMotion.fast),
                opacity: _hovered && !disabled ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: badgeColor.withValues(alpha: _hovered ? 0.7 : 0.0),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: _hovered ? 1.0 : 0.6,
                      duration: ShelfMotion.orZero(ShelfMotion.medium),
                      curve: ShelfMotion.easeOutStrong,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.95),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: badgeColor,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Title gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.92),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppTheme.blushGold
                              .withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (widget.badge != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.badgeIcon != null) ...[
                        Icon(widget.badgeIcon,
                            color: Colors.white, size: 9),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        widget.badge!,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.rankNumber != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.rankNumber! <= 3
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.blushGold,
                              AppTheme.blushGold.withValues(alpha: 0.7),
                            ],
                          )
                        : null,
                    color: widget.rankNumber! > 3
                        ? AppTheme.velvet.withValues(alpha: 0.85)
                        : null,
                    border: Border.all(
                      color: widget.rankNumber! <= 3
                          ? AppTheme.blushGold
                          : AppTheme.blushGold.withValues(alpha: 0.6),
                      width: widget.rankNumber! <= 3 ? 1.5 : 1,
                    ),
                    boxShadow: widget.rankNumber! <= 3
                        ? [
                            BoxShadow(
                              color: AppTheme.blushGold.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.rankNumber}',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: widget.rankNumber! <= 3 ? 15 : 12,
                      fontWeight: FontWeight.w900,
                      color: widget.rankNumber! <= 3
                          ? AppTheme.velvet
                          : AppTheme.blushGold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      button: !disabled,
      enabled: !disabled,
      label: widget.semanticLabel ?? announcement,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: FocusableActionDetector(
          enabled: !disabled,
          onShowFocusHighlight: (show) =>
              setState(() => _focused = show && !disabled),
          mouseCursor: disabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: disabled
                ? null
                : (_) => setState(() => _pressed = true),
            onTapUp: disabled
                ? null
                : (_) {
                    setState(() => _pressed = false);
                    widget.onTap!();
                  },
            onTapCancel: () => setState(() => _pressed = false),
            child: MouseRegion(
              cursor: disabled
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              onEnter: disabled || !isDesktop
                  ? null
                  : (_) {
                      _dismissDelayTimer?.cancel();
                      _dismissDelayTimer = null;
                      setState(() => _hovered = true);
                      // Show hover preview after 400ms delay
                      _hoverDelayTimer?.cancel();
                      _hoverDelayTimer = Timer(
                          const Duration(milliseconds: 400), () {
                        if (mounted && _hovered) {
                          _showHoverPreview();
                        }
                      });
                    },
              onExit: (_) {
                setState(() => _hovered = false);
                // Delay dismiss to allow mouse to travel to overlay
                _dismissDelayTimer?.cancel();
                _dismissDelayTimer = Timer(
                    const Duration(milliseconds: 200), () {
                  if (!_isHoveringOverlay) {
                    _dismissHoverPreview();
                  }
                });
              },
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final Color accent;
  const _Placeholder({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D1B33),
            AppTheme.twilight,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: accent.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
