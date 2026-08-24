import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/error_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import '../ani_zip_service.dart';
import '../anilist_service.dart';
import 'tmdb_base.dart';
import 'tmdb_details_service.dart';

/// Poster URL resolution, backfilling missing posters for watchlist items,
/// and refreshing anime posters from AniList/Jikan.
class TMDBPosterService with TMDBBase, ConnectivityAware, ErrorAware {
  final TMDBDetailsService _detailsService;

  TMDBPosterService(this._detailsService);

  /// Fetch poster URL for a media item by tmdbId and mediaType.
  /// Returns the full poster URL or empty string if not found.
  Future<String> fetchPosterUrl(int tmdbId, String mediaType) async {
    final details = await _detailsService.fetchMediaDetails(tmdbId, mediaType);
    if (details == null) return '';
    final posterPath = details['poster_path'];
    if (posterPath == null || posterPath.toString().isEmpty) return '';
    return '$imageBaseUrl$posterPath';
  }

  /// Backfill missing posterPath for items in a list.
  /// Returns the updated list with posters fetched where possible.
  ///
  /// For Jikan-sourced anime items, `tmdbId` is actually a MAL ID, not
  /// a TMDB ID. We resolve the real TMDB ID via ani.zip first so we
  /// don't fetch the poster for a completely unrelated title.
  Future<List<MediaItem>> backfillMissingPosters(List<MediaItem> items) async {
    final needsPoster = items
        .where((i) => i.posterPath.isEmpty && i.tmdbId > 0)
        .toList();
    if (needsPoster.isEmpty) return items;

    final aniZipService = AniZipService();
    final updated = List<MediaItem>.from(items);
    for (final item in needsPoster) {
      try {
        // If the source is jikan, tmdbId is actually a MAL ID — resolve
        // the real TMDB ID first.
        var tmdbId = item.tmdbId;
        if (item.source == 'jikan') {
          final resolved = await aniZipService.fetchTmdbId(item.tmdbId);
          if (resolved == null) continue;
          tmdbId = resolved;
        }

        final details = await _detailsService.fetchMediaDetails(
          tmdbId,
          item.mediaType,
        );
        if (details == null) continue;
        final tmdbTitle =
            (details['name'] as String?) ?? (details['title'] as String?) ?? '';
        if (!titlesMatch(item.title, tmdbTitle)) continue;
        final posterPath = details['poster_path'] as String?;
        if (posterPath == null || posterPath.isEmpty) continue;
        final posterUrl = '$imageBaseUrl$posterPath';
        final idx = updated.indexWhere((u) => u.id == item.id);
        if (idx != -1) {
          updated[idx] = updated[idx].copyWith(posterPath: posterUrl);
        }
        await firestore.collection('watch_list').doc(item.id).update({
          'posterPath': posterUrl,
        });
      } catch (e) {
        Logger.e('TMDB Backfill Poster Error for ${item.title}', error: e);
      }
    }
    return updated;
  }

  /// For anime items that have a TMDB poster (empty or backfilled from
  /// a potentially wrong ani.zip mapping), fetch the correct poster from
  /// AniList/Jikan using the MAL ID stored in tmdbId and verify the title
  /// matches before saving.
  Future<List<MediaItem>> refreshAnimePosters(List<MediaItem> items) async {
    final needsRefresh = items
        .where((i) => i.isAnime && i.tmdbId > 0)
        .where(
          (i) =>
              i.posterPath.isEmpty || i.posterPath.contains('image.tmdb.org'),
        )
        .toList();
    if (needsRefresh.isEmpty) return items;

    final aniListService = AniListService();
    final updated = List<MediaItem>.from(items);
    for (final item in needsRefresh) {
      try {
        final detail = await aniListService.fetchDetailsWithFallback(
          malId: item.tmdbId,
        );
        final correctPoster = detail?.coverImageUrl;
        if (correctPoster == null || correctPoster.isEmpty) continue;
        if (correctPoster == item.posterPath) continue;

        // Verify the AniList title matches the stored title to avoid
        // saving a wrong poster when tmdbId isn't actually a MAL ID.
        final anilistTitle = detail?.titleEnglish ?? detail?.titleRomaji ?? '';
        if (anilistTitle.isNotEmpty && !titlesMatch(item.title, anilistTitle)) {
          continue;
        }

        final idx = updated.indexWhere((u) => u.id == item.id);
        if (idx != -1) {
          updated[idx] = updated[idx].copyWith(posterPath: correctPoster);
        }
        await firestore.collection('watch_list').doc(item.id).update({
          'posterPath': correctPoster,
          'source': 'jikan',
        });
      } catch (e) {
        Logger.e('Refresh anime poster error for ${item.title}', error: e);
      }
    }
    return updated;
  }
}
