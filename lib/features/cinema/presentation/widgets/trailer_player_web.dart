import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _onLoadListener;
  @override
  void initState() {
    super.initState();
    _viewType =
        'everglow-trailer-player-${widget.videoKey}-${DateTime.now().microsecondsSinceEpoch}';

    // Construct Youtube embed URL with optimized parameters
    // mute=1 ensures autoplay succeeds in modern browsers without user gesture interaction
    final queryParams = [
      'autoplay=${widget.autoplay ? 1 : 0}',
      'mute=${widget.muted ? 1 : 0}',
      'controls=0',
      'loop=${widget.loop ? 1 : 0}',
      'playlist=${widget.videoKey}', // playlist param is required for loop=1 to work in YT embeds
      'rel=0',
      'modestbranding=1',
      'showinfo=0',
      'iv_load_policy=3',
      'disablekb=1',
      'fs=0',
      'playsinline=1',
      'enablejsapi=1',
    ].join('&');

    final embedUrl =
        'https://www.youtube.com/embed/${widget.videoKey}?$queryParams';

    _iframe = web.HTMLIFrameElement()
      ..src = embedUrl
      ..allow = 'autoplay; encrypted-media; picture-in-picture'
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no')
      // YouTube's embedded player requires a real referrer; explicit
      // no-referrer or missing referrers surface as Error 153.
      ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');

    // Make the iframe oversized with a 16:9 aspect ratio so the YouTube
    // video fills the entire container (like object-fit: cover). The
    // wrapper's overflow:hidden clips anything outside the visible area.
    _iframe.style
      ..border = '0'
      ..position = 'absolute'
      ..top = '50%'
      ..left = '50%'
      ..transform = 'translate(-50%, -50%)'
      ..width = 'auto'
      ..height = 'auto'
      ..minWidth = '100%'
      ..minHeight = '100%'
      ..setProperty('aspect-ratio', '16 / 9')
      ..backgroundColor = '#000'
      ..pointerEvents = 'none';

    // Wrapper clips the iframe overflow (hides the title bar shifted above)
    final wrapper = web.document.createElement('div') as web.HTMLDivElement;
    wrapper.style
      ..position = 'relative'
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden';

    wrapper.appendChild(_iframe);

    // Transparent overlay sits on top of the iframe to absorb hover/click
    // events so the YouTube player never shows its pause/skip controls.
    final overlay = web.document.createElement('div') as web.HTMLDivElement;
    overlay.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..width = '100%'
      ..height = '100%'
      ..zIndex = '10'
      ..cursor = 'default'
      ..touchAction = 'none'
      ..setProperty('-webkit-touch-callout', 'none')
      ..setProperty('-webkit-user-select', 'none')
      ..setProperty('user-select', 'none');

    wrapper.appendChild(overlay);

    _onLoadListener = ((web.Event _) {
      if (mounted) {
        widget.onLoaded?.call();
      }
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => wrapper,
    );
  }

  @override
  void dispose() {
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    _iframe.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
