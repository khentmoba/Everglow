import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache shared by every manga/manhwa/manhua reader page.
///
/// The default image cache only lives in memory, so once Clair scrolls
/// past a few big pages the earlier ones are thrown away and must
/// download all over again when she scrolls back. This manager keeps
/// page bytes on disk (30 days, room for several chapters), so a page
/// that has loaded once stays loaded.
final CacheManager readerPageCacheManager = CacheManager(
  Config(
    'reader-pages',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 300,
  ),
);

/// One chapter page in the manga readers.
///
/// What it guarantees for Clair:
/// - Once a page loads, scrolling past it and back never reloads it.
///   The state stays alive ([AutomaticKeepAliveClientMixin]) and the
///   bytes stay in the disk cache above.
/// - A failed page retries by itself a few times with a short backoff
///   instead of sitting there as a black gap.
/// - When retries run out, the slot always shows the page number plus
///   a big per-page Retry button — never a blank black box, and never
///   a button that reloads the whole chapter.
/// - On Flutter Web it uses plain `Image.network` with gapless
///   playback, mirroring [AppNetworkImage]: `CachedNetworkImage` hits
///   an upstream CanvasKit texture bug there.
///
/// Parents that rewrite failing URLs (the Katana reader silently tries
/// the next CDN host) pass [onError]: it fires once per failure,
/// post-frame so the parent may call `setState`. Changing [imageUrl]
/// in response resets the retry counter for the new URL.
class ReaderPageImage extends StatefulWidget {
  final String imageUrl;

  /// 1-based page number shown in the loading / error slots.
  final int pageNumber;

  final BoxFit fit;

  /// Set for paged fit-height mode; null lets the page size itself
  /// (webtoon full-width strip).
  final double? height;

  /// Downscale width for the in-memory bitmap so more pages fit in
  /// memory. Defaults to screen width x device pixel ratio.
  final int? memCacheWidth;

  /// Slot colors so each reader keeps its own theme.
  final Color slotColor;
  final Color accentColor;
  final Color mutedColor;

  /// Same-URL automatic retries before the error slot appears.
  final int maxAutoRetries;

  /// Delay before the first automatic retry; doubles each attempt.
  final Duration firstRetryDelay;

  /// Fired (post-frame) on every failure. May be used to swap in a
  /// fallback URL; the widget resets itself for the new URL.
  final void Function()? onError;

  /// Extra button in the error slot, e.g. "Try another server".
  final Widget? secondaryAction;

  /// Test seam: production callers leave this null (shared disk
  /// cache); tests inject a failing manager to drive the retry path
  /// without real network or disk I/O.
  final BaseCacheManager? cacheManager;

  const ReaderPageImage({
    super.key,
    required this.imageUrl,
    required this.pageNumber,
    this.fit = BoxFit.fitWidth,
    this.height,
    this.memCacheWidth,
    required this.slotColor,
    required this.accentColor,
    required this.mutedColor,
    this.maxAutoRetries = 3,
    this.firstRetryDelay = const Duration(milliseconds: 700),
    this.onError,
    this.secondaryAction,
    this.cacheManager,
  });

  /// Overrides [kIsWeb] in widget tests to verify the web branch.
  @visibleForTesting
  static bool? debugUseWebImplementation;

  static bool get _isWeb => debugUseWebImplementation ?? kIsWeb;

  /// Warms the cache for a page Clair is about to reach, using the
  /// same provider (and disk cache) the widget itself reads through.
  static Future<void> precachePage(BuildContext context, String url) {
    if (url.isEmpty) return Future.value();
    Future<void> precache(ImageProvider provider) {
      try {
        return precacheImage(provider, context).catchError((_) {});
      } catch (_) {
        return Future.value();
      }
    }

    if (_isWeb) {
      return precache(NetworkImage(url));
    }
    return precache(CachedNetworkImageProvider(url));
  }

  @override
  State<ReaderPageImage> createState() => _ReaderPageImageState();
}

