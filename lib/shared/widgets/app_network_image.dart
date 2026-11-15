import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/perf/perf_settings.dart';

class AppNetworkImage extends StatefulWidget {
  final String imageUrl;

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

  final FilterQuality filterQuality;

  final BaseCacheManager? cacheManager;

  final VoidCallback? onError;

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
    this.onError,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();

  @visibleForTesting
  static bool? debugUseWebImplementation;

  static bool get _isWeb => debugUseWebImplementation ?? kIsWeb;

  @visibleForTesting
  static int? resolveCacheWidth({
    required int? declaredCacheWidth,
    required double? displayWidth,
  }) {
    if (declaredCacheWidth != null && declaredCacheWidth > 0) {
      return declaredCacheWidth;
    }
    if (displayWidth == null || displayWidth <= 0) return null;
    return (displayWidth * 2).clamp(120, 1200).round();
  }

  @visibleForTesting
  static int? resolveCacheHeight({
    required int? declaredCacheHeight,
    required double? displayHeight,
    required int? explicitWidth,
  }) {
    if (declaredCacheHeight != null && declaredCacheHeight > 0) {
      return declaredCacheHeight;
    }
    if (explicitWidth != null) return null;
    if (displayHeight == null || displayHeight <= 0) return null;
    return (displayHeight * 2).clamp(120, 1800).round();
  }

  static final ValueNotifier<int> appResumeNotifier = ValueNotifier<int>(0);

  static void onAppResumed() {
    appResumeNotifier.value++;
  }

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
  static const _maxRetries = 5;
  static Duration _backoffFor(int attempt) =>
      Duration(seconds: 2 * (1 << (attempt * 2)));

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
    if (_attempt > 0) {
      _retryTimer?.cancel();
      _retryTimer = null;
      setState(() => _generation++);
    }
  }

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

  void _reportError() {
    widget.onError?.call();
    _scheduleRetry();
  }

  @override
  Widget build(BuildContext context) {
    final isAsset = widget.imageUrl.startsWith('assets/');
    if (!isAsset && !AppNetworkImage.isValidUrl(widget.imageUrl)) {
      if (widget.imageUrl.trim().isNotEmpty) widget.onError?.call();
      return _fallback();
    }

    Widget image;

    if (isAsset) {
      final decodeWidth = AppNetworkImage.resolveCacheWidth(
        declaredCacheWidth: widget.cacheWidth,
        displayWidth: widget.width,
      );
      image = Image.asset(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: decodeWidth == null
            ? null
            : PerfSettings.sizedDecodeWidth(decodeWidth),
        cacheHeight: widget.cacheHeight == null
            ? null
            : PerfSettings.sizedDecodeWidth(widget.cacheHeight!),
        filterQuality: widget.filterQuality,
        excludeFromSemantics: true,
        errorBuilder: (context, _, _) => _fallback(),
      );
    } else if (AppNetworkImage._isWeb) {
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
          final reduceMotion = AppMotion.reduceAmbientMotion(context);
          return Container(
            width: widget.width,
            height: widget.height,
            color: widget.placeholderColor,
            alignment: Alignment.center,
            child: reduceMotion
                ? const SizedBox.shrink()
                : const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.roseQuartz,
                    ),
                  ),
          );
        },
        errorBuilder: (context, _, _) {
          _reportError();
          return _fallback();
        },
      );
    } else {
      final safeCacheWidth = AppNetworkImage.resolveCacheWidth(
        declaredCacheWidth: widget.cacheWidth,
        displayWidth: widget.width,
      );
      final safeCacheHeight = AppNetworkImage.resolveCacheHeight(
        declaredCacheHeight: widget.cacheHeight,
        displayHeight: widget.height,
        explicitWidth: widget.cacheWidth,
      );
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
                color: AppColors.roseQuartz,
              ),
            ),
          );
        },
        errorWidget: (context, _, _) {
          _reportError();
          return _fallback();
        },
      );
    }

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
