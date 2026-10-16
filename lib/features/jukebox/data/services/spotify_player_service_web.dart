import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../../../../core/utils/logger.dart';
import 'spotify_auth_service.dart';

@JS('eval')
external JSAny? _evalJS(String code);

class SpotifyPlayerService extends ChangeNotifier {
  final SpotifyAuthService _auth;
  SpotifyPlayerService(this._auth);

  bool _ready = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _initialization;
  Completer<void>? _sdkReady;
  Timer? _sdkCheck;
  Timer? _tokenRefresh;
  final Map<String, JSFunction> _listeners = {};

  void _listen(String name, JSFunction listener) {
    final previous = _listeners[name];
    if (previous != null) web.window.removeEventListener(name, previous);
    _listeners[name] = listener;
    web.window.addEventListener(name, listener);
  }

  void _notify() {
    if (!_disposed) super.notifyListeners();
  }

  bool _connected = false;
  String? _deviceId;
  String? _error;

  bool get isReady => _ready;
  bool get isConnected => _connected;
  String? get deviceId => _deviceId;
  String? get error => _error;

  Future<void> init() {
    if (_disposed || _connected) return Future.value();
    final generation = _generation;
    return _initialization ??= _initialize(generation).whenComplete(() {
      if (generation == _generation) _initialization = null;
    });
  }

  Future<void> _initialize(int generation) async {
    if (!kIsWeb) return;
    final completer = _sdkReady = Completer<void>();
    void onReady() {
      if (!completer.isCompleted) completer.complete();
    }

    _listen('everglow_sdk_ready', ((web.Event _) => onReady()).toJS);
    _evalJS(
      'window.onSpotifyWebPlaybackSDKReady = function(){ window.dispatchEvent(new Event("everglow_sdk_ready")); }',
    );
    final present =
        _evalJS('typeof Spotify !== "undefined" && !!Spotify.Player')
            as JSBoolean?;
    if (present?.toDart ?? false) {
      onReady();
    } else {
      if (web.document.querySelector('script[data-spotify-sdk]') == null) {
        final script = web.HTMLScriptElement()
          ..src = 'https://sdk.scdn.co/spotify-player.js';
        script.setAttribute('data-spotify-sdk', '1');
        web.document.head!.appendChild(script);
      }
      _sdkCheck = Timer(const Duration(milliseconds: 900), () {
        final loaded =
            _evalJS('typeof Spotify !== "undefined" && !!Spotify.Player')
                as JSBoolean?;
        if (loaded?.toDart ?? false) onReady();
      });
    }
    try {
      await completer.future.timeout(const Duration(seconds: 12));
      if (_disposed || generation != _generation) return;
      _ready = true;
      _notify();
      await _createPlayer();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = 'Spotify SDK failed to load';
      Logger.e('Spotify SDK initialization failed', error: error);
      _notify();
    } finally {
      if (generation == _generation) {
        _sdkCheck?.cancel();
        _sdkReady = null;
      }
    }
  }

  Future<void> _createPlayer() async {
    final generation = _generation;
    final token = await _auth.getStoredAccessToken();
    if (_disposed || generation != _generation) return;
    if (token == null) {
      _error = 'Link Spotify first';
      _notify();
      return;
    }
    try {
      final escToken = token
          .replaceAll('\\', '\\\\')
          .replaceAll('"', r'\"')
          .replaceAll("'", r"\'")
          .replaceAll('\n', '');
      _listenWindowEvents();
      _evalJS('''
        (function(){
          if(window._everglowSpotifyPlayer) return;
          const player = new Spotify.Player({
            name: 'Everglow Jukebox',
            getOAuthToken: cb => { cb("$escToken"); },
            volume: 0.8
          });
          window._everglowSpotifyPlayer = player;
          player.addListener('ready', ({ device_id }) => {
            window.dispatchEvent(new CustomEvent('everglow_spotify_ready', {detail: device_id}));
          });
          player.addListener('not_ready', ({ device_id }) => {
            window.dispatchEvent(new CustomEvent('everglow_spotify_not_ready', {detail: device_id}));
          });
          player.addListener('initialization_error', ({message}) => {
            window.dispatchEvent(new CustomEvent('everglow_spotify_error', {detail: message}));
          });
          player.addListener('authentication_error', ({message}) => {
            window.dispatchEvent(new CustomEvent('everglow_spotify_auth_error', {detail: message}));
          });
          player.connect();
        })();
      ''');
      _scheduleTokenRefresh();
    } catch (e) {
      _error = e.toString();
      Logger.e('Spotify _createPlayer error', error: e);
      _notify();
    }
  }

