import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../gallery/domain/models/memory_photo.dart';
import '../../../gallery/data/services/gallery_service.dart';
import 'shelf_widgets.dart';
import '../../../../shared/widgets/everglow/everglow_marquee.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import 'feature_section.dart';

class GalleryPreview extends StatefulWidget {
  const GalleryPreview({super.key});

  @override
  State<GalleryPreview> createState() => _GalleryPreviewState();
}

class _GalleryPreviewState extends State<GalleryPreview> {
  late final GalleryService _service;
  late Stream<List<MemoryPhoto>> _recentPhotos;

  @override
  void initState() {
    super.initState();
    _service = GalleryService();
    _recentPhotos = _service.getRecentPhotos(limit: 6);
  }

  void _retry() {
    setState(() {
      _recentPhotos = _service.getRecentPhotos(limit: 6);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemoryPhoto>>(
      stream: _recentPhotos,
      builder: (context, snapshot) {
        // Error (or timeout-closed with no data) must never masquerade as
        // "empty" — the gallery screen would still show photos on tap.
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: FeatureSection(
              icon: Icons.photo_library_rounded,
              hue: AppColors.roseQuartz,
              title: 'Memory Gallery',
              subtitle: 'could not load gallery',
              trailing: const SectionChevron(),
              onTap: () => context.push('/gallery'),
              child: GestureDetector(
                onTap: _retry,
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.roseQuartz,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not load photos — tap here to retry.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: AppColors.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Waiting for the first snapshot is loading, not empty.
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: FeatureSection(
              icon: Icons.photo_library_rounded,
              hue: AppColors.roseQuartz,
              title: 'Memory Gallery',
              subtitle: 'loading photos…',
              trailing: const SectionChevron(),
              onTap: () => context.push('/gallery'),
              child: const EverglowSkeleton(height: 120, radius: 14),
            ),
          );
        }

        final photos = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.photo_library_rounded,
            hue: AppColors.roseQuartz,
            title: 'Memory Gallery',
            subtitle: photos.isEmpty
                ? 'no photos yet'
                : '${photos.length} ${photos.length == 1 ? 'photo' : 'photos'}',
            trailing: const SectionChevron(),
            onTap: () => context.push('/gallery'),
            child: photos.isEmpty
                ? Row(
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.roseQuartz,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add the first memory to the album',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  )
                : EverglowMarquee(
                    height: 194,
                    itemSpacing: 12,
                    children: [
                      for (final photo in photos.take(12)) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ShelfCard(
                              accent: ShelfAccent.gallery,
                              imageUrl: GalleryService.displayUrl(
                                photo.imageUrl,
                              ),
                              title: '',
                              onTap: () => context.push('/gallery'),
                            ),
                          ),
                        ],
                      ],
                    ),
          ),
        );
      },
    );
  }
}
