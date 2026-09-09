import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../../shared/widgets/everglow/everglow_card.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_section_header.dart';

/// Warm, inviting hub for couples arcade and mini-games.
///
/// Designed with responsive layout, ambient glows, and distinct visual
/// identities for Table Tennis, Scribble Together, and Couple Chess.
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
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraGold,
                  alignment: Alignment(0.8, -0.85),
                  size: 0.85,
                  opacity: 0.12,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(-0.85, 0.2),
                  size: 0.75,
                  opacity: 0.12,
                ),
                RadialGlow(
                  color: AppColors.auroraTeal,
                  alignment: Alignment(0.85, 0.9),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const EverglowFeatureHeader(
                  title: 'Play Zone',
                  subtitle: 'arcade \u00b7 co-op \u00b7 games for two',
                  icon: Icons.sports_esports_rounded,
                  hue: AppColors.auroraGold,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageH(context),
                      AppSpacing.md,
                      AppSpacing.pageH(context),
                      AppSpacing.x3,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildWelcomeHero(context),
                            const SizedBox(height: AppSpacing.xl),
                            const EverglowSectionHeader(
                              label: 'Choose your arena',
                              icon: Icons.videogame_asset_rounded,
                              hue: AppColors.auroraRose,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            PlayZoneGameCard(
                              title: 'Table Tennis World Tour',
                              subtitle:
                                  'Smash through the international tournament bracket solo, or rally face-to-face against Clair in a fast real-time 1v1 showdown!',
                              badge: 'ARCADE \u00b7 FAST 60 FPS',
                              icon: Icons.sports_tennis_rounded,
                              accent: AppColors.warmAmber,
                              tags: const [
                                '1v1 Matchmaking',
                                'Solo Tournament',
                                'Smooth Physics',
                              ],
                              actions: [
                                EverglowButton(
                                  label: 'Solo Tournament',
                                  icon: Icons.sports_tennis_rounded,
                                  backgroundColor: AppColors.warmAmber,
                                  foregroundColor: AppColors.inkDeep,
                                  onPressed: () => _startTableTennis(),
                                ),
                                EverglowButton.glass(
                                  label: '1v1 Match',
                                  icon: Icons.people_rounded,
                                  foregroundColor: AppColors.blushGold,
                                  onPressed: () => _startTableTennis1v1(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PlayZoneGameCard(
                              title: 'Scribble Together',
                              subtitle:
                                  'One draws, one guesses! Real-time synchronized canvas with live strokes, instant word reveals, and playful inside jokes.',
                              badge: 'CO-OP \u00b7 DRAW & GUESS',
                              icon: Icons.brush_rounded,
                              accent: AppColors.auroraTeal,
                              tags: const [
                                'Live Canvas',
                                'Couple Guessing',
                                'Instant Sync',
                              ],
                              actions: [
                                EverglowButton(
                                  label: 'Start Drawing',
                                  icon: Icons.brush_rounded,
                                  backgroundColor: AppColors.auroraTeal,
                                  foregroundColor: AppColors.inkDeep,
                                  onPressed: () =>
                                      context.push('/play-zone/scribble'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PlayZoneGameCard(
                              title: 'Couple Chess',
                              subtitle:
                                  'Our private board with full chess rules, checkmate detection, move history, and quiet cozy turns together.',
                              badge: 'CLASSIC \u00b7 PASS & PLAY',
                              icon: Icons.grid_4x4_rounded,
                              accent: AppColors.auroraRose,
                              tags: const [
                                '2-Player Board',
                                'Move History',
                                'No Rush',
                              ],
                              actions: [
                                EverglowButton(
                                  label: 'Play Chess',
                                  icon: Icons.grid_view_rounded,
                                  backgroundColor: AppColors.deepRose,
                                  foregroundColor: AppColors.petalWhite,
                                  onPressed: () =>
                                      context.push('/play-zone/chess'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.x2),
                            _buildFooterNote(),
                          ],
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
    );
  }

  Widget _buildWelcomeHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.velvet.withValues(alpha: 0.90),
            AppColors.inkDeep.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.x2),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.auroraGold.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.auroraGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.auroraGold.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  size: 20,
                  color: AppColors.auroraGold,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Ready for Game Night?',
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 24,
                    height: 1.15,
                    color: AppColors.roseQuartz,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Playful showdowns, shared live drawings, and cozy board games made just for Khent & Clair.',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.petalWhite.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _HeroPill(
                icon: Icons.people_outline_rounded,
                label: 'Couples Only',
                hue: AppColors.roseQuartz,
              ),
              _HeroPill(
                icon: Icons.bolt_rounded,
                label: 'Instant Sync',
                hue: AppColors.auroraGold,
              ),
              _HeroPill(
                icon: Icons.favorite_border_rounded,
                label: 'No Ads \u00b7 Pure Us',
                hue: AppColors.auroraRose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 14,
            color: AppColors.auroraRose.withValues(alpha: 0.85),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'More mini-games coming soon \u2014 made with love for Clair',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              color: AppColors.roseQuartz.withValues(alpha: 0.72),
            ),
          ),
        ],
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

/// Feature badge pill used inside the hero section.
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color hue;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.hue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: hue.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: hue),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: hue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rich, tactile game card for the Play Zone hub.
///
/// Extracted so layout tests can easily verify rendering across screen sizes.
class PlayZoneGameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accent;
  final List<String> tags;
  final List<Widget> actions;

  const PlayZoneGameCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.tags,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return EverglowCard(
      semanticLabel: title,
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadius.x2,
      fillColor: AppColors.velvet.withValues(alpha: 0.72),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.38),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 26, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cormorantBold.copyWith(
                        fontSize: 22,
                        height: 1.15,
                        color: AppColors.petalWhite,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              height: 1.45,
              color: AppColors.petalWhite.withValues(alpha: 0.80),
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.moonlight.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: AppColors.moonlight.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.roseQuartz.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
