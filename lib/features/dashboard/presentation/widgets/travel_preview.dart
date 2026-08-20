import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/travel/data/services/travel_service.dart';

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
            return GestureDetector(
              onTap: () => context.push('/travel'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.18))),
                child: Row(
                  children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.auroraTeal.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(Icons.map_rounded, color: AppColors.auroraTeal, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Atlas', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppColors.petalWhite)),
                          const SizedBox(height: 4),
                          Text(trips.isEmpty ? 'No trips yet — plan your first adventure' : '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'} • ${pins.length} pins • ${pins.where((p) => p.isVisited).length} visited', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.auroraTeal, size: 20),
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
