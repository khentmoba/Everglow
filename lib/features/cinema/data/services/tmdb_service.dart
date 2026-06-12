import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/constants/api_keys.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

class TMDBService {
  final String _baseUrl = 'https://api.themoviedb.org/3';
  final String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  final String _imageBaseOriginal = 'https://image.tmdb.org/t/p/original';
  final String _profileBaseUrl = 'https://image.tmdb.org/t/p/w185';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final TMDBService _instance = TMDBService._internal();
  factory TMDBService() => _instance;
  TMDBService._internal();

  // Generic mapping helper: TMDB result -> MediaItem
  MediaItem _mapResultToMediaItem(Map<String, dynamic> item, {String? forcedMediaType}) {
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
      posterPath: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
      backdropPath: item['backdrop_path'] != null
          ? '$_imageBaseOriginal${item['backdrop_path']}'
          : '',
      status: 'to-watch',
      year: year,
      addedAt: DateTime.now(),
    );
  }

  /// Search for movies and TV shows
  Future<List<MediaItem>> searchMedia(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
        '$_baseUrl/search/multi?api_key=${ApiKeys.tmdbApiKey}&query=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .where((item) =>
                item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) => _mapResultToMediaItem(item))
            .toList();
      } else {
        throw Exception('Failed to search TMDB: ${response.statusCode}');
      }
    } catch (e) {
      print('TMDB Search Error: $e');
      return [];
    }
  }

  /// Fetch Trending (optionally by region, e.g. 'PH' for Philippines)
  /// timeWindow: 'day' or 'week'
  Future<List<MediaItem>> fetchTrending({
    String region = 'all',
    String timeWindow = 'week',
  }) async {
    final url = Uri.parse(
        '$_baseUrl/trending/all/$timeWindow?api_key=${ApiKeys.tmdbApiKey}&region=$region');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .where((item) =>
                item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) => _mapResultToMediaItem(item))
            .toList();
      }
    } catch (e) {
      print('TMDB Trending Error: $e');
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
        '$_baseUrl/movie/top_rated?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => _mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      print('TMDB Top Rated Error: $e');
    }
    return [];
  }

  /// Fetch Popular TV Shows
  Future<List<MediaItem>> fetchPopularTVShows() async {
    final url = Uri.parse('$_baseUrl/tv/popular?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => _mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      print('TMDB Popular TV Error: $e');
    }
    return [];
  }

  /// Fetch Now Playing in Cinemas (movies currently in theaters)
  Future<List<MediaItem>> fetchNowPlaying({String region = 'PH'}) async {
    final url = Uri.parse(
        '$_baseUrl/movie/now_playing?api_key=${ApiKeys.tmdbApiKey}&region=$region');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => _mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      print('TMDB Now Playing Error: $e');
    }
    return [];
  }

  /// Fetch Upcoming movies (newly released / coming soon)
  Future<List<MediaItem>> fetchUpcoming({String region = 'PH'}) async {
    final url = Uri.parse(
        '$_baseUrl/movie/upcoming?api_key=${ApiKeys.tmdbApiKey}&region=$region');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => _mapResultToMediaItem(item, forcedMediaType: 'movie'))
            .toList();
      }
    } catch (e) {
      print('TMDB Upcoming Error: $e');
    }
    return [];
  }

  /// Fetch list of all available genres for a media type
  Future<Map<int, String>> fetchGenreList(String mediaType) async {
    final url = Uri.parse(
        '$_baseUrl/genre/$mediaType/list?api_key=${ApiKeys.tmdbApiKey}');
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
      print('TMDB Genre List Error: $e');
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
        '$_baseUrl/discover/$mediaType?api_key=${ApiKeys.tmdbApiKey}&with_genres=$genreId&sort_by=$sortBy');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => _mapResultToMediaItem(item, forcedMediaType: mediaType))
            .toList();
      }
    } catch (e) {
      print('TMDB Discover By Genre Error: $e');
    }
    return [];
  }

  /// Fetch cast (credits) for a movie or TV show
  Future<List<Map<String, dynamic>>> fetchCredits(int id, String mediaType) async {
    final url = Uri.parse(
        '$_baseUrl/$mediaType/$id/credits?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List cast = (data['cast'] as List?) ?? [];
        return cast.take(15).map<Map<String, dynamic>>((c) {
          return {
            'id': c['id'],
            'name': c['name'] ?? 'Unknown',
            'character': c['character'] ?? '',
            'profilePath': c['profile_path'] != null
                ? '$_profileBaseUrl${c['profile_path']}'
                : '',
          };
        }).toList();
      }
    } catch (e) {
      print('TMDB Credits Error: $e');
    }
    return [];
  }

  /// Fetch user reviews for a movie or TV show
  Future<List<Map<String, dynamic>>> fetchReviews(int id, String mediaType) async {
    final url = Uri.parse(
        '$_baseUrl/$mediaType/$id/reviews?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
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
                ? '$_profileBaseUrl${r['author_details']['avatar_path']}'
                : '',
          };
        }).toList();
      }
    } catch (e) {
      print('TMDB Reviews Error: $e');
    }
    return [];
  }

  /// Fetch similar movies / TV shows
  Future<List<MediaItem>> fetchSimilar(int id, String mediaType) async {
    final url = Uri.parse(
        '$_baseUrl/$mediaType/$id/similar?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .map((item) => _mapResultToMediaItem(item, forcedMediaType: mediaType))
            .toList();
      }
    } catch (e) {
      print('TMDB Similar Error: $e');
    }
    return [];
  }

  /// Fetch TV Show details (including seasons)
  Future<Map<String, dynamic>?> fetchTVShowDetails(int tvId) async {
    final url = Uri.parse('$_baseUrl/tv/$tvId?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('TMDB TV Details Error: $e');
    }
    return null;
  }

  /// Fetch TV Show Season Episodes
  Future<List<dynamic>> fetchSeasonEpisodes(int tvId, int seasonNumber) async {
    final url = Uri.parse(
        '$_baseUrl/tv/$tvId/season/$seasonNumber?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['episodes'] ?? [];
      }
    } catch (e) {
      print('TMDB TV Season Episodes Error: $e');
    }
    return [];
  }

  /// Fetch Media Item details (for Hero Banner metadata)
  Future<Map<String, dynamic>?> fetchMediaDetails(int id, String mediaType) async {
    final url = Uri.parse('$_baseUrl/$mediaType/$id?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('TMDB Details Error: $e');
    }
    return null;
  }

  Future<void> saveToWatchList(MediaItem item, String status) async {
    try {
      final collection = _firestore.collection('watch_list');

      // Check if exists
      final existing = await collection.where('tmdbId', isEqualTo: item.tmdbId).limit(1).get();

      if (existing.docs.isNotEmpty) {
        // Update status if exists
        await collection.doc(existing.docs.first.id).update({
          'status': status,
          'addedAt': Timestamp.now(),
        });
      } else {
        // Create new entry
        await collection.add(item.copyWith(status: status, addedAt: DateTime.now()).toFirestore());
      }
      print("Saved to watch list successfully: ${item.title}");
    } catch (e) {
      print("Error saving to watch list: $e");
    }
  }

  Future<void> removeFromWatchList(int tmdbId) async {
    try {
      final collection = _firestore.collection('watch_list');
      final existing = await collection.where('tmdbId', isEqualTo: tmdbId).limit(1).get();
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
        print("Removed from watch list: $tmdbId");
      }
    } catch (e) {
      print("Error removing from watch list: $e");
    }
  }

  /// Stream of watch list items (Firestore-based)
  Stream<List<MediaItem>> getWatchListStream() {
    return _firestore
        .collection('watch_list')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) => MediaItem.fromFirestore(doc.data(), doc.id)).toList();
      // Side effect: Cache the list locally
      cacheWatchList(items);
      return items;
    });
  }

  /// Cache watchlist items to SharedPreferences
  Future<void> cacheWatchList(List<MediaItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = items.map((item) => {
        'id': item.id,
        'tmdbId': item.tmdbId,
        'title': item.title,
        'mediaType': item.mediaType,
        'posterPath': item.posterPath,
        'backdropPath': item.backdropPath,
        'year': item.year,
        'status': item.status,
        'addedAt': item.addedAt.toIso8601String(),
      }).toList();
      await prefs.setString('cached_watch_list', json.encode(listJson));
    } catch (e) {
      print('Error caching watchlist: $e');
    }
  }

  /// Retrieve locally cached watchlist items
  Future<List<MediaItem>> getCachedWatchList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString('cached_watch_list');
      if (cacheStr != null) {
        final List decoded = json.decode(cacheStr);
        return decoded.map((data) => MediaItem(
          id: data['id'] ?? '',
          tmdbId: data['tmdbId'] ?? 0,
          title: data['title'] ?? '',
          mediaType: data['mediaType'] ?? 'movie',
          posterPath: data['posterPath'] ?? '',
          backdropPath: data['backdropPath'] ?? '',
          year: data['year'] ?? '',
          status: data['status'] ?? 'to-watch',
          addedAt: DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
        )).toList();
      }
    } catch (e) {
      print('Error getting cached watchlist: $e');
    }
    return [];
  }
}
