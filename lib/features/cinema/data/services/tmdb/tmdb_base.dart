import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../models/media_item.dart';

/// Process-wide ID token cache shared by all TMDB sub-services.
///
/// `getIdToken()` is the main bottleneck on dashboard boot — 6+ Last.fm
/// and TMDB calls fire concurrently, each calling it independently. Firebase
/// already caches the JWT for ~1h, but the async call still pays a bridge
/// + storage lookup. This coalesces concurrent callers onto one in-flight
/// future and caches the result for 4 minutes.
String? _tmdbCachedToken;
DateTime? _tmdbCachedAt;
Future<String?>? _tmdbInFlight;

Future<String?> _getIdTokenCached() async {
  final now = DateTime.now();
  if (_tmdbCachedToken != null &&
      _tmdbCachedAt != null &&
      now.difference(_tmdbCachedAt!).inMinutes < 4) {
    return _tmdbCachedToken;
  }
  if (_tmdbInFlight != null) return _tmdbInFlight!;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  _tmdbInFlight = user.getIdToken();
  try {
    _tmdbCachedToken = await _tmdbInFlight;
    _tmdbCachedAt = DateTime.now();
    return _tmdbCachedToken;
  } finally {
    _tmdbInFlight = null;
  }
}

/// Shared constants, Firestore access, and mapping helpers for all TMDB
/// sub-services. Mix this into each sub-service alongside [ConnectivityAware]
/// and [ErrorAware].
mixin TMDBBase {
  /// All metadata requests go through the app's authenticated Cloud Function
  /// so the TMDB key remains server-side and is never compiled into web JS.
  final String tmdbBaseUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyTmdb';
  final String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  final String imageBaseBackdrop = 'https://image.tmdb.org/t/p/w780';
  final String profileBaseUrl = 'https://image.tmdb.org/t/p/w185';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Sends a signed TMDB request. [http.get] cannot be used directly because
  /// the Authorization header makes browsers issue an authenticated CORS call.
  Future<http.Response> tmdbGet(Uri url) async {
    final token = await _getIdTokenCached();
    if (token == null || token.isEmpty) {
      throw StateError('TMDB requires an authenticated user');
    }
    return http
        .get(url, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 12));
  }

  /// Generic mapping helper: TMDB result -> MediaItem
  MediaItem mapResultToMediaItem(
    Map<String, dynamic> item, {
    String? forcedMediaType,
  }) {
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
          ? '$imageBaseBackdrop${item['backdrop_path']}'
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
    final overlap = wordsA
        .where((w) => w.length > 2 && wordsB.contains(w))
        .length;
    final minLen = wordsA.length < wordsB.length
        ? wordsA.length
        : wordsB.length;
    return overlap >= (minLen * 0.5).ceil();
  }
}
