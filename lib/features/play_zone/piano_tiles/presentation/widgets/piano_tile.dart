import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../models/piano_note.dart';

class PianoTile extends StatelessWidget {
  final PianoNoteState state;
  final double height;
  final VoidCallback onTap;

  const PianoTile({
    super.key,
    required this.height,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: _decoration(),
          child: state == PianoNoteState.ready
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.blushGold.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  BoxDecoration _decoration() {
    switch (state) {
      case PianoNoteState.ready:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3E1F3D),
              Color(0xFF1E1226),
            ],
          ),
          border: Border.all(
            color: AppTheme.blushGold.withValues(alpha: 0.25),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case PianoNoteState.tapped:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
        );
      case PianoNoteState.missed:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.deepRose.withValues(alpha: 0.95),
              AppTheme.velvet,
            ],
          ),
          border: Border.all(
            color: AppTheme.roseQuartz,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        );
    }
  }
}
