import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/constants/api_keys.dart';
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/core/utils/error_aware.dart';
import 'package:everglow/core/utils/logger.dart';
import 'tmdb_base.dart';

/// Fetches YouTube trailer keys for movies and TV shows, with in-memory
/// caching to avoid redundant network requests.
class TMDBTrailerService with TMDBBase, ConnectivityAware, ErrorAware {
  /// Cache for trailer keys: 'mediaType_tmdbId' -> Trailer Key
  final Map<String, String?> _trailerCache = {};

  /// Fetch YouTube trailer key for a movie or TV show, with caching.
  Future<String?> fetchTrailerKey(int id, String mediaType) async {
    final cacheKey = '${mediaType}_$id';
    if (_trailerCache.containsKey(cacheKey)) {
      return _trailerCache[cacheKey];
    }

    final url = Uri.parse(
        '$tmdbBaseUrl/$mediaType/$id/videos?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        // Prioritize official YouTube Trailer
        var trailer = results.firstWhere(
          (v) =>
              v['site'] == 'YouTube' &&
              v['type'] == 'Trailer' &&
              v['official'] == true,
          orElse: () => null,
        );
        // Fallback to any YouTube Trailer
        trailer ??= results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => null,
        );
        // Fallback to any YouTube video (Teaser, Clip, etc.)
        trailer ??= results.firstWhere(
          (v) => v['site'] == 'YouTube',
          orElse: () => null,
        );

        final key = trailer != null ? trailer['key'] as String? : null;
        _trailerCache[cacheKey] = key;
        return key;
      }
    } catch (e) {
      Logger.e('TMDB fetchTrailerKey Error', error: e);
    }
    _trailerCache[cacheKey] = null;
    return null;
  }
}
