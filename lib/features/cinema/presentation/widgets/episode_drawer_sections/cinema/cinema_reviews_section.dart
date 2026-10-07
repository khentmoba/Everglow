import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/app_network_image.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../drawer_helpers.dart';
import '../../netflix/netflix_colors.dart';

/// Review cards for the enhanced Cinema drawer.
class CinemaReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;

  const CinemaReviewsSection({
    super.key,
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: NetflixColors.accent,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    if (reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No reviews yet',
          style: AppTypography.outfitWhite.copyWith(
            color: NetflixColors.textMuted,
            fontSize: 13,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: reviews.map((review) {
          final author = (review['author'] ?? 'Anonymous').toString();
          final content = (review['content'] ?? '').toString();
          final rating = review['rating'];
          final preview = content.length > 340
              ? '${content.substring(0, 340)}\u2026'
              : content;
          final hasAvatar = (review['avatar'] ?? '').toString().isNotEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NetflixColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NetflixColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NetflixColors.surface,
                        border: Border.all(color: NetflixColors.hairline),
                      ),
                      child: ClipOval(
                        child: hasAvatar
                            ? AppNetworkImage(
                                imageUrl: review['avatar'],
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                errorWidget: _buildAuthorInitial(author),
                              )
                            : _buildAuthorInitial(author),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _buildStars(rating),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    style: AppTypography.outfitWhite.copyWith(
                      color: NetflixColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuthorInitial(String author) {
    return Container(
      color: NetflixColors.surface,
      alignment: Alignment.center,
      child: Text(
        getInitial(author),
        style: AppTypography.cormorantBold.copyWith(
          fontSize: 26,
          color: NetflixColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStars(dynamic rating) {
    final r = rating is num ? rating.toDouble() : 0.0;
    final filled = r.clamp(0.0, 10.0) / 2;
    return Row(
      children: List.generate(5, (i) {
        final full = i + 1 <= filled.floor();
        final partial = !full && i < filled.ceil();
        return Icon(
          partial ? Icons.star_half_rounded : Icons.star_rounded,
          size: 13,
          color: full || partial
              ? NetflixColors.gold
              : NetflixColors.textMuted.withValues(alpha: 0.4),
        );
      }),
    );
  }
}
