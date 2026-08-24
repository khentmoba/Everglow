import 'dart:ui_web' as ui_web;
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
  late final String _viewType;
  @override
  void initState() {
    super.initState();
    _viewType =
        'spotify-embed-${widget.trackId}-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final iframe =
            web.document.createElement('iframe') as web.HTMLIFrameElement;
        iframe.src =
            'https://open.spotify.com/embed/track/${widget.trackId}?utm_source=generator&theme=0';
        iframe.style.width = '100%';
        iframe.style.height = '80px';
        iframe.style.border = '0';
        iframe.style.borderRadius = '12px';
        iframe.allow =
            'autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture';
        iframe.loading = 'lazy';
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 80,
        width: double.infinity,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
