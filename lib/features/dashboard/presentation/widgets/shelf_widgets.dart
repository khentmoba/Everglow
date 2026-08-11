import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Per-shelf visual identity. Each rail (Cinema, Anime, Books, Manga)
/// passes one of these accents to the shared shelf primitives so the
/// icon, glow, and badge pick up a unique hue without each preview
/// having to redeclare the same color constants.
enum ShelfAccent {
  cinema(
    label: 'Cinema',
    color: Color(0xFFF4C2C2), // roseQuartz
    glow: Color(0xFFC2185B), // deepRose
    icon: Icons.local_movies_outlined,
  ),
  anime(
    label: 'Anime',
    color: Color(0xFFD4B5D6), // softLavender
    glow: Color(0xFF8E5DA0),
    icon: Icons.auto_awesome_outlined,
  ),
  books(
    label: 'Books',
    color: Color(0xFFF0A500), // warmAmber
    glow: Color(0xFFB87800),
    icon: Icons.menu_book_rounded,
  ),
  manga(
    label: 'Manga',
    color: Color(0xFFE8B4BC), // softer rose for manga
    glow: Color(0xFFAD1457),
    icon: Icons.import_contacts_outlined,
  ),
  gallery(
    label: 'Gallery',
    color: Color(0xFFF4C2C2), // roseQuartz
    glow: Color(0xFF880E4F), // deep magenta
    icon: Icons.photo_library_outlined,
  );

  const ShelfAccent({
    required this.label,
    required this.color,
    required this.glow,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color glow;
  final IconData icon;
}

/// Common header for the four dashboard shelves (Cinema, Anime, Books,
/// Manga). Pairs the section icon + title with an item count and a
/// "View All" affordance. All four rails share this header so the
/// visual rhythm of the dashboard stays consistent.
class ShelfHeader extends StatelessWidget {
  final ShelfAccent accent;
  final String title;
  final int itemCount;
  final String? badge;
  final VoidCallback onViewAll;

  const ShelfHeader({
    super.key,
    required this.accent,
    required this.title,
    required this.itemCount,
    required this.onViewAll,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AccentIcon(accent: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.cormorantBold.copyWith(fontSize: 26, height: 1.0, letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    _Badge(text: badge!),
                  ],
                ],
              ),
              if (itemCount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '$itemCount ${itemCount == 1 ? "title" : "titles"} shared',
                  style: AppTypography.outfitWhite.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.petalWhite.withValues(alpha: 0.55), letterSpacing: 0.4),
                ),
              ],
            ],
          ),
        ),
        _ViewAllButton(accent: accent, onPressed: onViewAll),
      ],
    );
  }
}

class _AccentIcon extends StatelessWidget {
  final ShelfAccent accent;
  const _AccentIcon({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.color.withValues(alpha: 0.18),
            accent.glow.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.color.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.glow.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        accent.icon,
        color: accent.color,
        size: 19,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.deepRose.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.deepRose.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.outfitWhite.copyWith(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.deepRose, letterSpacing: 1.4),
      ),
    );
  }
}