class _ReaderPageImageState extends State<ReaderPageImage>
    with AutomaticKeepAliveClientMixin {
  /// Bumped on every (re)try so the inner image gets a fresh [Key]
  /// and re-resolves instead of reusing its failed stream.
  int _generation = 0;
  int _attempt = 0;
  Timer? _retryTimer;

  /// Post-frame notifications already queued for this [_generation],
  /// so one failure notifies the parent exactly once.
  int _notifiedForGeneration = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant ReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
      _notifiedForGeneration = -1;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  bool get _exhausted => _attempt > widget.maxAutoRetries;

  /// Called from the error builder, which can run on every parent
  /// rebuild while failed — the guards keep one retry timer and one
  /// parent notification per attempt.
  void _handleError() {
    final onError = widget.onError;
    if (onError != null && _notifiedForGeneration != _generation) {
      _notifiedForGeneration = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onError();
      });
    }
    if (_attempt > widget.maxAutoRetries || _retryTimer != null) return;
    final delay = widget.firstRetryDelay * (1 << _attempt);
    _attempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!mounted) return;
      setState(() => _generation++);
    });
  }

  void _retryNow() {
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      widget.cacheManager?.removeFile(widget.imageUrl).catchError((_) {});
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _attempt = 0;
      _generation++;
    });
  }

  /// Slot heights stay bounded: an infinite page height (paged
  /// fit-height mode) would break the loading / error boxes, so
  /// those fall back to a fixed size like before.
  double _slotHeight(double fallback) {
    final h = widget.height;
    if (h == null || h.isInfinite) return fallback;
    return h;
  }

  int? _memCacheWidth(BuildContext context) {
    if (ReaderPageImage._isWeb) return null;
    final override = widget.memCacheWidth;
    if (override != null && override > 0) return override;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = width * dpr;
    if (w <= 0) return 1200;
    return w.clamp(400.0, 1600.0).round();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Widget image;
    if (ReaderPageImage._isWeb) {
      image = Image.network(
        widget.imageUrl,
        key: ValueKey('${widget.imageUrl}#$_generation'),
        width: double.infinity,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _pendingSlot(retrying: _attempt > 0);
        },
        errorBuilder: (context, _, _) {
          _handleError();
          if (_exhausted) return _errorSlot();
          return _pendingSlot(retrying: true);
        },
      );
    } else {
      image = CachedNetworkImage(
        key: ValueKey('${widget.imageUrl}#$_generation'),
        imageUrl: widget.imageUrl,
        width: double.infinity,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: _memCacheWidth(context),
        cacheManager: widget.cacheManager ?? readerPageCacheManager,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (context, _) => _pendingSlot(retrying: _attempt > 0),
        errorWidget: (context, _, _) {
          _handleError();
          if (_exhausted) return _errorSlot();
          return _pendingSlot(retrying: true);
        },
      );
    }

    // On native, isolate repaints so decode/upload never repaints the
    // parent list. On web, skip RepaintBoundary to avoid the upstream
    // CanvasKit Sliver bug (flutter/flutter#192347).
    if (!ReaderPageImage._isWeb) {
      image = RepaintBoundary(child: image);
    }
    return image;
  }

  /// Loading slot: always shows the page number plus a spinner, so a
  /// slow page never looks like a black gap.
  Widget _pendingSlot({required bool retrying}) {
    return Container(
      width: double.infinity,
      height: _slotHeight(380),
      alignment: Alignment.center,
      color: widget.slotColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            retrying
                ? 'Retrying page ${widget.pageNumber}…'
                : 'Page ${widget.pageNumber}',
            style: TextStyle(
              color: widget.mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: widget.accentColor.withValues(alpha: 0.7),
              strokeWidth: 2.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Failure slot after every automatic retry ran out: page number,
  /// message, and a per-page Retry that touches only this image.
  Widget _errorSlot() {
    return Container(
      width: double.infinity,
      height: _slotHeight(300),
      alignment: Alignment.center,
      color: widget.slotColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: widget.mutedColor, size: 32),
          const SizedBox(height: 8),
          Text(
            'Page ${widget.pageNumber} failed to load',
            style: TextStyle(color: widget.mutedColor),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _retryNow,
            child: Text(
              'Tap to retry',
              style: TextStyle(
                color: widget.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.secondaryAction != null) ...[
            const SizedBox(height: 10),
            widget.secondaryAction!,
          ],
        ],
      ),
    );
  }
}
