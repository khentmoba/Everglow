import 'package:flutter/material.dart';
import '../../models/piano_note.dart';
import 'piano_tile.dart';

class PianoLine extends AnimatedWidget {
  final int lineNumber;
  final List<PianoNote> currentNotes;
  final void Function(PianoNote) onTileTap;
  final double tileHeight;

  const PianoLine({
    super.key,
    required this.lineNumber,
    required this.currentNotes,
    required this.onTileTap,
    required this.tileHeight,
    required Animation<double> animation,
  }) : super(listenable: animation);

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final lineNotes = currentNotes.where((n) => n.line == lineNumber).toList();

    final tiles = lineNotes.map((note) {
      final index = currentNotes.indexOf(note);
      final offset = (3 - index + _animation.value) * tileHeight;

      return Transform.translate(
        offset: Offset(0, offset),
        child: PianoTile(
          height: tileHeight,
          state: note.state,
          onTap: () => onTileTap(note),
        ),
      );
    }).toList();

    return SizedBox.expand(
      child: Stack(children: tiles),
    );
  }
}
