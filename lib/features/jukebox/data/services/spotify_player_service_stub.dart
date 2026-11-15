import 'package:flutter/foundation.dart';
import 'spotify_auth_service.dart';

class SpotifyPlayerService extends ChangeNotifier {
  SpotifyPlayerService(SpotifyAuthService auth);

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
