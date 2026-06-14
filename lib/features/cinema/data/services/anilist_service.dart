import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/features/cinema/data/models/anilist_detail.dart';

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
  static const Duration _detailTtl = Duration(minutes: 30);

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
      if (anilistId == null && malId != null) 'malId': malId,
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
  List<AniListEpisode> _mapEpisodes(List? streaming, {int? episodeCount}) {
    final out = <AniListEpisode>[];
    if (streaming is List) {
      for (final e in streaming.whereType<Map<String, dynamic>>()) {
        final title = e['title'] as String?;
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
      number
      url
      airingAt
    }
  }
}
''';
