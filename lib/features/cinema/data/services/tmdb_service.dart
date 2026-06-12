import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/constants/api_keys.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

class TMDBService {
  final String _baseUrl = 'https://api.themoviedb.org/3';
  final String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final TMDBService _instance = TMDBService._internal();
  factory TMDBService() => _instance;
  TMDBService._internal();

  /// Search for movies and TV shows
  Future<List<MediaItem>> searchMedia(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$_baseUrl/search/multi?api_key=${ApiKeys.tmdbApiKey}&query=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) {
          final mediaType = item['media_type'] ?? 'movie';
          final title = mediaType == 'movie' ? item['title'] : item['name'];
          final posterPath = item['poster_path'];

          return MediaItem(
            id: '', // Not in Firestore yet
            tmdbId: item['id'] ?? 0,
            title: title ?? 'Unknown Title',
            mediaType: mediaType,
            posterPath: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
            status: 'to-watch',
            addedAt: DateTime.now(),
          );
        }).toList();
      } else {
        throw Exception('Failed to search TMDB: ${response.statusCode}');
      }
    } catch (e) {
      print('TMDB Search Error: $e');
      return [];
    }
  }

  /// Fetch Trending Today
  Future<List<MediaItem>> fetchTrendingToday() async {
    final url = Uri.parse('$_baseUrl/trending/all/day?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results
            .where((item) => item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) {
          final mediaType = item['media_type'] ?? 'movie';
          final title = mediaType == 'movie' ? item['title'] : item['name'];
          final posterPath = item['poster_path'];

          return MediaItem(
            id: '',
            tmdbId: item['id'] ?? 0,
            title: title ?? 'Unknown Title',
            mediaType: mediaType,
            posterPath: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
            status: 'to-watch',
            addedAt: DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      print('TMDB Trending Error: $e');
    }
    return [];
  }

  /// Fetch Top Rated Movies
  Future<List<MediaItem>> fetchTopRatedMovies() async {
    final url = Uri.parse('$_baseUrl/movie/top_rated?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results.map((item) {
          final posterPath = item['poster_path'];
          return MediaItem(
            id: '',
            tmdbId: item['id'] ?? 0,
            title: item['title'] ?? 'Unknown Title',
            mediaType: 'movie',
            posterPath: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
            status: 'to-watch',
            addedAt: DateTime.now(),
          );
        }).toList();
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

        return results.map((item) {
          final posterPath = item['poster_path'];
          return MediaItem(
            id: '',
            tmdbId: item['id'] ?? 0,
            title: item['name'] ?? 'Unknown Title',
            mediaType: 'tv',
            posterPath: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
            status: 'to-watch',
            addedAt: DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      print('TMDB Popular TV Error: $e');
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
    final url = Uri.parse('$_baseUrl/tv/$tvId/season/$seasonNumber?api_key=${ApiKeys.tmdbApiKey}');
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
