import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/app_network_image.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../../../../data/models/media_item.dart';

/// "More Like This" rail for the enhanced Cinema drawer: larger posters
/// with rounded corners, a soft lift on hover, and a two-line title
/// with a year/type caption.
class CinemaSimilarSection extends StatelessWidget {
  final List<MediaItem> similar;
  final bool isLoading;
  final void Function(MediaItem item) onItemTap;

  const CinemaSimilarSection({
    super.key,
    required this.similar,
    required this.isLoading,
    required this.onItemTap,
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
    if (similar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No similar titles found',
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.mutedPurple,
            fontSize: 13,
          ),
        ),
      );
    }

    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: similar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _SimilarCard(
          item: similar[index],
          onTap: () => onItemTap(similar[index]),
        ),
      ),
    );
  }
}

class _SimilarCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _SimilarCard({required this.item, required this.onTap});

  @override
  State<_SimilarCard> createState() => _SimilarCardState();
}

class _SimilarCardState extends State<_SimilarCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 128,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 128,
                  height: 182,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                      if (_hovered)
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.28),
                          blurRadius: 22,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: item.posterUrl.isNotEmpty
                        ? AppNetworkImage(
                            imageUrl: item.posterUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorWidget: _fallback(),
                          )
                        : _fallback(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitBold.copyWith(fontSize: 12.5),
                ),
                Text(
                  item.year.isNotEmpty
                      ? item.year
                      : (item.mediaType == 'movie' ? 'Movie' : 'Series'),
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.mutedPurple,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.shimmerBase, AppColors.deepBlack],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_creation_outlined,
        color: AppColors.mutedPurple,
        size: 30,
      ),
    );
  }
}
