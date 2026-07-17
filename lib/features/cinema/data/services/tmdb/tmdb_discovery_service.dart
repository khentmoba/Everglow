import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/constants/api_keys.dart';
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/core/utils/error_aware.dart';
import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'tmdb_base.dart';

/// TMDB discovery, trending, top rated, popular, and genre-based
/// catalogue endpoints.
class TMDBDiscoveryService with TMDBBase, ConnectivityAware, ErrorAware {
  /// Fetch trending anime (Japanese animation) from TMDB.
  ///
  /// Anime is a content descriptor, not a separate catalog on TMDB, so we
  /// discover TV shows filtered by `original_language=ja` and the
  /// Animation genre (id 16). Sorted by popularity so the carousel shows
  /// what's actually hot right now.
  Future<List<MediaItem>> fetchTrendingAnime() async {
    return discoverAnime(
      sortBy: 'popularity.desc',
      voteCountGte: 20,
    );
  }

  /// Unified anime discovery used by every category on the Anime screen
  /// (Trending, Currently Airing, Top Rated, Hidden Gems, By Genre, etc.).
  ///
  /// All filters are optional; when none are passed you get the broadest
  /// anime TV catalog sorted by popularity. The `with_original_language=ja`
  /// + `with_genres=16` (Animation) constraints are always applied so a
  /// caller can't accidentally pull non-anime results.
  Future<List<MediaItem>> discoverAnime({
    String? sortBy,
    List<int>? withGenres,
    List<int>? withKeywords,
    int? withStatus,
    String? airDateGte,
    String? airDateLte,
    String? firstAirDateGte,
    String? firstAirDateLte,
    int? voteCountGte,
    int? voteCountLte,
    double? voteAverageGte,
    int page = 1,
  }) async {
    final params = <String, String>{
      'api_key': ApiKeys.tmdbApiKey,
      'with_original_language': 'ja',
      'with_genres': '16',
      'include_adult': 'false',
      'page': '$page',
    };
    if (sortBy != null) params['sort_by'] = sortBy;
    if (withGenres != null && withGenres.isNotEmpty) {
      params['with_genres'] = '${params['with_genres']},${withGenres.join(',')}';
    }
    if (withKeywords != null && withKeywords.isNotEmpty) {
      params['with_keywords'] = withKeywords.join('|');
    }
    if (withStatus != null) params['with_status'] = '$withStatus';
    if (airDateGte != null) params['air_date.gte'] = airDateGte;
    if (airDateLte != null) params['air_date.lte'] = airDateLte;
    if (firstAirDateGte != null) {
      params['first_air_date.gte'] = firstAirDateGte;
    }
    if (firstAirDateLte != null) {
      params['first_air_date.lte'] = firstAirDateLte;
    }
    if (voteCountGte != null) params['vote_count.gte'] = '$voteCountGte';
    if (voteCountLte != null) params['vote_count.lte'] = '$voteCountLte';
    if (voteAverageGte != null) {
      params['vote_average.gte'] = voteAverageGte.toString();
    }

    final url = Uri.parse(
        '$tmdbBaseUrl/discover/tv?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) =>
                mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Discover Anime Error', error: e);
    }
    return [];
  }

  /// Discover anime movies. Same constraints as [discoverAnime] but hits
  /// the `/discover/movie` endpoint since standalone anime films are
  /// catalogued as movies on TMDB.
  Future<List<MediaItem>> discoverAnimeMovies({
    String? sortBy,
    String? primaryReleaseDateGte,
    String? primaryReleaseDateLte,
    int? voteCountGte,
    int page = 1,
  }) async {
    final params = <String, String>{
      'api_key': ApiKeys.tmdbApiKey,
      'with_original_language': 'ja',
      'with_genres': '16',
      'include_adult': 'false',
      'page': '$page',
    };
    if (sortBy != null) params['sort_by'] = sortBy;
    if (primaryReleaseDateGte != null) {
      params['primary_release_date.gte'] = primaryReleaseDateGte;
    }
    if (primaryReleaseDateLte != null) {
      params['primary_release_date.lte'] = primaryReleaseDateLte;
    }
    if (voteCountGte != null) params['vote_count.gte'] = '$voteCountGte';

    final url = Uri.parse(
        '$tmdbBaseUrl/discover/movie?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) => mapResultToMediaItem(
                item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Discover Anime Movies Error', error: e);
    }
    return [];
  }

