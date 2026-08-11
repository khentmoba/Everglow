import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/shared/widgets/animated_emblem.dart';
import 'package:everglow/shared/widgets/bouncy_button.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/shared/widgets/everglow/everglow_feature_header.dart';
import 'package:everglow/core/theme/app_typography.dart';

class PlayZoneHubScreen extends StatefulWidget {
  const PlayZoneHubScreen({super.key});

  @override
  State<PlayZoneHubScreen> createState() => _PlayZoneHubScreenState();

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PlayZoneHubScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var slideTween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }
}

class _PlayZoneHubScreenState extends State<PlayZoneHubScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GamifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
              const EverglowFeatureHeader(
                title: 'Play Zone',
                subtitle: 'games for two',
                icon: Icons.sports_esports_rounded,
                hue: AppColors.auroraGold,
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: _buildTableTennisCard(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableTennisCard() {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24.0),
      border: Border.all(
        color: AppTheme.blushGold.withValues(alpha: 0.25),
        width: 1.5,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          children: [
            const AnimatedEmblem(
              icon: Icons.sports_tennis_rounded,
              size: 56,
              color: AppTheme.warmAmber,
            ),
            const SizedBox(height: 16),
            Text(
              'Table Tennis World Tour',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 28,
                letterSpacing: 0.5,
                shadows: [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smash your way through the world tournament bracket',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BouncyButton(
                  onTap: () => _startTableTennis(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.warmAmber, AppTheme.deepRose],
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.warmAmber.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'SOLO',
                      style: AppTypography.outfitWhite.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.petalWhite,
                        letterSpacing: 2.0,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BouncyButton(
                  onTap: () => _startTableTennis1v1(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.softLavender, AppTheme.deepRose],
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.softLavender.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          color: AppTheme.petalWhite,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '1v1',
                          style: AppTypography.outfitWhite.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.petalWhite,
                            letterSpacing: 2.0,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startTableTennis() {
    context.push('/play-zone/tt');
  }

  void _startTableTennis1v1() {
    context.push('/play-zone/tt/lobby');
  }
}
