import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import '../providers/garden_provider.dart';
import '../../data/models/garden_stats.dart';
import '../../data/models/plant_type.dart';
import 'garden_plant_view.dart';

/// Shared view showing both partners' gardens side by side.
class SharedGardenView extends StatefulWidget {
  const SharedGardenView({super.key});

  @override
  State<SharedGardenView> createState() => _SharedGardenViewState();
}

class _SharedGardenViewState extends State<SharedGardenView> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final provider = context.read<GardenProvider>();
    provider.watchPartner(auth.partnerUid);
  }

  @override
  void dispose() {
    context.read<GardenProvider>().stopWatchingPartner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final provider = context.watch<GardenProvider>();
    final myName = auth.currentUser == 'khentsgdz' ? 'Khent' : 'Clair';
    final partnerName = auth.partnerName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.roseQuartz,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Our Garden',
                    style: AppTypography.cormorantBold.copyWith(
                      fontSize: 22,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gardens side by side
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildGardenCard(myName, provider.stats, true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGardenCard(
                            partnerName,
                            provider.partnerStats,
                            false,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: _buildGardenCard(myName, provider.stats, true),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildGardenCard(
                          partnerName,
                          provider.partnerStats,
                          false,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGardenCard(String name, GardenStats? stats, bool isMine) {
    final plantType = stats != null
        ? PlantType.fromId(stats.plantType)
        : PlantType.all.first;
    final stage = stats?.currentStage ?? 0;
    final effectiveStage = plantType.effectiveStage(stage);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: AppTypography.cormorantBold.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          if (plantType.isInSeason)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.blushGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${plantType.seasonalBonusName} ✨',
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 10,
                  color: AppTheme.blushGold,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: 150,
            child: GardenPlantView(plantType: plantType, stage: effectiveStage),
          ),
          const SizedBox(height: 8),
          if (stats != null)
            Text(
              '${stats.streakCount} day streak · ${stats.totalInteractions} visits',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}
