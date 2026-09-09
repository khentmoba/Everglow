import "dart:async";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_cache_manager/flutter_cache_manager.dart";

/// Shared network image with web-performance defaults.
///
/// Why this exists: the app renders ~90 `Image.network` posters/covers across
/// cinema, anime, books, manga, gallery and dashboard previews. Raw
/// `Image.network` without `cacheWidth`, `loadingBuilder` or `errorBuilder`
/// causes three measurable costs on Flutter Web (CanvasKit/SkWasm):
///
/// 1. Full-resolution decode: a 780px TMDB poster displayed at 120px still
///    decodes + uploads the full bitmap to the GPU on every scroll frame.
///    `cacheWidth` downscales at decode time (huge scroll-FPS win).
/// 2. Layout pop-in: no placeholder means zero-size -> image-size jumps that
///    retrigger layout of the whole row/grid (jank + CLS-like flashes).
/// 3. Re-fetch on rebuild: without `gaplessPlayback`, a parent rebuild shows
///    a blank frame while the image resolves again.
///
/// Rule of thumb for `cacheWidth`: displayed CSS width x device pixel ratio,
/// capped at ~2x. Examples: 175px poster card -> 350-400; 120px grid thumb ->
/// 240-300; full-width hero (~800px) -> 800-1200. When in doubt, copy the
/// call sites below (`AppPosterImage` defaults to 400).
///
/// Images resolve through `CachedNetworkImage` (memory + disk cache), so
/// scrolling a rail back and forth never re-fetches bytes that were
/// already decoded. `cacheWidth`/`cacheHeight` become `memCacheWidth` /
/// `memCacheHeight` so the in-memory bitmap stays downscaled too.
///
/// Exception: on Flutter Web they are ignored (native browser decode).
/// An upstream CanvasKit bug (flutter/flutter#158093, #160199) turns any
/// downscaled decode into `WebGL: INVALID_VALUE: texImage2D: no image`
/// + black rectangles, so web always decodes at natural size.
///
/// Failed loads retry on their own with backoff (2s, 8s, 32s, 128s, 512s).
/// A brief network blip no longer leaves every rail stuck on its fallback
/// tile: each image re-attempts for ~11 minutes, so leaving the dashboard
/// on another screen for a few minutes heals by the time you come back.
class AppNetworkImage extends StatefulWidget {
  final String imageUrl;

  /// Display size. When only [width] is given and [aspectRatio] is set, height
  /// is derived so the placeholder reserves the exact space (no pop-in).
  final double? width;
  final double? height;
  final double? aspectRatio;

  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final BorderRadius? borderRadius;
  final Color placeholderColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Thumbnails scroll faster with [FilterQuality.low]; heroes/full viewers
  /// can pass [FilterQuality.medium] or [FilterQuality.high].
  final FilterQuality filterQuality;

  /// Optional cache backend, passed straight to [CachedNetworkImage].
  /// Production callers leave this null (shared disk cache); tests inject
  /// a fake to drive the failure path without real network or disk I/O.
  final BaseCacheManager? cacheManager;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.borderRadius,
    this.placeholderColor = const Color(0xFF2A1A2E),
    this.placeholder,
    this.errorWidget,
    this.filterQuality = FilterQuality.low,
    this.cacheManager,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();

  /// Overrides [kIsWeb] in widget tests to verify web vs native branches.
  @visibleForTesting
  static bool? debugUseWebImplementation;

  static bool get _isWeb => debugUseWebImplementation ?? kIsWeb;

  /// Global notification triggered when the app resumes (e.g. alt-tab return
  /// or browser tab focus) to immediately re-attempt failed image loads.
  static final ValueNotifier<int> appResumeNotifier = ValueNotifier<int>(0);

  /// Called by the app lifecycle observer when the app transitions to [AppLifecycleState.resumed].
  static void onAppResumed() {
    appResumeNotifier.value++;
  }

