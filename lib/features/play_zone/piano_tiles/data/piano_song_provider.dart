import '../models/piano_note.dart';

class SongNote {
  final int midiNote;
  final double duration; // In beats (e.g. 1.0, 0.5, 2.0)
  final int line;        // Column index (0, 1, 2, 3)

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
  final List<SongNote> notes;

  const PianoSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.difficulty,
    required this.notes,
  });
}

class PianoSongProvider {
  static final List<PianoSong> songs = [
    PianoSong(
      id: 'twinkle_twinkle',
      title: 'Twinkle Twinkle Little Star',
      artist: 'Traditional',
      difficulty: 'Easy',
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
    PianoSong(
      id: 'ode_to_joy',
      title: 'Ode to Joy',
      artist: 'Ludwig van Beethoven',
      difficulty: 'Easy',
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
    PianoSong(
      id: 'fur_elise',
      title: 'Für Elise',
      artist: 'Ludwig van Beethoven',
      difficulty: 'Medium',
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
    PianoSong(
      id: 'canon_in_d',
      title: 'Canon in D (C-Major)',
      artist: 'Johann Pachelbel',
      difficulty: 'Hard',
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

  static List<PianoNote> initNotes(PianoSong song) {
    final notes = <PianoNote>[];
    for (var i = 0; i < song.notes.length; i++) {
      final sn = song.notes[i];
      notes.add(PianoNote(
        orderNumber: i,
        line: sn.line,
        midiNote: sn.midiNote,
        duration: sn.duration,
      ));
    }
    // Add 5 padding notes at the end to prevent drawing/upcoming check issues
    for (var i = 0; i < 5; i++) {
      notes.add(PianoNote(
        orderNumber: song.notes.length + i,
        line: -1,
        midiNote: 0,
        duration: 1.0,
      ));
    }
    return notes;
  }
}
