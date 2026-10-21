import '../../../cinema/data/models/media_item.dart';
import '../models/anilist_detail.dart';

typedef TmdbAnimeDetails = ({
  AniListDetail detail,
  Map<int, ({int season, int episode})> slots,
});

TmdbAnimeDetails mapTmdbAnimeDetails(
  MediaItem item,
  Map<String, dynamic> data,
) {
  final slots = <int, ({int season, int episode})>{};
  final seasons =
      (data['seasons'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((season) => (season['season_number'] as num? ?? 0) > 0)
          .toList()
        ..sort(
          (a, b) =>
              (a['season_number'] as num).compareTo(b['season_number'] as num),
        );
  for (final season in seasons.take(30)) {
    final number = (season['season_number'] as num).toInt();
    final count = ((season['episode_count'] as num?)?.toInt() ?? 0).clamp(
      0,
      500,
    );
    for (var episode = 1; episode <= count && slots.length < 2000; episode++) {
      slots[slots.length + 1] = (season: number, episode: episode);
    }
  }
  return (
    detail: AniListDetail(
      id: 0,
      titleEnglish: (data['name'] ?? data['title'] ?? item.title).toString(),
      titleRomaji: '',
      titleNative: '',
      synopsis: (data['overview'] as String?) ?? item.synopsis,
      coverImageUrl: item.posterUrl,
      bannerImageUrl: item.backdropPath,
      episodeCount: item.isMovie ? 1 : slots.length,
      duration: (data['runtime'] as num?)?.toInt(),
      airingStatus: (data['status'] as String?) ?? '',
      format: item.isMovie ? 'MOVIE' : 'TV',
      genres: (data['genres'] as List? ?? [])
          .whereType<Map>()
          .map((genre) => genre['name'].toString())
          .toList(),
    ),
    slots: slots,
  );
}
