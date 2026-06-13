enum PianoNoteState { ready, tapped, missed }

class PianoNote {
  final int orderNumber;
  final int line;
  final int midiNote;
  final double duration;
  PianoNoteState state;

  PianoNote({
    required this.orderNumber,
    required this.line,
    required this.midiNote,
    required this.duration,
    this.state = PianoNoteState.ready,
  });
}
