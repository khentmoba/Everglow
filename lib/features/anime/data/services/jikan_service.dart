import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import '../../../../shared/utils/catalog_proxy_client.dart';
import '../../../../core/utils/connectivity_aware.dart';
import '../../../../core/utils/logger.dart';
import '../../../cinema/data/models/media_item.dart';

class JikanService with ConnectivityAware {
  static const String _proxyBase = 'jikan';
  final CatalogProxyClient _proxy;
  final DateTime Function() _now;
  DateTime? _unavailableUntil;

  static final JikanService _instance = JikanService._internal();
  factory JikanService({CatalogProxyClient? proxy, DateTime Function()? now}) =>
      proxy == null && now == null ? _instance : JikanService._internal(proxy, now);
  JikanService._internal([CatalogProxyClient? proxy, DateTime Function()? now])
      : _proxy = proxy ?? CatalogProxyClient(), _now = now ?? DateTime.now;

  bool get _temporarilyUnavailable => _unavailableUntil?.isAfter(_now()) ?? false;

  final Queue<_JikanTask> _queue = Queue<_JikanTask>();
  bool _dispatching = false;

  static const Duration _minGap = Duration(milliseconds: 800);

  static const Duration _serverBackoff = Duration(seconds: 5);
  static const Duration _serverBackoffMax = Duration(seconds: 20);

  static const Duration _queueTaskTimeout = Duration(seconds: 40);

  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<T> _enqueue<T>(Future<T> Function() task) async {
    final completer = Completer<T>();
    _queue.add(
      _JikanTask(
        task: () async {
          try {
            final result = await task().timeout(_queueTaskTimeout);
            completer.complete(result);
          } catch (e, st) {
            completer.completeError(e, st);
          }
        },
      ),
    );
    _dispatch();
    return completer.future;
  }

  void _dispatch() {
    if (_dispatching) return;
    _dispatching = true;
    _runNext();
  }

  Future<void> _runNext() async {
    while (_queue.isNotEmpty) {
      final task = _queue.removeFirst();
      final now = DateTime.now();
      final since = now.difference(_lastCall);
      if (since < _minGap) {
        await Future.delayed(_minGap - since);
      }
      _lastCall = DateTime.now();
      try {
        await task.task();
      } catch (_) {
        // Errors are surfaced via the per-call completer in _enqueue.
      }
    }
    _dispatching = false;
  }

  Future<Map<String, dynamic>?> _getJson(
    String path, {
    Map<String, String>? params,
    int maxRetries = 3,
  }) async {
    if (_temporarilyUnavailable) return null;
    return _enqueue(() async {
      if (_temporarilyUnavailable) return null;
      var attempt = 0;
      while (true) {
        try {
          final response = await _proxy
              .get(_proxyBase, path.startsWith('/') ? path.substring(1) : path, query: params)
              .timeout(const Duration(seconds: 20));
          if (response.statusCode == 200) {
            return json.decode(response.body) as Map<String, dynamic>;
          }
          if (response.statusCode == 429 && attempt < maxRetries) {
            attempt++;
            final retryAfter = _parseRetryAfter(
              response.headers['retry-after'],
            );
            final base =
                retryAfter ??
                Duration(
                  milliseconds:
                      (_serverBackoff.inMilliseconds *
                              (1 << (attempt - 1).clamp(0, 4)))
                          .clamp(0, _serverBackoffMax.inMilliseconds),
                );
            final clamped = base > _serverBackoffMax ? _serverBackoffMax : base;
            await Future.delayed(clamped);
            continue;
          }
          Logger.e(
            '[Jikan] $path failed (${response.statusCode}): '
            '${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}',
          );
          if (response.statusCode >= 500) {
            _unavailableUntil = _now().add(const Duration(seconds: 30));
          }
          return null;
        } catch (e) {
          Logger.e('[Jikan] $path error', error: e);
          if (e is TimeoutException || e is http.ClientException) {
            _unavailableUntil = _now().add(const Duration(seconds: 30));
          }
          return null;
        }
      }
    });
  }

