import 'dart:async';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/error_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../../shared/utils/tmdb_images.dart';
import '../../models/media_item.dart';
import '../ani_zip_service.dart';
import '../../../../anime/data/services/anilist_service.dart';
import 'tmdb_base.dart';
import 'tmdb_details_service.dart';
import 'tmdb_search_service.dart';

/// Poster URL resolution, backfilling missing posters for watchlist items,
/// and refreshing anime posters from AniList/Jikan.
class TMDBPosterService with TMDBBase, ConnectivityAware, ErrorAware {
  final TMDBDetailsService _detailsService;
  final TMDBSearchService _searchService;

  TMDBPosterService(this._detailsService, [TMDBSearchService? searchService])
    : _searchService = searchService ?? TMDBSearchService();

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
  /// "Missing" means unusable ([TmdbImages.isUsablePath]), not just empty:
  /// a stringified null ("null"), a title that leaked into the poster
  /// field ("Yellow Jacket"), or a path with whitespace all build bogus
  /// URLs that 404 forever — those heal here instead of staying blank.
  ///
  /// For Jikan-sourced anime items, `tmdbId` is actually a MAL ID, not
  /// a TMDB ID. We resolve the real TMDB ID via ani.zip first so we
  /// don't fetch the poster for a completely unrelated title.
  Future<List<MediaItem>> backfillMissingPosters(List<MediaItem> items) async {
    final needsPoster = items
        .where((i) => !TmdbImages.isUsablePath(i.posterPath))
        .toList();
    if (needsPoster.isEmpty) return items;

    final updated = List<MediaItem>.from(items);

    // Batch with concurrency=4 so 10 posters don't take 10×RTT serially.
    // Each task handles its own errors; Firestore writes are fire-and-forget.
    const concurrency = 4;
    for (var i = 0; i < needsPoster.length; i += concurrency) {
      final chunk = needsPoster.skip(i).take(concurrency).toList();
      await Future.wait(chunk.map((item) async {
        final healed = await healPoster(item);
        if (healed == null) return;
        final idx = updated.indexWhere((u) => u.id == item.id);
        if (idx != -1) updated[idx] = healed;
      }));
    }
    return updated;
  }

  /// Heals one item's poster: refetches the current artwork from TMDB and
  /// persists it to Firestore. Returns the healed copy, or null when the
  /// title can't be matched safely.
  ///
  /// Used two ways: proactively by [backfillMissingPosters] for blank or
  /// garbage poster fields, and reactively by dashboard shelves when a
  /// present-but-broken URL 404s (stale TMDB artwork). The reactive path is
  /// why a 404ing cover heals instead of showing the placeholder forever.
  ///
  /// Safety: the fetched title must fuzzy-match the stored title before
  /// anything is saved, so a wrong-ID doc never steals another show's art.
  /// When the stored `mediaType` is wrong (movie saved as tv or vice
  /// versa), the other type is tried before giving up — and the corrected
  /// type is saved alongside the poster.
  Future<MediaItem?> healPoster(MediaItem item) async {
    try {
      // Jikan-sourced anime stores a MAL id in tmdbId — resolve the real
      // TMDB id first so the details lookup hits the right title.
      var tmdbId = item.tmdbId;
      if (tmdbId > 0 && item.source == 'jikan') {
        final resolved = await AniZipService().fetchTmdbId(item.tmdbId);
        if (resolved == null) return null;
        tmdbId = resolved;
      }
      if (tmdbId > 0) {
        final healed = await _healByDetails(item, tmdbId);
        if (healed != null) return healed;
      }
      // No usable id (custom / legacy docs): fall back to a title search
      // so those covers heal too instead of staying blank.
      final searched = await _healByTitleSearch(item);
      return searched;
    } catch (e) {
      Logger.e('TMDB Heal Poster Error for ${item.title}', error: e);
      return null;
    }
  }

