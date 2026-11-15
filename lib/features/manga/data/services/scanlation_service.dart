import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/connectivity_aware.dart';
import '../models/manga_item.dart';
import '../models/chapter_num.dart';
import '../../../../core/utils/logger.dart';

class ScanlationService with ConnectivityAware {
  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyScanlation';

  static const String _proxyHtmlUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';

  static final ScanlationService _instance = ScanlationService._internal();
  factory ScanlationService() => _instance;
  ScanlationService._internal();

  Future<Map<String, String>> _authHeaders() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {..._headers, 'Authorization': 'Bearer $token'};
      }
    } catch (e, st) {
      Logger.e(
        'ScanlationService: failed to get auth token, falling back unsigned',
        error: e,
        stackTrace: st,
      );
    }
    return _headers;
  }

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml',
  };

  static const List<_ScanSite> _sites = [
    _ScanSite(
      name: 'AsuraScans',
      baseUrl: 'https://asurascans.com',
      seriesPath: '/manga/',
      chapterHrefRe:
          r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header', 'discord'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'ReaperScans',
      baseUrl: 'https://reaperscans.com',
      seriesPath: '/series/',
      chapterHrefRe:
          r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'ArcaneScans',
      baseUrl: 'https://arcanescans.com',
      seriesPath: '/series/',
      chapterHrefRe:
          r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'FlameScans',
      baseUrl: 'https://flamescans.org',
      seriesPath: '/series/',
      chapterHrefRe:
          r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'LuminousScans',
      baseUrl: 'https://luminousscans.com',
      seriesPath: '/series/',
      chapterHrefRe:
          r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
    _ScanSite(
      name: 'VoidScans',
      baseUrl: 'https://void-scans.com',
      seriesPath: '/series/',
      chapterHrefRe:
          r'<a[^>]*href="(https?://[^"]*?(?:chapter|ch)[-_][^"]*?\d+[^"]*?)"[^>]*>',
      chapterNumRe: r'(?:chapter|ch)[-_](\d+(?:[.]\d+)?)',
      imgSrcRe: r'<img[^>]*src="(https?://[^"]+)"[^>]*>',
      imgExclude: ['avatar', 'logo', 'icon', 'banner', 'header'],
      readerApiPath: null,
    ),
  ];

  Future<Map<String, String>> searchAll(String title) async {
    final query = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final entries = await Future.wait(
      _sites.map((site) async {
        try {
          final slug = await _searchSite(site, query);
          if (slug.isNotEmpty) return MapEntry(site.name, slug);
        } catch (e) {
          debugPrint('[ScanlationService] Trying next source: $e');
        }
        return null;
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<String, String>>());
  }

  Future<List<MangaChapter>> getChapterFeedFromAll(
    Map<String, String> siteSlugs,
  ) async {
    final entries = siteSlugs.entries.toList();
    final perSite = await Future.wait(
      entries.map((entry) async {
        final site = _findSite(entry.key);
        if (site == null) return const <MangaChapter>[];
        try {
          return await _getChapters(site, entry.value);
        } catch (e) {
          debugPrint('[ScanlationService] Trying next source: $e');
          return const <MangaChapter>[];
        }
      }),
    );
    final all = <MangaChapter>[];
    final seen = <String>{};
    for (var i = 0; i < perSite.length; i++) {
      for (final c in perSite[i]) {
        final key = '${entries[i].key}:${c.chapter}';
        if (seen.add(key)) all.add(c);
      }
    }
    all.sort((a, b) {
      final na = chapterNumValue(a.chapter);
      final nb = chapterNumValue(b.chapter);
      return nb.compareTo(na);
    });
    return all;
  }

  Future<MangaChapterPages?> getChapterPages(
    String siteName,
    String chapterUrl,
  ) async {
    final site = _findSite(siteName);
    if (site == null) return null;
    try {
      final urls = await _getPageImages(site, chapterUrl);
      if (urls.isEmpty) return null;
      final proxied = urls.map(proxiedImageUrl).toList();
      return MangaChapterPages(
        chapterId: chapterUrl,
        baseUrl: '',
        hash: '',
        filenames: proxied,
        expiresAt: DateTime.now().add(const Duration(minutes: 14)),
      );
    } catch (e, st) {
      Logger.e(
        'ScanlationService: failed to resolve chapter pages for '
        '$siteName $chapterUrl',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<MangaChapterPages?> getChapterPagesFromAll(
    Map<String, String> siteSlugs,
    String chapterNumber,
  ) async {
    final normalizedTarget = normalizeChapterNum(chapterNumber);
    for (final entry in siteSlugs.entries) {
      final site = _findSite(entry.key);
      if (site == null) continue;
      try {
        final chapters = await _getChapters(site, entry.value);
        MangaChapter? match;
        for (final c in chapters) {
          if (normalizeChapterNum(c.chapter) == normalizedTarget) {
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

  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }

  Uri _proxiedFetch(Uri uri) {
    return Uri.parse(
      '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}',
    );
  }

  _ScanSite? _findSite(String name) {
    try {
      return _sites.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  Future<String> _searchSite(_ScanSite site, String query) async {
    final searchUrls = [
      '${site.baseUrl}/?s=${Uri.encodeComponent(query)}',
      '${site.baseUrl}/?search=${Uri.encodeComponent(query)}',
      '${site.baseUrl}/search?q=${Uri.encodeComponent(query)}',
    ];

    for (final searchUrl in searchUrls) {
      try {
        final headers = await _authHeaders();
        final response = await http
            .get(_proxiedFetch(Uri.parse(searchUrl)), headers: headers)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;

        final linkRe = RegExp(
          r'<a[^>]*href="(' +
              RegExp.escape(site.baseUrl) +
              r'/[^"]*?/[^"]*?)"[^>]*>',
          caseSensitive: false,
        );
        final matches = linkRe.allMatches(response.body);
        for (final m in matches) {
          final href = m.group(1) ?? '';
          if (href.contains(site.seriesPath) &&
              !RegExp(
                r'chapter|ch[-_]?\d',
                caseSensitive: false,
              ).hasMatch(href)) {
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

    return '';
  }

  Future<List<MangaChapter>> _getChapters(_ScanSite site, String slug) async {
    final url = '${site.baseUrl}${site.seriesPath}$slug/';
    final headers = await _authHeaders();
    final response = await http
        .get(_proxiedFetch(Uri.parse(url)), headers: headers)
        .timeout(const Duration(seconds: 8));
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

      String title = '';
      final fullMatch = m.group(0) ?? '';
      final textMatch = RegExp(
        r'>([^<]+)<',
      ).firstMatch(fullMatch.substring(fullMatch.indexOf(href) + href.length));
      if (textMatch != null) {
        title = textMatch.group(1)?.trim() ?? '';
      }

      chapters.add(
        MangaChapter(
          id: href,
          title: title,
          chapter: chapterNum,
          volume: '',
          pages: 0,
          translatedLanguage: 'en',
          scanlationGroup: site.name,
          publishAt: DateTime.now(),
        ),
      );
    }

    return chapters;
  }

  Future<List<String>> _getPageImages(_ScanSite site, String chapterUrl) async {
    final uri = chapterUrl.startsWith('http')
        ? Uri.parse(chapterUrl)
        : Uri.parse('${site.baseUrl}/$chapterUrl');
    final headers = await _authHeaders();
    final response = await http
        .get(_proxiedFetch(uri), headers: headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final imgRe = RegExp(site.imgSrcRe, caseSensitive: false);
    final excludeRe = RegExp(site.imgExclude.join('|'), caseSensitive: false);

    final urls = <String>[];
    for (final m in imgRe.allMatches(response.body)) {
      final src = (m.group(1) ?? '').trim();
      if (src.isEmpty) continue;
      if (!RegExp(
        r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)',
        caseSensitive: false,
      ).hasMatch(src)) {
        continue;
      }
      if (excludeRe.hasMatch(src)) continue;
      urls.add(src);
    }

    if (urls.isEmpty) {
      final broadRe = RegExp(
        '<img[^>]*\\s+src\\s*=\\s*["\']([^"\']+)["\']',
        caseSensitive: false,
      );
      for (final m in broadRe.allMatches(response.body)) {
        final src = (m.group(1) ?? '').trim();
        if (src.isEmpty) continue;
        if (!RegExp(
          r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)',
          caseSensitive: false,
        ).hasMatch(src)) {
          continue;
        }
        if (excludeRe.hasMatch(src)) continue;

        String fullSrc = src;
        if (src.startsWith('//')) {
          fullSrc = 'https:$src';
        } else if (!src.startsWith('http')) {
          fullSrc = '${site.baseUrl}/${src.replaceFirst(RegExp(r'^/+'), '')}';
        }
        urls.add(fullSrc);
      }
    }

    final seen = <String>{};
    return urls.where((u) => seen.add(u)).toList();
  }
}

class _ScanSite {
  final String name;
  final String baseUrl;

  final String seriesPath;

  final String chapterHrefRe;

  final String chapterNumRe;

  final String imgSrcRe;

  final List<String> imgExclude;

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
