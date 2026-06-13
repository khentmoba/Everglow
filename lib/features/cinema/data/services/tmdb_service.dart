import 'dart:async';
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
  
  // Cache for trailer keys to avoid redundant network requests: 'mediaType_tmdbId' -> Trailer Key
  final Map<String, String?> _trailerCache = {};

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
      isAnime: _detectAnime(item),
      year: year,
      addedAt: DateTime.now(),
    );
  }

  /// Best-effort anime detection from a TMDB result payload.
  ///
  /// Anime on TMDB is just a TV show with `original_language == 'ja'` and
  /// the Animation genre (id 16). The exact list of genre ids is sometimes
  /// absent from search/discover payloads (only `genre_ids` is present on
  /// list endpoints, while nested `genres` is only available on /details),
  /// so we handle both shapes here.
  static bool _detectAnime(Map<String, dynamic> item) {
    final lang = (item['original_language'] ?? '').toString();
    if (lang != 'ja') return false;

    final genreIds = item['genre_ids'];
    if (genreIds is List) {
      for (final g in genreIds) {
        if (g is num && g.toInt() == 16) return true;
      }
    }
    final genres = item['genres'];
    if (genres is List) {
      for (final g in genres) {
        if (g is Map && g['id'] is num && (g['id'] as num).toInt() == 16) {
          return true;
        }
      }
    }
    final keywords = item['keywords']?['results'];
    if (keywords is List) {
      for (final k in keywords) {
        if (k is Map && k['name']?.toString().toLowerCase() == 'anime') {
          return true;
        }
      }
    }
    return false;
  }

  /// Fetch trending anime (Japanese animation) from TMDB.
  ///
  /// Anime is a content descriptor, not a separate catalog on TMDB, so we
  /// discover TV shows filtered by `original_language=ja` and the
  /// Animation genre (id 16). Sorted by popularity so the carousel shows
  /// what's actually hot right now.
  Future<List<MediaItem>> fetchTrendingAnime() async {
    final url = Uri.parse(
        '$_baseUrl/discover/tv?api_key=${ApiKeys.tmdbApiKey}'
        '&with_original_language=ja'
        '&with_genres=16'
        '&sort_by=popularity.desc'
        '&include_adult=false'
        '&vote_count.gte=20'
        '&page=1');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results
            .map((item) =>
                _mapResultToMediaItem(item, forcedMediaType: 'tv'))
            .toList();
      }
    } catch (e) {
      print('TMDB Trending Anime Error: $e');
    }
    return [];
  }

  /// Returns `true` if the given TMDB item represents anime, by looking
  /// at the detailed payload (which is the only place we reliably have
  /// `original_language` for TV shows). Used by the episode drawer when
  /// saving a show to the watchlist.
  Future<bool> isAnimeByTmdbId(int tmdbId, String mediaType) async {
    final details = await fetchMediaDetails(tmdbId, mediaType);
    if (details == null) return false;
    return _detectAnime(details);
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
        '$_baseUrl/trending/all/$timeWindow?api_key=${ApiKeys.tmdbApiKey}');
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
        '$_baseUrl/discover/movie?api_key=${ApiKeys.tmdbApiKey}'
        '&sort_by=popularity.desc'
        '&watch_region=$cc'
        '&with_watch_monetization_types=$monetization'
        '&region=$cc'
        '&include_adult=false'
        '&vote_count.gte=50'
        '&page=1');
    final tvUrl = Uri.parse(
        '$_baseUrl/discover/tv?api_key=${ApiKeys.tmdbApiKey}'
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

      return combined.map((item) => _mapResultToMediaItem(item)).toList();
    } catch (e) {
      print('TMDB Trending By Country Error: $e');
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

  Future<void> saveToWatchList(
    MediaItem item,
    String status,
    String userName, {
    bool? isAnimeOverride,
  }) async {
    if (userName.isEmpty) {
      print("Error saving to watch list: userName is empty");
      return;
    }
    try {
      final collection = _firestore.collection('watch_list');

      // Check if the SAME user already has this tmdbId
      final existing = await collection
          .where('tmdbId', isEqualTo: item.tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();

      // Determine the anime flag. If the caller passed an explicit override
      // (e.g. the episode drawer detected anime via /details), trust it.
      // Otherwise fall back to whatever was already on the item.
      final isAnime = isAnimeOverride ?? item.isAnime;

      if (existing.docs.isNotEmpty) {
        // Update status if exists
        await collection.doc(existing.docs.first.id).update({
          'status': status,
          'isAnime': isAnime,
          'addedAt': Timestamp.now(),
        });
      } else {
        // Create new entry scoped to this user
        await collection.add(item
            .copyWith(
              status: status,
              isAnime: isAnime,
              userName: userName,
              addedAt: DateTime.now(),
            )
            .toFirestore());
      }
      print("Saved to watch list successfully: ${item.title} ($userName)");
    } catch (e) {
      print("Error saving to watch list: $e");
    }
  }

  Future<void> removeFromWatchList(int tmdbId, String userName) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('watch_list');
      final existing = await collection
          .where('tmdbId', isEqualTo: tmdbId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
        print("Removed from watch list: $tmdbId ($userName)");
      }
    } catch (e) {
      print("Error removing from watch list: $e");
    }
  }

  /// Stream of watch list items for a specific user (Firestore-based).
  /// We filter+sort in Dart to avoid needing a composite index in Firestore.
  Stream<List<MediaItem>> getWatchListStream(String userName) {
    return _firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      // Side effect: Cache the list locally per user
      cacheWatchList(items, userName);
      return items;
    });
  }

  /// Stream of the combined watch list for the couple
  /// (khentsgdz + clairjassen), deduplicated by `tmdbId`.
  ///
  /// On the merged `MediaItem`:
  ///   - `userName` is a comma-separated list of partners who have the title
  ///     (e.g. "khentsgdz", "clairjassen", or "khentsgdz,clairjassen").
  ///   - `status` is derived from both partners' statuses so the existing
  ///     `isWatched` / `watchedDisplay` helpers keep working.
  ///
  /// The dashboard preview and the wishlist/watched tabs in the cinema
  /// screen use this for the couple so both partners see the same combined
  /// catalog with khent/clair/both attribution on each row.
  Stream<List<MediaItem>> getCoupleWatchListStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      controller.add(_mergeCoupleItems(itemsA, itemsB));
    }

    controller.onListen = () {
      subA = _firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
          .snapshots()
          .listen((snapshot) {
        itemsA = snapshot.docs
            .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
            .toList();
        emit();
      });
      subB = _firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userB)
          .snapshots()
          .listen((snapshot) {
        itemsB = snapshot.docs
            .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
            .toList();
        emit();
      });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
    };

    return controller.stream;
  }

  /// Stream of anime-only items for a single user. Same source collection
  /// (`watch_list`) as the regular stream — we filter by `isAnime == true`
  /// in Dart so the dashboard's Anime rail and the AnimeScreen only show
  /// Japanese animation, no matter where the title was added.
  Stream<List<MediaItem>> getAnimeWatchListStream(String userName) {
    return _firestore
        .collection('watch_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
          .where((i) => i.isAnime)
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return items;
    });
  }

  /// Couple-scoped stream of the anime rail. Identical shape to
  /// [getCoupleWatchListStream] but the merge keeps only items where at
  /// least one partner has `isAnime == true`. The merged item's `isAnime`
  /// is the OR of the two partner entries, so partner-aware attribution
  /// keeps working.
  Stream<List<MediaItem>> getCoupleAnimeStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    final controller = StreamController<List<MediaItem>>.broadcast();
    List<MediaItem> itemsA = const [];
    List<MediaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      final merged = _mergeCoupleItems(itemsA, itemsB);
      controller.add(merged.where((i) => i.isAnime).toList());
    }

    controller.onListen = () {
      subA = _firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userA)
          .snapshots()
          .listen((snapshot) {
        itemsA = snapshot.docs
            .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
            .toList();
        emit();
      });
      subB = _firestore
          .collection('watch_list')
          .where('userName', isEqualTo: userB)
          .snapshots()
          .listen((snapshot) {
        itemsB = snapshot.docs
            .map((doc) => MediaItem.fromFirestore(doc.data(), doc.id))
            .toList();
        emit();
      });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
    };

    return controller.stream;
  }

  /// Merges the two partners' watch lists into a single list. Items are
  /// deduplicated by `tmdbId`; when both partners have the same title the
  /// merged `userName` becomes "userA,userB" and the `status` is the
  /// strongest watched-state across the two (see [_mergeWatchedStatus]).
  static List<MediaItem> _mergeCoupleItems(
      List<MediaItem> itemsA, List<MediaItem> itemsB) {
    final byId = <int, _MergedEntry>{};
    for (final item in itemsA) {
      byId[item.tmdbId] = _MergedEntry(primary: item, partner: null);
    }
    for (final item in itemsB) {
      final existing = byId[item.tmdbId];
      if (existing == null) {
        byId[item.tmdbId] = _MergedEntry(primary: item, partner: null);
      } else {
        byId[item.tmdbId] = _MergedEntry(primary: existing.primary, partner: item);
      }
    }

    final merged = byId.values.map((entry) {
      if (entry.partner == null) return entry.primary;
      final a = entry.primary;
      final b = entry.partner!;
      final userName = '${a.userName},${b.userName}';
      final status = _mergeWatchedStatus(a.status, b.status);
      // Use the most recent addedAt so the merged item is positioned
      // correctly in the sorted list.
      final addedAt = a.addedAt.isAfter(b.addedAt) ? a.addedAt : b.addedAt;
      // Anime flag is OR-ed across partners so a title tagged as anime by
      // either partner is considered anime in the merged view.
      final isAnime = a.isAnime || b.isAnime;
      return a.copyWith(
        userName: userName,
        status: status,
        isAnime: isAnime,
        addedAt: addedAt,
      );
    }).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return merged;
  }

  /// Returns the strongest watched status across the two partners.
  ///   - both watched (any form) -> 'watched-both'
  ///   - one watched (any form) -> 'watched-khent' or 'watched-clair'
  ///   - neither -> 'to-watch'
  static String _mergeWatchedStatus(String a, String b) {
    bool isWatched(String s) =>
        s == 'watched' ||
        s == 'watched-self' ||
        s == 'watched-khent' ||
        s == 'watched-clair' ||
        s == 'watched-both';

    final aWatched = isWatched(a);
    final bWatched = isWatched(b);

    if (aWatched && bWatched) return 'watched-both';
    if (aWatched) {
      // userA == khentsgdz by convention in this method
      if (a == 'watched-clair') return 'watched-clair';
      return 'watched-khent';
    }
    if (bWatched) {
      if (b == 'watched-khent') return 'watched-khent';
      return 'watched-clair';
    }
    return 'to-watch';
  }

  /// Cache watchlist items to SharedPreferences, scoped per user.
  Future<void> cacheWatchList(List<MediaItem> items, String userName) async {
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
        'isAnime': item.isAnime,
        'userName': item.userName,
        'addedAt': item.addedAt.toIso8601String(),
      }).toList();
      await prefs.setString(_cacheKey(userName), json.encode(listJson));
    } catch (e) {
      print('Error caching watchlist: $e');
    }
  }

  /// Retrieve locally cached watchlist items for a specific user.
  Future<List<MediaItem>> getCachedWatchList(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_cacheKey(userName));
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
          isAnime: data['isAnime'] == true,
          userName: data['userName'] ?? userName,
          addedAt: DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
        )).toList();
      }
    } catch (e) {
      print('Error getting cached watchlist: $e');
    }
    return [];
  }

  /// One-time migration: backfill `userName` for legacy watch_list items that
  /// predate the per-user scoping. Heuristic by status:
  ///   - watched-clair  -> clairjassen
  ///   - watched-khent  -> khentsgdz
  ///   - watched-both / watched / to-watch -> khentsgdz (default)
  Future<int> migrateWatchListOwnership() async {
    try {
      final collection = _firestore.collection('watch_list');
      final all = await collection.get();
      int migrated = 0;
      for (final doc in all.docs) {
        final data = doc.data();
        if ((data['userName'] as String?)?.isNotEmpty == true) continue;
        final status = (data['status'] as String?) ?? 'to-watch';
        String owner;
        if (status == 'watched-clair') {
          owner = 'clairjassen';
        } else if (status == 'watched-khent') {
          owner = 'khentsgdz';
        } else {
          owner = 'khentsgdz';
        }
        await doc.reference.update({'userName': owner});
        migrated++;
      }
      if (migrated > 0) {
        print("Migrated $migrated legacy watch_list items to user-scoped ownership.");
      }
      return migrated;
    } catch (e) {
      print("Watchlist migration error: $e");
      return 0;
    }
  }

  String _cacheKey(String userName) => 'cached_watch_list::$userName';

  /// Fetch YouTube trailer key for a movie or TV show, with caching.
  Future<String?> fetchTrailerKey(int id, String mediaType) async {
    final cacheKey = '${mediaType}_$id';
    if (_trailerCache.containsKey(cacheKey)) {
      return _trailerCache[cacheKey];
    }

    final url = Uri.parse(
        '$_baseUrl/$mediaType/$id/videos?api_key=${ApiKeys.tmdbApiKey}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        // Prioritize official YouTube Trailer
        var trailer = results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer' && v['official'] == true,
          orElse: () => null,
        );
        // Fallback to any YouTube Trailer
        trailer ??= results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => null,
        );
        // Fallback to any YouTube video (Teaser, Clip, etc.)
        trailer ??= results.firstWhere(
          (v) => v['site'] == 'YouTube',
          orElse: () => null,
        );

        final key = trailer != null ? trailer['key'] as String? : null;
        _trailerCache[cacheKey] = key;
        return key;
      }
    } catch (e) {
      print('TMDB fetchTrailerKey Error: $e');
    }
    _trailerCache[cacheKey] = null;
    return null;
  }
}

/// Internal helper for [TMDBService.getCoupleWatchListStream]. Pairs the
/// primary entry with an optional partner entry when both partners have
/// the same `tmdbId`.
class _MergedEntry {
  final MediaItem primary;
  final MediaItem? partner;
  const _MergedEntry({required this.primary, this.partner});
}
