import 'package:flutter/material.dart';

import 'embed_webview.dart';

/// Native trailer surface for the YouTube trailer player.
///
/// Android can't host the iframe used by the web player, so the same YouTube
/// embed runs inside an in-app WebView. Trailer taps no longer bounce out to
/// the browser.
class TrailerPlayer extends StatefulWidget {
  final String videoKey;
  final bool muted;
  final bool autoplay;
  final bool loop;
  final VoidCallback? onLoaded;

  const TrailerPlayer({
    super.key,
    required this.videoKey,
    this.muted = true,
    this.autoplay = true,
    this.loop = true,
    this.onLoaded,
  });

  @override
  State<TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<TrailerPlayer> {
  String get _embedUrl {
    final query = [
      'autoplay=${widget.autoplay ? 1 : 0}',
      'mute=${widget.muted ? 1 : 0}',
      'controls=1',
      'rel=0',
      'modestbranding=1',
      'playsinline=1',
      'fs=1',
      if (widget.loop) ...[
        'loop=1',
        'playlist=${widget.videoKey}',
      ],
    ].join('&');
    return 'https://www.youtube.com/embed/${widget.videoKey}?$query';
  }

  @override
  Widget build(BuildContext context) {
    return EmbedWebView(
      key: ValueKey(_embedUrl),
      url: _embedUrl,
      onLoaded: widget.onLoaded,
    );
  }
}