  Duration? _parseRetryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header);
    if (seconds != null) return Duration(seconds: seconds);
    final date = DateTime.tryParse(header);
    if (date != null) {
      final delta = date.difference(DateTime.now());
      if (delta.isNegative) return Duration.zero;
      return delta;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getJsonDirect(
    String path, {
    Map<String, String>? params,
    int maxRetries = 1,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        final response = await _proxy
            .get(_proxyBase, path.startsWith('/') ? path.substring(1) : path, query: params)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        }
        if (response.statusCode == 429 && attempt < maxRetries) {
          attempt++;
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          final base = retryAfter ?? const Duration(seconds: 2);
          final clamped = base > _serverBackoffMax ? _serverBackoffMax : base;
          await Future.delayed(clamped);
          continue;
        }
        Logger.e(
          '[Jikan][Direct] $path failed (${response.statusCode}): '
          '${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}',
        );
        return null;
      } catch (e) {
        Logger.e('[Jikan][Direct] $path error', error: e);
        return null;
      }
    }
  }

  MediaItem mapJikanToMediaItem(Map<String, dynamic> j) {
    final malId = (j['mal_id'] as num?)?.toInt() ?? 0;
    final title = (j['title_english'] as String?)?.isNotEmpty == true
        ? j['title_english'] as String
        : (j['title'] as String?) ?? 'Unknown Title';
    final images = j['images'] as Map<String, dynamic>?;
    final jpg = images?['jpg'] as Map<String, dynamic>?;
    final webp = images?['webp'] as Map<String, dynamic>?;
    String pickImage(String size) {
      final j = jpg?[size] as String?;
      if (j != null && j.isNotEmpty) return j;
      final w = webp?[size] as String?;
      if (w != null && w.isNotEmpty) return w;
      return '';
    }

    final poster = pickImage('large_image_url').isNotEmpty
        ? pickImage('large_image_url')
        : pickImage('image_url');
    final backdrop = pickImage('extra_large_image_url').isNotEmpty
        ? pickImage('extra_large_image_url')
        : poster;

    final yearVal = j['year'];
    final aired = j['aired'] as Map<String, dynamic>?;
    final airedFrom = aired?['from'] as String?;
    final year = yearVal != null
        ? yearVal.toString()
        : (airedFrom != null && airedFrom.length >= 4
              ? airedFrom.substring(0, 4)
              : '');

    final typeStr = (j['type'] as String?) ?? '';
    final mediaType = typeStr == 'Movie' ? 'movie' : 'tv';

    final studios = (j['studios'] as List?) ?? const [];
    String studioName = '';
    for (final s in studios) {
      if (s is Map && s['name'] is String) {
        studioName = s['name'] as String;
        break;
      }
    }

    final episodes = (j['episodes'] is num)
        ? (j['episodes'] as num).toInt()
        : null;

    final rawGenres = j['genres'] as List? ?? const [];
    final genres = rawGenres
        .whereType<Map<String, dynamic>>()
        .map((g) => (g['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final trailer = j['trailer'] as Map<String, dynamic>?;
    final ytId =
        (trailer?['youtube_id'] as String?) ??
        ((trailer?['url'] as String?)?.split('v=').last ?? '');
    final trailerId = (ytId.isNotEmpty && ytId != 'null') ? ytId : null;

    return MediaItem(
      id: '',
      tmdbId: malId,
      title: title,
      mediaType: mediaType,
      posterPath: poster,
      backdropPath: backdrop,
      year: year,
      status: '',
      isAnime: true,
      addedAt: DateTime.now(),
      source: 'jikan',
      synopsis: (j['synopsis'] as String?) ?? '',
      episodeCount: episodes,
      airingStatus: (j['status'] as String?) ?? '',
      format: typeStr,
      studio: studioName,
      genres: genres,
      score: (j['score'] is num) ? (j['score'] as num).toDouble() : null,
      trailerYoutubeId: trailerId,
    );
  }

  Future<List<MediaItem>> fetchSeasonNow({int page = 1, int limit = 20}) async {
    final json = await _getJson(
      '/seasons/now',
      params: {'page': '$page', 'limit': '$limit'},
    );
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
      }
    }
    return fetchTopAiring(page: page, limit: limit);
  }

  Future<List<MediaItem>> fetchUpcoming({int page = 1, int limit = 20}) async {
    final json = await _getJson(
      '/seasons/upcoming',
      params: {'page': '$page', 'limit': '$limit'},
    );
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  Future<List<MediaItem>> fetchSeason({
    required int year,
    required String season,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _getJson(
      '/seasons/$year/${Uri.encodeComponent(season)}',
      params: {'page': '$page', 'limit': '$limit'},
    );
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  Future<List<MediaItem>> fetchTopAnime({
    String type = 'tv',
    String filter = 'bypopularity',
    int page = 1,
    int limit = 20,
    String? genres,
  }) async {
    final params = <String, String>{
      'type': type,
      'filter': filter,
      'page': '$page',
      'limit': '$limit',
    };
    if (genres != null && genres.isNotEmpty) params['genres'] = genres;
    final json = await _getJson('/top/anime', params: params);
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  Future<List<MediaItem>> fetchTopAiring({int page = 1, int limit = 20}) async {
    return fetchTopAnime(
      type: 'tv',
      filter: 'airing',
      page: page,
      limit: limit,
    );
  }

  Future<List<MediaItem>> fetchHiddenGems({
    int page = 1,
    int limit = 25,
    double minScore = 7.5,
    int maxMembers = 200000,
  }) async {
    final json = await _getJson(
      '/top/anime',
      params: {'type': 'tv', 'page': '$page', 'limit': '$limit'},
    );
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    final gems = data.whereType<Map<String, dynamic>>().where((j) {
      final score = (j['score'] as num?)?.toDouble() ?? 0;
      final members = (j['members'] as num?)?.toInt() ?? 0;
      return score >= minScore && members > 0 && members <= maxMembers;
    }).toList();
    return gems.map(mapJikanToMediaItem).toList();
  }

  Future<List<MediaItem>> fetchNewReleases({
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _getJson(
      '/seasons/now',
      params: {'page': '$page', 'limit': '$limit'},
    );
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
      }
    }
    final topJson = await _getJson(
      '/top/anime',
      params: {'type': 'tv', 'page': '$page', 'limit': '$limit'},
    );
    if (topJson == null) return [];
    final topData = (topJson['data'] as List?) ?? const [];
    return topData
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map(mapJikanToMediaItem)
        .toList();
  }

  Future<List<MediaItem>> searchAnime(
    String query, {
    int page = 1,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return [];
    final json = await _getJson(
      '/anime',
      params: {
        'q': query,
        'page': '$page',
        'limit': '$limit',
        'order_by': 'popularity',
        'sort': 'desc',
      },
    );
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  Future<List<MediaItem>> searchAnimeDirect(
    String query, {
    int page = 1,
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return [];
    final json = await _getJsonDirect(
      '/anime',
      params: {
        'q': query,
        'page': '$page',
        'limit': '$limit',
        'order_by': 'popularity',
        'sort': 'desc',
      },
    );
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  Future<Map<String, dynamic>?> fetchAnimeById(int malId) async {
    return _getJson('/anime/$malId');
  }

  Future<List<MediaItem>> fetchAnimeByIds(List<int> malIds) async {
    if (malIds.isEmpty) return [];
    final json = await _getJson('/anime', params: {'ids': malIds.join(',')});
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        final items = data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
        final byId = {for (final i in items) i.tmdbId: i};
        return [
          for (final id in malIds)
            if (byId[id] != null) byId[id]!,
        ];
      }
    }
    final results = <MediaItem>[];
    for (final id in malIds) {
      final single = await fetchAnimeById(id);
      if (single != null && single['mal_id'] != null) {
        results.add(mapJikanToMediaItem(single));
      }
    }
    return results;
  }

  Future<List<MediaItem>> _fetchByGenresFallback(
    List<int> genreIds, {
    int limit = 20,
  }) async {
    final json = await _getJson(
      '/top/anime',
      params: {'type': 'tv', 'page': '1', 'limit': '50'},
    );
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    final genreSet = genreIds.toSet();
    final matched = data
        .whereType<Map<String, dynamic>>()
        .where((j) {
          final genres = j['genres'] as List? ?? const [];
          for (final g in genres) {
            if (g is Map && genreSet.contains(g['mal_id'])) return true;
          }
          return false;
        })
        .take(limit)
        .toList();
    return matched.map(mapJikanToMediaItem).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAnimeRecommendations(
    int malId,
  ) async {
    final json = await _getJson('/anime/$malId/recommendations');
    if (json == null) return const [];
    final data = (json['data'] as List?) ?? const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchAnimeEpisodes(int malId) async {
    const maxPages = 10;
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final json = await _getJson(
        '/anime/$malId/episodes',
        params: {'page': '$page'},
      );
      if (json == null) return out;
      final data = (json['data'] as List?) ?? const [];
      final entries = data.whereType<Map<String, dynamic>>().toList();
      out.addAll(entries);
      final pagination = json['pagination'] as Map<String, dynamic>?;
      final hasNext = pagination?['has_next_page'] == true;
      if (!hasNext || entries.isEmpty) break;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchAnimeReviews(int malId) async {
    const maxPages = 1;
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final json = await _getJson(
        '/anime/$malId/reviews',
        params: {'page': '$page'},
      );
      if (json == null) return out;
      final data = (json['data'] as List?) ?? const [];
      final entries = data.whereType<Map<String, dynamic>>().toList();
      out.addAll(entries);
      final pagination = json['pagination'] as Map<String, dynamic>?;
      final hasNext = pagination?['has_next_page'] == true;
      if (!hasNext || entries.isEmpty) break;
    }
    return out;
  }

  Future<List<MediaItem>> fetchByGenres(
    List<int> genreIds, {
    int page = 1,
    int limit = 20,
  }) async {
    if (genreIds.isEmpty) return [];
    final json = await _getJson(
      '/anime',
      params: {
        'genres': genreIds.join(','),
        'page': '$page',
        'limit': '$limit',
        'order_by': 'score',
        'sort': 'desc',
      },
    );
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
      }
    }
    return _fetchByGenresFallback(genreIds, limit: limit);
  }

  static const Map<int, String> malGenres = {
    1: 'Action',
    2: 'Adventure',
    4: 'Comedy',
    7: 'Mystery',
    8: 'Drama',
    10: 'Fantasy',
    13: 'Historical',
    14: 'Horror',
    18: 'Mecha',
    19: 'Music',
    22: 'Romance',
    24: 'Sci-Fi',
    27: 'Shounen',
    30: 'Sports',
    36: 'Slice of Life',
    37: 'Supernatural',
    40: 'Psychological',
    41: 'Thriller',
    42: 'Seinen',
    43: 'Josei',
  };
}

class _JikanTask {
  final Future<void> Function() task;
  _JikanTask({required this.task});
}