  /// Fetch Trending (optionally by region, e.g. 'PH' for Philippines)
  /// timeWindow: 'day' or 'week'
  ///
  /// Note: TMDB's /trending endpoint is globally aggregated and does NOT
  /// support a region filter. Passing a non-'all' region routes to a
  /// country-specific popularity feed via /discover so the list actually
  /// reflects that region.
  Future<List<MediaItem>> fetchTrending({
    String region = 'all',
    String timeWindow = 'week',
  }) async {
    if (region != 'all' && region.isNotEmpty) {
      return fetchTrendingByCountry(countryCode: region);
    }

    final url = Uri.parse(
        '$tmdbBaseUrl/trending/all/$timeWindow?api_key=${ApiKeys.tmdbApiKey}');
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
      }
    } catch (e) {
      Logger.e('TMDB Trending Error', error: e);
    }
    return [];
  }

  /// Fetch trending content for a specific country in a "Netflix top 10"
  /// style: what's globally popular AND actually streamable in [countryCode].
  ///
  /// We intentionally do NOT use `with_origin_country` — that restricts results
  /// to locally-produced titles, which on TMDB is dominated by Vivamax films
  /// and other niche local catalogs. Instead we use `watch_region` together
  /// with `with_watch_monetization_types` so the list reflects what people in
  /// that country can actually watch on streaming (Netflix, Disney+, Prime,
  /// Viu, iQIYI, etc.) sorted by popularity.
  Future<List<MediaItem>> fetchTrendingByCountry({
    required String countryCode,
  }) async {
    final cc = countryCode.toUpperCase();
    final monetization = 'flatrate|free|ads';

    final movieUrl = Uri.parse(
        '$tmdbBaseUrl/discover/movie?api_key=${ApiKeys.tmdbApiKey}'
        '&sort_by=popularity.desc'
        '&watch_region=$cc'
        '&with_watch_monetization_types=$monetization'
        '&region=$cc'
        '&include_adult=false'
        '&vote_count.gte=50'
        '&page=1');
    final tvUrl = Uri.parse(
        '$tmdbBaseUrl/discover/tv?api_key=${ApiKeys.tmdbApiKey}'
        '&sort_by=popularity.desc'
        '&watch_region=$cc'
        '&with_watch_monetization_types=$monetization'
        '&include_adult=false'
        '&vote_count.gte=50'
        '&page=1');

    try {
      final responses = await Future.wait([
        http.get(movieUrl),
        http.get(tvUrl),
      ]);

      final combined = <Map<String, dynamic>>[];

      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body);
        final List results = data['results'] ?? [];
        for (final item in results) {
          combined.add({...item as Map<String, dynamic>, 'media_type': 'movie'});
        }
      }
      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body);
        final List results = data['results'] ?? [];
        for (final item in results) {
          combined.add({...item as Map<String, dynamic>, 'media_type': 'tv'});
        }
      }

      combined.sort((a, b) {
        final ap = (a['popularity'] as num?)?.toDouble() ?? 0.0;
        final bp = (b['popularity'] as num?)?.toDouble() ?? 0.0;
        return bp.compareTo(ap);
      });

      return combined.map((item) => mapResultToMediaItem(item)).toList();
    } catch (e) {
      Logger.e('TMDB Trending By Country Error', error: e);
    }
    return [];
  }

  /// Fetch Trending Today (kept for backwards compatibility)
  Future<List<MediaItem>> fetchTrendingToday() async {
    return fetchTrending(region: 'all', timeWindow: 'day');
  }

  /// Fetch Top Rated Movies
  Future<List<MediaItem>> fetchTopRatedMovies() async {
    final url = Uri.parse(
        '$tmdbBaseUrl/movie/top_rated?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Top Rated Error', error: e);
    }
    return [];
  }

  /// Fetch Popular TV Shows
  Future<List<MediaItem>> fetchPopularTVShows() async {
    final url =
        Uri.parse('$tmdbBaseUrl/tv/popular?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Popular TV Error', error: e);
    }
    return [];
  }

  /// Fetch Popular Movies
  Future<List<MediaItem>> fetchPopularMovies() async {
    final url = Uri.parse(
        '$tmdbBaseUrl/movie/popular?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Popular Movies Error', error: e);
    }
    return [];
  }

  /// Fetch Top Rated TV Shows
  Future<List<MediaItem>> fetchTopRatedTV() async {
    final url = Uri.parse(
        '$tmdbBaseUrl/tv/top_rated?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Top Rated TV Error', error: e);
    }
    return [];
  }

  /// Fetch TV shows airing today
  Future<List<MediaItem>> fetchAiringToday() async {
    final url = Uri.parse(
        '$tmdbBaseUrl/tv/airing_today?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Airing Today Error', error: e);
    }
    return [];
  }

  /// Fetch TV shows currently on the air
  Future<List<MediaItem>> fetchOnTheAir() async {
    final url = Uri.parse(
        '$tmdbBaseUrl/tv/on_the_air?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB On The Air Error', error: e);
    }
    return [];
  }

  /// Fetch Now Playing in Cinemas (movies currently in theaters)
  Future<List<MediaItem>> fetchNowPlaying({String region = 'PH'}) async {
    final url = Uri.parse(
        '$tmdbBaseUrl/movie/now_playing?api_key=${ApiKeys.tmdbApiKey}&region=$region');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Now Playing Error', error: e);
    }
    return [];
  }

  /// Fetch Upcoming movies (newly released / coming soon)
  Future<List<MediaItem>> fetchUpcoming({String region = 'PH'}) async {
    final url = Uri.parse(
        '$tmdbBaseUrl/movie/upcoming?api_key=${ApiKeys.tmdbApiKey}&region=$region');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Upcoming Error', error: e);
    }
    return [];
  }

  /// Fetch list of all available genres for a media type
  Future<Map<int, String>> fetchGenreList(String mediaType) async {
    final url = Uri.parse(
        '$tmdbBaseUrl/genre/$mediaType/list?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List genres = data['genres'] ?? [];
        return {
          for (final g in genres) (g['id'] as int): (g['name'] as String),
        };
      }
    } catch (e) {
      Logger.e('TMDB Genre List Error', error: e);
    }
    return {};
  }

  /// Discover media by genre
  Future<List<MediaItem>> discoverByGenre({
    required int genreId,
    required String mediaType,
    String sortBy = 'popularity.desc',
  }) async {
    final url = Uri.parse(
        '$tmdbBaseUrl/discover/$mediaType?api_key=${ApiKeys.tmdbApiKey}&with_genres=$genreId&sort_by=$sortBy');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => mapResultToMediaItem(item, forcedMediaType: mediaType))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Discover By Genre Error', error: e);
    }
    return [];
  }

  /// General-purpose content discovery. Unlike [discoverAnime] it does
  /// NOT force the Japanese language / Animation genre constraint.
  ///
  /// Pass any combination of optional TMDB discover parameters to
  /// build a custom feed — language rows, decade rows, or combined
  /// filters. The default sort is popularity descending.
  Future<List<MediaItem>> discoverMedia({
    required String mediaType, // 'movie' or 'tv'
    String? sortBy,
    List<int>? withGenres,
    int? yearGte,
    int? yearLte,
    double? voteAverageGte,
    int? voteCountGte,
    String? withOriginalLanguage,
    int page = 1,
  }) async {
    final params = <String, String>{
      'api_key': ApiKeys.tmdbApiKey,
      'include_adult': 'false',
      'page': '$page',
    };
    if (sortBy != null) params['sort_by'] = sortBy;
    if (withGenres != null && withGenres.isNotEmpty) {
      params['with_genres'] = withGenres.join(',');
    }
    if (voteAverageGte != null) {
      params['vote_average.gte'] = voteAverageGte.toString();
    }
    if (voteCountGte != null) params['vote_count.gte'] = '$voteCountGte';
    if (withOriginalLanguage != null) {
      params['with_original_language'] = withOriginalLanguage;
    }

    if (yearGte != null) {
      final key = mediaType == 'tv'
          ? 'first_air_date.gte'
          : 'primary_release_date.gte';
      params[key] = '$yearGte-01-01';
    }
    if (yearLte != null) {
      final key = mediaType == 'tv'
          ? 'first_air_date.lte'
          : 'primary_release_date.lte';
      params[key] = '$yearLte-12-31';
    }

    final url = Uri.parse(
        '$tmdbBaseUrl/discover/$mediaType?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) =>
                mapResultToMediaItem(item, forcedMediaType: mediaType))
            .toList();
      }
    } catch (e) {
      Logger.e('TMDB Discover Media Error', error: e);
    }
    return [];
  }
}
