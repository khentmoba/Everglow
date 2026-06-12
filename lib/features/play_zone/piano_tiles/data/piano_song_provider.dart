import '../models/piano_note.dart';

class PianoSongProvider {
  static List<PianoNote> initNotes() {
    const lines = <int>[
      0, 1, 2, 1, 3, 0, 1, 2, 3, 2,
      3, 0, 2, 1, 3, 0, 1, 2, 3, 2,
      3, 1, 2, 1, 3, 0, 1, 2, 3, 2,
      3, 1, 2, 1, 3, 0, 1, 2, 3, 2,
      3,
    ];
    final notes = <PianoNote>[];
    for (var i = 0; i < lines.length; i++) {
      notes.add(PianoNote(i, lines[i]));
    }
    for (var i = 0; i < 4; i++) {
      notes.add(PianoNote(lines.length + i, -1));
    }
    return notes;
  }
}
