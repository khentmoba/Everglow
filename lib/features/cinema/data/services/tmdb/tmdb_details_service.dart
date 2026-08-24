import 'dart:convert';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/error_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import 'tmdb_base.dart';

/// TMDB detail endpoints: credits, reviews, similar titles, TV show
/// season/episode data, and generic media details.
class TMDBDetailsService with TMDBBase, ConnectivityAware, ErrorAware {
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
    final url = Uri.parse('$tmdbBaseUrl/$mediaType/$id');
    try {
      final response = await tmdbGet(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
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
