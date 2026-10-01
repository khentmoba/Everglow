import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class SpotifyEmbedView extends StatefulWidget {
  final String trackId;
  const SpotifyEmbedView({super.key, required this.trackId});
  @override
  State<SpotifyEmbedView> createState() => _SpotifyEmbedViewState();
}

class _SpotifyEmbedViewState extends State<SpotifyEmbedView> {
  web.HTMLIFrameElement? _iframe;

  @visibleForTesting
  web.HTMLIFrameElement? get debugIframe => _iframe;

  static String _embedUrl(String trackId) =>
      'https://open.spotify.com/embed/track/$trackId?utm_source=generator&theme=0';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _iframe = web.HTMLIFrameElement()
        ..src = _embedUrl(widget.trackId)
        ..style.width = '100%'
        ..style.height = '80px'
        ..style.border = '0'
        ..style.borderRadius = '12px'
        ..allow =
            'autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture'
        ..loading = 'lazy';
    }
  }

  @override
  void didUpdateWidget(covariant SpotifyEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _iframe?.src = _embedUrl(widget.trackId);
    }
  }

  @override
  void dispose() {
    _iframe?.src = 'about:blank';
    _iframe?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 80,
        width: double.infinity,
        // Built-in factory: no per-track registration to retain, and the
        // stored frame is blanked when the track changes or exits.
        child: HtmlElementView.fromTagName(
          tagName: 'div',
          onElementCreated: (element) {
            final iframe = _iframe;
            if (iframe != null) {
              (element as web.HTMLElement).appendChild(iframe);
            }
          },
        ),
      ),
    );
  }
}
