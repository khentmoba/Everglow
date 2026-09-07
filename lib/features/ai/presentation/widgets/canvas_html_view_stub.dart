import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Native preview: runs Mochi's self-contained HTML mini-app (e.g. chess)
/// inside an on-device WebView so the canvas works on Clair's phone and
/// tablet — not just the web app.
///
/// Isolation: JavaScript runs (games need it), but the controller exposes
/// no JavaScript channels, and every navigation attempt is blocked, so the
/// app can't leave its single page or reach app state.
class CanvasHtmlView extends StatefulWidget {
  final String html;

  const CanvasHtmlView({super.key, required this.html});

  @override
  State<CanvasHtmlView> createState() => _CanvasHtmlViewState();
}

class _CanvasHtmlViewState extends State<CanvasHtmlView> {
  WebViewController? _controller;
  bool _loading = true;

  static bool get _webViewSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (_) => NavigationDecision.prevent,
            onWebResourceError: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        )
        ..loadHtmlString(widget.html);
      _controller = controller;
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant CanvasHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html && _controller != null) {
      setState(() => _loading = true);
      _controller!.loadHtmlString(widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_webViewSupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Live preview needs the web app or the mobile app — open Everglow there to play this.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium().copyWith(
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_loading)
            const Center(child: CircularProgressIndicator.adaptive()),
        ],
      ),
    );
  }
}
