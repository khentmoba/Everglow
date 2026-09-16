part of 'animex_watch_page.dart';

/// Reusable thumbnail widget for episode cards with fallback to poster/backdrop,
/// pink pill episode badge, duration pill, and playing state overlay.
class _EpisodeThumbnail extends StatelessWidget {
  final AniListEpisode episode;
  final String fallbackPoster;
  final bool isPlaying;
  final double width;
  final double height;

  const _EpisodeThumbnail({
    required this.episode,
    required this.fallbackPoster,
    required this.isPlaying,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = episode.thumbnail;
    final hasThumb = thumb != null && thumb.isNotEmpty;
    final fallback = fallbackPoster.isNotEmpty ? fallbackPoster : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
      child: Container(
        width: width,
        height: height,
        color: AnimeXTokens.surfaceRaised,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumb)
              AppNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                cacheWidth: 320,
                errorWidget: fallback.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: fallback,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        errorWidget: _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              )
            else if (fallback.isNotEmpty)
              AppNetworkImage(
                imageUrl: fallback,
                fit: BoxFit.cover,
                cacheWidth: 320,
                errorWidget: _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            // Gradient scrim for badges
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x55000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.3, 0.65, 1.0],
                ),
              ),
            ),

            // Active / Playing sound-wave / rose tint overlay
            if (isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: AnimeXTokens.accent.withValues(alpha: 0.25),
                  border: Border.all(
                    color: AnimeXTokens.accentWarm,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: AnimeXTokens.accentWarm,
                    ),
                  ),
                ),
              ),

            // Bottom-left: Pink pill episode badge
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AnimeXTokens.accent,
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.scrimStrong,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2.5),
                    Text(
                      'Episode ${episode.number}',
                      style: dmSansStyle(
                        size: 10.5,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-right: Duration badge
            if (episode.duration != null && episode.duration! > 0)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xDD000000),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${episode.duration}m',
                    style: dmSansStyle(
                      size: 9.5,
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AnimeXTokens.surfaceRaised,
      child: Center(
        child: Icon(
          Icons.movie_filter_rounded,
          size: 26,
          color: AnimeXTokens.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

