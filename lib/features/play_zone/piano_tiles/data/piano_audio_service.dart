import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';

/// Low-latency piano sample player.
///
/// Pre-allocates a small pool of [AudioPlayer]s per unique midi note
/// in the active song, pre-loads the nearest sample asset, and pre-sets
/// the playback speed for pitch-shifting. Tapping a tile then only needs
/// a `seek(0)` + `play()` call (fire-and-forget, no awaits) which gives
/// near-instant response on web and mobile.
class PianoAudioService {
  static const Map<int, String> _refAssets = {
    60: 'assets/audio/piano/c.wav', // C4
    64: 'assets/audio/piano/e.wav', // E4
    65: 'assets/audio/piano/f.wav', // F4
    69: 'assets/audio/piano/a.wav', // A4
  };

  static const int _poolPerNote = 2;

  final Map<int, List<AudioPlayer>> _notePlayers = {};
  final Map<int, int> _poolIndex = {};
  final Set<int> _preparedNotes = {};
  bool _disposed = false;

  /// Pre-load and pre-configure players for every midi note the song will
  /// use. Call this once at game start; subsequent [playMidi] calls are
  /// synchronous fire-and-forget.
  Future<void> prepareNotes(Iterable<int> midiNotes) async {
    final toPrepare = midiNotes.where((n) => !_preparedNotes.contains(n)).toSet();
    await Future.wait(toPrepare.map(_prepareNote));
  }

  Future<void> _prepareNote(int midi) async {
    if (_disposed) return;
    final ref = findNearestRef(midi);
    final asset = _refAssets[ref];
    if (asset == null) return;
    final semitones = (midi - ref).toDouble();
    final speed = math.pow(2.0, semitones / 12.0).toDouble();

    final players = <AudioPlayer>[];
    for (var i = 0; i < _poolPerNote; i++) {
      final player = AudioPlayer();
      try {
        await player.setAsset(asset);
        // setSpeed also changes pitch in just_audio's default mode which is
        // what we want for a quick MIDI-style transposition.
        await player.setSpeed(speed);
      } catch (_) {}
      players.add(player);
    }
    _notePlayers[midi] = players;
    _poolIndex[midi] = 0;
    _preparedNotes.add(midi);
  }

  int findNearestRef(int midiNote) {
    final refs = _refAssets.keys.toList();
    var nearest = refs.first;
    var minDiff = (midiNote - nearest).abs();
    for (final ref in refs) {
      final diff = (midiNote - ref).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = ref;
      }
    }
    return nearest;
  }

  /// Fire-and-forget playback. Returns immediately; never awaits.
  void playMidi(int midiNote) {
    if (_disposed) return;
    final players = _notePlayers[midiNote];
    if (players == null || players.isEmpty) {
      // Lazy fallback for notes we didn't pre-prepare.
      _prepareNote(midiNote).then((_) => playMidi(midiNote));
      return;
    }
    final idx = _poolIndex[midiNote] ?? 0;
    final player = players[idx];
    _poolIndex[midiNote] = (idx + 1) % players.length;

    // No awaits — we want the audio to fire as close to the tap as possible.
    // Swallow any individual errors so a single bad call can't break the game.
    try {
      player.seek(Duration.zero);
      player.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final players in _notePlayers.values) {
      for (final p in players) {
        try {
          await p.dispose();
        } catch (_) {}
      }
    }
    _notePlayers.clear();
    _poolIndex.clear();
    _preparedNotes.clear();
  }
}
