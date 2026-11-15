import 'dart:convert';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import 'tmdb_base.dart';

class TMDBDetailsService with TMDBBase, ConnectivityAware {
  final _detailsCache = <String, Map<String, dynamic>>{};
  final _pendingDetails = <String, Future<Map<String, dynamic>?>>{};

  final _imdbIds = <String, String>{};

  static final Set<String> _deadIds = <String>{};

  static final Map<String, String> _typeFixes = <String, String>{};

  static void resetDetailsCacheForTests() {
    _deadIds.clear();
    _typeFixes.clear();
  }

  Future<List<Map<String, dynamic>>> fetchCredits(
    int id,
    String mediaType,
  ) async {
    final url = Uri.parse('$tmdbBaseUrl/$mediaType/$id/credits');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List cast = (data['cast'] as List?) ?? [];
        return cast.take(15).map<Map<String, dynamic>>((c) {
          return {
            'id': c['id'],
            'name': c['name'] ?? 'Unknown',
            'character': c['character'] ?? '',
            'profilePath': c['profile_path'] != null
                ? '$profileBaseUrl${c['profile_path']}'
                : '',
          };
        }).toList();
      }
    } catch (e) {
      Logger.e('TMDB Credits Error', error: e);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchReviews(
    int id,
    String mediaType,
  ) async {
    final url = Uri.parse('$tmdbBaseUrl/$mediaType/$id/reviews');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = (data['results'] as List?) ?? [];
        return results.take(8).map<Map<String, dynamic>>((r) {
          final author = r['author'] ?? 'Anonymous';
          final rawContent = r['content'] ?? '';
          final rating = r['author_details']?['rating'];
          return {
            'id': r['id'],
            'author': author,
            'content': rawContent,
            'rating': rating,
            'createdAt': r['created_at'] ?? '',
            'avatar': r['author_details']?['avatar_path'] != null
                ? '$profileBaseUrl${r['author_details']['avatar_path']}'
                : '',
          };
        }).toList();
      }
    } catch (e) {
      Logger.e('TMDB Reviews Error', error: e);
    }
    return [];
  }

  Future<List<MediaItem>> fetchSimilar(int id, String mediaType) async {
    final url = Uri.parse('$tmdbBaseUrl/$mediaType/$id/similar');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map(
              (item) => mapResultToMediaItem(item, forcedMediaType: mediaType),
            )
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Similar Error', error: e);
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchTVShowDetails(int tvId) async {
    final url = Uri.parse('$tmdbBaseUrl/tv/$tvId');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      Logger.e('TMDB TV Details Error', error: e);
    }
    return null;
  }

  Future<List<dynamic>> fetchSeasonEpisodes(int tvId, int seasonNumber) async {
    final url = Uri.parse('$tmdbBaseUrl/tv/$tvId/season/$seasonNumber');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['episodes'] ?? [];
      }
    } catch (e) {
      Logger.e('TMDB TV Season Episodes Error', error: e);
    }
    return [];
  }

  Future<String?> fetchImdbId(int id, String mediaType) async {
    if (id <= 0) return null;
    final key = '$mediaType:$id';
    final known = _imdbIds[key];
    if (known != null) return known.isEmpty ? null : known;
    String value = '';
    try {
      if (mediaType == 'movie') {
        final details = await fetchMediaDetails(id, mediaType);
        final imdb = details?['imdb_id'];
        if (imdb is String) value = imdb;
      } else {
        final response = await tmdbGet(
          Uri.parse('$tmdbBaseUrl/$mediaType/$id/external_ids'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final imdb = data is Map ? data['imdb_id'] : null;
          if (imdb is String) value = imdb;
        }
      }
    } catch (e) {
      Logger.e('TMDB IMDB id lookup failed for $key', error: e);
      return null;
    }
    _imdbIds[key] = value;
    return value.isEmpty ? null : value;
  }

  Future<Map<String, dynamic>?> fetchMediaDetails(
    int id,
    String mediaType,
  ) async {
    final key = '$mediaType:$id';
    final cached = _detailsCache[key];
    if (cached != null) return cached;
    final pending = _pendingDetails.putIfAbsent(
      key,
      () => _fetchMediaDetails(id, mediaType),
    );
    try {
      final details = await pending;
      if (details != null) {
        if (_detailsCache.length >= 80 && !_detailsCache.containsKey(key)) {
          _detailsCache.remove(_detailsCache.keys.first);
        }
        _detailsCache[key] = details;
      }
      return details;
    } finally {
      if (identical(_pendingDetails[key], pending)) {
        _pendingDetails.remove(key);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchMediaDetails(
    int id,
    String mediaType,
  ) async {
    final key = '$mediaType:$id';
    if (_deadIds.contains(key)) return null;
    final firstType = _typeFixes[key] ?? mediaType;
    final url = Uri.parse('$tmdbBaseUrl/$firstType/$id').replace(
      queryParameters: {'append_to_response': 'release_dates,content_ratings'},
    );
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      if (response.statusCode == 404) {
        final altType = firstType == 'tv'
            ? 'movie'
            : (firstType == 'movie' ? 'tv' : null);
        if (altType != null) {
          final altUrl = Uri.parse('$tmdbBaseUrl/$altType/$id').replace(
            queryParameters: {
              'append_to_response': 'release_dates,content_ratings',
            },
          );
          final altResponse = await tmdbGet(altUrl);
          if (altResponse.statusCode == 200) {
            _typeFixes[key] = altType;
            return json.decode(altResponse.body);
          }
        }
        _deadIds.add(key);
      }
    } catch (e) {
      Logger.e('TMDB Details Error', error: e);
    }
    return null;
  }

  Future<bool> isAnimeByTmdbId(int tmdbId, String mediaType) async {
    final details = await fetchMediaDetails(tmdbId, mediaType);
    if (details == null) return false;
    return detectAnime(details);
  }
}
