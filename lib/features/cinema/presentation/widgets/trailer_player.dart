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
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'everglow-trailer-player-${widget.videoKey}-${DateTime.now().microsecondsSinceEpoch}';

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
      'enablejsapi=1'
    ].join('&');

    final embedUrl = 'https://www.youtube.com/embed/${widget.videoKey}?$queryParams';

    _iframe = web.HTMLIFrameElement()
      ..src = embedUrl
      ..allow = 'autoplay; encrypted-media; picture-in-picture'
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no');

    // Shift the iframe up so the YouTube title bar sits above the visible
    // area. The extra height compensates so no video content is lost at the
    // bottom — only the title bar at the top is clipped by overflow:hidden.
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = 'calc(100% + 38px)'
      ..marginTop = '-38px'
      ..backgroundColor = '#000'
      ..pointerEvents = 'none'; // defense-in-depth: overlay already blocks events, but guard here too

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
      ..zIndex = '10';

    wrapper.appendChild(overlay);

    _onLoadListener = ((web.Event _) {
      if (mounted) {
        setState(() => _isLoaded = true);
        widget.onLoaded?.call();
      }
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => wrapper);
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
