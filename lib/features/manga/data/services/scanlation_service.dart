import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:everglow/core/utils/connectivity_aware.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Scrapes scanlation-group websites for chapter lists and page images.
/// Each supported site is defined as a [_ScanSite] with URL patterns
/// and regex selectors tailored to that site's HTML structure.
///
/// Catalogue discovery stays with [ComickService]; this service is a
/// fallback for titles not found on Comick / MangaDex / MangaKakalot,
/// and a primary source for the fastest chapter releases.
///
/// Supported providers (in priority order):
///   1. AsuraScans   (asurascans.com)
///   2. ReaperScans  (reaperscans.com)
///   3. ArcaneScans  (arcanescans.com)
///   4. FlameScans   (flamescans.org)
///   5. LuminousScans(luminousscans.com)
///   6. VoidScans    (void-scans.com)
class ScanlationService with ConnectivityAware {
  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyScanlation';

  // Singleton
  static final ScanlationService _instance = ScanlationService._internal();
  factory ScanlationService() => _instance;
  ScanlationService._internal();

  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      };

  // ── PROVIDER DEFINITIONS ──────────────────────────────────

  static const List<_ScanSite> _sites = [
    _ScanSite(
      name: 'AsuraScans',
      baseUrl: 'https://asurascans.com',
      // Series page: https://asurascans.com/manga/{slug}/
      seriesPath: '/manga/',
      // Chapter link regex — looks for <a> inside chapter list items
      chapterHrefRe: r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      // Image regex for chapter pages
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header', 'discord'],
      // Some Asura chapters use a reader API
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'ReaperScans',
      baseUrl: 'https://reaperscans.com',
      seriesPath: '/series/',
      chapterHrefRe: r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'ArcaneScans',
      baseUrl: 'https://arcanescans.com',
      seriesPath: '/series/',
      chapterHrefRe: r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'FlameScans',
      baseUrl: 'https://flamescans.org',
      seriesPath: '/series/',
      chapterHrefRe: r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'LuminousScans',
      baseUrl: 'https://luminousscans.com',
      seriesPath: '/series/',
      chapterHrefRe: r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'VoidScans',
      baseUrl: 'https://void-scans.com',
      seriesPath: '/series/',
      chapterHrefRe: r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
  ];

  // ── PUBLIC API ────────────────────────────────────────────

  /// Search all scanlation sites for a series matching [title].
  /// Returns a map of site name → page URL (slug) for sites that
  /// have the series. Empty map means not found anywhere.
  Future<Map<String, String>> searchAll(String title) async {
    final results = <String, String>{};
    final query = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    for (final site in _sites) {
      try {
        final slug = await _searchSite(site, query);
        if (slug.isNotEmpty) {
          results[site.name] = slug;
        }
      } catch (e) {
        debugPrint('[ScanlationService] Trying next source: $e');
      }
    }
    return results;
  }

  /// Fetch chapters from all scanlation sites. Returns a combined
  /// list deduplicated by chapter number, ordered descending.
  Future<List<MangaChapter>> getChapterFeedFromAll(
      Map<String, String> siteSlugs) async {
    final all = <MangaChapter>[];
    final seen = <String>{};
    for (final entry in siteSlugs.entries) {
      final site = _findSite(entry.key);
      if (site == null) continue;
      try {
        final chapters = await _getChapters(site, entry.value);
        for (final c in chapters) {
          final key = '${site.name}:${c.chapter}';
          if (seen.add(key)) all.add(c);
        }
      } catch (e) {
        debugPrint('[ScanlationService] Trying next source: $e');
      }
    }
    all.sort((a, b) {
      final na = double.tryParse(a.chapter) ?? 0;
      final nb = double.tryParse(b.chapter) ?? 0;
      return nb.compareTo(na); // newest first
    });
    return all;
  }

  /// Resolve page image URLs for a chapter on a specific site.
  /// [chapterUrl] is the full URL to the chapter page.
  Future<MangaChapterPages?> getChapterPages(
      String siteName, String chapterUrl) async {
    final site = _findSite(siteName);
    if (site == null) return null;
    try {
      final urls = await _getPageImages(site, chapterUrl);
      if (urls.isEmpty) return null;
      // Pre-proxy all image URLs
      final proxied = urls.map(proxiedImageUrl).toList();
      return MangaChapterPages(
        chapterId: chapterUrl,
        baseUrl: '',
        hash: '',
        filenames: proxied,
        expiresAt: DateTime.now().add(const Duration(minutes: 14)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolve pages for a chapter by searching across all known
  /// site slugs. Returns pages from the first site that responds.
  Future<MangaChapterPages?> getChapterPagesFromAll(
      Map<String, String> siteSlugs, String chapterNumber) async {
    for (final entry in siteSlugs.entries) {
      final site = _findSite(entry.key);
      if (site == null) continue;
      try {
        // Fetch chapter list to find the chapter URL
        final chapters = await _getChapters(site, entry.value);
        MangaChapter? match;
        for (final c in chapters) {
          if (c.chapter == chapterNumber) {
            match = c;
            break;
          }
        }
        if (match != null) {
          final pages = await getChapterPages(site.name, match.id);
          if (pages != null && pages.filenames.isNotEmpty) return pages;
        }
      } catch (e) {
        debugPrint('[ScanlationService] Trying next source: $e');
      }
    }
    return null;
  }

  /// Transform a raw image URL into a CORS-safe proxied URL.
  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }

  // ── INTERNAL SCRAPING ─────────────────────────────────────

  _ScanSite? _findSite(String name) {
    try {
      return _sites.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Try to find a series on a site by searching its listing.
  /// Returns the series slug (URL path) if found.
  Future<String> _searchSite(_ScanSite site, String query) async {
    // Try common search URL patterns
    final searchUrls = [
      '${site.baseUrl}/?s=${Uri.encodeComponent(query)}',
      '${site.baseUrl}/search?q=${Uri.encodeComponent(query)}',
    ];

    for (final searchUrl in searchUrls) {
      try {
        final response =
            await http.get(Uri.parse(searchUrl), headers: _headers).timeout(
                  const Duration(seconds: 8),
                );
        if (response.statusCode != 200) continue;

        // Look for series links in search results
        final linkRe = RegExp(
          r'<a[^>]*href="(' +
              RegExp.escape(site.baseUrl) +
              r'/[^"]*?/[^"]*?)"[^>]*>',
          caseSensitive: false,
        );
        final matches = linkRe.allMatches(response.body);
        for (final m in matches) {
          final href = m.group(1) ?? '';
          // Filter to series paths (not chapters or other pages)
          if (href.contains(site.seriesPath) &&
              !RegExp(r'chapter|ch[-_]?\d', caseSensitive: false)
                  .hasMatch(href)) {
            // Extract slug from URL
            final slug = href
                .replaceFirst(site.baseUrl, '')
                .replaceFirst(site.seriesPath, '')
                .replaceAll(RegExp(r'/+$'), '');
            if (slug.isNotEmpty) return slug;
          }
        }
      } catch (e) {
        debugPrint('[ScanlationService] Trying next URL: $e');
      }
    }

    // Fallback: guess the slug from the title
    return query
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^\w-]'), '')
        .toLowerCase();
  }

  /// Scrape a series page for its chapter list.
  Future<List<MangaChapter>> _getChapters(
      _ScanSite site, String slug) async {
    final url = '${site.baseUrl}${site.seriesPath}$slug/';
    final response = await http.get(Uri.parse(url), headers: _headers).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) return [];

    final chapters = <MangaChapter>[];
    final linkRe = RegExp(site.chapterHrefRe, caseSensitive: false);
    final numRe = RegExp(site.chapterNumRe, caseSensitive: false);
    final seen = <String>{};

    for (final m in linkRe.allMatches(response.body)) {
      final href = (m.group(1) ?? '').trim();
      if (href.isEmpty || !seen.add(href)) continue;

      final numMatch = numRe.firstMatch(href);
      final chapterNum = numMatch?.group(1) ?? '';

      // Try to get chapter title from link text
      String title = '';
      final fullMatch = m.group(0) ?? '';
      final textMatch =
          RegExp(r'>([^<]+)<').firstMatch(fullMatch.substring(fullMatch.indexOf(href) + href.length));
      if (textMatch != null) {
        title = textMatch.group(1)?.trim() ?? '';
      }

      chapters.add(MangaChapter(
        id: href,
        title: title,
        chapter: chapterNum,
        volume: '',
        pages: 0,
        translatedLanguage: 'en',
        scanlationGroup: site.name,
        publishAt: DateTime.now(),
      ));
    }

    return chapters;
  }

  /// Scrape a chapter page for image URLs.
  Future<List<String>> _getPageImages(
      _ScanSite site, String chapterUrl) async {
    final uri = chapterUrl.startsWith('http')
        ? Uri.parse(chapterUrl)
        : Uri.parse('${site.baseUrl}/$chapterUrl');
    final response = await http.get(uri, headers: _headers).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) return [];

    final imgRe = RegExp(site.imgSrcRe, caseSensitive: false);
    final excludeRe = RegExp(
      site.imgExclude.join('|'),
      caseSensitive: false,
    );

    final urls = <String>[];
    for (final m in imgRe.allMatches(response.body)) {
      final src = (m.group(1) ?? '').trim();
      if (src.isEmpty) continue;
      // Skip non-image URLs
      if (!RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)', caseSensitive: false)
          .hasMatch(src)) {
        continue;
      }
      // Skip excluded patterns (logos, avatars, etc.)
      if (excludeRe.hasMatch(src)) continue;
      urls.add(src);
    }

    // If no images found with the primary regex, try broader patterns
    if (urls.isEmpty) {
      final broadRe = RegExp(
        '<img[^>]*\\s+src\\s*=\\s*["\']([^"\']+)["\']',
        caseSensitive: false,
      );
      for (final m in broadRe.allMatches(response.body)) {
        final src = (m.group(1) ?? '').trim();
        if (src.isEmpty) continue;
        if (!RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)',
                caseSensitive: false)
            .hasMatch(src)) continue;
        if (excludeRe.hasMatch(src)) continue;

        // Handle protocol-relative URLs
        String fullSrc = src;
        if (src.startsWith('//')) {
          fullSrc = 'https:$src';
        } else if (!src.startsWith('http')) {
          fullSrc = '${site.baseUrl}/${src.replaceFirst(RegExp(r'^/+'), '')}';
        }
        urls.add(fullSrc);
      }
    }

    // Deduplicate while preserving order
    final seen = <String>{};
    return urls.where((u) => seen.add(u)).toList();
  }
}

/// Configuration for a single scanlation site.
class _ScanSite {
  final String name;
  final String baseUrl;

  /// Path prefix for series pages (e.g. "/manga/" or "/series/").
  final String seriesPath;

  /// Regex to extract chapter links from a series page.
  /// Must capture the full chapter URL in group 1.
  final String chapterHrefRe;

  /// Regex to extract the chapter number from a chapter URL.
  /// Must capture the number in group 1.
  final String chapterNumRe;

  /// Regex to extract image src URLs from a chapter page.
  /// Must capture the URL in group 1.
  final String imgSrcRe;

  /// Substrings that disqualify an image URL (logos, avatars, etc.).
  final List<String> imgExclude;

  /// Optional path for a JSON reader API (e.g. /api/reader/).
  final String? readerApiPath;

  const _ScanSite({
    required this.name,
    required this.baseUrl,
    required this.seriesPath,
    required this.chapterHrefRe,
    required this.chapterNumRe,
    required this.imgSrcRe,
    this.imgExclude = const [],
    this.readerApiPath,
  });
}
