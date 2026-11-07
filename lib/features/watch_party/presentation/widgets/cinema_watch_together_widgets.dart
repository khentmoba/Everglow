part of 'cinema_watch_together_tab.dart';

class _WatchTogetherPoster extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _WatchTogetherPoster({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetflixPosterCard(item: item, compact: true, onTap: onTap),
        Positioned(
          right: 6,
          bottom: 6,
          child: StartWatchPartyButton(
            media: MediaRef(
              tmdbId: item.tmdbId,
              malId: item.isAnime ? item.tmdbId : null,
              mediaType: item.mediaType,
              isAnime: item.isAnime,
              season: item.currentSeason,
              episode: item.currentEpisode,
              title: item.title,
              posterPath: item.posterPath,
            ),
          ),
        ),
      ],
    );
  }
}
