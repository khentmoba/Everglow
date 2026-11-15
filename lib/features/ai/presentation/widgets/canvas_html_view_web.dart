import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class CanvasHtmlView extends StatefulWidget {
  final String html;
  final ValueChanged<bool>? onContentFinishedChanged;

  const CanvasHtmlView({
    super.key,
    required this.html,
    this.onContentFinishedChanged,
  });

  @override
  State<CanvasHtmlView> createState() => _CanvasHtmlViewState();
}

class _CanvasHtmlViewState extends State<CanvasHtmlView> {
  web.HTMLIFrameElement? _iframe;
  late final JSFunction _messageListener = ((web.Event event) {
    final message = event as web.MessageEvent;
    if (_iframe == null ||
        !message.source.strictEquals(_iframe!.contentWindow).toDart) {
      return;
    }
    if (message.data == null || !message.data.isA<JSString>()) return;
    final data = (message.data as JSString).toDart;
    if (data == 'everglow:content-finished' ||
        data == 'everglow:content-reading') {
      widget.onContentFinishedChanged?.call(
        data == 'everglow:content-finished',
      );
    }
  }).toJS;

  @visibleForTesting
  web.HTMLIFrameElement? get debugIframe => _iframe;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      web.window.addEventListener('message', _messageListener);
      _iframe = web.HTMLIFrameElement()
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
    web.window.removeEventListener('message', _messageListener);
    _iframe?.removeAttribute('srcdoc');
    _iframe?.src = 'about:blank';
    _iframe?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
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
