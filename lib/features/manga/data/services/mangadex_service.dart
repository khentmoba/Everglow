import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/features/manga/data/models/manga_item.dart';

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
class MangaDexService {
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

  /// Build a proxied URL for an API path (without leading slash).
  /// The path may include a query string, e.g.
  /// `manga/abc/feed?translatedLanguage[]=en`.
  Uri _proxied(String apiPath) {
    return Uri.parse('$_proxyUrl?path=${Uri.encodeComponent(apiPath)}');
  }

  /// Return a proxied image URL suitable for `Image.network`.
  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }

  // ── CHAPTER FEED ───────────────────────────────────────────

  /// Fetch the chapter list for a MangaDex manga by its UUID.
  /// Returns chapters sorted by chapter number (ascending), newest
  /// first so the reading order is natural.
  Future<List<MangaChapter>> getChapterFeed(
    String mangaId, {
    String language = 'en',
    int limit = 500,
    int offset = 0,
  }) async {
    if (mangaId.isEmpty) return [];
    // includes[]=scanlation_group gives us group names in relationships
    final path = 'manga/$mangaId/feed'
        '?translatedLanguage[]=$language'
        '&limit=$limit'
        '&offset=$offset'
        '&order[chapter]=asc'
        '&includes[]=scanlation_group'
        '&contentRating[]=safe'
        '&contentRating[]=suggestive'
        '&contentRating[]=erotica';
    try {
      final response = await http.get(_proxied(path), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data.whereType<Map<String, dynamic>>().map((d) {
          final attrs = d['attributes'] as Map<String, dynamic>? ?? {};
          final rels = d['relationships'] as List? ?? [];
          String group = '';
          for (final rel in rels) {
            if (rel is Map && rel['type'] == 'scanlation_group') {
              group =
                  (rel['attributes']?['name'] as String?) ?? '';
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
    } catch (e) {
      print('MangaDex chapter feed error: $e');
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
      final response = await http.get(_proxied(path), headers: _headers);
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
      print('MangaDex chapter pages error: $e');
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
