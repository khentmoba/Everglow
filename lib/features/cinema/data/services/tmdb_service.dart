import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
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

        return results.map((item) {
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

  /// Stream of watch list items
  Stream<List<MediaItem>> getWatchListStream() {
    return _firestore
        .collection('watch_list')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MediaItem.fromFirestore(doc.data(), doc.id)).toList();
    });
  }
}
