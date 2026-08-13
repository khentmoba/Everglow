import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../data/models/media_item.dart';
import 'netflix_colors.dart';
import 'netflix_hover_preview.dart';
import 'netflix_poster_card.dart';
import '../../../../../core/theme/app_typography.dart';

/// Horizontal content rail with a Netflix-style title, edge arrows on
/// desktop, and a floating hover preview that pops above the row.
class NetflixRow extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem) onTapItem;
  final EdgeInsetsGeometry? padding;

  /// Renders Top-10 numerals next to the first ten posters.
  final bool ranked;

  const NetflixRow({
    super.key,
    required this.title,
    required this.items,
    required this.onTapItem,
    this.padding,
    this.ranked = false,
  });

  @override
  State<NetflixRow> createState() => _NetflixRowState();
}

class _NetflixRowState extends State<NetflixRow> {
  final ScrollController _controller = ScrollController();
  OverlayEntry? _previewEntry;
  MediaItem? _previewItem;
  Timer? _previewTimer;
  bool _pointerInPreview = false;
  bool _hovering = false;
  bool _canLeft = false;
  bool _canRight = false;
  int _hoverGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _removePreview();
    _controller.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final left = pos.pixels > pos.minScrollExtent + 4;
    final right = pos.pixels < pos.maxScrollExtent - 4;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _controller.offset + delta,
      duration: AppMotion.orZero(const Duration(milliseconds: 450)),
      curve: AppMotion.easeOutStrong,
    );
  }

  void _onCardHover(bool hovered, Rect rect, MediaItem item) {
    final generation = ++_hoverGeneration;
    if (!hovered) {
      _previewTimer?.cancel();
      // Only the row owns the popover: when the pointer leaves a card but is
      // inside the popover, keep it until the popover's own MouseRegion fires.
      if (!_pointerInPreview || _previewItem != item) _removePreview();
      return;
    }
    if (!AppBreakpoint.isDesktop(context)) return;
    // Hovering a different card should immediately retire the previous
    // popover instead of letting overlapping entries trap each other.
    if (_previewItem != item) _removePreview();
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || generation != _hoverGeneration) return;
      _removePreview();
      _showPreview(rect, item);
    });
  }

  void _showPreview(Rect rect, MediaItem item) {
    final overlay = Overlay.of(context);
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width * 0.26).clamp(300.0, 360.0);
    final height = width * 0.5625 + 178;
    final offset = positionHoverPreview(
      anchor: rect,
      previewSize: Size(width, height),
      screen: screen,
    );

    _previewItem = item;
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
            _removePreview();
          },
          child: NetflixHoverPreview(
            item: item,
            width: width,
            onTap: () {
              _removePreview();
              widget.onTapItem(item);
            },
          ),
        ),
      ),
    );
    overlay.insert(_previewEntry!);
  }

  void _removePreview() {
    _previewEntry?.remove();
    _previewEntry = null;
    _previewItem = null;
    _pointerInPreview = false;
  }

  void _onRowExit() {
    _hovering = false;
    setState(() {});
    _previewTimer?.cancel();
    // Removes immediately when the pointer is not inside the popover; the
    // popover's own MouseRegion.onExit handles the keep-while-hovered case.
    if (!_pointerInPreview) _removePreview();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad =
        widget.padding ?? EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16);
    final posterWidth = isDesktop ? 172.0 : 124.0;
    final rowHeight = widget.ranked
        ? (posterWidth * 1.5 + 6)
        : (posterWidth * 1.5 + 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            26,
            isDesktop ? 48 : 16,
            12,
          ),
          child: Text(
            widget.title,
            style: AppTypography.outfitHeading.copyWith(color: NetflixColors.textPrimary, fontSize: isDesktop ? 20 : 17, letterSpacing: 0),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: MouseRegion(
            onEnter: (_) {
              _hovering = true;
              setState(() {});
            },
            onExit: (_) => _onRowExit(),
            child: Stack(
              children: [
                ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: horizontalPad,
                  clipBehavior: Clip.none,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return NetflixPosterCard(
                      item: item,
                      onTap: () => widget.onTapItem(item),
                      onHover: isDesktop ? _onCardHover : null,
                      rank: widget.ranked && index < 10 ? index + 1 : null,
                    );
                  },
                ),
                if (isDesktop && _hovering && _canLeft)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _RowArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _scrollBy(-screenWidth(context)),
                    ),
                  ),
                if (isDesktop && _hovering && _canRight)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _RowArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _scrollBy(screenWidth(context)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Continue-watching rail - landscape cards with progress bars.
class NetflixContinueRow extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onTapItem;
  final String Function(MediaItem) subtitleOf;
  final double Function(MediaItem) progressOf;

  const NetflixContinueRow({
    super.key,
    required this.items,
    required this.onTapItem,
    required this.subtitleOf,
    required this.progressOf,
  });

  @override
  State<NetflixContinueRow> createState() => _NetflixContinueRowState();
}

class _NetflixContinueRowState extends State<NetflixContinueRow> {
  final ScrollController _controller = ScrollController();
  OverlayEntry? _previewEntry;
  MediaItem? _previewItem;
  Timer? _previewTimer;
  bool _pointerInPreview = false;
  int _hoverGeneration = 0;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _removePreview();
    _controller.dispose();
    super.dispose();
  }

  void _onCardHover(bool hovered, Rect rect, MediaItem item) {
    final generation = ++_hoverGeneration;
    if (!hovered) {
      _previewTimer?.cancel();
      // Only the row owns the popover: keep it while the pointer is inside
      // the popover and the popover belongs to this card, otherwise remove.
      if (!_pointerInPreview || _previewItem != item) _removePreview();
      return;
    }
    if (!AppBreakpoint.isDesktop(context)) return;
    // Hovering a different card immediately retires the previous popover.
    if (_previewItem != item) _removePreview();
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || generation != _hoverGeneration) return;
      _removePreview();
      final overlay = Overlay.of(context);
      final screen = MediaQuery.sizeOf(context);
      final width = (screen.width * 0.26).clamp(300.0, 360.0);
      final height = width * 0.5625 + 178;
      final offset = positionHoverPreview(
        anchor: rect,
        previewSize: Size(width, height),
        screen: screen,
      );
      _previewItem = item;
      final entry = OverlayEntry(
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
              if (_previewItem == item) _removePreview();
            },
            child: NetflixHoverPreview(
              item: item,
              width: width,
              onTap: () {
                _removePreview();
                widget.onTapItem(item);
              },
            ),
          ),
        ),
      );
      overlay.insert(entry);
      _previewEntry = entry;
    });
  }

  void _removePreview() {
    _previewEntry?.remove();
    _previewEntry = null;
    _previewItem = null;
    _pointerInPreview = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);
    final cardWidth = isDesktop ? 230.0 : 170.0;
    final rowHeight = cardWidth * 0.5625 + (isDesktop ? 30 : 26);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            26,
            isDesktop ? 48 : 16,
            12,
          ),
          child: Text(
            'Continue Watching',
            style: AppTypography.outfitHeading.copyWith(color: NetflixColors.textPrimary, fontSize: isDesktop ? 20 : 17),
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: MouseRegion(
            onExit: (_) {
              _previewTimer?.cancel();
              if (!_pointerInPreview) _removePreview();
            },
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
              clipBehavior: Clip.none,
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return NetflixContinueCard(
                  item: item,
                  subtitle: widget.subtitleOf(item),
                  progress: widget.progressOf(item),
                  onTap: () => widget.onTapItem(item),
                  onHover: isDesktop ? _onCardHover : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RowArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RowArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }
}

double screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;
