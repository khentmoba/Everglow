import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../../gallery/domain/models/memory_photo.dart';
import '../../../gallery/data/services/gallery_service.dart';
import 'shelf_widgets.dart';

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
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
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
                ),
                const SizedBox(height: 10),
                // Card carousel — same style as Cinema/Manga shelves
                SizedBox(
                  height: 168,
                  child: ShelfMarquee(
                    itemStride: 122.0,
                    children: [
                      for (final photo in photos) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ShelfCard(
                            accent: ShelfAccent.gallery,
                            imageUrl: GalleryService.displayUrl(photo.imageUrl),
                            title: photo.caption.isNotEmpty
                                ? photo.caption
                                : 'Memory',
                            subtitle: photo.uploadedBy,
                            onTap: () => context.push('/gallery'),
                          ),
                        ),
                      ],
                    ],
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
