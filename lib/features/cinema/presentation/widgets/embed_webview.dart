import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

/// In-app WebView surface used by the native cinema players.
///
/// The web player hosts the provider embeds as iframes; Android can't render
/// those, but a WebView can run the same embed URLs in-app. This widget keeps
/// the loading and main-frame failure states visible so users never stare at
/// a blank grey surface.
class EmbedWebView extends StatefulWidget {
  final String url;

  /// When provided, the player is letterboxed to this ratio. Otherwise it
  /// expands to fill the parent's constraints.
  final double? aspectRatio;

  /// Called once the main document finishes loading.
  final VoidCallback? onLoaded;

  /// Called when the main document fails to load (e.g. 404 / refused).
  final VoidCallback? onError;

  /// Optional corner rounding for framed player surfaces.
  final BorderRadius? borderRadius;

  const EmbedWebView({
    super.key,
    required this.url,
    this.aspectRatio,
    this.onLoaded,
    this.onError,
    this.borderRadius,
  });

  @override
  State<EmbedWebView> createState() => _EmbedWebViewState();
}

class _EmbedWebViewState extends State<EmbedWebView> {
  static const String _androidUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  /// How long to wait for the embed before treating the load as failed.
  /// Mirrors the web player's [_loadTimeout] so a hung WebView lands on the
  /// interactive error card instead of leaving the user staring at a spinner.
  static const Duration _loadTimeout = Duration(seconds: 15);

  // YouTube embeds reject requests with no referrer (Error 153), and a
  // WebView sends none by default. This public app origin is used as the
  // embed referrer so trailer playback keeps working in-app.
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
          onPageFinished: (url) {
            _loadTimer?.cancel();
            if (!mounted) return;
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
    // Rebuild with a fresh controller. A dead WebView can linger as a
    // platform view that keeps swallowing touches even underneath the
    // Flutter error card, so the retry never reuses the failed instance.
    final controller = WebViewController();
    _controller = controller;
    await _configure(controller);
  }

  void _fail() {
    if (!mounted) return;
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
        // Unmount the WebView on failure: on Android the platform view can
        // keep intercepting taps in its bounds even when Flutter paints the
        // error card above it, which makes the retry UI unresponsive.
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
              padding: const EdgeInsets.all(24),
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
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
