import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Scrapes mangasee123.com for chapter page images. MangaSee123 is a
/// manga aggregator that ComicK itself uses as a source. This service
/// serves as a fallback when MangaDex, MangaKakalot, and Bato.to
/// don't have the chapter.
///
/// Site structure:
///   * Series page  — `GET /manga/{slug}`
///   * Chapter page — `GET /read-online/{slug}-chapter-{num}.html`
///
/// Images are typically served from `scans-hot.xyz` or similar CDNs.
/// MangaSee123 loads images via JavaScript, so we extract them from
/// embedded JSON data or page scripts.
class MangaSee123Service {
  static const String _baseUrl = 'https://mangasee123.com';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyScanlation';

  // Singleton
  static final MangaSee123Service _instance = MangaSee123Service._internal();
  factory MangaSee123Service() => _instance;
  MangaSee123Service._internal();

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
  };

  final Map<String, MangaChapterPages> _pageCache = {};

  /// Search MangaSee123 by title and return the series slug.
  Future<String> searchByTitle(String title) async {
    if (title.trim().isEmpty) return '';
    // MangaSee123 has a search API
    final query = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final uri = Uri.parse(
      '$_baseUrl/_search.php?q=${Uri.encodeComponent(query)}',
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isNotEmpty && body != '[]') {
          final List results = json.decode(body);
          if (results.isNotEmpty) {
            final first = results.first;
            if (first is Map) {
              return first['s'] ?? '';
            }
          }
        }
      }
    } catch (_) { /* not found */ }
    return '';
  }

  /// Get chapter page images from MangaSee123.
  /// [slug] is the series slug (e.g. "The-Greatest-Estate-Developer").
  /// [chapter] is the chapter number (e.g. "1").
  Future<MangaChapterPages?> getChapterPages(
    String slug,
    String chapter,
  ) async {
    final cacheKey = '$slug::chapter-$chapter';
    final cached = _pageCache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }

    // Parse chapter number to zero-padded format MangaSee123 uses
    final chapNum = double.tryParse(chapter) ?? 0;
    final formatted = chapNum == chapNum.roundToDouble()
        ? chapNum.round().toString().padLeft(4, '0')
        : chapNum.toStringAsFixed(1).padLeft(6, '0');

    final chapterUrl =
        '$_baseUrl/read-online/$slug-chapter-$formatted-page-1.html';
    try {
      final response = await http.get(
        Uri.parse(chapterUrl),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final urls = <String>[];

        // Method 1: Look for embedded JSON-LD with image data
        final jsonLdRe = RegExp(
          r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
          caseSensitive: false,
          dotAll: true,
        );
        for (final m in jsonLdRe.allMatches(response.body)) {
          try {
            final data = json.decode(m.group(1) ?? '{}');
            if (data is Map) {
              final images = data['image'] ?? data['images'];
              if (images is List) {
                for (final img in images) {
                  if (img is String && img.isNotEmpty) urls.add(img);
                }
              }
            }
          } catch (_) { /* ignore parse errors */ }
        }

        // Method 2: Look for CurlReading/PrefetchImages script variables
        if (urls.isEmpty) {
          final imgRe = RegExp(
            r'(?:CurlReading|PrefetchImages|vm\.CurlyImages)\s*=\s*([^;]+)',
            caseSensitive: false,
          );
          for (final m in imgRe.allMatches(response.body)) {
            try {
              final raw = m.group(1) ?? '[]';
              final List parsed = json.decode(raw);
              for (final item in parsed) {
                if (item is String && item.isNotEmpty) {
                  // The image URL may be a relative path
                  final fullUrl = item.startsWith('http')
                      ? item
                      : 'https://scans-hot.xyz/manga/$slug/$formatted/$item';
                  urls.add(fullUrl);
                } else if (item is Map) {
                  final src = item['src'] ?? item['url'] ?? '';
                  if (src is String && src.isNotEmpty) {
                    urls.add(src.startsWith('http') ? src : 'https://scans-hot.xyz/$src');
                  }
                }
              }
            } catch (_) { /* ignore parse errors */ }
          }
        }

        // Method 3: Fallback to standard img tags
        if (urls.isEmpty) {
          const imgRe = r'<img[^>]*src="(https?://[^"]+)"[^>]*>';
          for (final m in RegExp(imgRe, caseSensitive: false)
              .allMatches(response.body)) {
            final src = (m.group(1) ?? '').trim();
            if (src.isEmpty) continue;
            if (!RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)',
                    caseSensitive: false)
                .hasMatch(src)) continue;
            urls.add(src);
          }
        }

        if (urls.isEmpty) return null;

        // Deduplicate
        final seen = <String>{};
        final unique = urls.where((u) => seen.add(u)).toList();

        // Pre-proxy image URLs
        final proxied = unique.map(proxiedImageUrl).toList();
        final result = MangaChapterPages(
          chapterId: cacheKey,
          baseUrl: '',
          hash: '',
          filenames: proxied,
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
        _pageCache[cacheKey] = result;
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
