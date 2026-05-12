import 'package:flutter/material.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class XPProgressBar extends StatelessWidget {
  final UserProgress progress;

  const XPProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Each level is 1000 XP
    final currentLevelXp = progress.xpTotal % 1000;
    final progressPercent = (currentLevelXp / 1000).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL ${progress.level}',
              style: GoogleFonts.outfit(
                color: AppTheme.champagneGold,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            Text(
              '$currentLevelXp / 1000 XP',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background track
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Progress fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              height: 12,
              width: MediaQuery.of(context).size.width * 0.8 * progressPercent, // Approximation
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.peachyMagenta, AppTheme.neonTeal],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonTeal.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
