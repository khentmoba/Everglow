part of 'daily_bloom.dart';

/// Classic single-garden card: own plant, own stats. Used for cinema-only
/// profiles and tests without an auth session.
class _SingleGardenCard extends StatelessWidget {
  final GardenProvider provider;
  final GardenStats? stats;
  final bool showTooltip;
  final double scale;
  final VoidCallback onPlantTap;

  const _SingleGardenCard({
    required this.provider,
    required this.stats,
    required this.showTooltip,
    required this.scale,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = stats;
    final stage = resolved?.currentStage ?? 0;
    final plantType = resolved != null
        ? PlantType.fromId(resolved.plantType)
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
                  showTooltip: showTooltip,
                  scale: scale,
                  onPlantTap: onPlantTap,
                ),
              ),
              const SizedBox(height: 12),
              _GrowthDots(effectiveStage: effectiveStage, stageName: stageName),
              const SizedBox(height: 12),
              if (resolved == null)
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
                            value: '${resolved.streakCount}',
                            label: resolved.streakCount == 1
                                ? 'day streak'
                                : 'day streak',
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            icon: Icons.favorite_rounded,
                            hue: AppColors.auroraRose,
                            value: '${resolved.totalInteractions}',
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
                              currentPlantType: resolved.plantType,
                              onSelected: (type) => provider.setPlantType(type),
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
  }
}

/// Dual-garden card for Khent & Clair: both plants share one night scene,
/// Clair on the left, Khent on the right.
class _DualGardenCard extends StatelessWidget {
  final GardenProvider provider;
  final AuthService auth;
  final String? tooltipSide;
  final String? pulseSide;
  final ValueChanged<String> onPlantTap;

  const _DualGardenCard({
    required this.provider,
    required this.auth,
    required this.tooltipSide,
    required this.pulseSide,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    // Keep the partner stream alive while the dashboard is up. Post-frame:
    // watchPartner notifies, which must never fire during build. This also
    // self-heals after the full /garden view stops watching on its way out.
    final partnerUid = auth.partnerUid;
    if (partnerUid != null &&
        partnerUid.isNotEmpty &&
        provider.partnerUid != partnerUid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.watchPartner(partnerUid);
      });
    } else if ((partnerUid == null || partnerUid.isEmpty) &&
        !auth.isResolvingPartner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        auth.refreshPartnerLink();
      });
    }

    final isKhent = auth.currentUser == 'khentsgdz';
    final GardenStats? khentStats = isKhent
        ? provider.stats
        : provider.partnerStats;
    final GardenStats? clairStats = isKhent
        ? provider.partnerStats
        : provider.stats;

    final khentPlant = khentStats != null
        ? PlantType.fromId(khentStats.plantType)
        : PlantType.all.first;
    final clairPlant = clairStats != null
        ? PlantType.fromId(clairStats.plantType)
        : PlantType.all.first;
    final khentStage = khentPlant.effectiveStage(khentStats?.currentStage ?? 0);
    final clairStage = clairPlant.effectiveStage(clairStats?.currentStage ?? 0);

    final bothMissing = khentStats == null && clairStats == null;
    final bothFailed = provider.hasError && provider.hasPartnerError;

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
                child: _DualGardenHeader(
                  clairPlant: clairPlant,
                  khentPlant: khentPlant,
                  hasStats: !bothMissing,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _DualGardenScene(
                  clairPlant: clairPlant,
                  khentPlant: khentPlant,
                  clairStage: clairStage,
                  khentStage: khentStage,
                  clairReady: clairStats != null,
                  khentReady: khentStats != null,
                  tooltipSide: tooltipSide,
                  pulseSide: pulseSide,
                  onPlantTap: onPlantTap,
                ),
              ),
              const SizedBox(height: 12),
              _DualGrowthDots(
                clairStage: clairStage,
                khentStage: khentStage,
                clairReady: clairStats != null,
                khentReady: khentStats != null,
              ),
              const SizedBox(height: 12),
              if (bothMissing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: bothFailed
                      ? _GhostAction(
                          icon: Icons.refresh_rounded,
                          label: 'Gardens unavailable — retry',
                          onTap: () {
                            provider.retry();
                            provider.retryPartner();
                          },
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
                              'waking the gardens…',
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
                          _PersonStatTile(
                            name: 'Clair',
                            isYou: !isKhent,
                            stats: clairStats,
                            hasError:
                                provider.hasPartnerError && isKhent ||
                                provider.hasError && !isKhent,
                            onRetry: isKhent
                                ? provider.retryPartner
                                : provider.retry,
                          ),
                          const SizedBox(width: 10),
                          _PersonStatTile(
                            name: 'Khent',
                            isYou: isKhent,
                            stats: khentStats,
                            hasError:
                                provider.hasError && isKhent ||
                                provider.hasPartnerError && !isKhent,
                            onRetry: isKhent
                                ? provider.retry
                                : provider.retryPartner,
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
                              currentPlantType:
                                  provider.stats?.plantType ?? 'lily',
                              onSelected: (type) => provider.setPlantType(type),
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
                hasStats
                    ? '${plantType.displayName} · $stageName'
                    : 'waking up…',
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

/// Dual header: names both gardens so Clair sees hers and Khent's at once.
class _DualGardenHeader extends StatelessWidget {
  final PlantType clairPlant;
  final PlantType khentPlant;
  final bool hasStats;

  const _DualGardenHeader({
    required this.clairPlant,
    required this.khentPlant,
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
                hasStats
                    ? "Clair's ${clairPlant.displayName} · Khent's ${khentPlant.displayName}"
                    : 'waking up…',
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
