import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'drawer_helpers.dart';
import '../../../../../core/theme/app_typography.dart';

/// Renders the reviews section: a vertical list of review cards with
/// avatar, author name, rating, and preview text. Shows a loading
/// skeleton while fetching, or an empty-state message when no reviews
/// are available.
class ReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;

  const ReviewsSection({
    super.key,
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return buildLoader();
    if (reviews.isEmpty) {
      return buildEmptySection('No reviews yet');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: reviews.map((review) {
          final author = review['author'] ?? 'Anonymous';
          final content = (review['content'] ?? '').toString();
          final rating = review['rating'];
          final preview = content.length > 300
              ? '${content.substring(0, 300)}…'
              : content;
          final hasAvatar =
              (review['avatar'] ?? '').toString().isNotEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.roseQuartz.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: avatarColor(author).withValues(alpha: 0.2),
                        border: Border.all(
                            color: avatarColor(author)
                                .withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: ClipOval(
                        child: hasAvatar
                            ? Image.network(
                                review['avatar'],
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    buildCastInitial(author),
                              )
                            : buildCastInitial(author),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitHeading.copyWith(fontSize: 13),
                          ),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.warmAmber,
                                    size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toString(),
                                  style: AppTypography.outfitWhite.copyWith(color: AppColors.warmAmber, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  preview,
                  style: AppTypography.outfitWhite.copyWith(color: AppColors.petalWhite.withValues(alpha: 0.75), fontSize: 13, height: 1.5),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
