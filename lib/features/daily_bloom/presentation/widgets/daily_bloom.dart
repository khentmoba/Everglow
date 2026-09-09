import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/garden_provider.dart';
import '../../data/models/plant_type.dart';
import 'garden_plant_view.dart';
import 'garden_weather_overlay.dart';
import 'plant_picker_sheet.dart';
import '../../../../core/theme/app_typography.dart';

/// The living heart of the dashboard: Clair's plant in a night-garden
/// sanctuary card — moonlight glow, stars, seasonal weather, growth dots,
/// glowing stats, and two clear actions.
///
/// No panel-level tap: the plant (tooltip), Change (sheet), and Our Garden
/// (route) each own their gesture, so nested taps never double-fire.
class DailyBloom extends StatefulWidget {
  const DailyBloom({super.key});

  @override
  State<DailyBloom> createState() => _DailyBloomState();
}

class _DailyBloomState extends State<DailyBloom> {
  bool _showTooltip = false;
  double _scale = 1.0;

  void _toggleTooltip() {
    setState(() => _showTooltip = !_showTooltip);
    if (_showTooltip) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showTooltip = false);
      });
    }
  }

  void _triggerPulse() {
    setState(() => _scale = 1.2);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GardenProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;
        final stage = stats?.currentStage ?? 0;
        final plantType = stats != null
            ? PlantType.fromId(stats.plantType)
            : PlantType.all.first;
        final effectiveStage = plantType.effectiveStage(stage);
        final stageIndex = effectiveStage.clamp(0, 5);
        final stageName = plantType.stageDescriptions[stageIndex];

        // Same outer shape as the other Today panels so the zone sits evenly.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.velvet.withValues(alpha: 0.5),
                  AppColors.inkDeep.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: AppRadius.radiusX2,
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.09),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.inkDeep.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.auroraTeal.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.radiusX2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: _GardenHeader(
                      plantType: plantType,
                      stageName: stageName,
                      hasStats: stats != null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _GardenScene(
                      plantType: plantType,
                      effectiveStage: effectiveStage,
                      showTooltip: _showTooltip,
                      scale: _scale,
                      onPlantTap: () {
                        _toggleTooltip();
                        _triggerPulse();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GrowthDots(
                    effectiveStage: effectiveStage,
                    stageName: stageName,
                  ),
                  const SizedBox(height: 12),
                  if (stats == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: provider.hasError
                          ? _GhostAction(
                              icon: Icons.refresh_rounded,
                              label: 'Garden unavailable — retry',
                              onTap: provider.retry,
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'waking the garden…',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 12,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _StatTile(
                                icon: Icons.local_fire_department_rounded,
                                hue: AppColors.warmAmber,
                                value: '${stats.streakCount}',
                                label: stats.streakCount == 1
                                    ? 'day streak'
                                    : 'day streak',
                              ),
                              const SizedBox(width: 10),
                              _StatTile(
                                icon: Icons.favorite_rounded,
                                hue: AppColors.auroraRose,
                                value: '${stats.totalInteractions}',
                                label: 'visits',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _PrimaryAction(
                                  icon: Icons.park_rounded,
                                  label: 'Our Garden',
                                  onTap: () => context.push('/garden'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _GhostAction(
                                icon: Icons.swap_horiz_rounded,
                                label: 'Change',
                                onTap: () => PlantPickerSheet.show(
                                  context,
                                  currentPlantType: stats.plantType,
                                  onSelected: (type) =>
                                      provider.setPlantType(type),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Panel header: teal garden badge + title + plant · stage subtitle.
class _GardenHeader extends StatelessWidget {
  final PlantType plantType;
  final String stageName;
  final bool hasStats;

  const _GardenHeader({
    required this.plantType,
    required this.stageName,
    required this.hasStats,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.auroraTeal.withValues(alpha: 0.12),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: AppColors.auroraTeal.withValues(alpha: 0.24),
            ),
          ),
          child: const Icon(
            Icons.spa_rounded,
            color: AppColors.auroraTeal,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our Garden',
                style: AppTypography.cormorantBold.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 3),
              Text(
                hasStats ? '${plantType.displayName} · $stageName' : 'waking up…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.25,
                  color: AppColors.petalWhite.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Night-garden scene: gradient sky, moon glow, stars, seasonal weather,
/// ground shadow, and the breathing plant. Tap the plant for its story.
class _GardenScene extends StatelessWidget {
  final PlantType plantType;
  final int effectiveStage;
  final bool showTooltip;
  final double scale;
  final VoidCallback onPlantTap;

  const _GardenScene({
    required this.plantType,
    required this.effectiveStage,
    required this.showTooltip,
    required this.scale,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusLg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.inkDeep,
            AppColors.plum.withValues(alpha: 0.55),
            AppColors.velvet.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.07),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Moonlight glow, top right.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.75, -0.75),
                  radius: 0.9,
                  colors: [
                    AppColors.blushGold.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ground glow the plant grows out of.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, 0.95),
                  radius: 0.75,
                  colors: [
                    AppColors.auroraTeal.withValues(alpha: 0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Static stars — one cheap repaint-free layer.
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _StarfieldPainter()),
            ),
          ),
          // Seasonal weather particles (snow / petals / motes / leaves).
          Positioned.fill(
            child: GardenWeatherOverlay(
              season: GardenWeatherOverlay.currentSeason(),
            ),
          ),
          // Soft shadow under the pot.
          Positioned(
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                width: 150,
                height: 26,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Semantics(
              label:
                  'Your ${plantType.displayName.toLowerCase()}, stage $effectiveStage of 5. Tap for details.',
              button: true,
              child: GestureDetector(
                onTap: onPlantTap,
                child: AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    height: 190,
                    width: 190,
                    child: ExcludeSemantics(
                      child: GardenPlantView(
                        plantType: plantType,
                        stage: effectiveStage,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showTooltip)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, -10 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inkDeep.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          plantType
                              .stageDescriptions[effectiveStage.clamp(0, 5)],
                          textAlign: TextAlign.center,
                          style: AppTypography.outfitHeading.copyWith(
                            color: AppColors.blushGold,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        if (plantType.isInSeason) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${plantType.seasonalBonusName} bonus active ✨',
                            textAlign: TextAlign.center,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Twelve fixed stars. Static paint, zero animation cost.
class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  static const _stars = [
    (0.08, 0.10, 1.6, 0.7),
    (0.18, 0.28, 1.2, 0.4),
    (0.30, 0.08, 1.9, 0.8),
    (0.42, 0.22, 1.1, 0.35),
    (0.55, 0.07, 1.5, 0.6),
    (0.66, 0.26, 1.2, 0.4),
    (0.76, 0.12, 1.8, 0.75),
    (0.88, 0.30, 1.3, 0.45),
    (0.93, 0.08, 1.5, 0.6),
    (0.24, 0.45, 1.0, 0.3),
    (0.62, 0.44, 1.0, 0.3),
    (0.84, 0.48, 1.1, 0.32),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in _stars) {
      final dx = star.$1 * size.width;
      final dy = star.$2 * size.height;
      paint.color = AppColors.petalWhite.withValues(alpha: star.$4 * 0.6);
      canvas.drawCircle(Offset(dx, dy), star.$3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Five growth dots showing how far the plant has bloomed.
class _GrowthDots extends StatelessWidget {
  final int effectiveStage;
  final String stageName;

  const _GrowthDots({required this.effectiveStage, required this.stageName});

  @override
  Widget build(BuildContext context) {
    final filled = effectiveStage.clamp(0, 5);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= filled
                  ? AppColors.auroraGold
                  : AppColors.moonlight.withValues(alpha: 0.15),
              boxShadow: i <= filled
                  ? [
                      BoxShadow(
                        color: AppColors.auroraGold.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          if (i < 5) const SizedBox(width: 7),
        ],
        const SizedBox(width: 10),
        Text(
          'Stage $filled of 5 · $stageName',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 11,
            letterSpacing: 0.3,
            color: AppColors.petalWhite.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Glowing stat tile: big numeral + tiny label.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color hue;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.hue,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.06),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.09),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: hue),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 18,
                    height: 1.0,
                    color: AppColors.petalWhite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 10,
                letterSpacing: 1.1,
                color: hue.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary rose action: full-width, 46px, easy to tap.
class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.deepRose, AppColors.roseDark],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.petalWhite),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 13,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.petalWhite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet ghost action for the secondary choice.
class _GhostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GhostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: AppColors.petalWhite.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppColors.petalWhite.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
