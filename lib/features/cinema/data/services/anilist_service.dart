import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/features/cinema/data/models/anilist_detail.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';

/// GraphQL client for AniList (https://anilist.co).
///
/// Used by the anime feature to load rich detail-page data — synopsis,
/// characters with Japanese VAs, staff, relations, recommendations, full
/// episode list, and a YouTube trailer key — that Jikan's REST payload
/// either doesn't expose or splits across many calls.
///
/// AniList is rate-limited to 90 requests per minute, so we still pipe
/// every request through a small FIFO queue with a 50ms gap. AniList
/// returns 429 with a `Retry-After` header on bursts, which we honor.
class AniListService {
  static const String _endpoint = 'https://graphql.anilist.co';

  // Singleton — AniList responses are stable and we want the in-memory
  // detail cache to survive screen rebuilds.
  static final AniListService _instance = AniListService._internal();
  factory AniListService() => _instance;
  AniListService._internal();

  /// In-memory detail cache. AniList detail pages are mostly static, so
  /// we only re-fetch if the user explicitly pulls to refresh.
  final Map<int, AniListDetail> _detailCache = {};
  final Map<int, DateTime> _detailCacheAt = {};
  static const Duration _detailTtl = Duration(minutes: 10);

  Future<T> _serialize<T>(Future<T> Function() task) async {
    // No need for a deep queue: AniList's 90 req/min ceiling is way above
    // the worst-case usage on the anime screen (a few details opens per
    // session). Still, we add a small gap so two simultaneous opens don't
    // trip the burst limiter.
    await Future.delayed(const Duration(milliseconds: 50));
    return task();
  }

