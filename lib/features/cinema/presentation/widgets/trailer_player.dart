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
      
    _iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = '#000'
      ..pointerEvents = 'none'; // prevents clicking YouTube interface inside iframe during hover

    _onLoadListener = ((web.Event _) {
      if (mounted) {
        setState(() => _isLoaded = true);
        widget.onLoaded?.call();
      }
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _iframe);
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
