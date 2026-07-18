import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import '../../../../core/utils/logger.dart';

/// Scrapes mangakatana.com for chapter data and page images.
/// MangaKatana is a sister site to MangaKakalot with broader coverage,
/// especially for manhwa and manhua. It serves as a high-priority
/// fallback when MangaDex and MangaKakalot don't have chapters.
///
/// Site structure:
///   * Search       — `GET /?s={title}&search_type=title`
///   * Chapter list — `GET /manga/{slug}`
///   * Page images  — `GET /manga/{slug}/{chapterId}` (or similar)
class MangakatanaService with ConnectivityAware {
  static const String _baseUrl = 'https://mangakatana.com';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana';

  static const String _proxyHtmlUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';

  static final MangakatanaService _instance = MangakatanaService._internal();
  factory MangakatanaService() => _instance;
  MangakatanaService._internal();

  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      };

  final Map<String, MangaChapterPages> _pageCache = {};

  /// Rewrite a direct [Uri] through the [proxyFetchHtml] Cloud Function
  /// so the request works on Flutter Web (CORS-safe).
  Uri _proxiedFetch(Uri uri) {
    return Uri.parse(
        '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}');
  }

  /// Search MangaKatana by title and return the manga slug.
  Future<String> searchByTitle(String title) async {
    if (title.trim().isEmpty) return '';
    final uri = Uri.parse(
        '$_baseUrl/?s=${Uri.encodeComponent(title)}&search_type=title');
    try {
      final response = await http.get(_proxiedFetch(uri), headers: _headers).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode == 200) {
        final body = response.body;
        final hrefReg = RegExp(r'<a[^>]*href="([^"]*)"[^>]*>');
        final matches = hrefReg.allMatches(body);
        for (final m in matches) {
          final href = m.group(1) ?? '';
          if (href.contains('/manga/') && !href.contains('?s=')) {
            final slug = href.replaceFirst(RegExp(r'.*/manga/'), '');
            if (slug.isNotEmpty && !slug.contains('/')) {
              return slug;
            }
          }
        }
      }
    } catch (e) {
      Logger.e('Mangakatana searchByTitle error', error: e);
    }
    return '';
  }

  /// Scrape the manga detail page for its chapter list.
  /// [slug] is the MangaKatana slug (e.g. "that-time-i-got-reincarnated-as-a-slime").
  Future<List<MangaChapter>> getChapterFeed(String slug) async {
    if (slug.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/manga/$slug');
    try {
      final response = await http.get(_proxiedFetch(uri), headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        return _parseChapterList(response.body, slug);
      }
    } catch (e) {
      Logger.e('Mangakatana chapter feed error', error: e);
    }
    return [];
  }

  List<MangaChapter> _parseChapterList(String html, String slug) {
    final chapters = <MangaChapter>[];
    final linkReg = RegExp(
      r'<a[^>]*href="([^"]*?/manga/[^"]*?/chapter[^"]*)"[^>]*>([^<]*)',
      caseSensitive: false,
    );
    final matches = linkReg.allMatches(html);
    final seen = <String>{};
    for (final m in matches) {
      final href = m.group(1)?.trim() ?? '';
      final text = m.group(2)?.trim() ?? '';
      if (href.isEmpty || !seen.add(href)) continue;
      final id = href;
      final numMatch =
          RegExp(r'chapter[_\s-]?([\d.]+)', caseSensitive: false)
              .firstMatch(href);
      final chapterNum = numMatch?.group(1) ?? '';
      chapters.add(MangaChapter(
        id: id,
        title: text,
        chapter: chapterNum,
        volume: '',
        pages: 0,
        translatedLanguage: 'en',
        scanlationGroup: '',
        publishAt: DateTime.now(),
      ));
    }
    return chapters;
  }

  /// Scrape a chapter page for image URLs.
  /// [chapterUrl] is the full URL or path to the chapter page.
  Future<MangaChapterPages?> getChapterPages(String chapterUrl) async {
    final cached = _pageCache[chapterUrl];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }
    final url = chapterUrl.startsWith('http')
        ? chapterUrl
        : '$_baseUrl/$chapterUrl';
    try {
      final response = await http.get(_proxiedFetch(Uri.parse(url)), headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final urls = <String>[];
        final imgReg = RegExp(r'<img[^>]*src="([^"]+)"[^>]*>');
        final matches = imgReg.allMatches(response.body);
        for (final m in matches) {
          final src = m.group(1)?.trim() ?? '';
          if (src.isEmpty) continue;
          if (!RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)',
                  caseSensitive: false)
              .hasMatch(src)) continue;
          if (src.contains('ads') ||
              src.contains('logo') ||
              src.contains('icon') ||
              src.contains('banner')) continue;
          urls.add(src);
        }
        if (urls.isEmpty) return null;
        final result = MangaChapterPages(
          chapterId: chapterUrl,
          baseUrl: '',
          hash: '',
          filenames: urls,
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
        _pageCache[chapterUrl] = result;
        return result;
      }
    } catch (e) {
      Logger.e('Mangakatana chapter pages error', error: e);
    }
    return null;
  }

  String proxiedImageUrl(String pageUrl) {
    if (pageUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(pageUrl)}';
  }
}
