import '../models/piano_note.dart';

/// Raw musical note as authored in a song: which lane, which pitch (MIDI),
/// and how many beats long.
class SongNote {
  final int midiNote;
  final double duration; // in beats (1.0 = quarter note, 0.5 = eighth, ...)
  final int line; // column index (0..3)

  const SongNote({
    required this.midiNote,
    required this.duration,
    required this.line,
  });
}

class PianoSong {
  final String id;
  final String title;
  final String artist;
  final String difficulty;

  /// Tempo expressed as milliseconds per beat. 500 ms/beat = 120 BPM.
  /// Lower = faster scroll.
  final int beatDurationMs;
  final List<SongNote> notes;

  const PianoSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.difficulty,
    required this.notes,
    this.beatDurationMs = 460,
  });
}

class PianoSongProvider {
  static final List<PianoSong> songs = [
    const PianoSong(
      id: 'twinkle_twinkle',
      title: 'Twinkle Twinkle Little Star',
      artist: 'Traditional',
      difficulty: 'Easy',
      beatDurationMs: 520, // ~115 BPM, gentle pace
      notes: [
        SongNote(midiNote: 60, duration: 1.0, line: 0),
        SongNote(midiNote: 60, duration: 1.0, line: 1),
        SongNote(midiNote: 67, duration: 1.0, line: 2),
        SongNote(midiNote: 67, duration: 1.0, line: 3),
        SongNote(midiNote: 69, duration: 1.0, line: 2),
        SongNote(midiNote: 69, duration: 1.0, line: 1),
        SongNote(midiNote: 67, duration: 2.0, line: 0),

        SongNote(midiNote: 65, duration: 1.0, line: 1),
        SongNote(midiNote: 65, duration: 1.0, line: 2),
        SongNote(midiNote: 64, duration: 1.0, line: 3),
        SongNote(midiNote: 64, duration: 1.0, line: 2),
        SongNote(midiNote: 62, duration: 1.0, line: 1),
        SongNote(midiNote: 62, duration: 1.0, line: 0),
        SongNote(midiNote: 60, duration: 2.0, line: 1),

        SongNote(midiNote: 67, duration: 1.0, line: 2),
        SongNote(midiNote: 67, duration: 1.0, line: 3),
        SongNote(midiNote: 65, duration: 1.0, line: 2),
        SongNote(midiNote: 65, duration: 1.0, line: 1),
        SongNote(midiNote: 64, duration: 1.0, line: 0),
        SongNote(midiNote: 64, duration: 1.0, line: 1),
        SongNote(midiNote: 62, duration: 2.0, line: 2),

        SongNote(midiNote: 67, duration: 1.0, line: 3),
        SongNote(midiNote: 67, duration: 1.0, line: 2),
        SongNote(midiNote: 65, duration: 1.0, line: 1),
        SongNote(midiNote: 65, duration: 1.0, line: 0),
        SongNote(midiNote: 64, duration: 1.0, line: 1),
        SongNote(midiNote: 64, duration: 1.0, line: 2),
        SongNote(midiNote: 62, duration: 2.0, line: 3),

        SongNote(midiNote: 60, duration: 1.0, line: 0),
        SongNote(midiNote: 60, duration: 1.0, line: 1),
        SongNote(midiNote: 67, duration: 1.0, line: 2),
        SongNote(midiNote: 67, duration: 1.0, line: 3),
        SongNote(midiNote: 69, duration: 1.0, line: 2),
        SongNote(midiNote: 69, duration: 1.0, line: 1),
        SongNote(midiNote: 67, duration: 2.0, line: 0),

        SongNote(midiNote: 65, duration: 1.0, line: 1),
        SongNote(midiNote: 65, duration: 1.0, line: 2),
        SongNote(midiNote: 64, duration: 1.0, line: 3),
        SongNote(midiNote: 64, duration: 1.0, line: 2),
        SongNote(midiNote: 62, duration: 1.0, line: 1),
        SongNote(midiNote: 62, duration: 1.0, line: 0),
        SongNote(midiNote: 60, duration: 2.0, line: 1),
      ],
    ),
    const PianoSong(
      id: 'ode_to_joy',
      title: 'Ode to Joy',
      artist: 'Ludwig van Beethoven',
      difficulty: 'Easy',
      beatDurationMs: 480, // ~125 BPM
      notes: [
        SongNote(midiNote: 64, duration: 1.0, line: 0),
        SongNote(midiNote: 64, duration: 1.0, line: 1),
        SongNote(midiNote: 65, duration: 1.0, line: 2),
        SongNote(midiNote: 67, duration: 1.0, line: 3),
        SongNote(midiNote: 67, duration: 1.0, line: 2),
        SongNote(midiNote: 65, duration: 1.0, line: 1),
        SongNote(midiNote: 64, duration: 1.0, line: 0),
        SongNote(midiNote: 62, duration: 1.0, line: 1),
        SongNote(midiNote: 60, duration: 1.0, line: 2),
        SongNote(midiNote: 60, duration: 1.0, line: 3),
        SongNote(midiNote: 62, duration: 1.0, line: 2),
        SongNote(midiNote: 64, duration: 1.0, line: 1),
        SongNote(midiNote: 64, duration: 1.5, line: 0),
        SongNote(midiNote: 62, duration: 0.5, line: 1),
        SongNote(midiNote: 62, duration: 2.0, line: 2),

        SongNote(midiNote: 64, duration: 1.0, line: 0),
        SongNote(midiNote: 64, duration: 1.0, line: 1),
        SongNote(midiNote: 65, duration: 1.0, line: 2),
        SongNote(midiNote: 67, duration: 1.0, line: 3),
        SongNote(midiNote: 67, duration: 1.0, line: 2),
        SongNote(midiNote: 65, duration: 1.0, line: 1),
        SongNote(midiNote: 64, duration: 1.0, line: 0),
        SongNote(midiNote: 62, duration: 1.0, line: 1),
        SongNote(midiNote: 60, duration: 1.0, line: 2),
        SongNote(midiNote: 60, duration: 1.0, line: 3),
        SongNote(midiNote: 62, duration: 1.0, line: 2),
        SongNote(midiNote: 64, duration: 1.0, line: 1),
        SongNote(midiNote: 62, duration: 1.5, line: 0),
        SongNote(midiNote: 60, duration: 0.5, line: 1),
        SongNote(midiNote: 60, duration: 2.0, line: 2),
      ],
    ),
    const PianoSong(
      id: 'fur_elise',
      title: 'Für Elise',
      artist: 'Ludwig van Beethoven',
      difficulty: 'Medium',
      beatDurationMs: 380, // ~158 BPM — busier rhythm
      notes: [
        SongNote(midiNote: 76, duration: 0.5, line: 0),
        SongNote(midiNote: 75, duration: 0.5, line: 1),
        SongNote(midiNote: 76, duration: 0.5, line: 0),
        SongNote(midiNote: 75, duration: 0.5, line: 1),
        SongNote(midiNote: 76, duration: 0.5, line: 0),
        SongNote(midiNote: 71, duration: 0.5, line: 2),
        SongNote(midiNote: 74, duration: 0.5, line: 3),
        SongNote(midiNote: 72, duration: 0.5, line: 2),
        SongNote(midiNote: 69, duration: 1.5, line: 1),

        SongNote(midiNote: 60, duration: 0.5, line: 0),
        SongNote(midiNote: 64, duration: 0.5, line: 1),
        SongNote(midiNote: 69, duration: 0.5, line: 2),
        SongNote(midiNote: 71, duration: 1.5, line: 3),

        SongNote(midiNote: 64, duration: 0.5, line: 0),
        SongNote(midiNote: 68, duration: 0.5, line: 1),
        SongNote(midiNote: 71, duration: 0.5, line: 2),
        SongNote(midiNote: 72, duration: 1.5, line: 3),
      ],
    ),
    const PianoSong(
      id: 'canon_in_d',
      title: 'Canon in D (C-Major)',
      artist: 'Johann Pachelbel',
      difficulty: 'Hard',
      beatDurationMs: 320, // ~188 BPM — quick tap-tempo
      notes: [
        SongNote(midiNote: 76, duration: 1.5, line: 0),
        SongNote(midiNote: 74, duration: 1.5, line: 1),
        SongNote(midiNote: 72, duration: 1.5, line: 2),
        SongNote(midiNote: 71, duration: 1.5, line: 3),
        SongNote(midiNote: 69, duration: 1.5, line: 2),
        SongNote(midiNote: 67, duration: 1.5, line: 1),
        SongNote(midiNote: 69, duration: 1.5, line: 0),
        SongNote(midiNote: 71, duration: 1.5, line: 1),

        SongNote(midiNote: 76, duration: 1.0, line: 0),
        SongNote(midiNote: 74, duration: 1.0, line: 1),
        SongNote(midiNote: 72, duration: 1.0, line: 2),
        SongNote(midiNote: 71, duration: 1.0, line: 3),
        SongNote(midiNote: 69, duration: 1.0, line: 2),
        SongNote(midiNote: 67, duration: 1.0, line: 1),
        SongNote(midiNote: 69, duration: 1.0, line: 0),
        SongNote(midiNote: 71, duration: 1.0, line: 1),
      ],
    ),
  ];

  /// Turn the static [SongNote] list into runtime [PianoNote] tiles with
  /// cumulative beat positions pre-computed so the renderer can position
  /// each tile from a single `currentBeat` value.
  static List<PianoNote> initNotes(PianoSong song) {
    final tiles = <PianoNote>[];
    var cursorBeat = 0.0;
    for (var i = 0; i < song.notes.length; i++) {
      final sn = song.notes[i];
      cursorBeat += sn.duration;
      tiles.add(
        PianoNote(
          orderNumber: i,
          line: sn.line,
          midiNote: sn.midiNote,
          duration: sn.duration,
          // The bottom edge of the tile should reach the judgment line at
          // `cursorBeat` (the running total of all previous note durations
          // plus this note's own length).
          hitBeat: cursorBeat,
        ),
      );
    }
    return tiles;
  }

  /// Every distinct MIDI pitch the song touches — used to pre-warm the
  /// audio player pool before play starts.
  static Set<int> uniqueMidiNotes(PianoSong song) {
    return song.notes.map((n) => n.midiNote).toSet();
  }
}
