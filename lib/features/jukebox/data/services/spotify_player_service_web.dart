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
  bool _connected = false;
  String? _deviceId;
  String? _error;

  bool get isReady => _ready;
  bool get isConnected => _connected;
  String? get deviceId => _deviceId;
  String? get error => _error;

  Future<void> init() async {
    if (!kIsWeb) return;
    if (_ready) return;
    if (web.document.querySelector('script[data-spotify-sdk]') == null) {
      final s = web.document.createElement('script') as web.HTMLScriptElement;
      s.src = 'https://sdk.scdn.co/spotify-player.js';
      s.setAttribute('data-spotify-sdk', '1');
      web.document.head!.appendChild(s);
      Logger.d('Spotify SDK script injected');
    }
    final completer = Completer<void>();
    void onReady() {
      if (completer.isCompleted) return;
      _ready = true;
      completer.complete();
      notifyListeners();
      _createPlayer();
    }

    _evalJS('window.onSpotifyWebPlaybackSDKReady = function(){ window.dispatchEvent(new Event("everglow_sdk_ready")); }');
    web.window.addEventListener('everglow_sdk_ready', ((web.Event _) => onReady()).toJS);

    Timer(const Duration(milliseconds: 900), () {
      final present = _evalJS('typeof Spotify !== "undefined" && !!Spotify.Player') as JSBoolean?;
      if (!completer.isCompleted && (present?.toDart ?? false)) onReady();
    });

    try {
      await completer.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      _error = 'Spotify SDK failed to load';
      Logger.w('Spotify SDK load timeout');
      notifyListeners();
    }
  }

  Future<void> _createPlayer() async {
    final token = await _auth.getStoredAccessToken();
    if (token == null) {
      _error = 'Link Spotify first';
      notifyListeners();
      return;
    }
    try {
      final escToken = token.replaceAll('\\', '\\\\').replaceAll('"', r'\"').replaceAll("'", r"\'").replaceAll('\n', '');
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
      _listenWindowEvents();
      _scheduleTokenRefresh();
    } catch (e) {
      _error = e.toString();
      Logger.e('Spotify _createPlayer error', error: e);
      notifyListeners();
    }
  }

  void _listenWindowEvents() {
    web.window.addEventListener('everglow_spotify_ready', ((web.Event e) {
      final ce = e as web.CustomEvent;
      final detail = ce.detail;
      if (detail != null) _deviceId = (detail as JSString).toDart;
      _connected = true;
      _error = null;
      Logger.d('Spotify device ready: $_deviceId');
      notifyListeners();
    }).toJS);

    web.window.addEventListener('everglow_spotify_not_ready', ((web.Event _) {
      _connected = false;
      notifyListeners();
    }).toJS);

    web.window.addEventListener('everglow_spotify_error', ((web.Event e) {
      final ce = e as web.CustomEvent;
      final detail = ce.detail;
      _error = detail != null ? (detail as JSString).toDart : 'Unknown';
      Logger.w('Spotify error: $_error');
      notifyListeners();
    }).toJS);
  }

  void _scheduleTokenRefresh() {
    Timer.periodic(const Duration(minutes: 50), (t) async {
      if (!_connected) return;
      final fresh = await _auth.getStoredAccessToken();
      if (fresh == null) return;
      final esc = fresh.replaceAll('\\', '\\\\').replaceAll('"', r'\"');
      _evalJS('if(window._everglowSpotifyPlayer) { window._everglowSpotifyPlayer._options.getOAuthToken = (cb)=>cb("$esc"); }');
    });
  }

  Future<void> playTrack(String trackId) async {
    await init();
    if (_deviceId == null) {
      Logger.w('playTrack: no deviceId yet - will retry after ready');
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (_deviceId != null) break;
      }
      if (_deviceId == null) return;
    }
    final token = await _auth.getStoredAccessToken();
    if (token == null) return;
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
    _evalJS('if(window._everglowSpotifyPlayer) window._everglowSpotifyPlayer.pause();');
  }

  Future<void> togglePlay() async {
    _evalJS('if(window._everglowSpotifyPlayer) window._everglowSpotifyPlayer.togglePlay();');
  }

  void disposePlayer() {
    try {
      _evalJS('if(window._everglowSpotifyPlayer) { window._everglowSpotifyPlayer.disconnect(); window._everglowSpotifyPlayer=null; }');
    } catch (_) {}
    _connected = false;
    _deviceId = null;
    notifyListeners();
  }
}