  /// Details-based heal: tries the stored mediaType, then the alternate
  /// type when the first lookup misses or the title doesn't match.
  Future<MediaItem?> _healByDetails(MediaItem item, int tmdbId) async {
    final primary = item.mediaType.isEmpty ? 'movie' : item.mediaType;
    final alternate = primary == 'movie' ? 'tv' : 'movie';
    for (final mediaType in [primary, alternate]) {
      final details = await _detailsService.fetchMediaDetails(
        tmdbId,
        mediaType,
      );
      if (details == null) continue;
      final tmdbTitle =
          (details['name'] as String?) ?? (details['title'] as String?) ?? '';
      if (!titlesMatch(item.title, tmdbTitle)) continue;
      final posterPath = details['poster_path'] as String?;
      if (posterPath == null || posterPath.isEmpty) continue;
      final posterUrl = TmdbImages.posterFor(posterPath);
      if (posterUrl.isEmpty || posterUrl == item.posterPath.trim()) continue;
      // Persist the matched type too: fixes wrong-type docs (movie saved
      // as tv) and normalizes empty / oddly-cased values.
      final healed = item.copyWith(
        posterPath: posterUrl,
        mediaType: mediaType,
      );
      // Don't block the heal on a single Firestore write.
      if (item.id.isNotEmpty) {
        final patch = <String, dynamic>{'posterPath': posterUrl};
        if (mediaType != item.mediaType) patch['mediaType'] = mediaType;
        unawaited(firestore
            .collection('watch_list')
            .doc(item.id)
            .update(patch)
            .catchError((_) {}));
      }
      return healed;
    }
    return null;
  }

  /// Title-search heal for docs without a usable TMDB id. Picks the first
  /// result whose title matches and actually has artwork.
  Future<MediaItem?> _healByTitleSearch(MediaItem item) async {
    final title = item.title.trim();
    if (title.isEmpty) return null;
    final results = await _searchService.searchMedia(title);
    for (final r in results) {
      if (!TmdbImages.isUsablePath(r.posterPath)) continue;
      if (!titlesMatch(title, r.title)) continue;
      final healed = item.copyWith(
        posterPath: r.posterPath,
        tmdbId: r.tmdbId,
        mediaType: r.mediaType,
      );
      if (item.id.isNotEmpty) {
        unawaited(firestore.collection('watch_list').doc(item.id).update({
          'posterPath': r.posterPath,
          'tmdbId': r.tmdbId,
          'mediaType': r.mediaType,
        }).catchError((_) {}));
      }
      return healed;
    }
    return null;
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
              !TmdbImages.isUsablePath(i.posterPath) ||
              i.posterPath.contains('image.tmdb.org'),
        )
        .toList();
    if (needsRefresh.isEmpty) return items;

    final aniListService = AniListService();
    final updated = List<MediaItem>.from(items);
    const concurrency = 4;
    for (var i = 0; i < needsRefresh.length; i += concurrency) {
      final chunk = needsRefresh.skip(i).take(concurrency).toList();
      await Future.wait(chunk.map((item) async {
        try {
          final detail = await aniListService.fetchDetailsWithFallback(
            malId: item.tmdbId,
          );
          final correctPoster = detail?.coverImageUrl;
          if (correctPoster == null || correctPoster.isEmpty) return;
          if (correctPoster == item.posterPath) return;
          final anilistTitle = detail?.titleEnglish ?? detail?.titleRomaji ?? '';
          if (anilistTitle.isNotEmpty &&
              !titlesMatch(item.title, anilistTitle)) {
            return;
          }
          final idx = updated.indexWhere((u) => u.id == item.id);
          if (idx != -1) {
            updated[idx] = updated[idx].copyWith(posterPath: correctPoster);
          }
          unawaited(firestore.collection('watch_list').doc(item.id).update({
            'posterPath': correctPoster,
            'source': 'jikan',
          }).catchError((_) {}));
        } catch (e) {
          Logger.e('Refresh anime poster error for ${item.title}', error: e);
        }
      }));
    }
    return updated;
  }
}
