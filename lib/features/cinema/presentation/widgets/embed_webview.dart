import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

class EmbedWebView extends StatefulWidget {
  final String url;

  final double? aspectRatio;

  final VoidCallback? onLoaded;

  final VoidCallback? onError;

  final BorderRadius? borderRadius;

  final Set<String>? allowedHosts;

  final void Function(String message)? onPlayerMessage;

  const EmbedWebView({
    super.key,
    required this.url,
    this.aspectRatio,
    this.onLoaded,
    this.onError,
    this.borderRadius,
    this.allowedHosts,
    this.onPlayerMessage,
  });

  static (int, int)? parsePlayerEpisode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['type'] != 'cinesrc:nextepisode') {
        return null;
      }
      final season = (decoded['season'] as num?)?.toInt();
      final episode = (decoded['episode'] as num?)?.toInt();
      if (season == null || episode == null) return null;
      return (season, episode);
    } catch (_) {
      return null;
    }
  }

  static (int, int)? parsePlayerProgress(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final type = decoded['type'];
      if (type != 'cinesrc:timeupdate' && type != 'animex-progress') {
        return null;
      }
      final position = type == 'animex-progress'
          ? decoded['position']
          : decoded['currentTime'];
      final duration = decoded['duration'];
      if (position is! num ||
          duration is! num ||
          !position.isFinite ||
          !duration.isFinite ||
          position < 0 ||
          duration <= 0 ||
          position > duration) {
        return null;
      }
      return (position.round(), duration.round());
    } catch (_) {
      return null;
    }
  }

  static bool isOwnedPlayerUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    if (uri.host == 'everglow-1c6db.web.app' && uri.path == '/embed.html') {
      return true;
    }
    return uri.host == 'everglow-stream.khentplaysmoba.workers.dev' &&
        uri.path == '/proxyAnime' &&
        uri.queryParameters['source'] == 'cinema';
  }

  static bool isPlayerFailure(String raw) {
    if (raw == 'animex-content-error') return true;
    try {
      final data = jsonDecode(raw);
      return data is Map && data['type'] == 'everglow-embed-failed';
    } catch (_) {
      return false;
    }
  }

  @override
  State<EmbedWebView> createState() => _EmbedWebViewState();
}

class _EmbedWebViewState extends State<EmbedWebView> {
  static const String _androidUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static const Duration _loadTimeout = Duration(seconds: 15);

  static const String _embedReferrer = 'https://everglow-1c6db.web.app';

  late WebViewController _controller;
  bool _loading = true;
  bool _failed = false;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _configure(_controller);
  }

  Future<void> _configure(WebViewController controller) async {
    _loadTimer?.cancel();
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.black);

      if (widget.onPlayerMessage != null) {
        await controller.addJavaScriptChannel(
          'EverglowPlayer',
          onMessageReceived: (message) {
            if (!mounted || controller != _controller) return;
            if (EmbedWebView.isOwnedPlayerUrl(widget.url) &&
                EmbedWebView.isPlayerFailure(message.message)) {
              _fail();
              return;
            }
            widget.onPlayerMessage?.call(message.message);
          },
        );
      }

      if (defaultTargetPlatform == TargetPlatform.android &&
          controller.platform is AndroidWebViewController) {
        final android = controller.platform as AndroidWebViewController;
        await android.setMediaPlaybackRequiresUserGesture(false);
        await android.setMixedContentMode(MixedContentMode.compatibilityMode);
        await android.setAllowFileAccess(false);
        await controller.setUserAgent(_androidUserAgent);
      }

      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.isMainFrame &&
                EmbedWebView.isOwnedPlayerUrl(widget.url) &&
                Uri.tryParse(request.url)?.host !=
                    Uri.tryParse(widget.url)?.host) {
              return NavigationDecision.prevent;
            }
            final allowed = widget.allowedHosts;
            if (allowed == null) return NavigationDecision.navigate;
            final host = Uri.tryParse(request.url)?.host ?? '';
            if (allowed.contains(host)) return NavigationDecision.navigate;
            debugPrint('[EmbedWebView] Blocked hijack nav to ${request.url}');
            return NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            _loadTimer?.cancel();
            if (!mounted || controller != _controller || _failed) return;
            setState(() => _loading = false);
            widget.onLoaded?.call();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            _fail();
          },
        ),
      );

      await controller.loadRequest(
        Uri.parse(widget.url),
        headers: const {'Referer': _embedReferrer},
      );
      if (!mounted) return;
      _loadTimer = Timer(_loadTimeout, () {
        if (!mounted || !_loading || _failed) return;
        debugPrint('[EmbedWebView] Load timed out: ${widget.url}');
        _fail();
      });
    } catch (e) {
      debugPrint('[EmbedWebView] Failed to load ${widget.url}: $e');
      _fail();
    }
  }

  Future<void> _retry() async {
    _loadTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _failed = false;
      _loading = true;
    });
    final controller = WebViewController();
    _controller = controller;
    await _configure(controller);
  }

  void _fail() {
    if (!mounted || _failed) return;
    _loadTimer?.cancel();
    setState(() {
      _loading = false;
      _failed = true;
    });
    widget.onError?.call();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Stack(
      fit: StackFit.expand,
      children: [
        if (!_failed) WebViewWidget(controller: _controller),
        if (_loading && !_failed)
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.roseQuartz,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading player...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        if (_failed)
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.roseQuartz,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This source couldn\'t load',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.petalWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try again or switch to another source below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.roseQuartz,
                        side: BorderSide(
                          color: AppColors.roseQuartz.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final ratio = widget.aspectRatio;
    final radius = widget.borderRadius;
    if (radius == null) {
      if (ratio != null) {
        return AspectRatio(aspectRatio: ratio, child: player);
      }
      return SizedBox.expand(child: player);
    }
    if (ratio != null) {
      return ClipRRect(
        borderRadius: radius,
        child: AspectRatio(aspectRatio: ratio, child: player),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.expand(child: player),
    );
  }
}
