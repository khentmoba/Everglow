import 'dart:convert';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/logger.dart';
import 'tmdb_base.dart';

class TMDBTrailerService with TMDBBase, ConnectivityAware {
  final Map<String, String?> _trailerCache = {};

  final _pendingTrailers = <String, Future<String?>>{};

  Future<String?> fetchTrailerKey(int id, String mediaType) async {
    final cacheKey = '${mediaType}_$id';
    if (_trailerCache.containsKey(cacheKey)) {
      return _trailerCache[cacheKey];
    }

    final pending = _pendingTrailers.putIfAbsent(
      cacheKey,
      () => _fetchTrailerKey(id, mediaType, cacheKey),
    );
    try {
      return await pending;
    } finally {
      if (identical(_pendingTrailers[cacheKey], pending)) {
        _pendingTrailers.remove(cacheKey);
      }
    }
  }

  Future<String?> _fetchTrailerKey(
    int id,
    String mediaType,
    String cacheKey,
  ) async {
    final url = Uri.parse('$tmdbBaseUrl/$mediaType/$id/videos');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        var trailer = results.firstWhere(
          (v) =>
              v['site'] == 'YouTube' &&
              v['type'] == 'Trailer' &&
              v['official'] == true,
          orElse: () => null,
        );
        trailer ??= results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => null,
        );
        trailer ??= results.firstWhere(
          (v) => v['site'] == 'YouTube',
          orElse: () => null,
        );

        final key = trailer != null ? trailer['key'] as String? : null;
        if (_trailerCache.length >= 80 &&
            !_trailerCache.containsKey(cacheKey)) {
          _trailerCache.remove(_trailerCache.keys.first);
        }
        _trailerCache[cacheKey] = key;
        return key;
      }
    } catch (e) {
      Logger.e('TMDB fetchTrailerKey Error', error: e);
    }
    return null;
  }
}
