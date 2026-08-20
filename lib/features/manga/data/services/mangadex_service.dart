import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/connectivity_aware.dart';
import '../models/manga_item.dart';
import '../../../../core/utils/logger.dart';

/// Talks to the MangaDex API for chapter listing and page-image
/// resolution. All requests go through the `proxyMangaDex` Cloud
/// Function so Flutter web isn't blocked by missing CORS headers on
/// api.mangadex.org responses.
///
/// MangaDex endpoints used:
///   * Chapter feed — `GET /manga/{id}/feed`
///   * At-home server — `GET /at-home/server/{chapterId}`
///
/// No API key required. Rate limiting is handled server-side by the
/// proxy function.
class MangaDexService with ConnectivityAware {
  static const String _proxyUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaDex';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaImage';

  // Singleton
  static final MangaDexService _instance = MangaDexService._internal();
  factory MangaDexService() => _instance;
  MangaDexService._internal();

  Map<String, String> get _headers => {
        'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
        'Accept': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {..._headers, 'Authorization': 'Bearer $token'};
      }
    } catch (_) {}
    return _headers;
  }

  /// Build a proxied URL for an API path (without leading slash).
  /// The path may include a query string, e.g.
  /// `manga/abc/feed?translatedLanguage[]=en`.
  Uri _proxied(String apiPath) {
    return Uri.parse('$_proxyUrl?path=${Uri.encodeComponent(apiPath)}');
  }

  /// Return a proxied image URL suitable for `Image.network`.
  /// If [originalUrl] is already proxied, it is returned as-is.
  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    if (originalUrl.contains('proxyMangaImage')) return originalUrl;
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }

  // ── CHAPTER FEED ───────────────────────────────────────────

  /// Fetch the chapter list for a MangaDex manga by its UUID.
  /// Returns chapters sorted by chapter number (ascending), newest
  /// first so the reading order is natural.
  /// Auto-paginates if the manga has more than [limit] chapters.
  Future<List<MangaChapter>> getChapterFeed(
    String mangaId, {
    String language = 'en',
    int limit = 500,
    int offset = 0,
  }) async {
    if (mangaId.isEmpty) return [];
    final allChapters = <Map<String, dynamic>>[];
    var currentOffset = offset;
    var total = 0;

    // Paginate until we've fetched all chapters
    do {
      final path = 'manga/$mangaId/feed'
          '?translatedLanguage[]=$language'
          '&limit=$limit'
          '&offset=$currentOffset'
          '&order[chapter]=asc'
          '&includes[]=scanlation_group'
          '&contentRating[]=safe'
          '&contentRating[]=suggestive'
          '&contentRating[]=erotica';
      try {
        final headers = await _authHeaders();
        final response = await http.get(_proxied(path), headers: headers).timeout(
              const Duration(seconds: 10),
            );
        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          if (body['result'] != 'ok') break;
          final data = body['data'] as List? ?? [];
          total = (body['total'] as num?)?.toInt() ?? 0;
          allChapters.addAll(data.whereType<Map<String, dynamic>>());
          currentOffset += data.length;
          // Safety: stop if we got fewer than requested (end of results)
          if (data.length < limit) break;
        } else {
          break;
        }
      } catch (e) {
        Logger.e('MangaDex chapter feed error', error: e);
        break;
      }
    } while (currentOffset < total);

    if (allChapters.isEmpty) return [];

    // Filter out chapters with 0 pages — these are external/official
    // publisher links (e.g. Webnovel, Pocket Comics, TappyToon) that
    // have no page data on MangaDex and can't be read through the
    // at-home server.
    final filtered = allChapters.where((d) {
      final attrs = d['attributes'] as Map<String, dynamic>? ?? {};
      final pages = (attrs['pages'] as num?)?.toInt() ?? 0;
      return pages > 0;
    }).toList();

    // Fallback: if all chapters were filtered out (licensed manga with
    // only official publisher links), return the full list so at least
    // the chapter numbers are visible in the UI.
    final chaptersToMap = filtered.isNotEmpty ? filtered : allChapters;

    return chaptersToMap.map((d) {
      final attrs = d['attributes'] as Map<String, dynamic>? ?? {};
      final rels = d['relationships'] as List? ?? [];
      String group = '';
      for (final rel in rels) {
        if (rel is Map && rel['type'] == 'scanlation_group') {
          group = (rel['attributes']?['name'] as String?) ?? '';
          break;
        }
      }
      return MangaChapter(
        id: d['id'] as String? ?? '',
        title: (attrs['title'] as String?) ?? '',
        chapter: (attrs['chapter'] as String?) ?? '',
        volume: (attrs['volume'] as String?) ?? '',
        pages: (attrs['pages'] as num?)?.toInt() ?? 0,
        translatedLanguage:
            (attrs['translatedLanguage'] as String?) ?? language,
        scanlationGroup: group,
        publishAt:
            DateTime.tryParse((attrs['publishAt'] as String?) ?? '') ??
                DateTime.now(),
      );
    }).toList();
  }

  // ── CATALOG / LISTING ──────────────────────────────────────

  /// Extract the English title from MangaDex's i18n title map.
  /// Falls back to the first available title or 'Untitled'.
  static String _extractTitle(Map<String, dynamic> attrs) {
    final title = attrs['title'] as Map<String, dynamic>?;
    if (title != null) {
      if (title['en'] is String && (title['en'] as String).isNotEmpty) {
        return title['en'] as String;
      }
      for (final v in title.values) {
        if (v is String && v.isNotEmpty) return v;
      }
    }
    final altTitles = attrs['altTitles'] as List?;
    if (altTitles != null && altTitles.isNotEmpty) {
      for (final alt in altTitles) {
        if (alt is Map) {
          for (final v in alt.values) {
            if (v is String && v.isNotEmpty) return v;
          }
        }
      }
    }
    return 'Untitled';
  }

  /// Build the cover art URL from relationships, proxied through
  /// `proxyMangaImage` to avoid hotlink protection from MangaDex CDN.
  String _coverUrl(String mangaId, List<dynamic>? relationships) {
    if (mangaId.isEmpty) return '';
    if (relationships == null) return '';
    for (final rel in relationships) {
      if (rel is Map && rel['type'] == 'cover_art') {
        final relAttrs = rel['attributes'] as Map<String, dynamic>?;
        final fileName = relAttrs?['fileName'] as String?;
        if (fileName != null && fileName.isNotEmpty) {
          final raw =
              'https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg';
          return proxiedImageUrl(raw);
        }
      }
    }
    return '';
  }

  /// Extract English description from MangaDex's i18n description map.
  static String _extractDescription(Map<String, dynamic> attrs) {
    final desc = attrs['description'] as Map<String, dynamic>?;
    if (desc == null) return '';
    if (desc['en'] is String && (desc['en'] as String).isNotEmpty) {
      return desc['en'] as String;
    }
    for (final v in desc.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// Map MangaDex status to our status string.
  /// MangaDex uses: ongoing, completed, hiatus, cancelled, discontinued
  static String _mapStatus(String? status) {
    switch (status) {
      case 'ongoing':
        return 'ongoing';
      case 'completed':
        return 'completed';
      case 'hiatus':
        return 'on hiatus';
      case 'cancelled':
      case 'discontinued':
        return status ?? 'cancelled';
      default:
        return '';
    }
  }

  /// Extract tag names from MangaDex tag objects (max 8).
  static List<String> _extractTags(List<dynamic>? tags) {
    if (tags == null) return [];
    final names = <String>[];
    for (final t in tags) {
      if (t is Map) {
        final tagAttrs = t['attributes'] as Map<String, dynamic>?;
        final nameMap = tagAttrs?['name'] as Map<String, dynamic>?;
        final name = nameMap?['en'] as String?;
        if (name != null && name.isNotEmpty) {
          names.add(name);
          if (names.length >= 8) break;
        }
      }
    }
    return names;
  }

  /// Normalise language codes from Comick API values to MangaDex values.
  /// Comick uses `jp`, `cn`; MangaDex uses `ja`, `zh`.
  static String? _normaliseLang(String? lang) {
    if (lang == null || lang.isEmpty) return null;
    switch (lang) {
      case 'jp':
        return 'ja';
      case 'cn':
        return 'zh';
      default:
        return lang;
    }
  }

  /// Map a single MangaDex API manga data object to [MangaItem].
  MangaItem _mapMangaItem(Map<String, dynamic> data) {
    final mangaId = data['id'] as String? ?? '';
    final attrs = data['attributes'] as Map<String, dynamic>? ?? {};
    final relationships = data['relationships'] as List?;
    final rating = attrs['rating'] as Map<String, dynamic>?;

    // Extract alt titles for fallback matching on other sources
    final altTitlesRaw = attrs['altTitles'] as List?;
    final altTitles = <String>[];
    if (altTitlesRaw != null) {
      for (final alt in altTitlesRaw) {
        if (alt is Map) {
          for (final v in alt.values) {
            if (v is String && v.isNotEmpty && !altTitles.contains(v)) {
              altTitles.add(v);
            }
          }
        }
      }
    }

    return MangaItem(
      id: '',
      mangaId: mangaId,
      mangaKakalotId: mangaId,
      title: _extractTitle(attrs),
      description: _extractDescription(attrs),
      coverUrl: _coverUrl(mangaId, relationships),
      year: (attrs['year'] as int?)?.toString() ?? '',
      status: _mapStatus(attrs['status'] as String?),
      originalLanguage: attrs['originalLanguage'] as String? ?? 'ja',
      tags: _extractTags(attrs['tags'] as List?),
      addedAt: DateTime.now(),
      rating: (rating?['bayesian'] as num?)?.toDouble() ?? 0,
      followCount: attrs['followedCount'] as int? ?? 0,
      altTitles: altTitles,
    );
  }

  /// Search MangaDex by title.
  ///
  /// [originalLanguage] filters by original language (`ja`/`ko`/`zh`).
  /// Pass `jp` as shorthand for `ja`.
  Future<List<MangaItem>> search({
    required String query,
    String? originalLanguage,
    int limit = 20,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];
    final offset = (page - 1) * limit;
    final lang = _normaliseLang(originalLanguage);
    final buf = StringBuffer('manga?title=${Uri.encodeQueryComponent(query)}'
        '&limit=$limit&offset=$offset'
        '&includes[]=cover_art'
        '&order[followedCount]=desc'
        '&contentRating[]=safe'
        '&contentRating[]=suggestive'
        '&contentRating[]=erotica');
    if (lang != null && lang.isNotEmpty) {
      buf.write('&originalLanguage[]=$lang');
    }
    try {
      final headers = await _authHeaders();
      final response = await http.get(_proxied(buf.toString()), headers: headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapMangaItem)
            .toList();
      }
    } catch (e) {
      Logger.e('MangaDex search error', error: e);
    }
    return [];
  }

  /// Fetch popular manga, optionally filtered by [originalLanguage].
  Future<List<MangaItem>> fetchPopular({
    String? originalLanguage,
    int limit = 20,
    int page = 1,
  }) async {
    final offset = (page - 1) * limit;
    final lang = _normaliseLang(originalLanguage);
    final buf = StringBuffer('manga?limit=$limit&offset=$offset'
        '&includes[]=cover_art'
        '&order[followedCount]=desc'
        '&contentRating[]=safe'
        '&contentRating[]=suggestive'
        '&contentRating[]=erotica');
    if (lang != null && lang.isNotEmpty) {
      buf.write('&originalLanguage[]=$lang');
    }
    try {
      final headers = await _authHeaders();
      final response = await http.get(_proxied(buf.toString()), headers: headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapMangaItem)
            .toList();
      }
    } catch (e) {
      Logger.e('MangaDex popular error', error: e);
    }
    return [];
  }

  /// Fetch latest updated manga, optionally filtered by [originalLanguage].
  Future<List<MangaItem>> fetchLatest({
    String? originalLanguage,
    int limit = 20,
    int page = 1,
  }) async {
    final offset = (page - 1) * limit;
    final lang = _normaliseLang(originalLanguage);
    final buf = StringBuffer('manga?limit=$limit&offset=$offset'
        '&includes[]=cover_art'
        '&order[latestUploadedChapter]=desc'
        '&contentRating[]=safe'
        '&contentRating[]=suggestive'
        '&contentRating[]=erotica');
    if (lang != null && lang.isNotEmpty) {
      buf.write('&originalLanguage[]=$lang');
    }
    try {
      final headers = await _authHeaders();
      final response = await http.get(_proxied(buf.toString()), headers: headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapMangaItem)
            .toList();
      }
    } catch (e) {
      Logger.e('MangaDex latest error', error: e);
    }
    return [];
  }

  // ── PAGE IMAGES ────────────────────────────────────────────

  /// Resolve page image URLs for a MangaDex chapter by its UUID.
  /// Hits the at-home server endpoint, then builds full-quality
  /// image URLs that are routed through `proxyMangaImage` for CORS.
  Future<MangaChapterPages?> getChapterPages(String chapterId) async {
    if (chapterId.isEmpty) return null;
    final path = 'at-home/server/$chapterId?forcePort443=false';
    try {
      final headers = await _authHeaders();
      final response = await http.get(_proxied(path), headers: headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return null;
        final baseUrl = body['baseUrl'] as String? ?? '';
        final chapter = body['chapter'] as Map<String, dynamic>?;
        if (chapter == null) return null;
        final hash = chapter['hash'] as String? ?? '';
        final filenames =
            (chapter['data'] as List?)?.whereType<String>().toList() ??
                const [];
        if (filenames.isEmpty) return null;
        return MangaChapterPages(
          chapterId: chapterId,
          baseUrl: baseUrl,
          hash: hash,
          filenames: filenames,
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
      }
    } catch (e) {
      Logger.e('MangaDex chapter pages error', error: e);
    }
    return null;
  }

  /// Resolve page image URLs for a chapter, automatically proxying
  /// each image URL through `proxyMangaImage` for CORS-free display.
  Future<MangaChapterPages?> getChapterPagesProxied(
      String chapterId) async {
    final pages = await getChapterPages(chapterId);
    if (pages == null) return null;
    // Replace direct URLs with proxied ones
    final proxiedFilenames = pages.filenames.map((f) {
      final directUrl = pages.urlForPage(pages.filenames.indexOf(f));
      return proxiedImageUrl(directUrl);
    }).toList();
    return MangaChapterPages(
      chapterId: pages.chapterId,
      baseUrl: '', // URLs are now fully proxied, not relative
      hash: '',
      filenames: proxiedFilenames,
      expiresAt: pages.expiresAt,
    );
  }
}
