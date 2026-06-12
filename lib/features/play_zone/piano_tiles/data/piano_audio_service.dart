import 'package:just_audio/just_audio.dart';

class PianoAudioService {
  static const List<String> _assetPaths = [
    'assets/audio/piano/a.wav',
    'assets/audio/piano/c.wav',
    'assets/audio/piano/e.wav',
    'assets/audio/piano/f.wav',
  ];

  final List<AudioPlayer> _players = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    for (final path in _assetPaths) {
      final player = AudioPlayer();
      try {
        await player.setAsset(path);
      } catch (_) {}
      _players.add(player);
    }
    _loaded = true;
  }

  Future<void> play(int line) async {
    if (line < 0 || line >= _players.length) return;
    final player = _players[line];
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
    _loaded = false;
  }
}
