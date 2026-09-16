part of 'daily_bloom.dart';

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
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.07)),
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
                          plantType.stageDescriptions[effectiveStage.clamp(
                            0,
                            5,
                          )],
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

/// Dual night-garden scene: Clair's plant left, Khent's right, sharing one
/// sky. Each plant owns its tap for its own story.
class _DualGardenScene extends StatelessWidget {
  final PlantType clairPlant;
  final PlantType khentPlant;
  final int clairStage;
  final int khentStage;
  final bool clairReady;
  final bool khentReady;
  final String? tooltipSide;
  final String? pulseSide;
  final ValueChanged<String> onPlantTap;

  const _DualGardenScene({
    required this.clairPlant,
    required this.khentPlant,
    required this.clairStage,
    required this.khentStage,
    required this.clairReady,
    required this.khentReady,
    required this.tooltipSide,
    required this.pulseSide,
    required this.onPlantTap,
  });

  @override
  Widget build(BuildContext context) {
    final tooltipPlant = tooltipSide == 'khent' ? khentPlant : clairPlant;
    final tooltipStage = tooltipSide == 'khent' ? khentStage : clairStage;

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
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.07)),
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
          // Ground glow the plants grow out of.
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
          // Both plants share the sky. Narrow phones get ~150px each;
          // the pot still reads clearly at that size.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 34, top: 40),
              child: Row(
                children: [
                  Expanded(
                    child: _DualPlant(
                      name: 'Clair',
                      plantType: clairPlant,
                      stage: clairStage,
                      ready: clairReady,
                      pulsing: pulseSide == 'clair',
                      onTap: () => onPlantTap('clair'),
                    ),
                  ),
                  // Soft divider so the two pots read as their own gardens.
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.moonlight.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _DualPlant(
                      name: 'Khent',
                      plantType: khentPlant,
                      stage: khentStage,
                      ready: khentReady,
                      pulsing: pulseSide == 'khent',
                      onTap: () => onPlantTap('khent'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (tooltipSide != null)
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
                          tooltipPlant.stageDescriptions[tooltipStage.clamp(
                            0,
                            5,
                          )],
                          textAlign: TextAlign.center,
                          style: AppTypography.outfitHeading.copyWith(
                            color: AppColors.blushGold,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        if (tooltipPlant.isInSeason) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${tooltipPlant.seasonalBonusName} bonus active ✨',
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

/// One side of the dual scene: breathing plant, soft shadow, name pill.
class _DualPlant extends StatelessWidget {
  final String name;
  final PlantType plantType;
  final int stage;
  final bool ready;
  final bool pulsing;
  final VoidCallback onTap;

  const _DualPlant({
    required this.name,
    required this.plantType,
    required this.stage,
    required this.ready,
    required this.pulsing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            label:
                "$name's ${plantType.displayName.toLowerCase()}, stage $stage of 5. Tap for details.",
            button: true,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedScale(
                scale: pulsing ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Opacity(
                  opacity: ready ? 1.0 : 0.45,
                  child: ExcludeSemantics(
                    child: GardenPlantView(plantType: plantType, stage: stage),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            ready ? '$name · ${plantType.displayName}' : '$name · …',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              letterSpacing: 0.6,
              color: AppColors.petalWhite.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
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
