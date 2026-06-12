import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';

class RacingGameScreen extends StatefulWidget {
  final String mode;
  final String? matchId;
  final String? userId;

  const RacingGameScreen({
    super.key,
    this.mode = 'solo',
    this.matchId,
    this.userId,
  });

  @override
  State<RacingGameScreen> createState() => _RacingGameScreenState();
}

class _RacingGameScreenState extends State<RacingGameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.speed_rounded, size: 64, color: AppTheme.roseQuartz),
                  const SizedBox(height: 24),
                  Text(
                    'Midnight Drive',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.roseQuartz,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This game runs in a web browser. Please open Everglow on the web to play.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppTheme.petalWhite.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepRose,
                      foregroundColor: AppTheme.petalWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
