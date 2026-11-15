import 'dart:async';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../../../../shared/utils/tmdb_images.dart';
import '../../models/media_item.dart';
import '../../../../../shared/utils/title_matcher.dart';
import '../ani_zip_service.dart';
import '../../../../anime/data/services/anilist_service.dart';
import 'tmdb_base.dart';
import 'tmdb_details_service.dart';
import 'tmdb_search_service.dart';

class TMDBPosterService with TMDBBase, ConnectivityAware {
  final TMDBDetailsService _detailsService;
  final TMDBSearchService _searchService;

  TMDBPosterService(this._detailsService, [TMDBSearchService? searchService])
    : _searchService = searchService ?? TMDBSearchService();

  Future<String> fetchPosterUrl(int tmdbId, String mediaType) async {
    final details = await _detailsService.fetchMediaDetails(tmdbId, mediaType);
    if (details == null) return '';
    final posterPath = details['poster_path'];
    if (posterPath == null || posterPath.toString().isEmpty) return '';
    return '$imageBaseUrl$posterPath';
  }

  Future<List<MediaItem>> backfillMissingPosters(List<MediaItem> items) async {
    final needsPoster = items
        .where((i) => !TmdbImages.isUsablePath(i.posterPath))
        .toList();
    if (needsPoster.isEmpty) return items;

    final updated = List<MediaItem>.from(items);

    const concurrency = 4;
    for (var i = 0; i < needsPoster.length; i += concurrency) {
      final chunk = needsPoster.skip(i).take(concurrency).toList();
      await Future.wait(chunk.map((item) async {
        final healed = await healPoster(item);
        if (healed == null) return;
        final idx = updated.indexWhere(
          (u) =>
              (item.id.isNotEmpty && u.id == item.id) ||
              (item.id.isEmpty &&
                  u.tmdbId == item.tmdbId &&
                  u.title == item.title),
        );
        if (idx != -1) updated[idx] = healed;
      }));
    }
    return updated;
  }

  Future<MediaItem?> healPoster(MediaItem item) async {
    try {
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
      final searched = await _healByTitleSearch(item);
      return searched;
    } catch (e) {
      Logger.e('TMDB Heal Poster Error for ${item.title}', error: e);
      return null;
    }
  }

  Future<MediaItem?> _healByDetails(MediaItem item, int tmdbId) async {
    final primary = item.mediaType.isEmpty ? 'movie' : item.mediaType;
    final alternate = primary == 'movie' ? 'tv' : 'movie';
    final fetched = <String, Map<String, dynamic>>{};
    for (final mediaType in [primary, alternate]) {
      final details = await _detailsService.fetchMediaDetails(
        tmdbId,
        mediaType,
      );
      if (details != null) fetched[mediaType] = details;
    }
    for (final loose in [false, true]) {
      for (final mediaType in [primary, alternate]) {
        final details = fetched[mediaType];
        if (details == null) continue;
        final tmdbTitle =
            (details['name'] as String?) ??
            (details['title'] as String?) ??
            '';
        final matches = loose
            ? TitleMatcher.titlesLooselyMatch(item.title, tmdbTitle)
            : titlesMatch(item.title, tmdbTitle);
        if (!matches) continue;
      final posterPath = details['poster_path'] as String?;
      if (posterPath == null || posterPath.isEmpty) continue;
      final posterUrl = TmdbImages.posterFor(posterPath);
      if (posterUrl.isEmpty || posterUrl == item.posterPath.trim()) continue;
      final fixTitle = tmdbTitle.isNotEmpty && tmdbTitle != item.title;
      final healed = item.copyWith(
        posterPath: posterUrl,
        mediaType: mediaType,
        title: fixTitle ? tmdbTitle : null,
      );
      if (item.id.isNotEmpty) {
        final patch = <String, dynamic>{'posterPath': posterUrl};
        if (mediaType != item.mediaType) patch['mediaType'] = mediaType;
        if (fixTitle) patch['title'] = tmdbTitle;
        try {
          unawaited(
            firestore
                .collection('watch_list')
                .doc(item.id)
                .update(patch)
                .catchError((Object e, StackTrace st) {
                  Logger.e(
                    'Poster heal: watch_list patch write failed for ${item.id}',
                    error: e,
                    stackTrace: st,
                  );
                }),
          );
        } catch (e) {
          Logger.w('Poster heal: Firestore update skipped: $e');
        }
      }
      return healed;
        }
      }
    return null;
  }

  Future<MediaItem?> _healByTitleSearch(MediaItem item) async {
    final title = item.title.trim();
    if (title.isEmpty) return null;
    final candidates = TitleMatcher.searchCandidates(title);

    for (final loose in [false, true]) {
      for (final query in candidates) {
        final results = await _searchService.searchMedia(query);
        for (final r in results) {
          if (!TmdbImages.isUsablePath(r.posterPath)) continue;
          final matches = loose
              ? TitleMatcher.titlesLooselyMatch(title, r.title)
              : titlesMatch(title, r.title);
          if (!matches) continue;
          final fixTitle = r.title.isNotEmpty && r.title != title;
          final healed = item.copyWith(
            posterPath: r.posterPath,
            tmdbId: r.tmdbId,
            mediaType: r.mediaType,
            title: fixTitle ? r.title : null,
          );
      if (item.id.isNotEmpty) {
        try {
          unawaited(
            firestore
                .collection('watch_list')
                .doc(item.id)
                .update({
                  'posterPath': r.posterPath,
                  'tmdbId': r.tmdbId,
                  'mediaType': r.mediaType,
                  if (fixTitle) 'title': r.title,
                })
                .catchError((Object e, StackTrace st) {
                  Logger.e(
                    'Poster resolve: watch_list write failed for ${item.id}',
                    error: e,
                    stackTrace: st,
                  );
                }),
          );
        } catch (e) {
          Logger.w('Poster resolve: Firestore update skipped: $e');
        }
      }
      return healed;
        }
      }
    }
    return null;
  }

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
