import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../drawer_helpers.dart';

/// Elevated review cards for the enhanced Cinema drawer: glass surface,
/// gradient hairline border, larger avatar with colored ring, star row,
/// and a softly indented quote block with an accent bar.
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
              color: AppColors.deepRose,
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
            color: AppColors.mutedPurple,
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.roseQuartz.withValues(alpha: 0.22),
                  AppColors.roseQuartz.withValues(alpha: 0.04),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(1.2),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.shimmerBase.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(17),
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
                          color: avatarColor(author).withValues(alpha: 0.22),
                          border: Border.all(
                            color: avatarColor(author).withValues(alpha: 0.55),
                            width: 1.6,
                          ),
                        ),
                        child: ClipOval(
                          child: hasAvatar
                              ? Image.network(
                                  review['avatar'],
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      buildCastInitial(author),
                                )
                              : buildCastInitial(author),
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
                    Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.blushGold.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        preview,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite.withValues(alpha: 0.78),
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
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
              ? AppColors.warmAmber
              : AppColors.mutedPurple.withValues(alpha: 0.4),
        );
      }),
    );
  }
}
