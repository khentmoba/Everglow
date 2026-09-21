import 'dart:convert';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/error_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import 'tmdb_base.dart';

/// TMDB detail endpoints: credits, reviews, similar titles, TV show
/// season/episode data, and generic media details.
class TMDBDetailsService with TMDBBase, ConnectivityAware, ErrorAware {
  /// IDs that 404'd on BOTH movie and tv lookups (stale/dead TMDB ids).
  /// Process-wide so the billboard, hover cards, and episode drawer share
  /// one memory of dead ids instead of re-404ing on every rotation.
  static final Set<String> _deadIds = <String>{};

  /// Requested-type -> resolved-type corrections, keyed `"$type:$id"`.
  /// E.g. `tv:1714066` -> `movie` for "Yellow Jacket Televison", a movie
  /// mistagged as tv in user data. Repeat opens fetch the right type
  /// first (one request, no 404) instead of probing the wrong type again.
  static final Map<String, String> _typeFixes = <String, String>{};

  /// Test helper: statics persist across tests in one file.
  static void resetDetailsCacheForTests() {
    _deadIds.clear();
    _typeFixes.clear();
  }

  /// Fetch cast (credits) for a movie or TV show
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

  /// Fetch user reviews for a movie or TV show
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

  /// Fetch similar movies / TV shows
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

  /// Fetch TV Show details (including seasons)
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

  /// Fetch TV Show Season Episodes
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

  /// Fetch Media Item details (for Hero Banner metadata)
  Future<Map<String, dynamic>?> fetchMediaDetails(
    int id,
    String mediaType,
  ) async {
    // Certifications ride along so the billboard can show an age chip
    // without a second round trip (the proxy passes query params through).
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
      // On 404, check the alternate mediaType in case a movie was tagged tv
      // or vice-versa (e.g. titles with "Televison" tagged as tv).
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
            // Remember the correction so repeat opens skip the 404 probe.
            _typeFixes[key] = altType;
            return json.decode(altResponse.body);
          }
        }
        // Both types 404'd: remember the dead id so rotations and
        // hovers stop re-requesting it for the rest of the session.
        // Other statuses (5xx/429) are transient and stay retryable.
        _deadIds.add(key);
      }
    } catch (e) {
      Logger.e('TMDB Details Error', error: e);
    }
    return null;
  }

  /// Returns `true` if the given TMDB item represents anime, by looking
  /// at the detailed payload (which is the only place we reliably have
  /// `original_language` for TV shows). Used by the episode drawer when
  /// saving a show to the watchlist.
  Future<bool> isAnimeByTmdbId(int tmdbId, String mediaType) async {
    final details = await fetchMediaDetails(tmdbId, mediaType);
    if (details == null) return false;
    return detectAnime(details);
  }
}
