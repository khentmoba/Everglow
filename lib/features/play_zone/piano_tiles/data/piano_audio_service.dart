import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';

class PianoAudioService {
  static const Map<int, String> _refAssets = {
    60: 'assets/audio/piano/c.wav', // C4
    64: 'assets/audio/piano/e.wav', // E4
    65: 'assets/audio/piano/f.wav', // F4
    69: 'assets/audio/piano/a.wav', // A4
  };

  final Map<int, List<AudioPlayer>> _players = {};
  final Map<int, int> _poolIndex = {};
  static const int _poolSize = 3;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    for (final entry in _refAssets.entries) {
      final midi = entry.key;
      final path = entry.value;
      _players[midi] = [];
      _poolIndex[midi] = 0;
      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        try {
          await player.setAsset(path);
        } catch (_) {}
        _players[midi]!.add(player);
      }
    }
    _loaded = true;
  }

  int findNearestRef(int midiNote) {
    final refs = _refAssets.keys.toList();
    int nearest = refs.first;
    int minDiff = (midiNote - nearest).abs();
    for (final ref in refs) {
      final diff = (midiNote - ref).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = ref;
      }
    }
    return nearest;
  }

  Future<void> playMidi(int midiNote) async {
    if (!_loaded) await load();
    
    final nearest = findNearestRef(midiNote);
    final players = _players[nearest];
    if (players == null || players.isEmpty) return;

    final index = _poolIndex[nearest] ?? 0;
    final player = players[index];
    _poolIndex[nearest] = (index + 1) % players.length;

    final semitones = (midiNote - nearest).toDouble();
    final speed = math.pow(2.0, semitones / 12.0).toDouble();

    try {
      await player.setSpeed(speed);
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }

  // Fallback compatibility with old play(line) method
  Future<void> play(int line) async {
    final midiNotes = [60, 64, 65, 69]; // C4, E4, F4, A4
    if (line < 0 || line >= midiNotes.length) return;
    await playMidi(midiNotes[line]);
  }

  Future<void> dispose() async {
    for (final players in _players.values) {
      for (final p in players) {
        try {
          await p.dispose();
        } catch (_) {}
      }
    }
    _players.clear();
    _poolIndex.clear();
    _loaded = false;
  }
}
