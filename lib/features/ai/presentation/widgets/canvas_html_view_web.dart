import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Renders one self-contained HTML mini-app inside a sandboxed iframe.
///
/// `sandbox="allow-scripts"` lets the game run its own JavaScript while the
/// frame stays opaque-origin: no access to the app, no storage, no top
/// navigation. Mochi is prompted to keep apps dependency-free (no CDN,
/// no network calls), so they run happily inside the sandbox.
class CanvasHtmlView extends StatefulWidget {
  final String html;

  const CanvasHtmlView({super.key, required this.html});

  @override
  State<CanvasHtmlView> createState() => _CanvasHtmlViewState();
}

class _CanvasHtmlViewState extends State<CanvasHtmlView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'canvas-html-${widget.html.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      final source = widget.html;
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final iframe =
            web.document.createElement('iframe') as web.HTMLIFrameElement;
        // setAttribute (not IDL properties) so huge inline docs and the
        // sandbox token list apply reliably across browsers.
        iframe.setAttribute('srcdoc', source);
        iframe.setAttribute('sandbox', 'allow-scripts');
        iframe.setAttribute('referrerpolicy', 'no-referrer');
        iframe.setAttribute('title', 'Mochi canvas preview');
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.border = '0';
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return HtmlElementView(viewType: _viewType);
  }
}
