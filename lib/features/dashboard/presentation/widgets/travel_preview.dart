import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/travel/data/services/travel_service.dart';
import 'feature_section.dart';

class TravelPreview extends StatelessWidget {
  const TravelPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final service = TravelService();
    return StreamBuilder(
      stream: service.watchTrips(),
      builder: (context, snap) {
        final trips = snap.data ?? [];
        return StreamBuilder(
          stream: service.watchAllPins(),
          builder: (context, pinSnap) {
            final pins = pinSnap.data ?? [];
            final visited = pins.where((p) => p.isVisited).length;
            final totalPins = pins.length;
            final pct = totalPins == 0 ? 0.0 : visited / totalPins;

            final subtitle = trips.isEmpty
                ? 'No trips yet — plan your first adventure'
                : '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'} • $visited/$totalPins visited';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: FeatureSection(
                icon: Icons.map_rounded,
                hue: AppColors.auroraTeal,
                title: 'Atlas',
                subtitle: subtitle,
                trailing: const SectionChevron(hue: AppColors.auroraTeal),
                onTap: () => context.push('/travel'),
                child: trips.isEmpty && pins.isEmpty
                    ? const _EmptyAtlas(hue: AppColors.auroraTeal)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (totalPins > 0) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  size: 12,
                                  color: AppColors.auroraTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$visited explored',
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 11,
                                    color: AppColors.auroraTeal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${totalPins - visited} dreaming',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 11,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(pct * 100).round()}%',
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 11,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: pct == 0 ? 0.04 : pct,
                                minHeight: 6,
                                backgroundColor: AppColors.petalWhite.withValues(
                                  alpha: 0.07,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.auroraTeal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (trips.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: trips.take(4).map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.petalWhite.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.petalWhite.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.flight_takeoff_rounded,
                                        size: 11,
                                        color: AppColors.auroraTeal.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        t.title.isEmpty
                                            ? 'Untitled trip'
                                            : t.title,
                                        style: AppTypography.outfitWhite
                                            .copyWith(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.petalWhite
                                                  .withValues(alpha: 0.85),
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          if (trips.isEmpty && pins.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: pins.take(5).map((p) {
                                return Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: p.isVisited
                                        ? AppColors.auroraTeal.withValues(
                                            alpha: 0.22,
                                          )
                                        : AppColors.petalWhite.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: p.isVisited
                                          ? AppColors.auroraTeal.withValues(
                                              alpha: 0.45,
                                            )
                                          : AppColors.petalWhite.withValues(
                                              alpha: 0.10,
                                            ),
                                    ),
                                  ),
                                  child: Icon(
                                    p.isVisited
                                        ? Icons.check_rounded
                                        : Icons.push_pin_rounded,
                                    size: 13,
                                    color: p.isVisited
                                        ? AppColors.auroraTeal
                                        : AppColors.petalWhite.withValues(
                                            alpha: 0.35,
                                          ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyAtlas extends StatelessWidget {
  final Color hue;
  const _EmptyAtlas({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hue.withValues(alpha: 0.10), hue.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hue.withValues(alpha: 0.14),
              border: Border.all(color: hue.withValues(alpha: 0.28)),
            ),
            child: Icon(Icons.explore_rounded, size: 16, color: hue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where to next?',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 12,
                    color: AppColors.petalWhite.withValues(alpha: 0.88),
                  ),
                ),
                Text(
                  'Pin Japan, Cebu, Kyoto — draw your map together.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: AppColors.petalWhite.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
