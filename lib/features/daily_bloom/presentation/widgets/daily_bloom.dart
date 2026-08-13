import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/garden_provider.dart';
import '../../data/models/plant_type.dart';
import 'garden_plant_view.dart';
import 'garden_weather_overlay.dart';
import 'plant_picker_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

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

        return Column(
          children: [
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Seasonal weather overlay
                  Positioned.fill(
                    child: GardenWeatherOverlay(
                      season: GardenWeatherOverlay.currentSeason(),
                    ),
                  ),

                  // Tooltip
                  if (_showTooltip)
                    Positioned(
                      top: 0,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, -10 * (1 - value)),
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 240),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.velvet,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.65), width: 1.5),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      plantType.stageDescriptions[effectiveStage.clamp(0, 5)],
                                      textAlign: TextAlign.center,
                                      style: AppTypography.outfitHeading.copyWith(
                                        color: AppTheme.blushGold,
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
                                          color: AppTheme.petalWhite.withValues(alpha: 0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Plant
                  Positioned(
                    bottom: 0,
                    child: Semantics(
                      label: 'Your ${plantType.displayName.toLowerCase()}, stage $effectiveStage of 5. Tap for details.',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          _toggleTooltip();
                          _triggerPulse();
                        },
                        child: AnimatedScale(
                          scale: _scale,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: SizedBox(
                            height: 180,
                            width: 180,
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
                ],
              ),
            ),

            // Interaction Stats + Actions
            if (stats != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(Icons.flash_on, '${stats.streakCount} day streak'),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.favorite, '${stats.totalInteractions} visits'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionChip(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Change Plant',
                          onTap: () => PlantPickerSheet.show(
                            context,
                            currentPlantType: stats.plantType,
                            onSelected: (type) => provider.setPlantType(type),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildActionChip(
                          icon: Icons.park_rounded,
                          label: 'Our Garden',
                          onTap: () => context.push('/garden'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.moonlight.withValues(alpha: 0.15), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.blushGold),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 12,
              color: AppTheme.petalWhite.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.deepRose.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.blushGold.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.roseQuartz),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppTheme.roseQuartz,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
