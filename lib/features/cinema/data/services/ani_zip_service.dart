import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight client for the `ani.zip` mapping API
/// (https://api.ani.zip). ani.zip aggregates per-episode metadata from
/// AniDB, TVDB, IMDB, MAL, AniList, and TMDB, which makes it the
/// single most useful source for the two things the rest of the app
/// can't get reliably on its own:
///
///   1. **MAL → TMDB / IMDB id mapping.** Jikan doesn't expose TMDB
///      ids and AniList doesn't either, so without a side-channel we
///      can't hand anime off to the same TMDB-based player (Videasy)
///      that plays non-anime content. ani.zip's `mappings` block gives
///      us `themoviedb_id` for almost every anime in MAL.
///
///   2. **Per-episode stills from TVDB.** Jikan v4 dropped per-episode
///      images, AniList's `streamingEpisodes.thumbnail` is sparse for
///      non-Western-licensed shows, and TMDB stills don't exist for
///      most anime. ani.zip's `episodes[].image` is a TVDB banner URL
///      that fills the gap.
///
/// The API is unauthenticated and has no published rate limit, so we
/// don't run requests through a queue — a small in-memory cache keyed
/// on MAL id is enough to keep re-opens snappy.
class AniZipService {
  static const String _baseUrl = 'https://api.ani.zip';

  // Singleton — same lifetime as JikanService so the cache survives
  // detail-drawer rebuilds and the video-player initState re-opens.
  static final AniZipService _instance = AniZipService._internal();
  factory AniZipService() => _instance;
  AniZipService._internal();

  /// In-memory cache of MAL-id -> full response map. Mappings are
  /// effectively static (TMDB/IMDB/TVDB ids don't move between
  /// titles), so we hold each entry for [_cacheTtl] and refetch on
  /// miss. Bounded by [_cacheMax] to keep the working set small.
  final Map<int, Map<String, dynamic>> _cache = {};
  final Map<int, DateTime> _cacheAt = {};
  static const Duration _cacheTtl = Duration(minutes: 30);
  static const int _cacheMax = 200;

  /// Returns the full ani.zip mapping payload for a MAL id, or null
  /// on a non-200 / network error. The map looks like:
  /// ```
  /// {
  ///   "titles": {...},
  ///   "episodes": {
  ///     "1": { "image": "https://...", "title": {...}, ... },
  ///     ...
  ///   },
  ///   "mappings": {
  ///     "mal_id": 16498,
  ///     "themoviedb_id": "1429",
  ///     "imdb_id": "tt2560140",
  ///     "thetvdb_id": 267440,
  ///     ...
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>?> fetchMappings(int malId) async {
    final cached = _cache[malId];
    if (cached != null) {
      final at = _cacheAt[malId];
      if (at != null && DateTime.now().difference(at) < _cacheTtl) {
        return cached;
      }
    }
    final uri = Uri.parse('$_baseUrl/mappings?mal_id=$malId');
    try {
      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode != 200) {
        print('ani.zip GET $uri failed: ${response.statusCode}');
        return null;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (_cache.length >= _cacheMax) {
        // Drop the oldest entry to keep the cache bounded. A simple
        // FIFO is fine here because the working set is small and
        // entries re-populate on next miss.
        final oldestKey = _cacheAt.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;
        _cache.remove(oldestKey);
        _cacheAt.remove(oldestKey);
      }
      _cache[malId] = body;
      _cacheAt[malId] = DateTime.now();
      return body;
    } catch (e) {
      print('ani.zip GET $uri error: $e');
      return null;
    }
  }

  /// TMDB id (as int) for a MAL id, or null if ani.zip doesn't have
  /// a cross-reference. Used by the video player to hand anime off
  /// to the TMDB-based Videasy player.
  Future<int?> fetchTmdbId(int malId) async {
    final data = await fetchMappings(malId);
    final mappings = data?['mappings'] as Map<String, dynamic>?;
    final raw = mappings?['themoviedb_id'];
    if (raw is String && raw.isNotEmpty) return int.tryParse(raw);
    if (raw is num) return raw.toInt();
    return null;
  }

  /// IMDB id (e.g. "tt2560140") for a MAL id, or null. Handy as a
  /// fallback for providers that key off IMDB ids.
  Future<String?> fetchImdbId(int malId) async {
    final data = await fetchMappings(malId);
    final mappings = data?['mappings'] as Map<String, dynamic>?;
    final raw = mappings?['imdb_id'] as String?;
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  /// Per-episode still URL from TVDB, keyed on the in-show episode
  /// number. Returns null when ani.zip has no record for that slot —
  /// which is the case for specials (S1, O1, etc.) on most shows.
  Future<String?> fetchEpisodeImage(int malId, int episodeNumber) async {
    final data = await fetchMappings(malId);
    if (data == null) return null;
    final episodes = data['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return null;
    final entry = episodes[episodeNumber.toString()] as Map<String, dynamic>?;
    final img = entry?['image'] as String?;
    return (img != null && img.isNotEmpty) ? img : null;
  }

  /// Bulk variant of [fetchEpisodeImage] for one round-trip. Returns
  /// a map of episode-number -> still URL. Episodes that ani.zip
  /// doesn't have a still for are simply absent from the map; the
  /// caller falls back to AniList's streamingEpisodes thumbnail or
  /// the anime's poster.
  Future<Map<int, String>> fetchEpisodeImages(int malId) async {
    final data = await fetchMappings(malId);
    final out = <int, String>{};
    if (data == null) return out;
    final episodes = data['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return out;
    episodes.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;
      final img = value['image'] as String?;
      if (img == null || img.isEmpty) return;
      final n = int.tryParse(key.toString());
      if (n == null) return;
      out[n] = img;
    });
    return out;
  }

  /// Bypasses the cache. Used by the episode drawer's pull-to-refresh
  /// gesture when the user knows the data is stale.
  Future<Map<String, dynamic>?> fetchMappingsFresh(int malId) async {
    _cache.remove(malId);
    _cacheAt.remove(malId);
    return fetchMappings(malId);
  }
}
