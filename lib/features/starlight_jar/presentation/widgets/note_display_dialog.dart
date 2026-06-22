import 'package:flutter/material.dart';
import '../../domain/models/star_note.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteDisplayDialog extends StatelessWidget {
  final StarNote note;

  const NoteDisplayDialog({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.blushGold, size: 40),
            const SizedBox(height: 16),
            Text(
              note.content,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                color: AppTheme.roseQuartz,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "— ${note.author.toUpperCase()}",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.blushGold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${note.timestamp.month}/${note.timestamp.day}/${note.timestamp.year}",
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.petalWhite.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRose,
                foregroundColor: AppTheme.petalWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: Text("Close", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
