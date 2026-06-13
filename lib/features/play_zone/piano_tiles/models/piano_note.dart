/// Visual / scoring state of a falling tile.
enum PianoNoteState { ready, tapped, missed }

/// A single tile that scrolls down a lane.
///
/// [hitBeat] is the beat number at which the **bottom edge** of this tile
/// should cross the judgment line (i.e. the moment the player is supposed
/// to tap). [duration] is the tile's length in beats — longer notes become
/// taller tiles, just like piano roll style games.
class PianoNote {
  final int orderNumber;
  final int line;
  final int midiNote;
  final double duration;
  final double hitBeat;
  PianoNoteState state;

  PianoNote({
    required this.orderNumber,
    required this.line,
    required this.midiNote,
    required this.duration,
    required this.hitBeat,
    this.state = PianoNoteState.ready,
  });
}
