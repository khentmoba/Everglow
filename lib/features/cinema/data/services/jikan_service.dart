import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/core/utils/error_aware.dart';
import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

/// REST client for the Jikan v4 API (an unofficial MyAnimeList mirror).
///
/// Used by the Everglow Anime feature for browse, search, and discovery
/// (Trending Now, Currently Airing, Top Rated, By Genre, etc.). Detail-page
/// enrichment (synopsis, characters + VAs, staff, relations) is served by
/// [AniListService] because AniList's GraphQL endpoint returns richer,
/// anime-specific metadata in a single round-trip.
///
/// Jikan is rate-limited to 30 requests per minute on the public API. To
/// stay under the limit, this service serializes every outbound request
/// through a FIFO queue and adds a small gap between calls. When the
/// queue head gets a `429`, we back off for the duration the response
/// asks for and then resume.
class JikanService with ConnectivityAware, ErrorAware {
  static const String _baseUrl = 'https://api.jikan.moe/v4';

  // Singleton — same lifetime as TMDBService so the queue is shared
  // between the anime screen, the search modal, and the episode drawer.
  static final JikanService _instance = JikanService._internal();
  factory JikanService() => _instance;
  JikanService._internal();

  /// Serial FIFO queue of pending request tasks. Every public method
  /// appends a [JikanTask] here and waits for its completion. Tasks run
  /// one-at-a-time so we never fire two requests simultaneously.
  final Queue<_JikanTask> _queue = Queue<_JikanTask>();
  bool _dispatching = false;

  /// Minimum gap between two requests. Jikan's documented limit is 60
  /// req/min plus a burst guard, so 800ms (~75 req/min ceiling) gives
  /// a ~25% safety margin and keeps the queue under the 429 cliff
  /// during Editor's Picks / per-episode fan-outs.
  static const Duration _minGap = Duration(milliseconds: 800);

  /// How long to back off when the server returns 429. The first 429
  /// uses this; subsequent consecutive 429s double the wait up to a
  /// cap of [_serverBackoffMax] so a single bad burst doesn't keep the
  /// queue dead for half a minute.
  static const Duration _serverBackoff = Duration(seconds: 5);
  static const Duration _serverBackoffMax = Duration(seconds: 20);

