import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Controls a real `<video>` element playing an HLS stream through
/// hls.js inside a Flutter platform view.
///
/// Unlike the iframe-based providers, an HLS server exposes the actual
/// timeline, so the watch party can sync play/pause/seek precisely.
/// The bridge (`web/hls_bridge.js`) owns the Hls instances; this Dart
/// controller only talks to the bridge by id.
class HlsServerPlayerController {
  HlsServerPlayerState? _state;
  double _lastTime = 0.0;
  bool _muted = true;

  void attach(HlsServerPlayerState state) {
    _state = state;
  }

  void detach(HlsServerPlayerState state) {
    if (_state == state) _state = null;
  }

  bool get isAttached => _state != null;

  /// Latest known playback position in seconds. Falls back to the last
  /// reported time so the screen's clock keeps ticking even between
  /// `timeupdate` events.
  double get currentTime {
    final state = _state;
    if (state == null || state._video == null || state._destroyed) {
      return _lastTime;
    }
    try {
      final t = state._video!.currentTime;
      _lastTime = t;
      return t;
    } catch (_) {
      return _lastTime;
    }
  }

  bool get isPlaying {
    final state = _state;
    if (state == null || state._video == null || state._destroyed) {
      return false;
    }
    try {
      return !state._video!.paused;
    } catch (_) {
      return false;
    }
  }

  void load({
    required String url,
    required double startSeconds,
    required bool autoplay,
  }) {
    _state?._loadStream(url, startSeconds: startSeconds, autoplay: autoplay);
  }

  void play() {
    _state?._play();
  }

  void pause() {
    _state?._pause();
  }

  void seek(double seconds) {
    _state?._seek(seconds);
  }

  void setMuted(bool muted) {
    _muted = muted;
    _state?._setMuted(muted);
  }

  bool get isMuted => _muted;
}

/// Platform view for a self-hosted HLS stream.
class HlsServerPlayer extends StatefulWidget {
  final String streamUrl;
  final double startSeconds;
  final bool autoplay;

  /// Optional WebVTT subtitle track URL (e.g. Jellyfin's subtitle
  /// endpoint). Added as a `<track>` child on the real `<video>` element
  /// so sidecar/embedded subtitles render natively in the browser.
  final String? subtitleUrl;

  /// Unique platform view id. Keep it stable for the same room so the
  /// same `<video>` element survives rebuilds and remote sync updates.
  final String viewType;
  final HlsServerPlayerController controller;

  final VoidCallback? onReady;
  final ValueChanged<double>? onTimeUpdate;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onEnded;
  final ValueChanged<String>? onError;

  const HlsServerPlayer({
    super.key,
    required this.streamUrl,
    required this.startSeconds,
    required this.autoplay,
    required this.viewType,
    required this.controller,
    this.subtitleUrl,
    this.onReady,
    this.onTimeUpdate,
    this.onPlay,
    this.onPause,
    this.onEnded,
    this.onError,
  });

  @override
  State<HlsServerPlayer> createState() => HlsServerPlayerState();
}

class HlsServerPlayerState extends State<HlsServerPlayer> {
  web.HTMLVideoElement? _video;
  web.HTMLTrackElement? _subtitleTrack;
  int? _hlsId;
  bool _nativeHls = false;
  bool _ready = false;
  bool _destroyed = false;
  String? _loadingUrl;
  double _pendingStart = 0.0;
  bool _pendingAutoplay = false;
  bool _muted = true;
  int _pollTries = 0;

