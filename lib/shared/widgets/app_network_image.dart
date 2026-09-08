import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

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
class AppNetworkImage extends StatelessWidget {
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
  });

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

  @override
  Widget build(BuildContext context) {
    if (!isValidUrl(imageUrl)) return _fallback(context);
    // Flutter Web CanvasKit (flutter/flutter#158093, #160199) has an upstream
    // engine bug where setting cacheWidth/memCacheWidth smaller than the intrinsic
    // image dimensions causes ResizeImage/createImageBitmap to detach the source
    // buffer before Skia uploads it, logging "WebGL: INVALID_VALUE: texImage2D: no image"
    // and rendering pure black rectangles. On web, allow native browser decode.
    final safeCacheWidth =
        (!kIsWeb && cacheWidth != null && cacheWidth! > 0) ? cacheWidth : null;
    final safeCacheHeight =
        (!kIsWeb && cacheHeight != null && cacheHeight! > 0) ? cacheHeight : null;
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: safeCacheWidth,
      memCacheHeight: safeCacheHeight,
      filterQuality: filterQuality,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (context, _) {
        if (placeholder != null) return placeholder!;
        return Container(
          width: width,
          height: height,
          color: placeholderColor,
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
      errorWidget: (context, _, _) => _fallback(context),
    );

    // Reserve space before decode so rows/grids never jump.
    if (aspectRatio != null && (width != null || height != null)) {
      image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    } else if (width != null && height != null) {
      image = SizedBox(width: width, height: height, child: image);
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    // Isolate repaints: image decode/upload never repaints the parent row.
    return RepaintBoundary(child: image);
  }

  Widget _fallback(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    Widget box = Container(
      width: width,
      height: height,
      color: placeholderColor,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFF8A7A8E),
        size: 26,
      ),
    );
    if (aspectRatio != null && (width != null || height != null)) {
      box = AspectRatio(aspectRatio: aspectRatio!, child: box);
    }
    if (borderRadius != null) {
      box = ClipRRect(borderRadius: borderRadius!, child: box);
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