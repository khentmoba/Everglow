import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../../gallery/domain/models/memory_photo.dart';
import '../../../gallery/data/services/gallery_service.dart';

class GalleryPreview extends StatelessWidget {
  const GalleryPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemoryPhoto>>(
      stream: GalleryService().getRecentPhotos(limit: 6),
      builder: (context, snapshot) {
        final photos = snapshot.data ?? [];
        if (photos.isEmpty) {
          return GestureDetector(
            onTap: () => context.push('/gallery'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.blushGold.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.blushGold,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your gallery is empty — add your first photo!',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.petalWhite.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.blushGold.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => context.push('/gallery'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.blushGold.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_rounded,
                      color: AppTheme.blushGold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Memory Gallery',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.roseQuartz,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${photos.length} photos',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.petalWhite.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: AppTheme.blushGold.withValues(alpha: 0.65),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length.clamp(0, 6),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          GalleryService.displayUrl(photos[index].imageUrl),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 70,
                            height: 70,
                            color: AppTheme.twilight,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppTheme.roseQuartz,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