  /// Validates that a string is a fetchable web URL. Protects WebGL/CanvasKit
  /// from trying to decode 404/SPA-rewritten HTML or dummy 'null' strings as textures.
  static bool isValidUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed == 'null' ||
        trimmed == 'undefined' ||
        trimmed == 'false') {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    return uri.hasScheme &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'blob' ||
            uri.scheme == 'data');
  }
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  /// Backoff between automatic reloads after a failed fetch.
  static const _maxRetries = 5;
  static Duration _backoffFor(int attempt) =>
      Duration(seconds: 2 * (1 << (attempt * 2)));

  /// Bumped on every retry so the inner image gets a fresh [Key] and
  /// re-resolves instead of reusing its failed stream.
  int _generation = 0;
  int _attempt = 0;
  int _scheduledForGeneration = -1;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    AppNetworkImage.appResumeNotifier.addListener(_onAppResumed);
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
      _scheduledForGeneration = -1;
    }
  }

  @override
  void dispose() {
    AppNetworkImage.appResumeNotifier.removeListener(_onAppResumed);
    _retryTimer?.cancel();
    super.dispose();
  }

  void _onAppResumed() {
    if (!mounted) return;
    // If this image was in an error/backoff state when the user alt-tabbed away
    // or the device slept, retry immediately on returning.
    if (_attempt > 0) {
      _retryTimer?.cancel();
      _retryTimer = null;
      setState(() => _generation++);
    }
  }

  /// Schedules one reload for the current [_generation]. Called from the
  /// error builder, which can run on every parent rebuild while failed —
  /// the generation guard keeps it to a single timer per attempt.
  void _scheduleRetry() {
    if (_attempt >= _maxRetries) return;
    if (_scheduledForGeneration == _generation) return;
    _scheduledForGeneration = _generation;
    final delay = _backoffFor(_attempt);
    _attempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _generation++);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppNetworkImage.isValidUrl(widget.imageUrl)) return _fallback();

    Widget image;

    if (AppNetworkImage._isWeb) {
      // Flutter Web CanvasKit (flutter/flutter#158093, #160199, #192347) has an upstream
      // issue where CachedNetworkImage's default ImageRenderMethodForWeb.HtmlImage creates
      // unattached HTMLImageElements that get their textures evicted by the browser on
      // Alt-Tab / backgrounding, logging "WebGL: INVALID_VALUE: texImage2D: no image"
      // and rendering blank. On Web, standard Image.network fetches arraybuffer bytes directly
      // into Skia WASM memory and is fully immune to browser background texture purging.
      image = Image.network(
        widget.imageUrl,
        key: ValueKey('${widget.imageUrl}#$_generation'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          if (widget.placeholder != null) return widget.placeholder!;
          return Container(
            width: widget.width,
            height: widget.height,
            color: widget.placeholderColor,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF4C2C2),
              ),
            ),
          );
        },
        errorBuilder: (context, _, _) {
          _scheduleRetry();
          return _fallback();
        },
      );
    } else {
      final safeCacheWidth =
          (widget.cacheWidth != null && widget.cacheWidth! > 0)
              ? widget.cacheWidth
              : null;
      final safeCacheHeight =
          (widget.cacheHeight != null && widget.cacheHeight! > 0)
              ? widget.cacheHeight
              : null;
      image = CachedNetworkImage(
        key: ValueKey('${widget.imageUrl}#$_generation'),
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: safeCacheWidth,
        memCacheHeight: safeCacheHeight,
        filterQuality: widget.filterQuality,
        cacheManager: widget.cacheManager,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (context, _) {
          if (widget.placeholder != null) return widget.placeholder!;
          return Container(
            width: widget.width,
            height: widget.height,
            color: widget.placeholderColor,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF4C2C2),
              ),
            ),
          );
        },
        errorWidget: (context, _, _) {
          _scheduleRetry();
          return _fallback();
        },
      );
    }

    // Reserve space before decode so rows/grids never jump.
    if (widget.aspectRatio != null &&
        (widget.width != null || widget.height != null)) {
      image = AspectRatio(aspectRatio: widget.aspectRatio!, child: image);
    } else if (widget.width != null && widget.height != null) {
      image = SizedBox(
        width: widget.width,
        height: widget.height,
        child: image,
      );
    }

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    // On native, isolate repaints so image decode/upload never repaints the parent row.
    // On web, skip RepaintBoundary to avoid upstream CanvasKit Sliver bug (flutter/flutter#192347).
    if (!AppNetworkImage._isWeb) {
      image = RepaintBoundary(child: image);
    }

    return image;
  }

  Widget _fallback() {
    if (widget.errorWidget != null) return widget.errorWidget!;
    Widget box = Container(
      width: widget.width,
      height: widget.height,
      color: widget.placeholderColor,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFF8A7A8E),
        size: 26,
      ),
    );
    if (widget.aspectRatio != null &&
        (widget.width != null || widget.height != null)) {
      box = AspectRatio(aspectRatio: widget.aspectRatio!, child: box);
    }
    if (widget.borderRadius != null) {
      box = ClipRRect(borderRadius: widget.borderRadius!, child: box);
    }
    return box;
  }
}

/// 2:3 poster default used by cinema / anime / books / manga grids.
///
/// Fixed [width] + aspect + `cacheWidth: 400` covers the common 120-200px card
/// range at up to 2x DPR without over-decoding. Pass a smaller `cacheWidth`
/// (240-300) for dense sub-120px thumbs, larger (800+) for detail heroes.
class AppPosterImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final int cacheWidth;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const AppPosterImage({
    super.key,
    required this.imageUrl,
    this.width = 175,
    this.cacheWidth = 400,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return AppNetworkImage(
      imageUrl: imageUrl,
      width: width,
      aspectRatio: 2 / 3,
      fit: fit,
      cacheWidth: cacheWidth,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
    );
  }
}