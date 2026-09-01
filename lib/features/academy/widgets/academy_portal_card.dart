import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/animated_emblem.dart';
import '../../../shared/widgets/bouncy_button.dart';
import '../../../core/theme/app_typography.dart';

class AcademyPortalCard extends StatelessWidget {
  const AcademyPortalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: GlassContainer(
        height: 220,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.25),
          width: 1.5,
        ),
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
                  color: AppColors.deepRose.withValues(alpha: 0.15),
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
                    size: 50,
                    color: AppColors.blushGold,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Everglow Academy',
                    style: AppTypography.cormorantBold.copyWith(
                      fontSize: 28,
                      letterSpacing: 0.5,
                      shadows: [
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.4),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'Enter Everglow Academy',
                    button: true,
                    child: BouncyButton(
                      onTap: () => context.push('/academy'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.deepRose, AppColors.blushGold],
                          ),
                          borderRadius: BorderRadius.circular(24.0),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.deepRose.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'ENTER PORTAL',
                          style: AppTypography.outfitWhite.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.petalWhite,
                            letterSpacing: 2.0,
                          ),
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