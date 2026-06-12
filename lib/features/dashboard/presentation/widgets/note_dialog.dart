import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/hidden_note.dart';
import '../../../../core/theme/app_theme.dart';

class NoteDialog extends StatelessWidget {
  final HiddenNote note;

  const NoteDialog({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.velvet, // Dark romantic paper color
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header / Envelope flap style
              Container(
                height: 50,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.twilight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.favorite, color: AppTheme.deepRose, size: 24),
                    Positioned(
                      right: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: AppTheme.roseQuartz,
                      ),
                    ),
                  ],
                ),
              ),
              // Content area with max height
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: GoogleFonts.dancingScript(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.blushGold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          note.content,
                          style: GoogleFonts.caveat(
                            fontSize: 24,
                            color: AppTheme.petalWhite.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
