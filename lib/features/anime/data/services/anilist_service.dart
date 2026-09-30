import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/connectivity_aware.dart';
import '../../../../core/utils/logger.dart';
import '../models/anilist_detail.dart';
import '../models/animex_models.dart';
import '../../../cinema/data/models/media_item.dart';
import './jikan_service.dart';
import '../../../cinema/data/services/tmdb/tmdb_discovery_service.dart';
import '../../../cinema/data/services/tmdb/tmdb_search_service.dart';

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
class AniListService with ConnectivityAware {
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
            Logger.e('AniList GraphQL errors: ${body['errors']}');
            // A GraphQL error payload (e.g. AniList's temporary 403
            // "API disabled" response) has no usable `data`, so treat
            // it like a failed request and let callers fall back.
            return null;
          }
          return body['data'] as Map<String, dynamic>?;
        }
        Logger.e('AniList HTTP ${response.statusCode}: ${response.body}');
        return null;
      } catch (e) {
        Logger.e('AniList request error', error: e);
        return null;
      }
    });
  }

  @visibleForTesting
  static List<AniListSeason> mapSeasonsForTesting(Map<String, dynamic> m) {
    return AniListService()._mapSeasons(m);
  }

  @visibleForTesting
  static List<AniListEpisode> mapEpisodesForTesting(
    List? streaming, {
    int? episodeCount,
  }) {
    return AniListService()._mapEpisodes(streaming, episodeCount: episodeCount);
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
      'id': ?anilistId,
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
  AniListDetail _mapJikanDetail(
    Map<String, dynamic> j, {
    required int fallbackMalId,
  }) {
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
    final ytId =
        (trailer?['youtube_id'] as String?) ??
        ((trailer?['url'] as String?)?.split('v=').last ?? '');
    final trailerId = (ytId.isNotEmpty && ytId != 'null') ? ytId : null;

    final aired = j['aired'] as Map<String, dynamic>?;
    final airedFrom = aired?['from'] as String?;
    final airedTo = aired?['to'] as String?;

    final malId = (j['mal_id'] as num?)?.toInt() ?? fallbackMalId;

    return AniListDetail(
      id: 0,
      malId: malId,
      titleEnglish:
          (j['title_english'] as String?) ?? (j['title'] as String?) ?? '',
      titleRomaji: (j['title_japanese'] as String?) ?? '',
      titleNative: '',
      synopsis: _stripHtml((j['synopsis'] as String?) ?? ''),
      coverImageUrl: pickImage('large_image_url').isNotEmpty
          ? pickImage('large_image_url')
          : pickImage('image_url'),
      bannerImageUrl: pickImage('extra_large_image_url'),
      episodeCount: (j['episodes'] is num)
          ? (j['episodes'] as num).toInt()
          : null,
      duration:
          (j['duration'] as String?)
                  ?.replaceAll(RegExp(r'[^0-9]'), '')
                  .isNotEmpty ==
              true
          ? int.tryParse(
              (j['duration'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
            )
          : null,
      airingStatus: (j['status'] as String?) ?? '',
      format: (j['type'] as String?) ?? '',
      season: (j['season'] as String?),
      seasonYear: (j['year'] is num) ? (j['year'] as num).toInt() : null,
      averageScore: (j['score'] is num) ? (j['score'] as num).toDouble() : null,
      genres: genres,
      studios: studioNames,
      trailerYoutubeId: trailerId,
      // Jikan doesn't return relations/recommendations/characters/staff
      // here; the drawer treats empty lists as "no data" which is fine.
      relations: const [],
      recommendations: const [],
      episodes: _mapJikanStreaming(
        malId: malId,
        episodeCount: (j['episodes'] is num)
            ? (j['episodes'] as num).toInt()
            : null,
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
      coverImageUrl:
          (cover?['extraLarge'] as String?) ??
          (cover?['large'] as String?) ??
          (cover?['medium'] as String?) ??
          '',
      bannerImageUrl: (m['bannerImage'] as String?) ?? '',
      siteUrl: (m['siteUrl'] as String?) ?? '',
      episodeCount: (m['episodes'] is num)
          ? (m['episodes'] as num).toInt()
          : null,
      duration: (m['duration'] is num) ? (m['duration'] as num).toInt() : null,
      airingStatus: (m['status'] as String?) ?? '',
      format: (m['format'] as String?) ?? '',
      season: m['season'] as String?,
      seasonYear: (m['seasonYear'] is num)
          ? (m['seasonYear'] as num).toInt()
          : null,
      averageScore: (m['averageScore'] is num)
          ? (m['averageScore'] as num).toDouble() / 10
          : null,
      genres: ((m['genres'] as List?) ?? const []).whereType<String>().toList(),
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
      seasons: _mapSeasons(m),
      recommendations: _mapRecommendations(
        m['recommendations'] as Map<String, dynamic>?,
      ),
      episodes: _mapEpisodes(
        m['streamingEpisodes'] as List?,
        episodeCount: (m['episodes'] is num)
            ? (m['episodes'] as num).toInt()
            : null,
      ),
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
          name:
              (vname['full'] as String?) ?? (vname['native'] as String?) ?? '',
          imageUrl:
              (vimage['large'] as String?) ??
              (vimage['medium'] as String?) ??
              '',
          language: 'JAPANESE',
        );
      }).toList();
      return AniListCharacter(
        id: (node['id'] as num?)?.toInt() ?? 0,
        name:
            (name['full'] as String?) ??
            (name['native'] as String?) ??
            (name['first'] as String?) ??
            '',
        imageUrl:
            (image['large'] as String?) ?? (image['medium'] as String?) ?? '',
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
        name:
            (name['full'] as String?) ??
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
    const validFormats = {'TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL'};
    return edges.whereType<Map<String, dynamic>>().where((e) {
      final node = (e['node'] as Map<String, dynamic>?) ?? const {};
      final format = ((node['format'] as String?) ?? '').toUpperCase().trim();
      final type = (node['type'] as String?) ?? '';
      if (type.isNotEmpty && type != 'ANIME') return false;
      if (format.isNotEmpty && !validFormats.contains(format)) return false;
      return true;
    }).map((e) {
      final node = (e['node'] as Map<String, dynamic>?) ?? const {};
      final title = (node['title'] as Map<String, dynamic>?) ?? const {};
      final cover = (node['coverImage'] as Map<String, dynamic>?) ?? const {};
      return AniListRelated(
        id: (node['id'] as num?)?.toInt() ?? 0,
        malId: (node['idMal'] as num?)?.toInt(),
        title:
            (title['english'] as String?) ?? (title['romaji'] as String?) ?? '',
        coverImageUrl:
            (cover['large'] as String?) ?? (cover['medium'] as String?) ?? '',
        relationType: (e['relationType'] as String?) ?? '',
        format: (node['format'] as String?) ?? '',
      );
    }).toList();
  }

  List<AniListSeason> _mapSeasons(Map<String, dynamic> m) {
    final currentId = (m['id'] as num?)?.toInt() ?? 0;
    final seasonsMap = <int, AniListSeason>{};

    void addNode(
      Map<String, dynamic>? node, {
      String? relType,
      bool isCurrent = false,
    }) {
      if (node == null) return;
      final id = (node['id'] as num?)?.toInt() ?? 0;
      if (id <= 0) return;

      final format = ((node['format'] as String?) ?? '').toUpperCase().trim();
      const validFormats = {
        'TV',
        'TV_SHORT',
        'MOVIE',
        'OVA',
        'ONA',
        'SPECIAL',
      };
      if (!validFormats.contains(format)) return;

      if (relType == 'SUMMARY' ||
          relType == 'CHARACTER' ||
          relType == 'OTHER') {
        return;
      }

      final titleMap = node['title'] as Map<String, dynamic>?;
      final english = titleMap?['english'] as String?;
      final romaji = titleMap?['romaji'] as String?;
      final title = (english != null && english.isNotEmpty)
          ? english
          : (romaji ?? '');
      if (title.isEmpty) return;

      final cover = node['coverImage'] as Map<String, dynamic>?;
      final coverUrl = (cover?['large'] as String?) ??
          (cover?['extraLarge'] as String?) ??
          (cover?['medium'] as String?) ??
          '';

      final start = node['startDate'] as Map<String, dynamic>?;
      final year = (start?['year'] as num?)?.toInt() ??
          (node['seasonYear'] as num?)?.toInt();
      final month = (start?['month'] as num?)?.toInt() ?? 0;
      final day = (start?['day'] as num?)?.toInt() ?? 0;

      final episodes = (node['episodes'] as num?)?.toInt();
      final malId = (node['idMal'] as num?)?.toInt();

      seasonsMap.putIfAbsent(
        id,
        () => AniListSeason(
          id: id,
          malId: malId,
          title: title,
          coverImageUrl: coverUrl,
          format: format,
          year: year,
          month: month,
          day: day,
          episodeCount: episodes,
          isCurrent: isCurrent || id == currentId,
        ),
      );
    }

    addNode(m, isCurrent: true);

    const allowedRelations = {
      'SEQUEL',
      'PREQUEL',
      'PARENT',
      'SIDE_STORY',
      'SPIN_OFF',
      'ALTERNATIVE',
      'ADAPTATION',
    };

    final relations = m['relations'] as Map<String, dynamic>?;
    final edges = (relations?['edges'] as List?) ?? const [];
    for (final edge in edges) {
      if (edge is! Map<String, dynamic>) continue;
      final relType = edge['relationType'] as String? ?? '';
      if (!allowedRelations.contains(relType)) continue;

      final node = edge['node'] as Map<String, dynamic>?;
      if (node == null) continue;

      final type = node['type'] as String? ?? '';
      if (type == 'ANIME') {
        addNode(node, relType: relType);
      }

      if (relType == 'ADAPTATION' ||
          relType == 'SEQUEL' ||
          relType == 'PREQUEL') {
        final nestedRelations = node['relations'] as Map<String, dynamic>?;
        final nestedEdges = (nestedRelations?['edges'] as List?) ?? const [];
        for (final nEdge in nestedEdges) {
          if (nEdge is! Map<String, dynamic>) continue;
          final nRelType = nEdge['relationType'] as String? ?? '';
          if (!allowedRelations.contains(nRelType)) continue;

          final nNode = nEdge['node'] as Map<String, dynamic>?;
          if (nNode == null) continue;
          final nType = nNode['type'] as String? ?? '';
          if (nType == 'ANIME') {
            addNode(nNode, relType: nRelType);
          }
        }
      }
    }

    final list = seasonsMap.values.toList();
    list.sort((a, b) {
      final yA = a.year ?? 9999;
      final yB = b.year ?? 9999;
      if (yA != yB) return yA.compareTo(yB);
      if (a.month != b.month) return a.month.compareTo(b.month);
      return a.day.compareTo(b.day);
    });

    return assignSeasonLabels(list);
  }

  /// Assigns clean, human-readable labels to seasons (e.g. "Season 1",
  /// "Season 1 Part 2", "Season 2", "OVA", "Movie", "Special").
  static List<AniListSeason> assignSeasonLabels(List<AniListSeason> seasons) {
    if (seasons.isEmpty) return seasons;

    int? parseSeasonNumber(String title) {
      if (RegExp(r'\bFinal\s+Season\b', caseSensitive: false).hasMatch(title)) {
        return 999;
      }
      final sMatch = RegExp(
        r'\b(?:Season|Series)\s*(\d+)\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (sMatch != null) return int.tryParse(sMatch.group(1)!);

      final ordMatch = RegExp(
        r'\b(\d+)(?:st|nd|rd|th)\s+(?:Season|Stage)\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (ordMatch != null) return int.tryParse(ordMatch.group(1)!);

      const words = {
        'first': 1,
        'second': 2,
        'third': 3,
        'fourth': 4,
        'fifth': 5,
        'sixth': 6,
      };
      final wordMatch = RegExp(
        r'\b(First|Second|Third|Fourth|Fifth|Sixth)\s+(?:Season|Stage)\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (wordMatch != null) {
        final w = wordMatch.group(1)!.toLowerCase();
        if (words.containsKey(w)) return words[w];
      }

      final romanMatch = RegExp(
        r'\b(?:Season\s+)?(II|III|IV|VI|VII|VIII|IX)\b',
      ).firstMatch(title);
      if (romanMatch != null) {
        const romans = {
          'II': 2,
          'III': 3,
          'IV': 4,
          'VI': 6,
          'VII': 7,
          'VIII': 8,
          'IX': 9,
        };
        final val = romans[romanMatch.group(1)!];
        if (val != null) return val;
      }

      final romanV = RegExp(
        r'\bSeason\s+V\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (romanV != null) return 5;

      final endNumMatch = RegExp(
        r'(?<!(?:Part|Cour|Ep|Episode|Movie|OVA|ONA|Vol|Volume)\s*)(?:^|\s+)(\d{1,2})(?:\s*[:\-\—]|\s*$)',
        caseSensitive: false,
      ).firstMatch(title);
      if (endNumMatch != null) {
        final n = int.tryParse(endNumMatch.group(1)!);
        if (n != null && n >= 2 && n <= 20) return n;
      }

      return null;
    }

    int? parsePartNumber(String title) {
      final pMatch = RegExp(
        r'\b(?:Part|Cour)\s*(\d+)\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (pMatch != null) return int.tryParse(pMatch.group(1)!);

      final ordCour = RegExp(
        r'\b(\d+)(?:st|nd|rd|th)\s+Cour\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (ordCour != null) return int.tryParse(ordCour.group(1)!);

      final romanPart = RegExp(
        r'\bPart\s+(II|III|IV|V)\b',
        caseSensitive: false,
      ).firstMatch(title);
      if (romanPart != null) {
        const romans = {'II': 2, 'III': 3, 'IV': 4, 'V': 5};
        return romans[romanPart.group(1)!.toUpperCase()];
      }

      return null;
    }

    final formatCounts = <String, int>{};
    for (final s in seasons) {
      final fmt = s.format.toUpperCase().trim();
      formatCounts[fmt] = (formatCounts[fmt] ?? 0) + 1;
    }

    final hasTv =
        (formatCounts['TV'] ?? 0) > 0 || (formatCounts['TV_SHORT'] ?? 0) > 0;

    final formatIndices = <String, int>{};
    var currentSeasonNum = 0;
    final results = <AniListSeason>[];

    for (final s in seasons) {
      final fmt = s.format.toUpperCase().trim();
      formatIndices[fmt] = (formatIndices[fmt] ?? 0) + 1;
      final indexInFormat = formatIndices[fmt]!;
      final totalInFormat = formatCounts[fmt] ?? 0;

      String label;
      final isEpisodic =
          fmt == 'TV' || fmt == 'TV_SHORT' || (!hasTv && fmt == 'ONA');

      if (isEpisodic) {
        final explicitSeason = parseSeasonNumber(s.title);
        final explicitPart = parsePartNumber(s.title);

        if (explicitSeason == 999) {
          label = 'Final Season';
          if (explicitPart != null && explicitPart > 1) {
            label += ' Part $explicitPart';
          }
        } else if (explicitSeason != null) {
          currentSeasonNum = explicitSeason;
          label = 'Season $explicitSeason';
          if (explicitPart != null && explicitPart > 1) {
            label += ' Part $explicitPart';
          }
        } else {
          if (explicitPart != null &&
              explicitPart > 1 &&
              currentSeasonNum > 0) {
            label = 'Season $currentSeasonNum Part $explicitPart';
          } else {
            currentSeasonNum =
                currentSeasonNum == 0 ? 1 : currentSeasonNum + 1;
            label = 'Season $currentSeasonNum';
            if (explicitPart != null && explicitPart > 1) {
              label += ' Part $explicitPart';
            }
          }
        }
      } else if (fmt == 'OVA') {
        label = totalInFormat > 1 ? 'OVA $indexInFormat' : 'OVA';
      } else if (fmt == 'ONA') {
        label = totalInFormat > 1 ? 'ONA $indexInFormat' : 'ONA';
      } else if (fmt == 'MOVIE') {
        label = totalInFormat > 1 ? 'Movie $indexInFormat' : 'Movie';
      } else if (fmt == 'SPECIAL') {
        label = totalInFormat > 1 ? 'Special $indexInFormat' : 'Special';
      } else {
        label = s.title;
      }

      results.add(s.copyWith(label: label));
    }

    return results;
  }

  List<AniListRecommended> _mapRecommendations(Map<String, dynamic>? r) {
    if (r == null) return const [];
    final nodes = (r['nodes'] as List?) ?? const [];
    return nodes.whereType<Map<String, dynamic>>().map((n) {
      final media =
          (n['mediaRecommendation'] as Map<String, dynamic>?) ?? const {};
      final title = (media['title'] as Map<String, dynamic>?) ?? const {};
      final cover = (media['coverImage'] as Map<String, dynamic>?) ?? const {};
      final rating = n['rating'];
      return AniListRecommended(
        id: (media['id'] as num?)?.toInt() ?? 0,
        malId: (media['idMal'] as num?)?.toInt(),
        title:
            (title['english'] as String?) ?? (title['romaji'] as String?) ?? '',
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
    // AniList's `streamingEpisodes` has no `number` field — the episode
    // number is embedded in the title as "Episode N - <name>". Parse it
    // out and key entries by number so out-of-order feeds still map to
    // the right episode slots, and strip the prefix so tiles show only
    // the real episode name.
    final byNum = <int, AniListEpisode>{};
    if (streaming is List) {
      var autoIndex = 1;
      for (final e in streaming.whereType<Map<String, dynamic>>()) {
        final rawTitle = e['title'] as String?;
        final thumb = e['thumbnail'] as String?;
        int epNum = (e['number'] as num?)?.toInt() ?? 0;
        String? cleanTitle = rawTitle;

        if (rawTitle != null) {
          final m = RegExp(
            r'^Episode\s+(\d+)\s*(?:-\s*(.*))?$',
            caseSensitive: false,
          ).firstMatch(rawTitle.trim());
          if (m != null) {
            if (epNum == 0) {
              epNum = int.tryParse(m.group(1) ?? '') ?? 0;
            }
            final rest = m.group(2)?.trim();
            if (rest != null && rest.isNotEmpty) {
              cleanTitle = rest;
            }
          }
        }
        if (epNum <= 0) {
          epNum = autoIndex;
        }
        autoIndex = epNum + 1;

        byNum[epNum] = AniListEpisode(
          number: epNum,
          title: cleanTitle,
          titleRomaji: null,
          synopsis: null,
          airedAt: e['airingAt'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (e['airingAt'] as num).toInt() * 1000,
                )
              : null,
          duration: null,
          thumbnail: (thumb != null && thumb.isNotEmpty) ? thumb : null,
        );
      }
    }
    // When the canonical count is known, keep stray multi-season feed entries
    // from creating ghost episodes that won't exist on the streaming servers.
    final maxAnilistEp = byNum.isEmpty
        ? null
        : byNum.keys.reduce((a, b) => a > b ? a : b);
    final maxEp = (episodeCount != null && episodeCount > 0)
        ? episodeCount
        : (maxAnilistEp ?? 0);

    final out = <AniListEpisode>[];
    for (var i = 1; i <= maxEp; i++) {
      out.add(byNum[i] ?? AniListEpisode(number: i));
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
  Future<AniListDetail?> fetchDetailsFresh({int? anilistId, int? malId}) async {
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
  Future<List<MediaItem>> searchAnime(
    String query, {
    int page = 1,
    int limit = 25,
  }) async {
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
    final displayTitle =
        (titleEn?.isNotEmpty == true ? titleEn : titleRom) ?? 'Unknown Title';

    final cover = m['coverImage'] as Map<String, dynamic>?;
    final poster =
        (cover?['extraLarge'] as String?) ??
        (cover?['large'] as String?) ??
        (cover?['medium'] as String?) ??
        '';
    final banner = (m['bannerImage'] as String?) ?? '';

    final format = (m['format'] as String?) ?? '';
    final episodesForType = (m['episodes'] is num)
        ? (m['episodes'] as num).toInt()
        : null;
    final durationForType = (m['duration'] is num)
        ? (m['duration'] as num).toInt()
        : null;
    // ONA-listed films (e.g. Drifting Home: ONA + 1 x 120min) are really
    // movies — without this they open as tv with a fake episode list.
    final mediaType = MediaItem.isSingleEpisodeFilm(
      format: format,
      episodeCount: episodesForType,
      durationMinutes: durationForType,
    )
        ? 'movie'
        : 'tv';

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

    final trailer = m['trailer'] as Map<String, dynamic>?;
    final trailerId = (trailer != null && trailer['site'] == 'youtube')
        ? trailer['id'] as String?
        : null;

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
      trailerYoutubeId: trailerId,
    );
  }

  /// Rich media page for the anime section (browse grid, home rows,
  /// seasonal). Supports the same filters the reference UI exposes:
  /// sort, status, season/year, format, single genre and free text.
  /// Returns items with synopsis, genres, banner and scores populated so
  /// cards and hover popovers render full detail without extra fetches.
  Future<AnimexMediaPage> fetchAnimexPage({
    String? search,
    String? sort,
    String? status,
    String? season,
    int? seasonYear,
    String? format,
    String? genre,
    int page = 1,
    int perPage = 24,
  }) async {
    final variables = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (sort != null && sort.isNotEmpty) 'sort': [sort],
      if (status != null && status.isNotEmpty) 'status': status,
      if (season != null && season.isNotEmpty) 'season': season,
      'seasonYear': ?seasonYear,
      if (format != null && format.isNotEmpty) 'format': format,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      'page': page,
      'perPage': perPage,
    };
    final data = await _postGraphQL(_animexPageQuery, variables);
    final pageData = data?['Page'] as Map<String, dynamic>?;
    if (pageData == null) {
      final fallback = await _fallbackAnimexPage(
        search: search,
        sort: sort,
        status: status,
        season: season,
        seasonYear: seasonYear,
        format: format,
        genre: genre,
        page: page,
        perPage: perPage,
      );
      if (fallback != null) return fallback;
      return const AnimexMediaPage(
        items: [],
        scores: [],
        currentPage: 1,
        hasNextPage: false,
      );
    }
    final pageInfo = pageData['pageInfo'] as Map<String, dynamic>?;
    final media = (pageData['media'] as List?) ?? const [];
    final items = <MediaItem>[];
    final scores = <double>[];
    for (final m in media.whereType<Map<String, dynamic>>()) {
      final mapped = _mapAnimexMedia(m);
      if (mapped != null) {
        items.add(mapped.item);
        scores.add(mapped.score);
      }
    }
    return AnimexMediaPage(
      items: items,
      scores: scores,
      currentPage: (pageInfo?['currentPage'] as num?)?.toInt() ?? page,
      lastPage: (pageInfo?['lastPage'] as num?)?.toInt(),
      hasNextPage: pageInfo?['hasNextPage'] == true,
    );
  }

  /// Best-effort replacement for AniList page queries when the GraphQL
  /// endpoint is down or rate-limited. Jikan is the closest match for
  /// anime lists; TMDB's anime discovery is a second fallback when no
  /// key is present for Jikan or the query shape doesn't translate.
  Future<AnimexMediaPage?> _fallbackAnimexPage({
    String? search,
    String? sort,
    String? status,
    String? season,
    int? seasonYear,
    String? format,
    String? genre,
    int page = 1,
    int perPage = 24,
  }) async {
    final jikan = JikanService();
    List<MediaItem>? items;

    if (search != null && search.trim().isNotEmpty) {
      items = await jikan.searchAnime(search, page: page, limit: perPage);
    } else if (season != null && seasonYear != null) {
      items = await jikan.fetchSeason(
        year: seasonYear,
        season: season.toLowerCase(),
        page: page,
        limit: perPage,
      );
    } else if (status == 'RELEASING') {
      items = await jikan.fetchTopAiring(page: page, limit: perPage);
    } else if (sort == 'SCORE_DESC') {
      items = await jikan.fetchTopAnime(type: 'tv', page: page, limit: perPage);
    } else {
      items = await jikan.fetchTopAnime(
        type: 'tv',
        filter: 'bypopularity',
        page: page,
        limit: perPage,
      );
    }

    if (genre != null && genre.trim().isNotEmpty) {
      final genreIds = _jikanGenreIds(genre);
      if (genreIds.isNotEmpty) {
        final byGenre = await jikan.fetchByGenres(
          genreIds,
          page: page,
          limit: perPage,
        );
        if (byGenre.isNotEmpty) items = byGenre;
      }
    }
    if (format == 'MOVIE' && items.isNotEmpty) {
      items = items.where((i) => i.mediaType == 'movie').toList();
    }

    if (items.isNotEmpty) {
      Logger.w('[AnimeX] AniList unavailable; showing Jikan fallback');
      return _pageFromItems(items, page: page);
    }

    // TMDB's anime discovery is a coarse but independent third source.
    // The API key is optional in dev builds, so skip when it's absent.
    if (search != null && search.trim().isNotEmpty) {
      items = await TMDBSearchService().searchMedia(search);
    } else if (sort == 'SCORE_DESC') {
      items = await TMDBDiscoveryService().discoverAnime(
        sortBy: 'vote_average.desc',
        voteCountGte: 20,
        page: page,
      );
    } else if (status == 'RELEASING') {
      items = await TMDBDiscoveryService().discoverAnime(
        sortBy: 'popularity.desc',
        withStatus: 1, // TMDB airing-today status.
        page: page,
      );
    } else {
      items = await TMDBDiscoveryService().fetchTrendingAnime();
    }
    if (items.isNotEmpty) {
      Logger.w('[AnimeX] AniList and Jikan unavailable; showing TMDB fallback');
      return _pageFromItems(items, page: page);
    }

    return null;
  }

  AnimexMediaPage _pageFromItems(List<MediaItem> items, {int page = 1}) {
    return AnimexMediaPage(
      items: items,
      scores: items.map((i) => i.score ?? 0).toList(),
      currentPage: page,
      lastPage: null,
      hasNextPage: false,
    );
  }

  /// Maps a display genre name to MAL genre ids so the Jikan fallback
  /// can apply the same Browse filter as AniList's `genre` argument.
  static List<int> _jikanGenreIds(String genre) {
    const map = <String, int>{
      'Action': 1,
      'Adventure': 2,
      'Comedy': 4,
      'Mystery': 7,
      'Drama': 8,
      'Fantasy': 10,
      'Horror': 14,
      'Romance': 22,
      'Sci-Fi': 24,
      'Sports': 30,
      'Slice of Life': 36,
      'Supernatural': 37,
      'Thriller': 41,
    };
    final id = map[genre];
    return id == null ? const [] : [id];
  }

  /// Weekly airing schedule via AniList's `airingSchedules`. AniList has
  /// no weekday filter, so we query the window covering the current week
  /// (starting at the most recent occurrence of [weekday]) and filter the
  /// results client-side. Weekday is 0 = Monday .. 6 = Sunday.
  Future<List<AnimexScheduleEntry>> fetchAiringSchedule({
    int weekday = 0,
    int perPage = 100,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = now.weekday - 1; // 0 = Monday
    final daysBack = (todayIndex - weekday + 7) % 7;
    final start = today.subtract(Duration(days: daysBack));
    final end = start.add(const Duration(days: 7));
    final data = await _postGraphQL(_airingScheduleQuery, {
      'airingAtGreater': start.millisecondsSinceEpoch ~/ 1000,
      'airingAtLesser': end.millisecondsSinceEpoch ~/ 1000,
      'perPage': perPage,
    });
    final pageData = data?['Page'] as Map<String, dynamic>?;
    final schedule = (pageData?['airingSchedules'] as List?) ?? const [];
    final out = <AnimexScheduleEntry>[];
    for (final s in schedule.whereType<Map<String, dynamic>>()) {
      final airingAt = s['airingAt'];
      if (airingAt is! num) continue;
      final airingTime = DateTime.fromMillisecondsSinceEpoch(
        airingAt.toInt() * 1000,
      );
      if (airingTime.weekday - 1 != weekday) continue;
      final media = s['media'] as Map<String, dynamic>?;
      if (media == null) continue;
      final mapped = _mapAnimexMedia(media);
      if (mapped == null) continue;
      out.add(
        AnimexScheduleEntry(
          media: mapped.item,
          episode: (s['episode'] as num?)?.toInt() ?? 1,
          airingAt: airingTime,
        ),
      );
    }
    return out;
  }

  ({MediaItem item, double score})? _mapAnimexMedia(Map<String, dynamic> m) {
    final id = (m['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return null;
    final malId = (m['idMal'] as num?)?.toInt() ?? 0;
    final title = m['title'] as Map<String, dynamic>?;
    final titleEn = (title?['english'] as String?)?.trim();
    final titleRom = (title?['romaji'] as String?)?.trim();
    final displayTitle =
        (titleEn?.isNotEmpty == true ? titleEn : titleRom) ?? 'Unknown Title';

    final cover = m['coverImage'] as Map<String, dynamic>?;
    final poster =
        (cover?['extraLarge'] as String?) ??
        (cover?['large'] as String?) ??
        (cover?['medium'] as String?) ??
        '';
    final banner = (m['bannerImage'] as String?) ?? '';
    final format = (m['format'] as String?) ?? '';
    final episodesForType = (m['episodes'] is num)
        ? (m['episodes'] as num).toInt()
        : null;
    final durationForType = (m['duration'] is num)
        ? (m['duration'] as num).toInt()
        : null;
    final mediaType = MediaItem.isSingleEpisodeFilm(
      format: format,
      episodeCount: episodesForType,
      durationMinutes: durationForType,
    )
        ? 'movie'
        : 'tv';
    final yearVal = m['seasonYear'];
    final year = yearVal is num ? yearVal.toString() : '';

    final studios = m['studios'] as Map<String, dynamic>?;
    String studioName = '';
    for (final s
        in ((studios?['nodes'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()) {
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
    final scoreVal = (m['averageScore'] is num)
        ? (m['averageScore'] as num).toDouble() / 10
        : 0.0;
    final genres = ((m['genres'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final synopsis = _stripHtml((m['description'] as String?) ?? '');
    final trailer = m['trailer'] as Map<String, dynamic>?;
    final trailerId = (trailer != null && trailer['site'] == 'youtube')
        ? trailer['id'] as String?
        : null;

    final item = MediaItem(
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
      synopsis: synopsis,
      episodeCount: episodes,
      airingStatus: status,
      format: format,
      studio: studioName,
      genres: genres,
      // Cards and hover popovers read `item.score`; the parallel `scores`
      // list on the page is never consumed, so the score lives here.
      score: scoreVal > 0 ? scoreVal : null,
      trailerYoutubeId: trailerId,
    );
    return (item: item, score: scoreVal);
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
          type
          seasonYear
          startDate { year month day }
          episodes
          coverImage { large medium extraLarge }
          relations {
            edges {
              relationType
              node {
                id
                idMal
                title { romaji english }
                format
                type
                seasonYear
                startDate { year month day }
                episodes
                coverImage { large medium extraLarge }
              }
            }
          }
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

/// Filterable browse/seasonal/search query for the anime section.
const String _animexPageQuery = r'''
query (
  $search: String
  $sort: [MediaSort]
  $status: MediaStatus
  $season: MediaSeason
  $seasonYear: Int
  $format: MediaFormat
  $genre: String
  $page: Int
  $perPage: Int
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      currentPage
      lastPage
      hasNextPage
    }
    media(
      search: $search
      type: ANIME
      sort: $sort
      status: $status
      season: $season
      seasonYear: $seasonYear
      format: $format
      genre: $genre
    ) {
      id
      idMal
      title { romaji english native }
      coverImage { extraLarge large medium }
      bannerImage
      description(asHtml: false)
      episodes
      duration
      status
      format
      season
      seasonYear
      averageScore
      genres
      studios(isMain: true) { nodes { id name } }
      nextAiringEpisode { airingAt episode }
      trailer { id site }
    }
  }
}
''';

/// Weekly airing schedule query over a unix-timestamp window.
const String _airingScheduleQuery = r'''
query ($airingAtGreater: Int, $airingAtLesser: Int, $perPage: Int) {
  Page(page: 1, perPage: $perPage) {
    pageInfo {
      currentPage
      lastPage
      hasNextPage
    }
    airingSchedules(
      airingAt_greater: $airingAtGreater
      airingAt_lesser: $airingAtLesser
      notYetAired: false
      sort: TIME
    ) {
      id
      airingAt
      episode
      media {
        id
        idMal
        title { romaji english native }
        coverImage { extraLarge large medium }
        bannerImage
        description(asHtml: false)
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
}
''';
