import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../../shared/utils/tmdb_images.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../data/models/media_item.dart';
import 'netflix_colors.dart';
import 'netflix_hover_preview.dart';
import 'netflix_touch_preview.dart';
import '../../../../../core/theme/app_typography.dart';

typedef NetflixHoverCallback =
    void Function(bool hovered, Rect globalRect, MediaItem item);

class NetflixPosterCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final NetflixHoverCallback? onHover;
  final void Function(MediaItem)? onPlay;
  final void Function(MediaItem, bool add)? onToggleList;
  final void Function(MediaItem, double? rating)? onRate;
  final bool Function(MediaItem)? isInList;

  final double? progress;

  final int? rank;

  final bool compact;

  final bool selfPreview;

  final VoidCallback? onImageError;

  const NetflixPosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.onHover,
    this.onPlay,
    this.onToggleList,
    this.onRate,
    this.isInList,
    this.progress,
    this.rank,
    this.compact = false,
    this.selfPreview = false,
    this.onImageError,
  });

  @override
  State<NetflixPosterCard> createState() => _NetflixPosterCardState();
}

class _NetflixPosterCardState extends State<NetflixPosterCard> {
  bool _hovered = false;
  bool _pressed = false;
  OverlayEntry? _previewEntry;
  Timer? _previewTimer;

  bool get _isDesktop => MediaQuery.sizeOf(context).width >= 1024;

  String get _posterUrl => TmdbImages.cardFor(widget.item.posterPath);

  void _onHover(bool hovered) {
    if (widget.selfPreview) {
      setState(() => _hovered = hovered);
      if (!hovered) {
        _previewTimer?.cancel();
        return;
      }
      if (!_isDesktop) return;
      unawaited(prefetchNetflixPreview(widget.item));
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
      unawaited(prefetchNetflixPreview(widget.item));
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
    final height = netflixPreviewHeight(width);
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
        child: MouseRegion(
          onExit: (_) {
            _previewTimer?.cancel();
            _removeSelfPreview();
          },
          child: NetflixHoverPreview(
            item: widget.item,
            width: width,
            anchorWidth: rect.width,
            inList: widget.isInList?.call(widget.item) ?? false,
            onTap: () {
              _removeSelfPreview();
              widget.onTap?.call();
            },
            onPlay: () => widget.onPlay?.call(widget.item),
            onToggleList: (add) => widget.onToggleList?.call(widget.item, add),
            onRate: (rating) => widget.onRate?.call(widget.item, rating),
          ),
        ),
      ),
    );
    overlay.insert(_previewEntry!);
  }

  void _removeSelfPreview() {
    _previewEntry?.remove();
    _previewEntry = null;
  }

  void _showTouchPreview() {
    final play = widget.onPlay;
    final toggle = widget.onToggleList;
    final rate = widget.onRate;
    showTouchPreview(
      context: context,
      item: widget.item,
      inList: widget.isInList?.call(widget.item) ?? false,
      onTap: widget.onTap,
      onPlay: play == null ? null : () => play(widget.item),
      onToggleList: toggle == null ? null : (add) => toggle(widget.item, add),
      onRate: rate == null ? null : (rating) => rate(widget.item, rating),
    );
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _removeSelfPreview();
    super.dispose();
  }

  Widget _buildPoster(double width, double height) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final reduceAmbient = AppMotion.reduceAmbientMotion(context);
    final scale = _pressed
        ? 0.96
        : (_hovered && isDesktop ? (widget.compact ? 1.05 : 1.08) : 1.0);

    final transform = reduceAmbient
        ? null
        : Matrix4.diagonal3Values(scale, scale, 1.0);
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      boxShadow: reduceAmbient
          ? null
          : [
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
    );
    final clipped = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_posterUrl.isNotEmpty)
                AppNetworkImage(
                  imageUrl: _posterUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 420,
                  errorWidget: _PosterFallback(title: widget.item.title),
                  onError: widget.onImageError,
                )
              else
                _PosterFallback(title: widget.item.title),
              if (_hovered && isDesktop)
                Container(color: NetflixColors.hoverScrim),
              if (widget.item.remindMe)
                const Positioned(top: 6, left: 6, child: _RemindBadge()),
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
      );
    return RepaintBoundary(
      child: reduceAmbient
          ? DecoratedBox(decoration: decoration, child: clipped)
          : AnimatedContainer(
              duration: AppMotion.orZero(const Duration(milliseconds: 220)),
              curve: AppMotion.easeOutStrong,
              transform: transform,
              decoration: decoration,
              child: clipped,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop;
    final width = widget.rank != null ? 118.0 : (isDesktop ? 172.0 : 124.0);
    final height = width * 1.5;

    final poster = Stack(
      fit: StackFit.passthrough,
      children: [
        _NetflixCardAction(
          label: 'Details for ${widget.item.title}',
          onTap: widget.onTap,
          onHover: isDesktop ? _onHover : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              setState(() => _pressed = true);
              unawaited(prefetchNetflixPreview(widget.item));
            },
            excludeFromSemantics: true,
            onTap: widget.onTap,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onLongPress: _showTouchPreview,
            child: ExcludeSemantics(child: _buildPoster(width, height)),
          ),
        ),
      ],
    );

    if (widget.rank == null) return SizedBox(width: width, child: poster);

    TextStyle numeral({required bool stroke}) =>
        AppTypography.outfitWhite.copyWith(
          fontSize: 200,
          fontWeight: FontWeight.w900,
          height: 0.8,
          color: stroke ? null : NetflixColors.textSecondary,
          foreground: stroke
              ? (Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 8
                  ..color = Colors.black)
              : null,
        );
    return SizedBox(
      width: width + 64,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 84,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
              child: Stack(
                children: [
                  Text('${widget.rank}', style: numeral(stroke: true)),
                  Text('${widget.rank}', style: numeral(stroke: false)),
                ],
              ),
            ),
          ),
          Positioned(right: 0, top: 0, bottom: 0, child: poster),
        ],
      ),
    );
  }
}

