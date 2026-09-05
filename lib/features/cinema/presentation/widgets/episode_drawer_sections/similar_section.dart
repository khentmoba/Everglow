import 'package:flutter/material.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/media_item.dart';
import 'drawer_helpers.dart';
import '../../../../../core/theme/app_typography.dart';

/// Renders the "More Like This" horizontal rail of similar titles.
/// Shows a loading skeleton while fetching, an empty-state message
/// when no similar titles are found, or a horizontal scrollable list
/// of poster cards with title and year/type labels.
class SimilarSection extends StatelessWidget {
  final List<MediaItem> similar;
  final bool isLoading;
  final void Function(MediaItem item) onItemTap;

  const SimilarSection({
    super.key,
    required this.similar,
    required this.isLoading,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return buildLoader();
    if (similar.isEmpty) {
      return buildEmptySection('No similar titles found');
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: similar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = similar[index];
          return GestureDetector(
            onTap: () => onItemTap(item),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.posterUrl.isNotEmpty
                            ? AppNetworkImage(
                                imageUrl: item.posterUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                              )
                            : Container(
                                color: AppColors.shimmerBase,
                                child: const Center(
                                  child: Icon(
                                    Icons.movie_creation_outlined,
                                    color: AppColors.mutedPurple,
                                    size: 28,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(fontSize: 11),
                  ),
                  Text(
                    item.year.isNotEmpty
                        ? item.year
                        : (item.mediaType == 'movie' ? 'Movie' : 'Series'),
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.mutedPurple,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
