import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/connectivity_aware.dart';
import '../models/manga_item.dart';
import '../../../../core/utils/logger.dart';

class BatoService with ConnectivityAware {
  static const String _baseUrl = 'https://bato.to';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyScanlation';

  static const String _proxyHtmlUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';

  static final BatoService _instance = BatoService._internal();
  factory BatoService() => _instance;
  BatoService._internal();

  Future<Map<String, String>> _authHeaders() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {..._headers, 'Authorization': 'Bearer $token'};
      }
    } catch (e, st) {
      Logger.e(
        'BatoService: failed to get auth token, falling back unsigned',
        error: e,
        stackTrace: st,
      );
    }
    return _headers;
  }

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
  };

  final Map<String, MangaChapterPages> _pageCache = {};

  Uri _proxiedFetch(Uri uri) {
    return Uri.parse(
      '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}',
    );
  }

  Future<String> searchByTitle(String title) async {
    if (title.trim().isEmpty) return '';
    final uri = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(title)}');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxiedFetch(uri), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
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
    } catch (e) {
      debugPrint('[BatoService] Failed to find series ID: $e');
    }
    return '';
  }

  Future<List<MangaChapter>> getChapterFeed(String slug) async {
    if (slug.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/title/$slug');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxiedFetch(uri), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return _parseChapterList(response.body, slug);
      }
    } catch (e) {
      Logger.e('Bato.to chapter feed error', error: e);
    }
    return [];
  }

  List<MangaChapter> _parseChapterList(String html, String slug) {
    final chapters = <MangaChapter>[];
    final linkRe = RegExp(
      r'<a[^>]*href="(/(?:title/[^"]*?/chapter-[^"]+|chapter/\d+))"[^>]*>',
      caseSensitive: false,
    );
    final textRe = RegExp(r'>([^<]+)<');
    final numRe = RegExp(r'chapter[_\s-]?([\d.]+)', caseSensitive: false);
    final seen = <String>{};

    for (final m in linkRe.allMatches(html)) {
      final href = m.group(1)?.trim() ?? '';
      if (href.isEmpty || !seen.add(href)) continue;
      if (slug.isNotEmpty &&
          href.startsWith('/title/') &&
          !href.contains(slug)) {
        continue;
      }

      String chapterNum = '';
      String title = '';
      final fullMatch = m.group(0) ?? '';
      final textMatch = textRe.firstMatch(fullMatch);
      if (textMatch != null) {
        title = textMatch.group(1)?.trim() ?? '';
        final numMatch = numRe.firstMatch(title);
        chapterNum = numMatch?.group(1) ?? '';
      }
      if (chapterNum.isEmpty) {
        final numMatch = numRe.firstMatch(href);
        chapterNum = numMatch?.group(1) ?? '';
      }

      chapters.add(
        MangaChapter(
          id: href,
          title: title,
          chapter: chapterNum,
          volume: '',
          pages: 0,
          translatedLanguage: 'en',
          scanlationGroup: 'Bato.to',
          publishAt: DateTime.now(),
        ),
      );
    }
    return chapters;
  }

  Future<MangaChapterPages?> getChapterPages(String chapterPath) async {
    final cached = _pageCache[chapterPath];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }

    final url = chapterPath.startsWith('http')
        ? chapterPath
        : '$_baseUrl$chapterPath';
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxiedFetch(Uri.parse(url)), headers: headers)
          .timeout(const Duration(seconds: 10));
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
          if (!RegExp(
            r'\.(jpg|jpeg|png|webp|gif|bmp)(\?|$)',
            caseSensitive: false,
          ).hasMatch(src)) {
            continue;
          }
          if (excludeRe.hasMatch(src)) continue;
          urls.add(src);
        }
        if (urls.isEmpty) return null;

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
    } catch (e) {
      debugPrint('[BatoService] Failed to fetch chapter pages: $e');
    }
    return null;
  }

  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }
}