class NetflixContinueCard extends StatefulWidget {
  final MediaItem item;

  final VoidCallback? onDetails;
  final VoidCallback? onRestart;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onTap;
  final NetflixHoverCallback? onHover;
  final void Function(MediaItem)? onPlay;
  final void Function(MediaItem, bool add)? onToggleList;
  final void Function(MediaItem, double? rating)? onRate;
  final bool Function(MediaItem)? isInList;
  final VoidCallback? onImageError;

  const NetflixContinueCard({
    super.key,
    required this.item,
    this.onDetails,
    this.onRestart,
    this.subtitle,
    this.progress,
    this.onTap,
    this.onHover,
    this.onPlay,
    this.onToggleList,
    this.onRate,
    this.isInList,
    this.onImageError,
  });

  @override
  State<NetflixContinueCard> createState() => _NetflixContinueCardState();
}

class _NetflixContinueCardState extends State<NetflixContinueCard> {
  bool _hovered = false;

  String get _backdropUrl {
    final b = TmdbImages.backdropFor(widget.item.backdropPath);
    if (b.isNotEmpty) return b;
    return TmdbImages.cardFor(widget.item.posterPath);
  }

  Widget _backdropErrorFallback() {
    final backdrop = TmdbImages.backdropFor(widget.item.backdropPath);
    final poster = TmdbImages.cardFor(widget.item.posterPath);
    if (backdrop.isNotEmpty && poster.isNotEmpty && backdrop != poster) {
      return AppNetworkImage(
        imageUrl: poster,
        fit: BoxFit.cover,
        cacheWidth: 520,
        errorWidget: _PosterFallback(title: widget.item.title),
        onError: widget.onImageError,
      );
    }
    return _PosterFallback(title: widget.item.title);
  }

  void _onHover(bool hovered) {
    if (widget.onHover == null) {
      setState(() => _hovered = hovered);
      return;
    }
    if (hovered == _hovered) return;
    setState(() => _hovered = hovered);
    if (hovered) {
      unawaited(prefetchNetflixPreview(widget.item));
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

  void _showTouchPreview() {
    final play = widget.onPlay;
    final toggle = widget.onToggleList;
    final rate = widget.onRate;
    showTouchPreview(
      context: context,
      item: widget.item,
      inList: widget.isInList?.call(widget.item) ?? false,
      onTap: widget.onDetails,
      onRestart: widget.onRestart,
      onPlay: play == null ? null : () => play(widget.item),
      onToggleList: toggle == null ? null : (add) => toggle(widget.item, add),
      onRate: rate == null ? null : (rating) => rate(widget.item, rating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final width = isDesktop ? 230.0 : 170.0;

    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          _NetflixCardAction(
            label: 'Continue watching ${widget.item.title}',
            onTap: widget.onTap,
            onHover: isDesktop ? _onHover : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              excludeFromSemantics: true,
              onTapDown: (_) => unawaited(prefetchNetflixPreview(widget.item)),
              onLongPress: _showTouchPreview,
              child: ExcludeSemantics(
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
                                AppNetworkImage(
                                  imageUrl: _backdropUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 520,
                                  errorWidget: _backdropErrorFallback(),
                                  onError: widget.onImageError,
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
                                        style: AppTypography.outfitHeading
                                            .copyWith(
                                              color: Colors.white,
                                              fontSize: 13,
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
                            style: AppTypography.outfitWhite.copyWith(
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
          ),
        ],
      ),
    );
  }
}

class NetflixRemoveBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final String tooltip;

  const NetflixRemoveBadge({
    super.key,
    this.onTap,
    this.tooltip = 'Remove from Continue Watching',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: NetflixColors.background.withValues(alpha: 0.8),
        foregroundColor: NetflixColors.textPrimary,
        side: const BorderSide(color: NetflixColors.textSecondary),
      ),
      icon: const Icon(Icons.close_rounded, size: 20),
    );
  }
}

class _NetflixCardAction extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;
  final Widget child;

  const _NetflixCardAction({
    required this.label,
    required this.onTap,
    required this.child,
    this.onHover,
  });

  @override
  State<_NetflixCardAction> createState() => _NetflixCardActionState();
}

class _NetflixCardActionState extends State<_NetflixCardAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      enabled: widget.onTap != null,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: widget.onHover,
        onFocusChange: (focused) {
          if (focused) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          }
          setState(() => _focused = focused);
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: _focused
                ? Border.all(color: NetflixColors.gold, width: 3)
                : null,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: NetflixColors.gold.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _RemindBadge extends StatelessWidget {
  const _RemindBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: NetflixColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.notifications_rounded,
        color: Colors.white,
        size: 14,
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
        style: AppTypography.outfitBold.copyWith(
          color: NetflixColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}