  void _listenWindowEvents() {
    _listen(
      'everglow_spotify_ready',
      ((web.Event e) {
        final ce = e as web.CustomEvent;
        final detail = ce.detail;
        if (detail != null) _deviceId = (detail as JSString).toDart;
        _connected = true;
        _error = null;
        Logger.d('Spotify device ready: $_deviceId');
        _notify();
      }).toJS,
    );

    _listen(
      'everglow_spotify_not_ready',
      ((web.Event _) {
        _connected = false;
        _notify();
      }).toJS,
    );

    _listen(
      'everglow_spotify_error',
      ((web.Event e) {
        final ce = e as web.CustomEvent;
        final detail = ce.detail;
        _error = detail != null ? (detail as JSString).toDart : 'Unknown';
        Logger.w('Spotify error: $_error');
        _notify();
      }).toJS,
    );
  }

  void _scheduleTokenRefresh() {
    _tokenRefresh?.cancel();
    _tokenRefresh = Timer.periodic(const Duration(minutes: 50), (t) async {
      if (_disposed || !_connected) return;
      final generation = _generation;
      final fresh = await _auth.getStoredAccessToken();
      if (_disposed || generation != _generation || fresh == null) return;
      final esc = fresh.replaceAll('\\', '\\\\').replaceAll('"', r'\"');
      _evalJS(
        'if(window._everglowSpotifyPlayer) { window._everglowSpotifyPlayer._options.getOAuthToken = (cb)=>cb("$esc"); }',
      );
    });
  }

  Future<void> playTrack(String trackId) async {
    final generation = _generation;
    await init();
    if (_disposed || generation != _generation) return;
    if (_deviceId == null) {
      Logger.w('playTrack: no deviceId yet - will retry after ready');
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || generation != _generation) return;
        if (_deviceId != null) break;
      }
      if (_deviceId == null) return;
    }
    final token = await _auth.getStoredAccessToken();
    if (_disposed || generation != _generation || token == null) return;
    final escToken = token.replaceAll('\\', '\\\\').replaceAll('"', r'\"');
    final escDevice = _deviceId!.replaceAll('"', r'\"');
    _evalJS('''
      (async () => {
        try {
          await fetch("https://api.spotify.com/v1/me/player", {
            method: "PUT",
            headers: {"Authorization": "Bearer $escToken", "Content-Type": "application/json"},
            body: JSON.stringify({device_ids: ["$escDevice"], play: false})
          });
          await new Promise(r=>setTimeout(r, 400));
          const res = await fetch("https://api.spotify.com/v1/me/player/play?device_id=$escDevice", {
            method: "PUT",
            headers: {"Authorization": "Bearer $escToken", "Content-Type": "application/json"},
            body: JSON.stringify({uris: ["spotify:track:$trackId"]})
          });
          console.log("[Everglow] play", res.status);
        } catch(e){ console.warn(e); }
      })();
    ''');
    Logger.d('Spotify play $trackId on $_deviceId');
  }

  Future<void> pause() async {
    _evalJS(
      'if(window._everglowSpotifyPlayer) window._everglowSpotifyPlayer.pause();',
    );
  }

  Future<void> togglePlay() async {
    _evalJS(
      'if(window._everglowSpotifyPlayer) window._everglowSpotifyPlayer.togglePlay();',
    );
  }

  void disposePlayer() {
    ++_generation;
    _initialization = null;
    _sdkCheck?.cancel();
    _tokenRefresh?.cancel();
    if (_sdkReady case final pending? when !pending.isCompleted) {
      pending.complete();
    }
    _sdkReady = null;
    for (final entry in _listeners.entries) {
      web.window.removeEventListener(entry.key, entry.value);
    }
    _listeners.clear();
    _ready = false;
    try {
      _evalJS(
        'if(window._everglowSpotifyPlayer) { window._everglowSpotifyPlayer.disconnect(); window._everglowSpotifyPlayer=null; }',
      );
    } catch (_) {}
    _connected = false;
    _deviceId = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    disposePlayer();
    super.dispose();
  }
}