  /// Maximum time a single task can hold the queue. If a request hangs
  /// (e.g. network black hole, infinite retry loop) the queue moves on
  /// so subsequent calls — especially user-facing search — aren't stuck.
  static const Duration _queueTaskTimeout = Duration(seconds: 40);

  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<T> _enqueue<T>(Future<T> Function() task) async {
    final completer = Completer<T>();
    _queue.add(_JikanTask(task: () async {
      try {
        // Wrap the task in a timeout so a stuck HTTP call can't block
        // the queue indefinitely. When the timeout fires the queue
        // continues to the next task and the caller gets a null result.
        final result = await task().timeout(_queueTaskTimeout);
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }));
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
      // Enforce a minimum gap between calls.
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

  /// Performs a GET against the Jikan v4 API. Returns the raw decoded JSON
  /// map, or null on a non-200 / network error. On 429 we back off
  /// exponentially (5s, 10s, 20s) up to [_serverBackoffMax] and respect
  /// the server's `Retry-After` header when present.
  Future<Map<String, dynamic>?> _getJson(String path,
      {Map<String, String>? params, int maxRetries = 3}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    // Jikan strongly recommends a custom User-Agent to avoid aggressive
    // rate-limiting. The Accept header ensures we always request JSON.
    const headers = <String, String>{
      'User-Agent': 'Everglow/5.3 (anime; +https://everglow.app)',
      'Accept': 'application/json',
    };
    return _enqueue(() async {
      var attempt = 0;
      while (true) {
        try {
          final response = await http.get(uri, headers: headers).timeout(
                const Duration(seconds: 20),
              );
          if (response.statusCode == 200) {
            return json.decode(response.body) as Map<String, dynamic>;
          }
          if (response.statusCode == 429 && attempt < maxRetries) {
            attempt++;
            // Prefer the server's Retry-After, else grow exponentially
            // from [_serverBackoff] up to [_serverBackoffMax] so a
            // single sustained burst doesn't keep the queue dead.
            final retryAfter = _parseRetryAfter(response.headers['retry-after']);
            final base = retryAfter ??
                Duration(
                  milliseconds: (_serverBackoff.inMilliseconds *
                          (1 << (attempt - 1).clamp(0, 4)))
                      .clamp(0, _serverBackoffMax.inMilliseconds),
                );
            final clamped = base > _serverBackoffMax ? _serverBackoffMax : base;
            await Future.delayed(clamped);
            continue;
          }
          Logger.e('[Jikan] $path failed (${response.statusCode}): '
              '${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}');
          return null;
        } catch (e) {
          Logger.e('[Jikan] $path error', error: e);
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

  /// Same as [_getJson] but bypasses the rate-limit queue entirely.
  ///
  /// Use this for user-facing operations (search in particular) that
  /// must not be blocked by a backed-up queue from carousel preloads.
  /// The caller is responsible for not flooding Jikan — this should only
  /// be called for one-shot user interactions, not bulk fan-out.
  Future<Map<String, dynamic>?> _getJsonDirect(String path,
      {Map<String, String>? params, int maxRetries = 1}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    const headers = <String, String>{
      'User-Agent': 'Everglow/5.3 (anime; +https://everglow.app)',
      'Accept': 'application/json',
    };
    var attempt = 0;
    while (true) {
      try {
        final response = await http.get(uri, headers: headers).timeout(
              const Duration(seconds: 10),
            );
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
        Logger.e('[Jikan][Direct] $path failed (${response.statusCode}): '
            '${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}');
        return null;
      } catch (e) {
        Logger.e('[Jikan][Direct] $path error', error: e);
        return null;
      }
    }
  }

  /// Maps a single Jikan anime data block to a [MediaItem]. We set
  /// `tmdbId` to the MAL id so the existing watchlist's unique-by-`tmdbId`
  /// deduplication still works for anime. `source` is tagged `'jikan'`
  /// so the [EpisodeDrawer] knows to route to [AniListService] for the
  /// detail page.
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
    // Jikan's type maps loosely to TMDB's mediaType so the existing
    // Movie vs TV branching in the episode drawer still makes sense.
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
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API — used by the anime screen, search modal, and
  //  episode drawer. All methods return decoded Jikan data so
  //  callers don't pay an extra mapping step when they want raw
  //  payloads (e.g. the episode drawer reading /anime/{id}/episodes).
  // ─────────────────────────────────────────────────────────────

  /// Anime that are currently airing this season.
  ///
  /// Falls back to [`fetchTopAiring`] when the `/seasons/now` endpoint
  /// is unavailable (a common Jikan degradation pattern), so the
  /// "Currently Airing" Browse chip still returns results.
  Future<List<MediaItem>> fetchSeasonNow({int page = 1, int limit = 20}) async {
    final json = await _getJson('/seasons/now', params: {
      'page': '$page',
      'limit': '$limit',
    });
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
      }
    }
    // /seasons/now empty or errored – fall back to the airing filter on
    // the more reliable /top/anime endpoint.
    return fetchTopAiring(page: page, limit: limit);
  }

  /// Upcoming anime (next season + later).
  Future<List<MediaItem>> fetchUpcoming({int page = 1, int limit = 20}) async {
    final json = await _getJson('/seasons/upcoming', params: {
      'page': '$page',
      'limit': '$limit',
    });
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  /// A specific historical season (e.g. `year=2024, season='spring'`).
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

  /// Top anime with optional type / filter narrowing.
  ///
  /// `type` is one of: `tv`, `movie`, `ova`, `special`, `ona`, `music`.
  /// `filter` is one of: `airing`, `upcoming`, `bypopularity`, `favorite`.
  /// `genres` is a comma-separated list of MAL genre ids.
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

  /// Currently-airing anime sorted by score, used for the "Top Rated"
  /// home rail. We use the `airing` filter so only shows that are
  /// actively airing compete in the ranking.
  Future<List<MediaItem>> fetchTopAiring({int page = 1, int limit = 20}) async {
    return fetchTopAnime(
      type: 'tv',
      filter: 'airing',
      page: page,
      limit: limit,
    );
  }

  /// High-rated anime with limited popularity — the "hidden gems" rail.
  /// Jikan doesn't expose a score-floor filter directly, so we apply it
  /// in Dart after the page comes back. We pull a slightly larger page
  /// than requested so the user still gets a full row of gems.
  Future<List<MediaItem>> fetchHiddenGems({
    int page = 1,
    int limit = 25,
    double minScore = 7.5,
    int maxMembers = 200000,
  }) async {
    final json = await _getJson('/top/anime', params: {
      'type': 'tv',
      'page': '$page',
      'limit': '$limit',
    });
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    final gems = data.whereType<Map<String, dynamic>>().where((j) {
      final score = (j['score'] as num?)?.toDouble() ?? 0;
      final members = (j['members'] as num?)?.toInt() ?? 0;
      return score >= minScore && members > 0 && members <= maxMembers;
    }).toList();
    return gems.map(mapJikanToMediaItem).toList();
  }

  /// "New Releases" rail. Fetches the most recent season + next season
  /// and returns anime that started airing recently. Falls back to the
  /// top-anime endpoint with a generous member filter when seasons fail.
  Future<List<MediaItem>> fetchNewReleases({int page = 1, int limit = 20}) async {
    // Try current season first — this is the most reliable source for
    // genuinely new releases.
    final json = await _getJson('/seasons/now', params: {
      'page': '$page',
      'limit': '$limit',
    });
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
      }
    }
    // Current season empty — try recent top anime with a generous
    // member threshold so we actually get results.
    final topJson = await _getJson('/top/anime', params: {
      'type': 'tv',
      'page': '$page',
      'limit': '$limit',
    });
    if (topJson == null) return [];
    final topData = (topJson['data'] as List?) ?? const [];
    return topData
        .whereType<Map<String, dynamic>>()
        .take(limit)
        .map(mapJikanToMediaItem)
        .toList();
  }

  /// Search anime by free-text query. We rely on the standard `q` param
  /// and return the first page of results (limit capped at 25 to keep
  /// the search modal snappy).
  Future<List<MediaItem>> searchAnime(String query,
      {int page = 1, int limit = 25}) async {
    if (query.trim().isEmpty) return [];
    final json = await _getJson('/anime', params: {
      'q': query,
      'page': '$page',
      'limit': '$limit',
      'order_by': 'popularity',
      'sort': 'desc',
    });
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  /// Same as [searchAnime] but bypasses the shared rate-limit queue.
  ///
  /// Use this for user-facing search where responsiveness matters —
  /// the main queue may be backed up by carousel preloads (Trending Now,
  /// Currently Airing, etc.) and we don't want the search modal to feel
  /// stuck. The caller should still handle null/empty gracefully since
  /// Jikan's /anime search endpoint is less reliable than AniList.
  Future<List<MediaItem>> searchAnimeDirect(String query,
      {int page = 1, int limit = 25}) async {
    if (query.trim().isEmpty) return [];
    final json = await _getJsonDirect('/anime', params: {
      'q': query,
      'page': '$page',
      'limit': '$limit',
      'order_by': 'popularity',
      'sort': 'desc',
    });
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(mapJikanToMediaItem)
        .toList();
  }

  /// Fetch the full MAL/Jikan record for one anime (used as a fallback
  /// by the episode drawer if AniList can't be reached).
  Future<Map<String, dynamic>?> fetchAnimeById(int malId) async {
    return _getJson('/anime/$malId');
  }

  /// Batched lookup for up to 25 MAL ids in a single call. Jikan's
  /// `/anime` endpoint accepts a comma-separated `ids=` parameter, which
  /// collapses the 21-way fan-out of the Editor's Picks into one HTTP
  /// request and one queue slot. The endpoint returns the entries in
  /// the same order as the input; missing ids are silently dropped, so
  /// we re-align by `mal_id` to be safe.
  ///
  /// Falls back to fetching the anime [`one-by-one`][fetchAnimeById] when
  /// the `/anime?ids=` batch endpoint fails, so Editor's Picks still
  /// renders even during partial Jikan outages.
  Future<List<MediaItem>> fetchAnimeByIds(List<int> malIds) async {
    if (malIds.isEmpty) return [];
    final json = await _getJson('/anime', params: {
      'ids': malIds.join(','),
    });
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
    // Batch endpoint failed – fetch each id individually so the
    // curated list still populates even during a partial outage.
    final results = <MediaItem>[];
    for (final id in malIds) {
      final single = await fetchAnimeById(id);
      if (single != null && single['mal_id'] != null) {
        results.add(mapJikanToMediaItem(single));
      }
    }
    return results;
  }

  /// Fallback: fetch a large batch from `/top/anime` and filter entries whose
  /// genre list includes at least one of [genreIds]. Used when the primary
  /// `/anime?genres=...` endpoint fails (common when Jikan's backend is
  /// degraded but its Cloudflare cache for `/top/anime` still serves).
  Future<List<MediaItem>> _fetchByGenresFallback(
    List<int> genreIds, {
    int limit = 20,
  }) async {
    // Pull a bigger page so genre filtering doesn't leave us with 0 items.
    final json = await _getJson('/top/anime', params: {
      'type': 'tv',
      'page': '1',
      'limit': '50',
    });
    if (json == null) return [];
    final data = (json['data'] as List?) ?? const [];
    final genreSet = genreIds.toSet();
    final matched = data.whereType<Map<String, dynamic>>().where((j) {
      final genres = j['genres'] as List? ?? const [];
      for (final g in genres) {
        if (g is Map && genreSet.contains(g['mal_id'])) return true;
      }
      return false;
    }).take(limit).toList();
    return matched.map(mapJikanToMediaItem).toList();
  }

  /// Jikan's user-recommendation rail for an anime
  /// (`/anime/{id}/recommendations`). Used as a fallback when AniList's
  /// `relations` + `recommendations` come back empty (which happens for
  /// most niche shows). Returns the raw Jikan envelope entries — the
  /// caller maps them into [MediaItem].
  Future<List<Map<String, dynamic>>> fetchAnimeRecommendations(int malId) async {
    final json = await _getJson('/anime/$malId/recommendations');
    if (json == null) return const [];
    final data = (json['data'] as List?) ?? const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Per-episode list (titles, air dates, durations) for an anime from
  /// Jikan's `/anime/{id}/episodes` endpoint. Episodes come back in
  /// airing order with `mal_id` set to the in-show episode number.
  ///
  /// Note that Jikan v4 dropped the per-episode `synopsis` field that
  /// v3 used to expose — that column is intentionally absent here.
  /// `title_japanese` and `title_romanji` are also returned by Jikan but
  /// we keep the envelope raw so the caller can pick the best title
  /// variant for its UI.
  ///
  /// The endpoint is paginated (100 per page) and we walk the pages
  /// internally up to a cap so long-running shows (One Piece, Naruto)
  /// come back complete without the caller having to manage pages.
  Future<List<Map<String, dynamic>>> fetchAnimeEpisodes(int malId) async {
    const maxPages = 10; // 10 * 100 = 1000 episodes, more than enough.
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final json = await _getJson('/anime/$malId/episodes', params: {
        'page': '$page',
      });
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

  /// User-submitted reviews for an anime, fetched from Jikan's
  /// `/anime/{id}/reviews` endpoint. Returns the raw Jikan envelope
  /// entries so the caller can pick the fields it cares about. We
  /// fetch one page (25 reviews) which is more than the episode
  /// drawer needs (it caps at 8).
  ///
  /// Going through [_getJson] means the call respects the rate-limit
  /// queue and exponential backoff — the previous direct `http.get`
  /// path used by the episode drawer would routinely get 429'd during
  /// the Editor's Picks fan-out.
  Future<List<Map<String, dynamic>>> fetchAnimeReviews(int malId) async {
    const maxPages = 1;
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final json = await _getJson('/anime/$malId/reviews', params: {
        'page': '$page',
      });
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

  /// Anime that share at least one MAL genre with the given title.
  /// Uses the simple Jikan `/anime` search-with-genre endpoint, then
  /// sorts by popularity in Dart. `genreIds` is a list of MAL genre ids
  /// (e.g. `[1, 10]` for Action + Fantasy).
  ///
  /// If the primary endpoint fails (Jikan's `/anime` endpoint is often
  /// less reliable than `/top/anime`) we fall back to filtering a larger
  /// `/top/anime` batch by genre client-side so the Browse tab never
  /// silently shows "No matches".
  Future<List<MediaItem>> fetchByGenres(
    List<int> genreIds, {
    int page = 1,
    int limit = 20,
  }) async {
    if (genreIds.isEmpty) return [];
    final json = await _getJson('/anime', params: {
      'genres': genreIds.join(','),
      'page': '$page',
      'limit': '$limit',
      'order_by': 'score',
      'sort': 'desc',
    });
    if (json != null) {
      final data = (json['data'] as List?) ?? const [];
      if (data.isNotEmpty) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(mapJikanToMediaItem)
            .toList();
      }
    }
    // Primary endpoint returned empty or errored – fall back to
    // client-side genre filtering from the (more reliable) top-anime list.
    return _fetchByGenresFallback(genreIds, limit: limit);
  }

  /// Full MAL genre list, used by the Browse tab to render the genre
  /// picker. Returns a map of `malGenreId -> name`. We hardcode the
  /// common anime genres so we don't have to make a network call just
  /// to render chips.
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
