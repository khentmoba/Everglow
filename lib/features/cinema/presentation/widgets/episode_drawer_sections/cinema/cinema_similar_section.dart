import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/app_network_image.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../../../../data/models/media_item.dart';
import '../../netflix/netflix_colors.dart';

/// "More Like This" section for the enhanced Cinema drawer:
/// Supports either a horizontal carousel or a Netflix-style responsive grid
/// of preview cards with match %, age badge, year, and synopsis preview.
class CinemaSimilarSection extends StatelessWidget {
  final List<MediaItem> similar;
  final bool isLoading;
  final void Function(MediaItem item) onItemTap;
  final bool isGrid;

  const CinemaSimilarSection({
    super.key,
    required this.similar,
    required this.isLoading,
    required this.onItemTap,
    this.isGrid = false,
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
    if (similar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'No similar titles found',
          style: AppTypography.outfitWhite.copyWith(
            color: NetflixColors.textMuted,
            fontSize: 13,
          ),
        ),
      );
    }

    if (isGrid) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final columns = isWide ? 3 : 2;
            final spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - (columns - 1) * spacing) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: 14,
              children: similar
                  .take(isWide ? 9 : 6)
                  .map(
                    (item) => SizedBox(
                      width: cardWidth,
                      child: _NetflixSimilarGridCard(
                        item: item,
                        onTap: () => onItemTap(item),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
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

class _NetflixSimilarGridCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _NetflixSimilarGridCard({required this.item, required this.onTap});

  @override
  State<_NetflixSimilarGridCard> createState() =>
      _NetflixSimilarGridCardState();
}

class _NetflixSimilarGridCardState extends State<_NetflixSimilarGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final matchScore = (item.score != null && item.score! > 0)
        ? (item.score! * 10).round()
        : 90 + (item.tmdbId % 9);

    final imageUrl = item.backdropUrl.isNotEmpty
        ? item.backdropUrl
        : (item.posterUrl.isNotEmpty ? item.posterUrl : '');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: NetflixColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: _hovered ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 16:9 Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        AppNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          placeholder: const ColoredBox(
                            color: NetflixColors.surface,
                          ),
                          errorWidget: const ColoredBox(
                            color: NetflixColors.surface,
                          ),
                        )
                      else
                        const ColoredBox(color: NetflixColors.surface),
                      // Duration or year badge overlay
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.year.isNotEmpty
                                ? item.year
                                : (item.mediaType == 'movie' ? 'Movie' : 'TV'),
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card details
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$matchScore% Match',
                                style: AppTypography.outfitBold.copyWith(
                                  color: NetflixColors.match,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  item.isAnime ? '13+' : '16+',
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      if (item.synopsis.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.synopsis,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11.5,
                            color: NetflixColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NetflixColors.hairline),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
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
                    color: NetflixColors.textMuted,
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
      color: NetflixColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        color: NetflixColors.textMuted,
        size: 30,
      ),
    );
  }
}
