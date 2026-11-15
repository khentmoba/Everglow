import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../../core/utils/logger.dart';

final CacheManager readerPageCacheManager = CacheManager(
  Config(
    'reader-pages',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 300,
  ),
);

class ReaderPageImage extends StatefulWidget {
  final String imageUrl;

  final int pageNumber;

  final BoxFit fit;

  final double? height;

  final int? memCacheWidth;

  final Color slotColor;
  final Color accentColor;
  final Color mutedColor;

  final int maxAutoRetries;

  final Duration firstRetryDelay;

  final void Function()? onError;

  final void Function()? onLoaded;

  final Widget? secondaryAction;

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
    this.onLoaded,
    this.secondaryAction,
    this.cacheManager,
  });

  @visibleForTesting
  static bool? debugUseWebImplementation;

  static bool get _isWeb => debugUseWebImplementation ?? kIsWeb;

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

class _ReaderPageImageState extends State<ReaderPageImage> {
  int _generation = 0;
  int _attempt = 0;
  Timer? _retryTimer;

  int _notifiedForGeneration = -1;

  int _notifiedLoadedForGeneration = -1;

  @override
  void didUpdateWidget(covariant ReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
      _notifiedForGeneration = -1;
      _notifiedLoadedForGeneration = -1;
    }
  }

  void _notifyLoaded() {
    if (_notifiedLoadedForGeneration == _generation) return;
    _notifiedLoadedForGeneration = _generation;
    final onLoaded = widget.onLoaded;
    if (onLoaded == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onLoaded();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  bool get _exhausted => _attempt > widget.maxAutoRetries;

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
      widget.cacheManager?.removeFile(widget.imageUrl).catchError(
        (Object e, StackTrace st) {
          Logger.e(
            'ReaderPageImage: cache eviction failed for page '
            '${widget.pageNumber}',
            error: e,
            stackTrace: st,
          );
        },
      );
    } catch (e, st) {
      Logger.e(
        'ReaderPageImage: cache eviction threw for page ${widget.pageNumber}',
        error: e,
        stackTrace: st,
      );
    }
    if (!mounted) return;
    setState(() {
      _attempt = 0;
      _generation++;
    });
  }

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
          if (progress == null) {
            _notifyLoaded();
            return child;
          }
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
        imageBuilder: (context, imageProvider) {
          _notifyLoaded();
          return Image(
            image: imageProvider,
            width: double.infinity,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          );
        },
        errorWidget: (context, _, _) {
          _handleError();
          if (_exhausted) return _errorSlot();
          return _pendingSlot(retrying: true);
        },
      );
    }

    if (!ReaderPageImage._isWeb) {
      image = RepaintBoundary(child: image);
    }
    return image;
  }

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
