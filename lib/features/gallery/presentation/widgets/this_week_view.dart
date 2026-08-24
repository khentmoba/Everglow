import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../gallery/data/services/gallery_service.dart';
import '../../../gallery/domain/models/memory_photo.dart';

class ThisWeekView extends StatelessWidget {
  const ThisWeekView({super.key});

  @override
  Widget build(BuildContext context) {
    final gallery = GalleryService();
    return FutureBuilder<List<MemoryPhoto>>(
      future: gallery.getPhotosFromThisWeek(),
      builder: (context, snap) {
        final photos = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                color: AppColors.deepRose,
                strokeWidth: 2,
              ),
            ),
          );
        }
        if (photos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 42,
                    color: AppColors.blushGold.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No memories this week in past',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 13,
                      color: AppTheme.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Photos from the same week in previous years will appear here — keep capturing!',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 11,
                      color: AppTheme.petalWhite.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        // Group by yearsAgo
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: photos.length,
          itemBuilder: (context, idx) {
            final p = photos[idx];
            final yearsAgo = DateTime.now().year - p.uploadedAt.year;
            final dayDiff =
                DateTime(
                      DateTime.now().year,
                      p.uploadedAt.month,
                      p.uploadedAt.day,
                    )
                    .difference(
                      DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      ),
                    )
                    .inDays;
            final label = dayDiff == 0
                ? 'Today • $yearsAgo ${yearsAgo == 1 ? 'year' : 'years'} ago'
                : '${dayDiff > 0 ? '+$dayDiff' : '$dayDiff'} days • $yearsAgo y ago';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.moonlight.withValues(
                  alpha: AppTheme.glassOpacity,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                    child: Image.network(
                      GalleryService.displayUrl(p.imageUrl),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 90,
                        height: 90,
                        color: AppColors.twilight,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warmAmber.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warmAmber,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.caption.isEmpty ? 'Untitled memory' : p.caption,
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 13,
                              color: AppTheme.petalWhite,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.uploadedAt.month}/${p.uploadedAt.day}/${p.uploadedAt.year} • by ${p.uploadedBy}${p.locationName != null ? ' • 📍 ${p.locationName}' : ''}',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              color: AppTheme.petalWhite.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
