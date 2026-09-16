part of 'daily_bloom.dart';

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

/// Two compact growth rows: Clair's dots above Khent's.
class _DualGrowthDots extends StatelessWidget {
  final int clairStage;
  final int khentStage;
  final bool clairReady;
  final bool khentReady;

  const _DualGrowthDots({
    required this.clairStage,
    required this.khentStage,
    required this.clairReady,
    required this.khentReady,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DualGrowthRow(name: 'Clair', stage: clairStage, ready: clairReady),
        const SizedBox(height: 6),
        _DualGrowthRow(name: 'Khent', stage: khentStage, ready: khentReady),
      ],
    );
  }
}

class _DualGrowthRow extends StatelessWidget {
  final String name;
  final int stage;
  final bool ready;

  const _DualGrowthRow({
    required this.name,
    required this.stage,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final filled = ready ? stage.clamp(0, 5) : 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            name,
            textAlign: TextAlign.right,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              letterSpacing: 0.6,
              color: AppColors.petalWhite.withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 1; i <= 5; i++) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= filled
                  ? AppColors.auroraGold
                  : AppColors.moonlight.withValues(alpha: 0.15),
              boxShadow: i <= filled
                  ? [
                      BoxShadow(
                        color: AppColors.auroraGold.withValues(alpha: 0.5),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          ),
          if (i < 5) const SizedBox(width: 5),
        ],
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            ready ? 'Stage $filled of 5' : 'waking…',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              letterSpacing: 0.2,
              color: AppColors.petalWhite.withValues(alpha: 0.6),
            ),
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

/// One person's glowing stats: streak + visits under their name.
class _PersonStatTile extends StatelessWidget {
  final String name;
  final bool isYou;
  final GardenStats? stats;
  final bool hasError;
  final VoidCallback onRetry;

  const _PersonStatTile({
    required this.name,
    required this.isYou,
    required this.stats,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.0,
                      color: AppColors.petalWhite.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                if (isYou) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.auroraTeal.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'you',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        color: AppColors.auroraTeal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (stats == null && hasError)
              GestureDetector(
                onTap: onRetry,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 13,
                      color: AppColors.blushGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'retry',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 11,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ],
                ),
              ),
            if (stats == null && !hasError)
              Text(
                'waking…',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.5),
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: AppColors.warmAmber,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${stats!.streakCount}',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 16,
                      height: 1.0,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    stats!.streakCount == 1 ? 'day streak' : 'day streak',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.6,
                      color: AppColors.warmAmber.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 13,
                    color: AppColors.auroraRose,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${stats!.totalInteractions}',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 16,
                      height: 1.0,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'visits',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.6,
                      color: AppColors.auroraRose.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
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
