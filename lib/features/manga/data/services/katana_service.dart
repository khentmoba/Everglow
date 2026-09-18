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

/// Scrapes mangakatana.com exactly the way the site presents it:
/// the home page (Latest Updates / Hot Manga / Genres), the Manga
/// Directory with genre include/exclude filters and sorting, search
/// results with author lookup, the manga detail page (full chapter
/// table), and chapter pages whose inline JS arrays hold the page
/// image URLs.
///
/// All HTML requests go through the `proxyFetchHtml` Cloud Function
/// so Flutter Web isn't blocked by CORS; page images go through
/// `proxyMangaKatana`.
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

  /// Matches every MangaKatana chapter id shape seen on the live
  /// site: plain (`c413`), decimals (`c528.5`), part/version
  /// suffixes (`c38-p11`, `c12-v2`), volume ids (`v6c147`) and the
  /// first-chapter id (`fc`).
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
    } catch (_) {}
    return _headers;
  }

  Uri _proxiedFetch(Uri uri, {String cookie = ''}) {
    final base = '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}';
    if (cookie.isEmpty) return Uri.parse(base);
    return Uri.parse('$base&cookie=${Uri.encodeComponent(cookie)}');
  }

  /// Proxies a page image (covers and chapter pages) through the
  /// MangaKatana image Cloud Function. All covers now go through the
  /// image proxy (which allows anonymous <img> loads via host allowlist)
  /// so they work from Image.network without Authorization headers.
  static String proxyImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.contains('proxyMangaKatana')) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    final host = uri.host.toLowerCase();
    final isAllowed =
        host == 'mangakatana.com' ||
        host.endsWith('.mangakatana.com') ||
        host == 'mangakatana.net' ||
        host.endsWith('.mangakatana.net') ||
        host.endsWith('.mangakakalot.com') ||
        host.endsWith('.mkklcdnv6temp.com') ||
        host.endsWith('.catmanga.org');
    if (!isAllowed) return url;
    return '$_proxyImageUrl?url=${Uri.encodeComponent(url)}';
  }

  String proxiedImageUrl(String url) => proxyImageUrl(url);

  Future<String?> _fetchHtml(Uri uri, {String cookie = ''}) async {
    // One retry for transient hiccups (cold Cloud Function instances
    // occasionally answer 200 with an empty body, and the site or CDN
    // sometimes drops a request). Keeps chapter loads and search from
    // failing on the first volley.
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
          return null; // Retrying an auth failure won't help.
        }
        // Non-200s used to fail silently, which made chapter loads
        // look like the app hung. Log them so release builds show why.
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

  // ── Detail ──────────────────────────────────────────────────────

  Future<KatanaManga?> fetchMangaDetail(String slug) async {
    if (slug.isEmpty) return null;
    final html = await _fetchHtml(Uri.parse('$_baseUrl/manga/$slug'));
    if (html == null) return null;
    return _parseDetail(html, slug);
  }

  // ── Chapter pages ───────────────────────────────────────────────

  /// CDN hosts MangaKatana serves chapter images from. The site's own
  /// reader retries a failed image on a different `iN.` host with the
  /// same token path — the token stays valid across hosts.
  static const List<String> katanaCdnHosts = ['i1', 'i6', 'i7', 'i5', 'i2'];

  /// Rewrites [url] to its [step]-th fallback CDN host (step 0 is the
  /// URL unchanged). Returns [url] unchanged when it has no `iN.`
  /// host or [step] runs past the available hosts.
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

  /// How many silent CDN-host retries [url] gets before the reader
  /// shows its tap-to-retry slot. Zero for non-`iN.` URLs.
  static int cdnFallbackCount(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 0;
    final match = RegExp(r'^(i\d+)\.').firstMatch(uri.host);
    if (match == null) return 0;
    return katanaCdnHosts.contains(match.group(1))
        ? katanaCdnHosts.length - 1
        : katanaCdnHosts.length;
  }

  /// Maps the reader's server switch to the cookie the site itself
  /// sets (`#switch_sv` in the chapter page): Server 1 is the absence
  /// of the cookie, Server 2 is `s_r=sv2`, Server 3 is `s_r=sv3`.
  /// Without the cookie, Server 2/3 requests silently return Server
  /// 1's page URLs — the `?sv=` query alone is ignored by the site.
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

  /// Resolves the page image URLs for a chapter. The site embeds two
  /// image URL arrays in inline scripts (`thzq` plus the `ytaw`
  /// fallback). The requested server is tried first — with the
  /// cookie + query combination the site's own server switcher uses
  /// — then the other two servers, so a down CDN never blocks the
  /// chapter outright.
  Future<List<String>> fetchChapterPages(
    String slug,
    String chapterId, {
    String server = '',
  }) async {
    if (slug.isEmpty || chapterId.isEmpty) return const [];
    const servers = ['', '?sv=mk', '?sv=3'];
    final ordered = [server, ...servers.where((s) => s != server)];
    for (final sv in ordered) {
      final html = await _fetchHtml(
        Uri.parse('$_baseUrl/manga/$slug/$chapterId$sv'),
        cookie: cookieForServer(sv),
      );
      if (html == null) continue;
      final urls = _parseImageArrays(html);
      if (urls.isNotEmpty) return urls;
    }
    return const [];
  }

  /// Parses both `var thzq=[...]` and `var ytaw=[...]` arrays.
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

  // ── Parsers ─────────────────────────────────────────────────────

  /// Parses only the real "Search results" section of a search
  /// page. The page also embeds the Latest Updates and Hot Manga
  /// rails below the results — without this bound those rails were
  /// parsed as search results, so a search for anything returned
  /// dozens of unrelated homepage titles.
  List<String> _searchResultBlocks(String html) {
    final start = html.indexOf('Search results');
    if (start < 0) return const [];
    // The section ends at the next widget header (Genres, Hot Manga…).
    final end = html.indexOf('widget-title', start + 20);
    return _blocksOfClass(html, 'item', start: start, end: end);
  }

  /// Finds balanced `<div class="item" ...>...</div>` blocks starting
  /// at or after [start].
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

  /// Parses the detail-page chapter table. Public so tests can feed
  /// it real row HTML and pin the behavior.
  ///
  /// Two shapes used to slip through and silently drop chapters:
  /// rows the site marks as "Go to" jump targets carry the chapter
  /// id in `data-jump` (`<tr data-jump="c30">`) instead of a number,
  /// and volume chapters link to `v6c147`-style paths.
  static List<KatanaChapter> parseChapterTable(String html) {
    final unescape = HtmlUnescape();
    final chapters = <KatanaChapter>[];
    final rows = RegExp(
      r'<tr data-jump="[^"]*">.*?</tr>',
      dotAll: true,
    ).allMatches(html);
    final hrefRe = RegExp(
      r'href="https://mangakatana\.com/manga/[^"]*/(' +
          chapterIdPattern +
          r')"',
    );
    for (final row in rows) {
      final block = row.group(0)!;
      final hrefM = hrefRe.firstMatch(block);
      if (hrefM == null) continue;
      final id = hrefM.group(1)!;
      final titleM = RegExp(
        r'<div class="chapter"><a[^>]*>([^<]*)</a>',
      ).firstMatch(block);
      final timeM = RegExp(
        r'class="update_time">([^<]*)</div>',
      ).firstMatch(block);
      chapters.add(
        KatanaChapter(
          id: id,
          num: katanaChapterNumFromId(id),
          title: unescape.convert(titleM?.group(1)?.trim() ?? 'Chapter $id'),
          updateAt: _parseKatanaDate(timeM?.group(1) ?? ''),
          // The site marks its own fresh rows with a New badge
          // (only the newest, and only when recently updated) —
          // mirror it instead of guessing.
          isNew: block.contains('class="new"'),
        ),
      );
    }
    return chapters;
  }

  /// Parses "Aug-12-2026" style dates from chapter tables.
  static DateTime? _parseKatanaDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final m = RegExp(r'(\w{3})-(\d{1,2})-(\d{4})').firstMatch(raw);
    if (m == null) return null;
    const months = {
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
    final month = months[m.group(1)];
    if (month == null) return null;
    return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!));
  }

  /// Converts "58 minutes ago" / "2 hours ago" into a DateTime.
  DateTime? _parseRelativeTime(String raw) {
    final text = raw.toLowerCase();
    final now = DateTime.now();
    final numM = RegExp(r'(\d+)').firstMatch(text);
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