  JSFunction? _timeListener;
  JSFunction? _playListener;
  JSFunction? _pauseListener;
  JSFunction? _endedListener;
  JSFunction? _errorListener;
  JSFunction? _loadedListener;
  Timer? _bridgePollTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
    _createVideo();
    _attachSubtitle();
    _loadStream(
      widget.streamUrl,
      startSeconds: widget.startSeconds,
      autoplay: widget.autoplay,
    );
  }

  @override
  void didUpdateWidget(HlsServerPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitleUrl != widget.subtitleUrl) {
      _attachSubtitle();
    }
  }

  /// Adds (or replaces) the WebVTT subtitle track on the video element.
  void _attachSubtitle() {
    final video = _video;
    if (video == null || _destroyed) return;

    try {
      _subtitleTrack?.remove();
      _subtitleTrack = null;
    } catch (_) {
      // Track element may already be detached by a media reset.
    }

    final url = widget.subtitleUrl;
    if (url == null || url.isEmpty) return;
    try {
      final track = web.HTMLTrackElement()
        ..kind = 'subtitles'
        ..label = 'Subtitles'
        ..srclang = 'en'
        ..src = url
        ..default_ = true;
      video.appendChild(track);
      _subtitleTrack = track;
    } catch (e) {
      debugPrint('[HlsServerPlayer] Could not attach subtitles: $e');
    }
  }

  /// Forces any attached text tracks to show once the media is ready.
  void _showSubtitles() {
    final video = _video;
    if (video == null || _destroyed) return;
    try {
      final tracks = video.textTracks;
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].mode = 'showing';
      }
    } catch (_) {
      // Some browsers expose textTracks as a live list without settable
      // modes until metadata loads; the next ready event retries.
    }
  }

  void _createVideo() {
    final video = web.HTMLVideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000'
      ..controls = false
      ..autoplay = false
      ..muted = true
      ..playsInline = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..setAttribute('x5-playsinline', 'true');
    try {
      video.crossOrigin = 'anonymous';
    } catch (_) {
      // Some browsers reject this for non-media URLs; playback still works.
    }
    _video = video;

    try {
      _nativeHls = video
          .canPlayType('application/vnd.apple.mpegurl')
          .isNotEmpty;
    } catch (_) {
      _nativeHls = false;
    }

    _timeListener = ((web.Event _) {
      if (_destroyed || !mounted) return;
      widget.onTimeUpdate?.call(widget.controller.currentTime);
    }).toJS;
    _playListener = ((web.Event _) {
      if (_destroyed || !mounted) return;
      widget.onPlay?.call();
    }).toJS;
    _pauseListener = ((web.Event _) {
      if (_destroyed || !mounted) return;
      widget.onPause?.call();
    }).toJS;
    _endedListener = ((web.Event _) {
      if (_destroyed || !mounted) return;
      widget.onEnded?.call();
    }).toJS;
    _errorListener = ((web.Event _) {
      if (_destroyed || !mounted) return;
      final code = video.error?.code ?? 0;
      widget.onError?.call('video error $code');
    }).toJS;
    _loadedListener = ((web.Event _) {
      if (_destroyed || !mounted) return;
      _showSubtitles();
      _applyPendingStart();
    }).toJS;

    video.addEventListener('timeupdate', _timeListener);
    video.addEventListener('play', _playListener);
    video.addEventListener('pause', _pauseListener);
    video.addEventListener('ended', _endedListener);
    video.addEventListener('error', _errorListener);
    video.addEventListener('loadedmetadata', _loadedListener);

    ui_web.platformViewRegistry.registerViewFactory(
      widget.viewType,
      (int viewId) => video,
    );
  }

  void _loadStream(
    String url, {
    required double startSeconds,
    required bool autoplay,
  }) {
    _loadingUrl = url;
    _pendingStart = startSeconds;
    _pendingAutoplay = autoplay;
    _ready = false;
    _pollTries = 0;
    _destroyHls();
    final video = _video;
    if (video == null || _destroyed) return;

    try {
      video.pause();
      video.removeAttribute('src');
      video.load();
    } catch (_) {
      // Fresh element; nothing to reset.
    }
    _attachSubtitle();

    if (_nativeHls) {
      try {
        video.src = url;
      } catch (e) {
        widget.onError?.call('unable to load stream');
      }
    } else {
      _ensureBridgeAndCreate();
    }
  }

  void _ensureBridgeAndCreate() {
    if (_destroyed || _loadingUrl == null) return;
    final bridge = globalContext.getProperty<JSObject>(
      'EverglowHlsBridge'.toJS,
    );
    if (bridge.isUndefinedOrNull) {
      _scheduleBridgePoll();
      return;
    }
    final supported =
        bridge.callMethod<JSBoolean?>('isSupported'.toJS)?.toDart ?? false;
    if (!supported) {
      _scheduleBridgePoll();
      return;
    }
    _bridgePollTimer?.cancel();
    final video = _video;
    if (video == null || _loadingUrl == null) return;
    final id = bridge.callMethod<JSNumber?>(
      'create'.toJS,
      video,
      _loadingUrl!.toJS,
      <String, dynamic>{'startPosition': _pendingStart}.jsify(),
    );
    _hlsId = id?.toDartInt;
    if (_hlsId == null) {
      widget.onError?.call('hls.js failed to start');
    }
  }

  void _scheduleBridgePoll() {
    _bridgePollTimer?.cancel();
    if (_pollTries >= 40) {
      widget.onError?.call('hls.js unavailable');
      return;
    }
    _pollTries++;
    _bridgePollTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_destroyed && mounted) _ensureBridgeAndCreate();
    });
  }

  void _applyPendingStart() {
    if (_ready) return;
    _ready = true;
    _showSubtitles();
    if (_pendingStart > 0) {
      try {
        _video?.currentTime = _pendingStart;
      } catch (_) {
        // Stream may not be seekable yet; start from zero.
      }
    }
    widget.onReady?.call();
    if (_pendingAutoplay) {
      _setMuted(true);
      _play();
    }
  }

  void _play() {
    final video = _video;
    if (video == null || _destroyed) return;
    video.muted = _muted;
    try {
      video.play();
    } catch (e) {
      debugPrint('[HlsServerPlayer] play() rejected: $e');
    }
  }

  void _pause() {
    try {
      _video?.pause();
    } catch (_) {}
  }

  void _seek(double seconds) {
    if (_ready) {
      try {
        _video?.currentTime = seconds;
      } catch (_) {}
    } else {
      _pendingStart = seconds;
    }
  }

  void _setMuted(bool muted) {
    _muted = muted;
    try {
      _video?.muted = muted;
    } catch (_) {}
  }

  void _destroyHls() {
    final id = _hlsId;
    if (id == null) return;
    _hlsId = null;
    final bridge = globalContext.getProperty<JSObject>(
      'EverglowHlsBridge'.toJS,
    );
    if (!bridge.isUndefinedOrNull) {
      bridge.callMethod('destroy'.toJS, id.toJS);
    }
  }

  @override
  void dispose() {
    _destroyed = true;
    _bridgePollTimer?.cancel();
    _destroyHls();
    try {
      _subtitleTrack?.remove();
    } catch (_) {}
    _subtitleTrack = null;
    final video = _video;
    if (video != null) {
      if (_timeListener != null) {
        video.removeEventListener('timeupdate', _timeListener);
      }
      if (_playListener != null) {
        video.removeEventListener('play', _playListener);
      }
      if (_pauseListener != null) {
        video.removeEventListener('pause', _pauseListener);
      }
      if (_endedListener != null) {
        video.removeEventListener('ended', _endedListener);
      }
      if (_errorListener != null) {
        video.removeEventListener('error', _errorListener);
      }
      if (_loadedListener != null) {
        video.removeEventListener('loadedmetadata', _loadedListener);
      }
      try {
        video.pause();
        video.removeAttribute('src');
        video.load();
      } catch (_) {}
    }
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: widget.viewType);
  }
}
