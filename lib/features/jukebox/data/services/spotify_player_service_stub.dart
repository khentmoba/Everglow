import 'package:flutter/foundation.dart';
import 'spotify_auth_service.dart';

/// Stub for VM / test environments where Web Playback SDK is unavailable.
class SpotifyPlayerService extends ChangeNotifier {
  final SpotifyAuthService _auth;
  SpotifyPlayerService(this._auth);

  bool get isReady => false;
  bool get isConnected => false;
  String? get deviceId => null;
  String? get error => null;

  Future<void> init() async {}
  Future<void> playTrack(String trackId) async {}
  Future<void> pause() async {}
  Future<void> togglePlay() async {}
  void disposePlayer() {}
}
