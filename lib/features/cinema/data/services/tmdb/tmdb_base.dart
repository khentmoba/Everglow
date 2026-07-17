import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

/// Shared constants, Firestore access, and mapping helpers for all TMDB
/// sub-services. Mix this into each sub-service alongside [ConnectivityAware]
/// and [ErrorAware].
mixin TMDBBase {
  final String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  final String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  final String imageBaseOriginal = 'https://image.tmdb.org/t/p/original';
  final String profileBaseUrl = 'https://image.tmdb.org/t/p/w185';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Generic mapping helper: TMDB result -> MediaItem
  MediaItem mapResultToMediaItem(Map<String, dynamic> item,
      {String? forcedMediaType}) {
    final mediaType = forcedMediaType ?? item['media_type'] ?? 'movie';
    final title = mediaType == 'movie'
        ? (item['title'] ?? item['name'] ?? 'Unknown Title')
        : (item['name'] ?? item['title'] ?? 'Unknown Title');
    final posterPath = item['poster_path'];
    final releaseDate = item['release_date'] ?? item['first_air_date'] ?? '';
    final year = releaseDate.toString().length >= 4
        ? releaseDate.toString().substring(0, 4)
        : '';

    return MediaItem(
      id: '',
      tmdbId: item['id'] ?? 0,
      title: title,
      mediaType: mediaType,
      posterPath: posterPath != null ? '$imageBaseUrl$posterPath' : '',
      backdropPath: item['backdrop_path'] != null
          ? '$imageBaseOriginal${item['backdrop_path']}'
          : '',
      status: '',
      isAnime: detectAnime(item),
      year: year,
      addedAt: DateTime.now(),
    );
  }

  /// Best-effort anime detection from a TMDB result payload.
  ///
  /// Anime on TMDB is just a TV show with `original_language == 'ja'` and
  /// the Animation genre (id 16). The exact list of genre ids is sometimes
  /// absent from search/discover payloads (only `genre_ids` is present on
  /// list endpoints, while nested `genres` is only available on /details),
  /// so we handle both shapes here.
  bool detectAnime(Map<String, dynamic> item) {
    final lang = (item['original_language'] ?? '').toString();
    if (lang != 'ja') return false;

    final genreIds = item['genre_ids'];
    if (genreIds is List) {
      for (final g in genreIds) {
        if (g is num && g.toInt() == 16) return true;
      }
    }
    final genres = item['genres'];
    if (genres is List) {
      for (final g in genres) {
        if (g is Map && g['id'] is num && (g['id'] as num).toInt() == 16) {
          return true;
        }
      }
    }
    final keywords = item['keywords']?['results'];
    if (keywords is List) {
      for (final k in keywords) {
        if (k is Map && k['name']?.toString().toLowerCase() == 'anime') {
          return true;
        }
      }
    }
    return false;
  }

  /// Fuzzy title matching to verify poster/title correspondence.
  bool titlesMatch(String storedTitle, String tmdbTitle) {
    String normalize(String s) {
      return s
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final a = normalize(storedTitle);
    final b = normalize(tmdbTitle);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b || a.contains(b) || b.contains(a)) return true;
    final wordsA = a.split(' ');
    final wordsB = b.split(' ');
    final overlap =
        wordsA.where((w) => w.length > 2 && wordsB.contains(w)).length;
    final minLen = wordsA.length < wordsB.length ? wordsA.length : wordsB.length;
    return overlap >= (minLen * 0.5).ceil();
  }
}
