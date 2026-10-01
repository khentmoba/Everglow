import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Renders one self-contained HTML mini-app inside a sandboxed iframe.
///
/// `sandbox="allow-scripts"` lets the game run its own JavaScript while the
/// frame stays opaque-origin: no access to the app, no storage, no top
/// navigation. Motchi is prompted to keep apps dependency-free (no CDN,
/// no network calls), so they run happily inside the sandbox.
class CanvasHtmlView extends StatefulWidget {
  final String html;

  const CanvasHtmlView({super.key, required this.html});

  @override
  State<CanvasHtmlView> createState() => _CanvasHtmlViewState();
}

class _CanvasHtmlViewState extends State<CanvasHtmlView> {
  web.HTMLIFrameElement? _iframe;

  @visibleForTesting
  web.HTMLIFrameElement? get debugIframe => _iframe;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _iframe = web.HTMLIFrameElement()
        // setAttribute (not IDL properties) so huge inline docs and the
        // sandbox token list apply reliably across browsers.
        ..setAttribute('srcdoc', widget.html)
        ..setAttribute('sandbox', 'allow-scripts')
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..setAttribute('title', 'Motchi canvas preview')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0';
    }
  }

  @override
  void didUpdateWidget(covariant CanvasHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _iframe?.setAttribute('srcdoc', widget.html);
    }
  }

  @override
  void dispose() {
    _iframe?.removeAttribute('srcdoc');
    _iframe?.src = 'about:blank';
    _iframe?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    // Built-in factory: no per-message registration to retain, and the
    // stored frame is blanked when the chat moves on.
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (element) {
        final iframe = _iframe;
        if (iframe != null) {
          (element as web.HTMLElement).appendChild(iframe);
        }
      },
    );
  }
}