class _ViewAllButton extends StatefulWidget {
  final ShelfAccent accent;
  final VoidCallback onPressed;
  const _ViewAllButton({required this.accent, required this.onPressed});

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.accent.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.accent.color.withValues(alpha: _hovered ? 0.55 : 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: AppTypography.outfitBold.copyWith(fontSize: 12, color: widget.accent.color, letterSpacing: 0.4),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: widget.accent.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable poster / cover card used by every shelf. Wraps a network
/// image in a rounded glass tile with an accent-tinted border, a soft
/// glow shadow, and a gradient title overlay at the bottom so users
/// can read what's in the card without opening it.
class ShelfCard extends StatefulWidget {
  final ShelfAccent accent;
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? topBadge;
  final VoidCallback? onTap;

  const ShelfCard({
    super.key,
    required this.accent,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.topBadge,
    this.onTap,
  });

  @override
  State<ShelfCard> createState() => _ShelfCardState();
}

class _ShelfCardState extends State<ShelfCard> {
  bool _pressed = false;
  bool _hovered = false;

  static const _tmdbImageBase = 'https://image.tmdb.org/t/p/w342';

  String get _resolvedImageUrl {
    final url = widget.imageUrl;
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$_tmdbImageBase$url';
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final isHovered = _hovered && !_pressed && widget.onTap != null;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.onTap == null) return;
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (widget.onTap == null) return;
          setState(() => _pressed = false);
          _handleTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, isHovered ? -4.0 : 0.0, 0.0)
            ..scaleByDouble(_pressed ? 0.95 : (isHovered ? 1.04 : 1.0)),
          width: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.accent.color
                  .withValues(alpha: isHovered ? 0.45 : 0.22),
              width: 1,
            ),
            boxShadow: [
              if (isHovered) ...[
                BoxShadow(
                  color: widget.accent.glow.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ] else ...[
                BoxShadow(
                  color: widget.accent.glow.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_resolvedImageUrl.isNotEmpty)
                  Image.network(
                    _resolvedImageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, _, _) =>
                        _Placeholder(accent: widget.accent, title: widget.title),
                  )
                else
                  _Placeholder(accent: widget.accent, title: widget.title),
                // Bottom gradient for the title overlay.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xCC000000),
                          Color(0x66000000),
                          Color(0x00000000),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.outfitHeading.copyWith(color: AppTheme.petalWhite, fontSize: 11, height: 1.15, shadows: const [
                              Shadow(
                                color: Color(0xCC000000),
                                blurRadius: 4,
                              ),
                            ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: AppTypography.outfitBold.copyWith(color: widget.accent.color, fontSize: 9, letterSpacing: 0.3, shadows: const [
                                Shadow(
                                  color: Color(0xCC000000),
                                  blurRadius: 4,
                                ),
                              ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.topBadge != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.accent.color.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.topBadge!,
                        style: AppTypography.outfitWhite.copyWith(color: widget.accent.color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
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

class _Placeholder extends StatelessWidget {
  final ShelfAccent accent;
  final String title;
  const _Placeholder({required this.accent, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.velvet,
            AppTheme.twilight,
            accent.glow.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                accent.icon,
                color: accent.color.withValues(alpha: 0.75),
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.85), fontSize: 9, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state panel shown when a shelf has no items yet. Uses the
/// shelf's accent so each section still feels like itself.
class ShelfEmpty extends StatelessWidget {
  final ShelfAccent accent;
  final String message;
  final IconData? icon;

  const ShelfEmpty({
    super.key,
    required this.accent,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
            accent.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.color.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon ?? accent.icon,
              color: accent.color.withValues(alpha: 0.85),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.75), fontStyle: FontStyle.italic, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Constant-speed, seamless infinite marquee used by the Cinema, Anime,
/// and Manga rails. Children are rendered twice so the ticker can loop
/// back to offset 0 once it reaches one full set's width, which keeps
/// the seam off-screen.
class ShelfMarquee extends StatefulWidget {
  final List<Widget> children;
  final double itemStride;
  final double pixelsPerSecond;
  final bool hasLoaded;
  final int skeletonCount;

  const ShelfMarquee({
    super.key,
    required this.children,
    this.itemStride = 122.0,
    this.pixelsPerSecond = 30.0,
    this.hasLoaded = true,
    this.skeletonCount = 5,
  });

  @override
  State<ShelfMarquee> createState() => _ShelfMarqueeState();
}

class _ShelfMarqueeState extends State<ShelfMarquee>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _showShimmer = true;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick)..start();
    if (widget.hasLoaded) {
      _showShimmer = false;
    } else {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _showShimmer = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShelfMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    if (widget.hasLoaded && _showShimmer) {
      setState(() => _showShimmer = false);
    }
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients || widget.children.isEmpty) {
      _lastTick = elapsed;
      return;
    }

    if (_paused) {
      _lastTick = elapsed;
      return;
    }
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    _lastTick = elapsed;

    final viewport = _scrollController.position.viewportDimension;
    final singleSetWidth = widget.children.length * widget.itemStride;
    final needsLoop = singleSetWidth >= viewport;
    if (!needsLoop) return;

    final effectiveSingleSet = singleSetWidth;

    var newOffset = _scrollController.offset + widget.pixelsPerSecond * dt;
    if (newOffset >= effectiveSingleSet) {
      newOffset -= effectiveSingleSet;
    }
    _scrollController.jumpTo(newOffset);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showShimmer) {
      return _ShimmerRow(count: widget.skeletonCount);
    }
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleSetWidth = widget.children.length * widget.itemStride;
          final needsLoop = singleSetWidth >= constraints.maxWidth;
          return MouseRegion(
            onEnter: (_) => setState(() => _paused = true),
            onExit: (_) => setState(() => _paused = false),
            child: ClipRect(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    ...widget.children,
                    if (needsLoop) ...widget.children,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  final int count;
  const _ShimmerRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => Container(
        width: 110,
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.moonlight.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
    );
  }
}
