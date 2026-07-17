import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/constants/api_keys.dart';
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/core/utils/error_aware.dart';
import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'tmdb_base.dart';

/// TMDB search endpoints (multi-search and targeted TV/movie search).
class TMDBSearchService with TMDBBase, ConnectivityAware, ErrorAware {
  /// Search for movies and TV shows
  Future<List<MediaItem>> searchMedia(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
        '$tmdbBaseUrl/search/multi?api_key=${ApiKeys.tmdbApiKey}&query=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .where((item) =>
                item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) => mapResultToMediaItem(item))
            .toList();
      } else {
        throw Exception('Failed to search TMDB: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('TMDB Search Error', error: e);
      return [];
    }
  }

  /// Search TMDB for a TV show by title and year. Used as fallback when
  /// ani.zip doesn't have a TMDB mapping for the MAL id. Returns the
  /// first result's ID, or null on no match / API error.
  Future<int?> searchTvShow(String title, {String? firstAirDateYear}) async {
    final params = <String, String>{
      'query': title,
      'api_key': ApiKeys.tmdbApiKey,
    };
    if (firstAirDateYear != null && firstAirDateYear.isNotEmpty) {
      params['first_air_date_year'] = firstAirDateYear;
    }
    final url =
        Uri.parse('$tmdbBaseUrl/search/tv').replace(queryParameters: params);
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return (results[0]['id'] as num?)?.toInt();
        }
      }
    } catch (e) {
      Logger.e('TMDB Search TV Error', error: e);
    }
    return null;
  }
}
