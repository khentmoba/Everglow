import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Scrapes bato.to for chapter page images. Bato.to is a manga
/// aggregator that ComicK itself uses as a source. This service
/// serves as a fallback when MangaDex and MangaKakalot don't have
/// the chapter.
///
/// Site structure:
///   * Search       — `GET /search?q={title}`
///   * Series page  — `GET /title/{slug}`
///   * Chapter page — `GET /title/{slug}/{chapterId}` or `GET /chapter/{id}`
///
/// Images are typically served from `img.bato.to` CDN.
class BatoService {
  static const String _baseUrl = 'https://bato.to';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyScanlation';

  // Singleton
  static final BatoService _instance = BatoService._internal();
  factory BatoService() => _instance;
  BatoService._internal();

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
  };

  final Map<String, MangaChapterPages> _pageCache = {};

  /// Search Bato.to by title and return the first matching series slug.
  Future<String> searchByTitle(String title) async {
    if (title.trim().isEmpty) return '';
    final uri = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(title)}');
    try {
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode == 200) {
        // Look for series links matching /title/{slug}
        final linkRe = RegExp(
          r'<a[^>]*href="(/title/[^"]+)"[^>]*>',
          caseSensitive: false,
        );
        final matches = linkRe.allMatches(response.body);
        for (final m in matches) {
          final href = m.group(1) ?? '';
          if (href.startsWith('/title/')) {
            return href.replaceFirst('/title/', '');
          }
        }
      }
    } catch (_) { /* not found */ }
    return '';
  }

  /// Scrape a chapter page for image URLs.
  /// [chapterPath] is the URL path (e.g. "/title/{slug}/chapter-1").
  Future<MangaChapterPages?> getChapterPages(String chapterPath) async {
    final cached = _pageCache[chapterPath];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }

    final url = chapterPath.startsWith('http')
        ? chapterPath
        : '$_baseUrl$chapterPath';
    try {
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        final imgRe = RegExp(
          r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
          caseSensitive: false,
        );
        final matches = imgRe.allMatches(response.body);
        final urls = <String>[];
        final excludeRe = RegExp(
          r'avatar|logo|icon|banner|header|discord',
          caseSensitive: false,
        );
        for (final m in matches) {
          final src = (m.group(1) ?? '').trim();
          if (src.isEmpty) continue;
          if (!RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)', caseSensitive: false)
              .hasMatch(src)) continue;
          if (excludeRe.hasMatch(src)) continue;
          urls.add(src);
        }
        if (urls.isEmpty) return null;

        // Pre-proxy image URLs
        final proxied = urls.map(proxiedImageUrl).toList();
        final result = MangaChapterPages(
          chapterId: chapterPath,
          baseUrl: '',
          hash: '',
          filenames: proxied,
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
        _pageCache[chapterPath] = result;
        return result;
      }
    } catch (_) { /* failed */ }
    return null;
  }

  /// Transform a raw image URL into a CORS-safe proxied URL.
  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }
}
