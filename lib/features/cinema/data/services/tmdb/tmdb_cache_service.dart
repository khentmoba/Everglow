import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/utils/connectivity_aware.dart';
import '../../../../../core/utils/error_aware.dart';
import '../../../../../core/utils/logger.dart';
import '../../models/media_item.dart';
import 'tmdb_base.dart';

/// SharedPreferences-based caching for watchlist items, scoped per user.
class TMDBCacheService with TMDBBase, ConnectivityAware, ErrorAware {
  /// Cache watchlist items to SharedPreferences, scoped per user.
  Future<void> cacheWatchList(List<MediaItem> items, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = items
          .map(
            (item) => {
              'id': item.id,
              'tmdbId': item.tmdbId,
              'title': item.title,
              'mediaType': item.mediaType,
              'posterPath': item.posterPath,
              'backdropPath': item.backdropPath,
              'year': item.year,
              'status': item.status,
              'isAnime': item.isAnime,
              'userName': item.userName,
              'addedAt': item.addedAt.toIso8601String(),
            },
          )
          .toList();
      await prefs.setString(_cacheKey(userName), json.encode(listJson));
    } catch (e) {
      Logger.e('Error caching watchlist', error: e);
    }
  }

  /// Retrieve locally cached watchlist items for a specific user.
  Future<List<MediaItem>> getCachedWatchList(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_cacheKey(userName));
      if (cacheStr != null) {
        final List decoded = json.decode(cacheStr);
        return decoded
            .map(
              (data) => MediaItem(
                id: data['id'] ?? '',
                tmdbId: data['tmdbId'] ?? 0,
                title: data['title'] ?? '',
                mediaType: data['mediaType'] ?? 'movie',
                posterPath: data['posterPath'] ?? '',
                backdropPath: data['backdropPath'] ?? '',
                year: data['year'] ?? '',
                status: data['status'] ?? 'to-watch',
                isAnime: data['isAnime'] == true,
                userName: data['userName'] ?? userName,
                addedAt:
                    DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
              ),
            )
            .toList();
      }
    } catch (e) {
      Logger.e('Error getting cached watchlist', error: e);
    }
    return [];
  }

  String _cacheKey(String userName) => 'cached_watch_list::$userName';
}