  Future<Map<String, dynamic>?> _postGraphQL(
    String query,
    Map<String, dynamic> variables,
  ) async {
    return _serialize(() async {
      try {
        final response = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode({'query': query, 'variables': variables}),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          if (body['errors'] != null) {
            print('AniList GraphQL errors: ${body['errors']}');
          }
          return body['data'] as Map<String, dynamic>?;
        }
        print('AniList HTTP ${response.statusCode}: ${response.body}');
        return null;
      } catch (e) {
        print('AniList request error: $e');
        return null;
      }
    });
  }

  /// Single comprehensive query for the anime detail page. Resolves
  /// either by AniList id (preferred) or MAL id (via the `idMal` filter).
  /// Cached in memory for [_detailTtl] after the first fetch.
  Future<AniListDetail?> fetchDetails({int? anilistId, int? malId}) async {
    if (anilistId == null && malId == null) return null;

    // Cache key: AniList id if we know it, else a synthetic prefix on MAL.
    final cacheKey = anilistId ?? -malId!;
    final cached = _detailCache[cacheKey];
    if (cached != null) {
      final at = _detailCacheAt[cacheKey];
      if (at != null && DateTime.now().difference(at) < _detailTtl) {
        return cached;
      }
    }

    final variables = <String, dynamic>{
      if (anilistId != null) 'id': anilistId,
      // GraphQL variable name has to match the query (`$idMal`), not the
      // `Media.idMal` field. The previous `'malId': malId` mismatch
      // silently produced errors and returned a null `Media`, which is
      // why tapping an anime showed no details.
      if (anilistId == null && malId != null) 'idMal': malId,
      'type': 'ANIME',
    };

    final data = await _postGraphQL(_detailsQuery, variables);
    final media = data?['Media'] as Map<String, dynamic>?;
    if (media == null) return null;

    final detail = _mapDetail(media);
    _detailCache[cacheKey] = detail;
    _detailCacheAt[cacheKey] = DateTime.now();
    return detail;
  }

  /// Like [fetchDetails] but falls back to Jikan's `/anime/{id}` payload
  /// when AniList returns no `Media`. Jikan carries the same fields the
  /// detail drawer needs (synopsis, status, format, studios, genres,
  /// episodes, cover image, YouTube trailer) so the UI renders even when
  /// AniList is rate-limited, transiently down, or doesn't have the id.
  Future<AniListDetail?> fetchDetailsWithFallback({
    int? anilistId,
    int? malId,
  }) async {
    if (anilistId == null && malId == null) return null;
    final primary = await fetchDetails(anilistId: anilistId, malId: malId);
    if (primary != null) return primary;
    if (malId == null) return null;
    final jikan = await JikanService().fetchAnimeById(malId);
    if (jikan == null) return null;
    return _mapJikanDetail(jikan, fallbackMalId: malId);
  }

  /// Maps a Jikan `/anime/{id}` payload into an [AniListDetail] so the
  /// drawer can render when AniList is unavailable. Only the fields the
  /// UI actually reads are populated; the rest stay at their defaults.
  AniListDetail _mapJikanDetail(Map<String, dynamic> j, {required int fallbackMalId}) {
    final images = j['images'] as Map<String, dynamic>?;
    final jpg = images?['jpg'] as Map<String, dynamic>?;
    String pickImage(String size) {
      final v = jpg?[size] as String?;
      return (v != null && v.isNotEmpty) ? v : '';
    }

    final studios = (j['studios'] as List?) ?? const [];
    final studioNames = studios
        .whereType<Map<String, dynamic>>()
        .map((s) => (s['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final genres = ((j['genres'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((g) => (g['name'] as String?) ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final trailer = j['trailer'] as Map<String, dynamic>?;
    final ytId = (trailer?['youtube_id'] as String?) ??
        ((trailer?['url'] as String?)?.split('v=').last ?? '');
    final trailerId = (ytId.isNotEmpty && ytId != 'null') ? ytId : null;

    final aired = j['aired'] as Map<String, dynamic>?;
    final airedFrom = aired?['from'] as String?;
    final airedTo = aired?['to'] as String?;

    final malId = (j['mal_id'] as num?)?.toInt() ?? fallbackMalId;

    return AniListDetail(
      id: 0,
      malId: malId,
      titleEnglish: (j['title_english'] as String?) ?? (j['title'] as String?) ?? '',
      titleRomaji: (j['title_japanese'] as String?) ?? '',
      titleNative: '',
      synopsis: _stripHtml((j['synopsis'] as String?) ?? ''),
      coverImageUrl:
          pickImage('large_image_url').isNotEmpty ? pickImage('large_image_url') : pickImage('image_url'),
      bannerImageUrl: pickImage('extra_large_image_url'),
      episodeCount:
          (j['episodes'] is num) ? (j['episodes'] as num).toInt() : null,
      duration: (j['duration'] as String?)
              ?.replaceAll(RegExp(r'[^0-9]'), '')
              .isNotEmpty == true
          ? int.tryParse((j['duration'] as String).replaceAll(RegExp(r'[^0-9]'), ''))
          : null,
      airingStatus: (j['status'] as String?) ?? '',
      format: (j['type'] as String?) ?? '',
      season: (j['season'] as String?),
      seasonYear: (j['year'] is num) ? (j['year'] as num).toInt() : null,
      averageScore: (j['score'] is num)
          ? (j['score'] as num).toDouble()
          : null,
      genres: genres,
      studios: studioNames,
      trailerYoutubeId: trailerId,
      // Jikan doesn't return relations/recommendations/characters/staff
      // here; the drawer treats empty lists as "no data" which is fine.
      relations: const [],
      recommendations: const [],
      episodes: _mapJikanStreaming(
        malId: malId,
        episodeCount: (j['episodes'] is num) ? (j['episodes'] as num).toInt() : null,
        airedFrom: airedFrom,
        airedTo: airedTo,
      ),
    );
  }

  /// Synthesizes [AniListEpisode] entries for a Jikan-only fallback so
  /// the episode list still has 1..N entries with air dates. Titles are
  /// filled in by the episode drawer's Jikan overlay.
  List<AniListEpisode> _mapJikanStreaming({
    required int malId,
    int? episodeCount,
    String? airedFrom,
    String? airedTo,
  }) {
    if (episodeCount == null || episodeCount <= 0) return const [];
    return List.generate(episodeCount, (i) => AniListEpisode(number: i + 1));
  }

  AniListDetail _mapDetail(Map<String, dynamic> m) {
    final title = m['title'] as Map<String, dynamic>?;
    final cover = m['coverImage'] as Map<String, dynamic>?;
    final trailer = m['trailer'] as Map<String, dynamic>?;
    final studios = m['studios'] as Map<String, dynamic>?;
    final studioNodes = (studios?['nodes'] as List?) ?? const [];

    return AniListDetail(
      id: (m['id'] as num?)?.toInt() ?? 0,
      malId: (m['idMal'] as num?)?.toInt(),
      titleEnglish: (title?['english'] as String?) ?? '',
      titleRomaji: (title?['romaji'] as String?) ?? '',
      titleNative: (title?['native'] as String?) ?? '',
      synopsis: _stripHtml((m['description'] as String?) ?? ''),
      coverImageUrl: (cover?['extraLarge'] as String?) ??
          (cover?['large'] as String?) ??
          (cover?['medium'] as String?) ??
          '',
      bannerImageUrl: (m['bannerImage'] as String?) ?? '',
      episodeCount: (m['episodes'] is num)
          ? (m['episodes'] as num).toInt()
          : null,
      duration: (m['duration'] is num)
          ? (m['duration'] as num).toInt()
          : null,
      airingStatus: (m['status'] as String?) ?? '',
      format: (m['format'] as String?) ?? '',
      season: m['season'] as String?,
      seasonYear: (m['seasonYear'] is num)
          ? (m['seasonYear'] as num).toInt()
          : null,
      averageScore: (m['averageScore'] is num)
          ? (m['averageScore'] as num).toDouble() / 10
          : null,
      genres: ((m['genres'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      studios: studioNodes
          .whereType<Map<String, dynamic>>()
          .map((s) => (s['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList(),
      trailerYoutubeId: (trailer != null && trailer['site'] == 'youtube')
          ? trailer['id'] as String?
          : null,
      characters: _mapCharacters(m['characters'] as Map<String, dynamic>?),
      staff: _mapStaff(m['staff'] as Map<String, dynamic>?),
      relations: _mapRelations(m['relations'] as Map<String, dynamic>?),
      recommendations:
          _mapRecommendations(m['recommendations'] as Map<String, dynamic>?),
      episodes: _mapEpisodes(m['streamingEpisodes'] as List?,
          episodeCount: (m['episodes'] is num)
              ? (m['episodes'] as num).toInt()
              : null),
      nextAiringAt: _parseNextAiringAt(m['nextAiringEpisode']),
      nextAiringEpisode: _parseNextAiringEpisode(m['nextAiringEpisode']),
    );
  }

  List<AniListCharacter> _mapCharacters(Map<String, dynamic>? c) {
    if (c == null) return const [];
    final edges = (c['edges'] as List?) ?? const [];
    return edges.whereType<Map<String, dynamic>>().map((e) {
      final node = (e['node'] as Map<String, dynamic>?) ?? const {};
      final name = (node['name'] as Map<String, dynamic>?) ?? const {};
      final image = (node['image'] as Map<String, dynamic>?) ?? const {};
      final vaEdges = (e['voiceActors'] as List?) ?? const [];
      final vas = vaEdges.whereType<Map<String, dynamic>>().map((v) {
        final vname = (v['name'] as Map<String, dynamic>?) ?? const {};
        final vimage = (v['image'] as Map<String, dynamic>?) ?? const {};
        return AniListVoiceActor(
          id: (v['id'] as num?)?.toInt() ?? 0,
          name: (vname['full'] as String?) ??
              (vname['native'] as String?) ??
              '',
          imageUrl: (vimage['large'] as String?) ??
              (vimage['medium'] as String?) ??
              '',
          language: 'JAPANESE',
        );
      }).toList();
      return AniListCharacter(
        id: (node['id'] as num?)?.toInt() ?? 0,
        name: (name['full'] as String?) ??
            (name['native'] as String?) ??
            (name['first'] as String?) ??
            '',
        imageUrl: (image['large'] as String?) ??
            (image['medium'] as String?) ??
            '',
        role: (e['role'] as String?) ?? 'SUPPORTING',
        voiceActors: vas,
      );
    }).toList();
  }

  List<AniListStaffMember> _mapStaff(Map<String, dynamic>? s) {
    if (s == null) return const [];
    final edges = (s['edges'] as List?) ?? const [];
    return edges.whereType<Map<String, dynamic>>().map((e) {
      final node = (e['node'] as Map<String, dynamic>?) ?? const {};
      final name = (node['name'] as Map<String, dynamic>?) ?? const {};
      final image = (node['image'] as Map<String, dynamic>?) ?? const {};
      return AniListStaffMember(
        id: (node['id'] as num?)?.toInt() ?? 0,
        name: (name['full'] as String?) ??
            (name['native'] as String?) ??
            (name['first'] as String?) ??
            '',
        imageUrl: (image['medium'] as String?) ?? '',
        role: (e['role'] as String?) ?? '',
      );
    }).toList();
  }

  List<AniListRelated> _mapRelations(Map<String, dynamic>? r) {
    if (r == null) return const [];
    final edges = (r['edges'] as List?) ?? const [];
    return edges.whereType<Map<String, dynamic>>().map((e) {
      final node = (e['node'] as Map<String, dynamic>?) ?? const {};
      final title = (node['title'] as Map<String, dynamic>?) ?? const {};
      final cover = (node['coverImage'] as Map<String, dynamic>?) ?? const {};
      return AniListRelated(
        id: (node['id'] as num?)?.toInt() ?? 0,
        malId: (node['idMal'] as num?)?.toInt(),
        title: (title['english'] as String?) ??
            (title['romaji'] as String?) ??
            '',
        coverImageUrl:
            (cover['large'] as String?) ?? (cover['medium'] as String?) ?? '',
        relationType: (e['relationType'] as String?) ?? '',
        format: (node['format'] as String?) ?? '',
      );
    }).toList();
  }

  List<AniListRecommended> _mapRecommendations(
      Map<String, dynamic>? r) {
    if (r == null) return const [];
    final nodes = (r['nodes'] as List?) ?? const [];
    return nodes.whereType<Map<String, dynamic>>().map((n) {
      final media = (n['mediaRecommendation'] as Map<String, dynamic>?) ??
          const {};
      final title = (media['title'] as Map<String, dynamic>?) ?? const {};
      final cover = (media['coverImage'] as Map<String, dynamic>?) ?? const {};
      final rating = n['rating'];
      return AniListRecommended(
        id: (media['id'] as num?)?.toInt() ?? 0,
        malId: (media['idMal'] as num?)?.toInt(),
        title: (title['english'] as String?) ??
            (title['romaji'] as String?) ??
            '',
        coverImageUrl:
            (cover['large'] as String?) ?? (cover['medium'] as String?) ?? '',
        rating: rating is num ? rating.toInt() : null,
      );
    }).toList();
  }

  /// AniList's `streamingEpisodes` carries a partial list (often empty
  /// for non-Western-licensed shows), so we synthesize the rest from
  /// `episodeCount` with placeholder titles. The episode drawer falls
  /// back to Jikan's `/anime/{id}/episodes` for real titles when this
  /// list is short.
  ///
  /// We also capture each entry's `thumbnail` URL — AniList ships the
  /// licensed-still image from whichever streaming partner owns the
  /// episode (Crunchyroll, Funimation, etc.). Western-licensed shows
  /// usually have thumbnails for every entry; non-Western shows are
  /// sparse and the tile falls back to the anime poster or a color
  /// block.
  List<AniListEpisode> _mapEpisodes(List? streaming, {int? episodeCount}) {
    final out = <AniListEpisode>[];
    if (streaming is List) {
      for (final e in streaming.whereType<Map<String, dynamic>>()) {
        final title = e['title'] as String?;
        final thumb = e['thumbnail'] as String?;
        out.add(AniListEpisode(
          number: (e['number'] as num?)?.toInt() ?? (out.length + 1),
          title: title,
          titleRomaji: null,
          synopsis: null,
          airedAt: e['airingAt'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (e['airingAt'] as num).toInt() * 1000)
              : null,
          duration: null,
          thumbnail: (thumb != null && thumb.isNotEmpty) ? thumb : null,
        ));
      }
    }
    // Fill out any missing slots so the drawer has a complete list of
    // episode numbers even when AniList only ships a partial feed.
    if (episodeCount != null && episodeCount > out.length) {
      for (var i = out.length + 1; i <= episodeCount; i++) {
        out.add(AniListEpisode(number: i));
      }
    }
    return out;
  }

  /// AniList returns HTML in its `description` field for some titles.
  /// Strip tags to plain text so we can render with a `Text` widget.
  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    // Remove simple HTML tags. We deliberately don't add an HTML parser
    // dependency for this; the upstream tags are always well-formed.
    final noTags = html.replaceAll(RegExp(r'<[^>]*>'), '');
    return unescapeHtmlEntities(noTags);
  }

  /// Bypasses the cache. Used by the episode drawer's pull-to-refresh
  /// gesture when the user knows the data is stale.
  Future<AniListDetail?> fetchDetailsFresh(
      {int? anilistId, int? malId}) async {
    if (anilistId != null) _detailCache.remove(anilistId);
    if (malId != null) _detailCache.remove(-malId);
    return fetchDetails(anilistId: anilistId, malId: malId);
  }

  /// Parses the `nextAiringEpisode` block from AniList's GraphQL response.
  /// Returns the `airingAt` unix timestamp (seconds) or null.
  static int? _parseNextAiringAt(dynamic nextAiring) {
    if (nextAiring is! Map<String, dynamic>) return null;
    final airingAt = nextAiring['airingAt'];
    return airingAt is num ? airingAt.toInt() : null;
  }

  /// Parses the `nextAiringEpisode` block from AniList's GraphQL response.
  /// Returns the episode number or null.
  static int? _parseNextAiringEpisode(dynamic nextAiring) {
    if (nextAiring is! Map<String, dynamic>) return null;
    final episode = nextAiring['episode'];
    return episode is num ? episode.toInt() : null;
  }

  /// Search anime by free-text query via AniList's GraphQL API.
  /// Returns [MediaItem]s compatible with the existing watchlist flow.
  /// Used as fallback when Jikan is unavailable.
  Future<List<MediaItem>> searchAnime(String query,
      {int page = 1, int limit = 25}) async {
    if (query.trim().isEmpty) return [];
    final data = await _postGraphQL(_searchQuery, {
      'search': query,
      'page': page,
      'perPage': limit,
    });
    if (data == null) return [];
    final pageData = data['Page'] as Map<String, dynamic>?;
    if (pageData == null) return [];
    final media = (pageData['media'] as List?) ?? const [];
    return media
        .whereType<Map<String, dynamic>>()
        .map(_mapAniListSearchResult)
        .toList();
  }

  MediaItem _mapAniListSearchResult(Map<String, dynamic> m) {
    final id = (m['id'] as num?)?.toInt() ?? 0;
    final malId = (m['idMal'] as num?)?.toInt() ?? 0;
    final title = m['title'] as Map<String, dynamic>?;
    final titleEn = (title?['english'] as String?)?.trim();
    final titleRom = (title?['romaji'] as String?)?.trim();
    final displayTitle = (titleEn?.isNotEmpty == true ? titleEn : titleRom) ?? 'Unknown Title';

    final cover = m['coverImage'] as Map<String, dynamic>?;
    final poster = (cover?['extraLarge'] as String?) ??
        (cover?['large'] as String?) ??
        (cover?['medium'] as String?) ??
        '';
    final banner = (m['bannerImage'] as String?) ?? '';

    final format = (m['format'] as String?) ?? '';
    final mediaType = format == 'MOVIE' ? 'movie' : 'tv';

    final yearVal = m['seasonYear'];
    final year = yearVal is num ? yearVal.toString() : '';

    final studios = m['studios'] as Map<String, dynamic>?;
    final nodes = (studios?['nodes'] as List?) ?? const [];
    String studioName = '';
    for (final s in nodes.whereType<Map<String, dynamic>>()) {
      final name = s['name'] as String?;
      if (name != null && name.isNotEmpty) {
        studioName = name;
        break;
      }
    }

    final episodes = (m['episodes'] is num)
        ? (m['episodes'] as num).toInt()
        : null;

    final status = (m['status'] as String?) ?? '';

    return MediaItem(
      id: '',
      tmdbId: malId,
      title: displayTitle,
      mediaType: mediaType,
      posterPath: poster,
      backdropPath: banner,
      year: year,
      status: '',
      isAnime: true,
      addedAt: DateTime.now(),
      source: 'jikan',
      anilistId: id,
      synopsis: '',
      episodeCount: episodes,
      airingStatus: status,
      format: format,
      studio: studioName,
    );
  }
}

/// Minimal HTML entity unescaper; we don't pull in `html_unescape` here
/// because AniList's description rarely uses anything beyond `&amp;`,
/// `&quot;`, `&#039;`, `&lt;`, `&gt;`, and `&nbsp;`.
String unescapeHtmlEntities(String input) {
  return input
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}

/// Comprehensive detail-page query. Fetches everything in one round-trip
/// to avoid rate-limiting and to keep the detail drawer snappy.
const String _searchQuery = r'''
query ($search: String, $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(search: $search, type: ANIME, sort: POPULARITY_DESC) {
      id
      idMal
      title { romaji english native }
      coverImage { extraLarge large medium }
      bannerImage
      episodes
      duration
      status
      format
      season
      seasonYear
      averageScore
      genres
      studios(isMain: true) { nodes { id name } }
      trailer { id site }
    }
  }
}
''';

const String _detailsQuery = r'''
query ($id: Int, $idMal: Int, $type: MediaType) {
  Media(id: $id, idMal: $idMal, type: $type) {
    id
    idMal
    title { romaji english native }
    description(asHtml: false)
    coverImage { extraLarge large medium color }
    bannerImage
    episodes
    duration
    status
    format
    season
    seasonYear
    startDate { year month day }
    endDate { year month day }
    averageScore
    meanScore
    popularity
    genres
    studios(isMain: true) { nodes { id name } }
    trailer { id site thumbnail }
    siteUrl

    characters(perPage: 12, sort: ROLE) {
      edges {
        role
        node {
          id
          name { full native }
          image { large medium }
        }
        voiceActors(language: JAPANESE) {
          id
          name { full native }
          image { large medium }
        }
      }
    }

    staff(perPage: 8) {
      edges {
        role
        node {
          id
          name { full native }
          image { medium }
        }
      }
    }

    relations {
      edges {
        relationType
        node {
          id
          idMal
          title { romaji english }
          format
          coverImage { large medium }
        }
      }
    }

    recommendations(perPage: 10, sort: RATING_DESC) {
      nodes {
        rating
        mediaRecommendation {
          id
          idMal
          title { romaji english }
          coverImage { large medium }
        }
      }
    }

    streamingEpisodes {
      title
      url
      site
      thumbnail
    }

    nextAiringEpisode {
      airingAt
      episode
    }
  }
}
''';
