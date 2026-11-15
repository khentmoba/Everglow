import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../../../core/utils/logger.dart';

class TrailerPlayer extends StatefulWidget {
  final String videoKey;
  final bool muted;
  final bool autoplay;
  final bool loop;
  final bool playing;
  final VoidCallback? onLoaded;

  const TrailerPlayer({
    super.key,
    required this.videoKey,
    this.muted = true,
    this.autoplay = true,
    this.loop = true,
    this.playing = true,
    this.onLoaded,
  });

  @override
  State<TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<TrailerPlayer> {
  late final web.HTMLIFrameElement _iframe;

  @visibleForTesting
  web.HTMLIFrameElement get debugIframe => _iframe;
  late final web.HTMLDivElement _wrapper;
  JSFunction? _onLoadListener;
  JSFunction? _onMessageListener;
  Timer? _readyFallbackTimer;
  Timer? _settleTimer;
  bool _loaded = false;
  bool _notifiedReady = false;
  bool _active = true;

  String _buildEmbedUrl(String key) {
    final queryParams = [
      'autoplay=${widget.autoplay && widget.playing ? 1 : 0}',
      'mute=${widget.muted ? 1 : 0}',
      'controls=0',
      'loop=${widget.loop ? 1 : 0}',
      if (widget.loop) 'playlist=$key',
      'rel=0',
      'modestbranding=1',
      'showinfo=0',
      'iv_load_policy=3',
      'cc_load_policy=0',
      'disablekb=1',
      'fs=0',
      'playsinline=1',
      'enablejsapi=1',
    ].join('&');
    return 'https://www.youtube.com/embed/$key?$queryParams';
  }

  void _postCommand(String command, [Object? args]) {
    try {
      final argsJson = args is String
          ? '"$args"'
          : (args != null ? '$args' : '""');
      final json = '{"event":"command","func":"$command","args":$argsJson}';
      _iframe.contentWindow?.postMessage(json.toJS, '*'.toJS);
    } catch (_) {}
  }

  void _notifyReady() {
    if (_notifiedReady || !mounted || !_active) return;
    _notifiedReady = true;
    _readyFallbackTimer?.cancel();
    _settleTimer?.cancel();
    widget.onLoaded?.call();
  }

  void _loadVideo(String key) {
    _loaded = false;
    _notifiedReady = false;
    _readyFallbackTimer?.cancel();
    _settleTimer?.cancel();
    _iframe.src = _buildEmbedUrl(key);
  }

  @override
  void initState() {
    super.initState();
    final embedUrl = _buildEmbedUrl(widget.videoKey);

    _iframe = web.HTMLIFrameElement()
      ..allow = 'autoplay; encrypted-media'
      ..setAttribute('frameborder', '0')
      ..setAttribute('scrolling', 'no')
      ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');

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

    final wrapper = _wrapper = web.HTMLDivElement();
    wrapper.style
      ..position = 'relative'
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden'
      ..pointerEvents = 'none';

    wrapper.appendChild(_iframe);

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
      ..setProperty('user-select', 'none')
      ..pointerEvents = 'none';

    wrapper.appendChild(overlay);

    _onMessageListener = ((web.MessageEvent event) {
      if (!mounted || !_active || _notifiedReady) return;
      if (event.source != _iframe.contentWindow) return;
      final raw = event.data;
      if (!raw.isA<JSString>()) return;
      final text = (raw as JSString).toDart;
      if (!text.contains('playerState')) return;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          final info = decoded['info'];
          final state = info is Map<String, dynamic>
              ? info['playerState']
              : null;
          if (state == 1) {
            _settleTimer?.cancel();
            _settleTimer = Timer(const Duration(milliseconds: 350), _notifyReady);
          }
        }
      } catch (e) {
        Logger.d('TrailerPlayer: ignored non-JSON postMessage: $e');
      }
    }).toJS;
    web.window.addEventListener('message', _onMessageListener);

    _onLoadListener = ((web.Event _) {
      _loaded = true;
      if (mounted && _active) {
        try {
          _iframe.contentWindow?.postMessage(
            '{"event":"listening"}'.toJS,
            '*'.toJS,
          );
        } catch (e) {
          Logger.d('TrailerPlayer: failed to subscribe to YT events: $e');
        }
        if (!widget.playing) {
          _postCommand('pauseVideo');
        }
        _readyFallbackTimer?.cancel();
        _readyFallbackTimer = Timer(
          const Duration(milliseconds: 2200),
          _notifyReady,
        );
      }
    }).toJS;
    _iframe.addEventListener('load', _onLoadListener);

    _iframe.src = embedUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active == active) return;
    _active = active;
    _loaded = false;
    _notifiedReady = false;
    _readyFallbackTimer?.cancel();
    _settleTimer?.cancel();
    _iframe.src = active ? _buildEmbedUrl(widget.videoKey) : 'about:blank';
  }

  @override
  void didUpdateWidget(covariant TrailerPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_active) return;
    if (oldWidget.videoKey != widget.videoKey) {
      _loadVideo(widget.videoKey);
    } else {
      if (oldWidget.muted != widget.muted && _loaded) {
        if (widget.muted) {
          _postCommand('mute');
        } else {
          _postCommand('unMute');
          _postCommand('setVolume', 100);
        }
      }
      if (oldWidget.playing != widget.playing && _loaded) {
        _postCommand(widget.playing ? 'playVideo' : 'pauseVideo');
      }
    }
  }

  @override
  void dispose() {
    _readyFallbackTimer?.cancel();
    _settleTimer?.cancel();
    if (_onMessageListener != null) {
      web.window.removeEventListener('message', _onMessageListener);
    }
    if (_onLoadListener != null) {
      _iframe.removeEventListener('load', _onLoadListener);
    }
    _iframe.src = 'about:blank';
    _iframe.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (element) {
        (element as web.HTMLElement).appendChild(_wrapper);
      },
    );
  }
}
