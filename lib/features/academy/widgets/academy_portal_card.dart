import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/features/academy/screens/academy_hub_screen.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/core/theme/app_theme.dart';

class AcademyPortalCard extends StatelessWidget {
  const AcademyPortalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: GlassContainer(
        height: 220,
        borderRadius: BorderRadius.circular(32.0),
        border: Border.all(color: AppTheme.neonTeal.withValues(alpha: 0.3), width: 2),
        child: Stack(
          children: [
            // Shifting Aura
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.peachyMagenta.withValues(alpha: 0.2),
                ),
              ),
            ),
            
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AnimatedEmblem(
                    icon: Icons.school_rounded,
                    size: 60,
                    color: AppTheme.champagneGold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Everglow Academy',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        const Shadow(
                          color: AppTheme.peachyMagenta,
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  BouncyButton(
                    onTap: () => Navigator.push(context, AcademyHubScreen.route()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.peachyMagenta, AppTheme.neonTeal],
                        ),
                        borderRadius: BorderRadius.circular(32.0),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonTeal.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'ENTER PORTAL',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
