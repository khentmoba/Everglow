import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';

import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/katana_models.dart';

part 'katana_service_catalog.dart';
part 'katana_service_social.dart';
part 'katana_service_parse.dart';
part 'katana_service_format.dart';

class KatanaService {
  static const String _baseUrl = 'https://mangakatana.com';
  static const String _proxyHtmlUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';
  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKatana';

  static final KatanaService _instance = KatanaService._internal();
  factory KatanaService() => _instance;
  KatanaService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final HtmlUnescape _unescape = HtmlUnescape();

  static const Duration _timeout = Duration(seconds: 9);

  static const String chapterIdPattern = r'(?:v\d+)?c[^"/]+|fc';

  Map<String, String> get _headers => const {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  Future<Map<String, String>> _authHeaders() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {..._headers, 'Authorization': 'Bearer $token'};
      }
    } catch (e, st) {
      Logger.e(
        'KatanaService: failed to get auth token, falling back unsigned',
        error: e,
        stackTrace: st,
      );
    }
    return _headers;
  }

  Uri _proxiedFetch(Uri uri, {String cookie = ''}) {
    final base = '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}';
    if (cookie.isEmpty) return Uri.parse(base);
    return Uri.parse('$base&cookie=${Uri.encodeComponent(cookie)}');
  }

  static String rewriteAvifToWebp(String url) {
    if (url.isEmpty || !url.toLowerCase().contains('.avif')) return url;
    return url.replaceAll(
      RegExp(r'\.avif(?=$|[?&#])', caseSensitive: false),
      '.webp',
    );
  }

  static String proxyImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.toLowerCase().contains('mangakatana')) {
      url = rewriteAvifToWebp(url);
    }
    if (url.contains('proxyMangaKatana')) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    final host = uri.host.toLowerCase();
    final isAllowed =
        host == 'mangakatana.com' ||
        host.endsWith('.mangakatana.com') ||
        host.endsWith('.mangakakalot.com') ||
        host.endsWith('.mkklcdnv6temp.com') ||
        host.endsWith('.catmanga.org');
    if (!isAllowed) return url;
    return '$_proxyImageUrl?url=${Uri.encodeComponent(url)}';
  }

  String proxiedImageUrl(String url) => proxyImageUrl(url);

  Future<String?> _fetchHtml(
    Uri uri, {
    String cookie = '',
    bool forceRefresh = false,
  }) async {
    return _rawFetchHtml(uri, cookie: cookie);
  }

  Future<String?> _rawFetchHtml(Uri uri, {String cookie = ''}) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _authHeaders();
        final response = await http
            .get(_proxiedFetch(uri, cookie: cookie), headers: headers)
            .timeout(_timeout);
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          return response.body;
        }
        if (response.statusCode == 401) {
          Logger.e('KatanaService fetch 401 - auth required: $uri');
          return null;
        }
        Logger.e('KatanaService fetch ${response.statusCode}: $uri');
      } catch (e) {
        Logger.e('KatanaService fetch failed: $uri', error: e);
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return null;
  }

  Future<KatanaManga?> fetchMangaDetail(String slug) async {
    if (slug.isEmpty) return null;
    final html = await _fetchHtml(Uri.parse('$_baseUrl/manga/$slug'));
    if (html == null) return null;
    return _parseDetail(html, slug);
  }

  static const List<String> katanaCdnHosts = ['i1', 'i6', 'i7', 'i5', 'i2'];

  static String cdnFallbackUrl(String url, int step) {
    if (step <= 0) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final match = RegExp(r'^(i\d+)\.').firstMatch(uri.host);
    if (match == null) return url;
    final current = match.group(1)!;
    final rest = katanaCdnHosts.where((h) => h != current).toList();
    if (step > rest.length) return url;
    return url.replaceFirst('$current.', '${rest[step - 1]}.');
  }

  static int cdnFallbackCount(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 0;
    final match = RegExp(r'^(i\d+)\.').firstMatch(uri.host);
    if (match == null) return 0;
    return katanaCdnHosts.contains(match.group(1))
        ? katanaCdnHosts.length - 1
        : katanaCdnHosts.length;
  }

  static String cookieForServer(String server) {
    switch (server) {
      case '?sv=mk':
        return 's_r=sv2';
      case '?sv=3':
        return 's_r=sv3';
      default:
        return '';
    }
  }

  Future<List<String>> fetchChapterPages(
    String slug,
    String chapterId, {
    String server = '',
    bool forceRefresh = false,
  }) async {
    if (slug.isEmpty || chapterId.isEmpty) return const [];
    const servers = ['', '?sv=mk', '?sv=3'];
    final ordered = [server, ...servers.where((s) => s != server)];
    for (final sv in ordered) {
      final html = await _fetchHtml(
        Uri.parse('$_baseUrl/manga/$slug/$chapterId$sv'),
        cookie: cookieForServer(sv),
        forceRefresh: forceRefresh,
      );
      if (html == null) continue;
      final urls = _parseImageArrays(html);
      if (urls.isNotEmpty) return urls;
    }
    return const [];
  }

  static List<String> _parseImageArrays(String html) {
    final result = <String>[];
    for (final varName in ['thzq', 'ytaw']) {
      final m = RegExp(
        'var $varName=\\[(.*?)\\];',
        dotAll: true,
      ).firstMatch(html);
      if (m == null) continue;
      for (final raw in m.group(1)!.split(',')) {
        final url = raw
            .trim()
            .replaceAll(RegExp(r"^'"), '')
            .replaceAll(RegExp(r"'$"), '');
        if (url.startsWith('http') && url.isNotEmpty && !result.contains(url)) {
          result.add(url);
        }
      }
      if (result.isNotEmpty) break;
    }
    return result;
  }

  static String _katanaMangaId(String slug) => 'katana|$slug';

  List<String> _searchResultBlocks(String html) {
    final start = html.indexOf('Search results');
    if (start < 0) return const [];
    final end = html.indexOf('widget-title', start + 20);
    return _blocksOfClass(html, 'item', start: start, end: end);
  }

  static List<String> _blocksOfClass(
    String html,
    String className, {
    int start = 0,
    int end = -1,
  }) {
    final result = <String>[];
    final marker = '<div class="$className"';
    var pos = html.indexOf(marker, start);
    while (pos >= 0) {
      if (end >= 0 && pos >= end) break;
      final open = html.indexOf('<div', pos);
      var depth = 0;
      var i = open;
      var blockEnd = -1;
      while (i < html.length) {
        final nextOpen = html.indexOf('<div', i);
        final nextClose = html.indexOf('</div>', i);
        if (nextClose < 0) break;
        if (nextOpen >= 0 && nextOpen < nextClose) {
          depth++;
          i = nextOpen + 4;
        } else {
          depth--;
          i = nextClose + 6;
          if (depth == 0) {
            blockEnd = i;
            break;
          }
        }
      }
      if (blockEnd < 0) break;
      result.add(html.substring(pos, blockEnd));
      pos = html.indexOf(marker, blockEnd);
    }
    return result;
  }

  List<KatanaChapter> _parseChapterTable(String html) =>
      parseChapterTable(html);

  static final RegExp _reChapterRow = RegExp(
    r'<tr data-jump="[^"]*">.*?</tr>',
    dotAll: true,
  );
  static final RegExp _reChapterRowHref = RegExp(
    r'href="https://mangakatana\.com/manga/[^"]*/(' + chapterIdPattern + r')"',
  );
  static final RegExp _reChapterRowTitle = RegExp(
    r'<div class="chapter"><a[^>]*>([^<]*)</a>',
  );
  static final RegExp _reChapterRowTime = RegExp(
    r'class="update_time">([^<]*)</div>',
  );
  static final RegExp _reKatanaDate = RegExp(r'(\w{3})-(\d{1,2})-(\d{4})');
  static final RegExp _reDigits = RegExp(r'(\d+)');
  static final HtmlUnescape _staticUnescape = HtmlUnescape();
  static const Map<String, int> _katanaMonths = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  static List<KatanaChapter> parseChapterTable(String html) {
    final chapters = <KatanaChapter>[];
    final rows = _reChapterRow.allMatches(html);
    for (final row in rows) {
      final block = row.group(0)!;
      final hrefM = _reChapterRowHref.firstMatch(block);
      if (hrefM == null) continue;
      final id = hrefM.group(1)!;
      final titleM = _reChapterRowTitle.firstMatch(block);
      final timeM = _reChapterRowTime.firstMatch(block);
      chapters.add(
        KatanaChapter(
          id: id,
          num: katanaChapterNumFromId(id),
          title: _staticUnescape.convert(
            titleM?.group(1)?.trim() ?? 'Chapter $id',
          ),
          updateAt: _parseKatanaDate(timeM?.group(1) ?? ''),
          isNew: block.contains('class="new"'),
        ),
      );
    }
    return chapters;
  }

  static DateTime? _parseKatanaDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final m = _reKatanaDate.firstMatch(raw);
    if (m == null) return null;
    final month = _katanaMonths[m.group(1)];
    if (month == null) return null;
    return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!));
  }

  DateTime? _parseRelativeTime(String raw) {
    final text = raw.toLowerCase();
    final now = DateTime.now();
    final numM = _reDigits.firstMatch(text);
    if (numM == null) return null;
    final n = int.parse(numM.group(1)!);
    if (text.contains('year')) return now.subtract(Duration(days: 365 * n));
    if (text.contains('month')) return now.subtract(Duration(days: 30 * n));
    if (text.contains('week')) return now.subtract(Duration(days: 7 * n));
    if (text.contains('day')) return now.subtract(Duration(days: n));
    if (text.contains('hour')) return now.subtract(Duration(hours: n));
    if (text.contains('minute')) return now.subtract(Duration(minutes: n));
    if (text.contains('second')) return now.subtract(Duration(seconds: n));
    return null;
  }
}
