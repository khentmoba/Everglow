enum PianoNoteState { ready, tapped, missed }

class PianoNote {
  final int orderNumber;
  final int line;
  PianoNoteState state;

  PianoNote(this.orderNumber, this.line, {this.state = PianoNoteState.ready});
}
