import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';

import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';

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

  static const Duration _timeout = Duration(seconds: 14);

  Map<String, String> get _headers => const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      };

  Uri _proxiedFetch(Uri uri) {
    return Uri.parse(
        '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}');
  }

  /// Proxies a page image (covers and chapter pages) through the
  /// MangaKatana image Cloud Function. Covers served directly from
  /// Covers live on the bare `mangakatana.com` host which the image
  /// proxy only accepts for subdomains, so those go through the HTML
  /// proxy instead (Flutter decodes by bytes, not content-type).
  String proxiedImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('https://mangakatana.com/imgs/')) {
      return '$_proxyHtmlUrl?url=${Uri.encodeComponent(url)}';
    }
    return '$_proxyImageUrl?url=${Uri.encodeComponent(url)}';
  }

  Future<String?> _fetchHtml(Uri uri) async {
    try {
      final response =
          await http.get(_proxiedFetch(uri), headers: _headers).timeout(_timeout);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return response.body;
      }
    } catch (e) {
      Logger.e('KatanaService fetch failed: $uri', error: e);
    }
    return null;
  }

  // ── Home ────────────────────────────────────────────────────────

  /// Aggregates the Manga Katana home page: Latest Updates items,
  /// the Hot Manga rail, and all genres with counts.
  Future<KatanaHomeData> fetchHome() async {
    final html = await _fetchHtml(Uri.parse('$_baseUrl/'));
    if (html == null) return const KatanaHomeData();

    final hotStart = html.indexOf('Hot Manga');
    final latest = _parseExpandedItems(
      _blocksOfClass(html, 'item',
          start: html.indexOf('Latest Updates'), end: hotStart < 0 ? -1 : hotStart),
    );

    final hotBlocks = <String>[];
    if (hotStart >= 0) {
      hotBlocks.addAll(_blocksOfClass(html, 'item', start: hotStart));
    }
    final hot = _parseHotItems(hotBlocks);

    return KatanaHomeData(
      latest: latest,
      hot: hot,
      genres: _parseGenres(html),
    );
  }

  // ── Directory / Latest / New / Genre / Author ───────────────────

  /// Fetches a paginated catalog page.
  ///
  /// [mode] is one of `directory`, `latest`, `new`, `genre`, `author`
  /// or `search`; [key] is the genre/author slug for those modes.
  /// [include]/[exclude] are genre slugs, [genreMode] is `and`/`or`,
  /// [chapters] is the minimum chapter count and [orderBy] is
  /// `latest`, `new`, `az` or `numc`.
  Future<KatanaPageResult> fetchCatalog({
    String mode = 'directory',
    String key = '',
    int page = 1,
    List<String> include = const [],
    List<String> exclude = const [],
    String genreMode = 'and',
    String chapters = '1',
    String orderBy = 'latest',
    String query = '',
    String searchBy = 'm_name',
  }) async {
    final pagePath = page > 1 ? '/page/$page' : '';
    Uri uri;
    switch (mode) {
      case 'latest':
        uri = Uri.parse('$_baseUrl/latest$pagePath');
        break;
      case 'new':
        uri = Uri.parse('$_baseUrl/new-manga$pagePath');
        break;
      case 'genre':
        uri = Uri.parse('$_baseUrl/genre/$key$pagePath');
        break;
      case 'author':
        uri = Uri.parse('$_baseUrl/author/$key$pagePath');
        break;
      case 'search':
        uri = Uri.parse('$_baseUrl$pagePath')
            .replace(queryParameters: {'s': query, 'search_by': searchBy});
        break;
      case 'directory':
      default:
        uri = Uri.parse('$_baseUrl/manga$pagePath');
        break;
    }

    if (mode == 'directory' || mode == 'genre' || mode == 'author') {
      uri = uri.replace(queryParameters: {
        'filter': '1',
        // The site's filter JS joins checked include genres with ','
        // but exclude genres with '_' — the server only honors the
        // underscore form for multiple excludes.
        'include': include.join(','),
        'exclude': exclude.join('_'),
        'genre_mode': genreMode,
        'chapters': chapters,
        'order_by': orderBy,
      });
    }

    final html = await _fetchHtml(uri);
    if (html == null) {
      return KatanaPageResult(items: const [], page: page, hasNext: false, hasPrev: page > 1);
    }

    final isSearch = mode == 'search';
    final items = isSearch
        ? _parseCompactItems(_blocksOfClass(html, 'item'))
        : _parseExpandedItems(_blocksOfClass(html, 'item'));

    return KatanaPageResult(
      items: items,
      page: page,
      hasNext: html.contains('class="next page-numbers"'),
      hasPrev: page > 1 && html.contains('class="prev page-numbers"'),
    );
  }

  /// Fetches the catalog filtered by content type.
  ///
  /// Manga Katana tags Korean titles with the `manhwa` genre and
  /// Chinese titles with `manhua`, so:
  ///   * `all`     – the full directory
  ///   * `manga`   – directory excluding `manhwa` + `manhua`
  ///   * `manhwa`  – directory including `manhwa`
  ///   * `manhua`  – directory including `manhua`
  Future<KatanaPageResult> fetchByType(
    String type, {
    int page = 1,
    String orderBy = 'latest',
    String chapters = '1',
  }) async {
    switch (type) {
      case 'manga':
        return fetchCatalog(
          mode: 'directory',
          page: page,
          exclude: const ['manhwa', 'manhua'],
          orderBy: orderBy,
          chapters: chapters,
        );
      case 'manhwa':
        return fetchCatalog(
          mode: 'directory',
          page: page,
          include: const ['manhwa'],
          orderBy: orderBy,
          chapters: chapters,
        );
      case 'manhua':
        return fetchCatalog(
          mode: 'directory',
          page: page,
          include: const ['manhua'],
          orderBy: orderBy,
          chapters: chapters,
        );
      default:
        return fetchCatalog(
          mode: 'directory',
          page: page,
          orderBy: orderBy,
          chapters: chapters,
        );
    }
  }

  /// Live suggestions for the header search box. Mirrors the site's
  /// autocomplete response: compact cover + title + latest chapter +
  /// authors. Requires at least 3 characters, like Manga Katana.
  Future<List<KatanaManga>> fetchSuggestions(String query,
      {String searchBy = 'm_name'}) async {
    if (query.trim().length < 3) return const [];
    final html = await _fetchHtml(Uri.parse('$_baseUrl/')
        .replace(queryParameters: {'s': query, 'search_by': searchBy}));
    if (html == null) return const [];
    final items = _parseCompactItems(_blocksOfClass(html, 'item'));
    return items.take(8).toList();
  }

  // ── Genres ──────────────────────────────────────────────────────

  Future<List<KatanaGenre>> fetchGenres() async {
    final html = await _fetchHtml(Uri.parse('$_baseUrl/genres'));
    if (html == null) return const [];
    return _parseGenres(html);
  }

  // ── Detail ──────────────────────────────────────────────────────

  Future<KatanaManga?> fetchMangaDetail(String slug) async {
    if (slug.isEmpty) return null;
    final html = await _fetchHtml(Uri.parse('$_baseUrl/manga/$slug'));
    if (html == null) return null;
    return _parseDetail(html, slug);
  }

  // ── Chapter pages ───────────────────────────────────────────────

  /// Resolves the page image URLs for a chapter. The site embeds two
  /// image URL arrays in inline scripts (`thzq` for server 1, `ytaw`
  /// as fallback). If the first server's array is empty we retry the
  /// `?sv=mk` and `?sv=3` variants exactly like the site's server
  /// switcher.
  Future<List<String>> fetchChapterPages(String slug, String chapterId,
      {String server = ''}) async {
    if (slug.isEmpty || chapterId.isEmpty) return const [];
    final uris = <Uri>[
      Uri.parse('$_baseUrl/manga/$slug/$chapterId$server'),
      Uri.parse('$_baseUrl/manga/$slug/$chapterId?sv=mk'),
      Uri.parse('$_baseUrl/manga/$slug/$chapterId?sv=3'),
    ];
    for (final uri in uris) {
      final html = await _fetchHtml(uri);
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
      final m = RegExp('var $varName=\\[(.*?)\\];', dotAll: true).firstMatch(html);
      if (m == null) continue;
      for (final raw in m.group(1)!.split(',')) {
        final url = raw.trim().replaceAll(RegExp(r"^'"), '').replaceAll(RegExp(r"'$"), '');
        if (url.startsWith('http') && url.isNotEmpty && !result.contains(url)) {
          result.add(url);
        }
      }
      if (result.isNotEmpty) break;
    }
    return result;
  }

  // ── Bookmarks (Firestore, per Everglow user) ────────────────────

  CollectionReference<Map<String, dynamic>> get _bookmarks =>
      _firestore.collection('katana_bookmarks');

  Stream<List<KatanaBookmark>> bookmarkStream(String userName) {
    if (userName.isEmpty) return Stream.value(const []);
    return _bookmarks
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => KatanaBookmark.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt)));
  }

  Future<bool> isBookmarked(String slug, String userName) async {
    if (userName.isEmpty || slug.isEmpty) return false;
    try {
      final doc = await _bookmarks.doc('$userName|$slug').get();
      return doc.exists;
    } catch (e) {
      Logger.e('isBookmarked error', error: e);
      return false;
    }
  }

  Future<void> setBookmark(
    KatanaManga manga,
    String userName, {
    bool bookmarked = true,
  }) async {
    if (userName.isEmpty || manga.slug.isEmpty) return;
    try {
      final ref = _bookmarks.doc('$userName|${manga.slug}');
      if (!bookmarked) {
        await ref.delete();
        return;
      }
      final data = KatanaBookmark(
        slug: manga.slug,
        title: manga.title,
        coverUrl: manga.coverUrl,
        status: manga.status,
        addedAt: DateTime.now(),
        latestChapterTitle: manga.latestChapter?.displayTitle ?? '',
      ).toFirestore();
      data['userName'] = userName;
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      Logger.e('setBookmark error', error: e);
    }
  }

  Future<void> saveReadingProgress({
    required String slug,
    required String userName,
    required String chapterId,
    required String chapterTitle,
    required int page,
  }) async {
    if (userName.isEmpty || slug.isEmpty) return;
    try {
      await _bookmarks.doc('$userName|$slug').set({
        'slug': slug,
        'userName': userName,
        'lastReadChapterId': chapterId,
        'lastReadChapterTitle': chapterTitle,
        'lastReadPage': page,
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('saveReadingProgress error', error: e);
    }
  }

  // ── Reading list (manga_library, shared with the dashboard's "Reading" shelf) ──
  //
  // The dashboard's "Reading" section streams `manga_library` entries whose
  // `libraryStatus == 'reading'`, split into "ME" / partner sub-rows. Katana
  // titles are keyed with a `katana|` prefix so they never collide with the
  // Comick-sourced manga ids used by the rest of the library.

  CollectionReference<Map<String, dynamic>> get _library =>
      _firestore.collection('manga_library');

  static String _katanaMangaId(String slug) => 'katana|$slug';

  Future<bool> isReading(String slug, String userName) async {
    if (userName.isEmpty || slug.isEmpty) return false;
    try {
      final docs = await _library
          .where('mangaId', isEqualTo: _katanaMangaId(slug))
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      return docs.docs.isNotEmpty;
    } catch (e) {
      Logger.e('isReading error', error: e);
      return false;
    }
  }

  Future<void> setReading(
    KatanaManga manga,
    String userName, {
    bool reading = true,
  }) async {
    if (userName.isEmpty || manga.slug.isEmpty) return;
    try {
      final mangaId = _katanaMangaId(manga.slug);
      final existing = await _library
          .where('mangaId', isEqualTo: mangaId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      if (!reading) {
        for (final doc in existing.docs) {
          await doc.reference.delete();
        }
        return;
      }
      final data = <String, dynamic>{
        'mangaId': mangaId,
        'title': manga.title,
        'author': manga.authors.isNotEmpty ? manga.authors.first : '',
        'artist': manga.artists.isNotEmpty ? manga.artists.first : '',
        'description': manga.summary,
        'coverUrl': proxiedImageUrl(manga.coverUrl),
        'status': manga.status,
        'originalLanguage': 'jp',
        'contentRating': 'safe',
        'tags': [for (final genre in manga.genres) genre.name],
        'userName': userName,
        'addedAt': Timestamp.now(),
        'libraryStatus': 'reading',
        'lastReadChapterId': '',
        'lastReadPage': 0,
        'comickId': 0,
        'comickSlug': '',
        'mangaKakalotId': manga.slug,
        'rating': 0.0,
        'followCount': 0,
        'altTitles': manga.altNames,
      };
      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.set(data, SetOptions(merge: true));
      } else {
        await _library.doc('$userName|$mangaId').set(data);
      }
    } catch (e) {
      Logger.e('setReading error', error: e);
    }
  }

  // ── Parsers ─────────────────────────────────────────────────────

  /// Finds balanced `<div class="item" ...>...</div>` blocks starting
  /// at or after [start].
  static List<String> _blocksOfClass(String html, String className,
      {int start = 0, int end = -1}) {
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

  String _clean(String html) {
    final withoutTags =
        html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return _unescape.convert(withoutTags);
  }

  /// Parses the expanded list-item layout used by Latest Updates,
  /// the Manga Directory and genre/author/latest pages.
  List<KatanaManga> _parseExpandedItems(List<String> blocks) {
    final items = <KatanaManga>[];
    for (final block in blocks) {
      final manga = _parseExpandedItem(block);
      if (manga != null) items.add(manga);
    }
    return items;
  }

  KatanaManga? _parseExpandedItem(String block) {
    final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
    final hrefMatch =
        RegExp(r'href="https://mangakatana\.com/manga/([^"/]+)"').firstMatch(block);
    if (hrefMatch == null) return null;

    final slug = hrefMatch.group(1)!;
    final id = idMatch?.group(1) ?? slug;

    final cover = _coverFrom(block);
    final statusM = RegExp(r'class="status (ongoing|completed)"').firstMatch(block);
    final status = statusM?.group(1) ?? 'ongoing';

    final titleM = RegExp(
            r'<h3 class="title">.*?<a[^>]*href="[^"]*manga/[^"]+"[^>]*>([^<]+)</a>',
            dotAll: true)
        .firstMatch(block);
    final title = titleM != null ? _unescape.convert(titleM.group(1)!.trim()) : slug;

    final dateM = RegExp(r'<div class="date">.*?</div>', dotAll: true).firstMatch(block);
    final updateText = dateM != null ? _clean(dateM.group(0)!) : '';

    final summaryM =
        RegExp(r'<div class="summary[^"]*">(.*?)</div>', dotAll: true).firstMatch(block);
    final summary = summaryM != null ? _clean(summaryM.group(1)!) : '';

    final genres = <KatanaGenre>[];
    for (final g in RegExp(r'href="https://mangakatana\.com/genre/([a-z0-9-]+)"[^>]*>([^<]+)</a>')
        .allMatches(block)) {
      genres.add(KatanaGenre(
        slug: g.group(1)!,
        name: _unescape.convert(g.group(2)!.trim()),
      ));
    }

    final latest = _parseChapterLink(block);

    final recent = <KatanaChapter>[];
    final chapterBlocks =
        RegExp(r'<div class="chapter"><a href="[^"]*/(c[^"/]+|fc)"[^>]*>([^<]*)</a></div>'
            r'\s*</div>\s*<div class="uk-width-2-10"><div class="update_time">([^<]*)</div>',
            dotAll: true)
            .allMatches(block);
    for (final m in chapterBlocks) {
      recent.add(KatanaChapter(
        id: m.group(1)!,
        num: m.group(1) == 'fc' ? '' : m.group(1)!.substring(1),
        title: _unescape.convert(m.group(2)!.trim()),
        updateAt: _parseKatanaDate(m.group(3) ?? ''),
      ));
    }

    return KatanaManga(
      slug: slug,
      id: id,
      title: title,
      coverUrl: cover,
      status: status,
      updateText: updateText,
      summary: summary,
      genres: genres,
      latestChapter: latest,
      recentChapters: recent,
    );
  }

  KatanaChapter? _parseChapterLink(String block) {
    final m = RegExp(
            r'<a href="https://mangakatana\.com/manga/[^"]*/(c\d+)"[^>]*>([^<]*)</a>')
        .firstMatch(block);
    if (m == null) {
      final fc = RegExp(
              r'<a href="https://mangakatana\.com/manga/[^"]*/fc"[^>]*>([^<]*)</a>')
          .firstMatch(block);
      if (fc == null) return null;
      return KatanaChapter(
        id: 'fc',
        num: '',
        title: _unescape.convert(fc.group(1)!.trim()),
      );
    }
    final id = m.group(1)!;
    return KatanaChapter(
      id: id,
      num: id == 'fc' ? '' : id.substring(1),
      title: _unescape.convert(m.group(2)!.trim()),
    );
  }

  /// Parses the compact search / autocomplete layout: cover, title,
  /// latest chapter and (where present) authors. Handles both the
  /// search results layout (h3 title + chapter with icon) and the
  /// autocomplete layout (title link + authors).
  List<KatanaManga> _parseCompactItems(List<String> blocks) {
    final items = <KatanaManga>[];
    for (final block in blocks) {
      final hrefMatch = RegExp(
              r'href="https://mangakatana\.com/manga/([^"/]+)"')
          .firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
      final titleM = RegExp(
              r'<h3 class="title">\s*<a[^>]*>([^<]+)</a>', dotAll: true)
          .firstMatch(block) ??
          RegExp(r'class="title">([^<]+)</a>').firstMatch(block);
      final chapterM = RegExp(r'href="[^"]*/(c\d+|fc)"[^>]*>(.*?)</a>',
              dotAll: true)
          .firstMatch(block);
      final authors = <String>[];
      for (final a in RegExp(r'class="author" href="[^"]*"[^>]*>([^<]+)</a>')
          .allMatches(block)) {
        authors.add(_unescape.convert(a.group(1)!.trim()));
      }
      final chapterTitle = chapterM != null ? _clean(chapterM.group(2)!) : '';
      items.add(KatanaManga(
        slug: slug,
        id: idMatch?.group(1) ?? slug,
        title: titleM != null ? _unescape.convert(titleM.group(1)!.trim()) : slug,
        coverUrl: _coverFrom(block),
        latestChapter: chapterM != null
            ? KatanaChapter(
                id: chapterM.group(1)!,
                num: chapterM.group(1) == 'fc' ? '' : chapterM.group(1)!.substring(1),
                title: chapterTitle,
              )
            : null,
        authors: authors,
      ));
    }
    return items;
  }

  /// Parses the Hot Manga rail (compact cover + title + status +
  /// latest chapter).
  List<KatanaManga> _parseHotItems(List<String> blocks) {
    final items = <KatanaManga>[];
    for (final block in blocks) {
      final hrefMatch =
          RegExp(r'href="https://mangakatana\.com/manga/([^"/]+)"').firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final titleM = RegExp(r'<h3 class="title"><a href="[^"]*"[^>]*>([^<]+)</a>')
          .firstMatch(block);
      final statusM = RegExp(r'class="status (ongoing|completed)"').firstMatch(block);
      final chapterM = RegExp(r'<div class="chapter"><a href="[^"]*/(c[^"/]+|fc)"[^>]*>([^<]*)</a>')
          .firstMatch(block);
      final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
      items.add(KatanaManga(
        slug: slug,
        id: idMatch?.group(1) ?? slug,
        title: titleM != null ? _unescape.convert(titleM.group(1)!.trim()) : slug,
        coverUrl: _coverFrom(block),
        status: statusM?.group(1) ?? 'ongoing',
        latestChapter: chapterM != null
            ? KatanaChapter(
                id: chapterM.group(1)!,
                num: chapterM.group(1) == 'fc' ? '' : chapterM.group(1)!.substring(1),
                title: _unescape.convert(chapterM.group(2)!.trim()),
              )
            : null,
      ));
    }
    return items;
  }

  String _coverFrom(String block) {
    final webp = RegExp(r'<source srcset="(https://[^"]+\.webp)"')
        .firstMatch(block);
    if (webp != null) return webp.group(1)!;
    final img = RegExp(r'<img src="(https://[^"]+)"').firstMatch(block);
    if (img != null) return img.group(1)!;
    final dataSrc = RegExp(r'<img data-src="(https://[^"]+)"').firstMatch(block);
    if (dataSrc != null) return dataSrc.group(1)!;
    return '';
  }

  KatanaManga? _parseDetail(String html, String slug) {
    final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(html);
    final titleM = RegExp(r'<h1 class="heading">([^<]+)</h1>').firstMatch(html);
    final cover = _coverFrom(html);
    final statusM = RegExp(r'class="d-cell-small value status (ongoing|completed)"')
        .firstMatch(html);
    final latestM = RegExp(r'class="d-cell-small value new_chap">([^<]+)</div>')
        .firstMatch(html);
    final updateM = RegExp(r'class="d-cell-small value updateAt">([^<]+)</div>')
        .firstMatch(html);

    final altNames = <String>[];
    final altM = RegExp(
            r'<div class="d-cell-small label">Alt name\(s\):</div>\s*<div class="d-cell-small value"><div class="alt_name">([^<]+)</div>',
            dotAll: true)
        .firstMatch(html);
    if (altM != null) {
      altNames.addAll(_unescape
          .convert(altM.group(1)!.trim())
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    }

    final authors = <String>[];
    final artists = <String>[];
    final authorM = RegExp(
            r'<div class="d-cell-small label">Author\(s\) / Artist\(s\):</div>.*?</div>',
            dotAll: true)
        .firstMatch(html);
    if (authorM != null) {
      final section = authorM.group(0)!;
      var first = true;
      for (final a in RegExp(r'<a class="author" href="[^"]*"[^>]*>([^<]+)</a>')
          .allMatches(section)) {
        if (first) {
          authors.add(_unescape.convert(a.group(1)!.trim()));
        } else {
          artists.add(_unescape.convert(a.group(1)!.trim()));
        }
        first = false;
      }
    }

    final genres = <KatanaGenre>[];
    final genreSectionM = RegExp(
            r'<div class="d-cell-small label">Genres:</div>.*?</div>', dotAll: true)
        .firstMatch(html);
    final genreSection = genreSectionM?.group(0) ?? html;
    for (final g in RegExp(
            r'href="https://mangakatana\.com/genre/([a-z0-9-]+)"[^>]*>([^<]+)</a>')
        .allMatches(genreSection)) {
      genres.add(KatanaGenre(
        slug: g.group(1)!,
        name: _unescape.convert(g.group(2)!.trim()),
      ));
    }

    final summaryM = RegExp(
            r'<div class="summary">\s*<div class="label">Description</div>\s*<p>(.*?)</p>',
            dotAll: true)
        .firstMatch(html);

    final chapters = _parseChapterTable(html);

    return KatanaManga(
      slug: slug,
      id: idMatch?.group(1) ?? slug,
      title: titleM != null ? _unescape.convert(titleM.group(1)!.trim()) : slug,
      coverUrl: cover,
      status: statusM?.group(1) ?? 'ongoing',
      updateText: updateM?.group(1)?.trim() ?? '',
      summary: summaryM != null ? _clean(summaryM.group(1)!) : '',
      genres: genres,
      altNames: altNames,
      authors: authors,
      artists: artists,
      latestChapter: latestM != null
          ? KatanaChapter(id: 'latest', num: '', title: latestM.group(1)!.trim())
          : null,
      updateAt: _parseRelativeTime(updateM?.group(1)?.trim() ?? ''),
      chapters: chapters,
    );
  }

  List<KatanaChapter> _parseChapterTable(String html) {
    final chapters = <KatanaChapter>[];
    final rows = RegExp(r'<tr data-jump="\d+">.*?</tr>', dotAll: true).allMatches(html);
    for (final row in rows) {
      final block = row.group(0)!;
      final hrefM = RegExp(r'href="https://mangakatana\.com/manga/[^"]*/(c[^"/]+|fc)"')
          .firstMatch(block);
      if (hrefM == null) continue;
      final id = hrefM.group(1)!;
      final titleM = RegExp(r'<div class="chapter"><a[^>]*>([^<]*)</a>')
          .firstMatch(block);
      final timeM = RegExp(r'class="update_time">([^<]*)</div>').firstMatch(block);
      chapters.add(KatanaChapter(
        id: id,
        num: id == 'fc' ? '' : id.substring(1),
        title: _unescape.convert(titleM?.group(1)?.trim() ?? 'Chapter $id'),
        updateAt: _parseKatanaDate(timeM?.group(1) ?? ''),
      ));
    }
    return chapters;
  }

  /// Parses genre links with counts (home Genres widget / directory
  /// sidebar / genres page) and merges descriptions from the nav menu.
  List<KatanaGenre> _parseGenres(String html) {
    final bySlug = <String, KatanaGenre>{};
    final chipRe = RegExp(
        r'href="https://mangakatana\.com/genre/([a-z0-9-]+)">([^<]+)</a> <span>\((\d+)\)</span>');
    for (final m in chipRe.allMatches(html)) {
      bySlug[m.group(1)!] = KatanaGenre(
        slug: m.group(1)!,
        name: _unescape.convert(m.group(2)!.trim()),
        count: int.tryParse(m.group(3)!) ?? 0,
      );
    }
    final navRe = RegExp(
        r'href="https://mangakatana\.com/genre/([a-z0-9-]+)" data-desc="([^"]*)"><h3 class="nav_label">([^<]+)</h3>');
    for (final m in navRe.allMatches(html)) {
      final existing = bySlug[m.group(1)!];
      bySlug[m.group(1)!] = KatanaGenre(
        slug: m.group(1)!,
        name: existing?.name ?? _unescape.convert(m.group(3)!.trim()),
        count: existing?.count ?? 0,
        description: _unescape.convert(m.group(2) ?? ''),
      );
    }
    final list = bySlug.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Parses "Aug-12-2026" style dates from chapter tables.
  DateTime? _parseKatanaDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final m = RegExp(r'(\w{3})-(\d{1,2})-(\d{4})').firstMatch(raw);
    if (m == null) return null;
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final month = months[m.group(1)];
    if (month == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(2)!),
    );
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

/// Formats a [DateTime] as a Manga Katana style relative string
/// ("58 minutes ago") or "Aug-12-2026" for older dates.
String formatKatanaTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[time.month - 1]}-${time.day.toString().padLeft(2, '0')}-${time.year}';
}

/// Sorts a chapter list oldest → newest for the reader.
List<KatanaChapter> sortChaptersAscending(List<KatanaChapter> chapters) {
  final sorted = List<KatanaChapter>.of(chapters)
    ..sort((a, b) => a.numeric.compareTo(b.numeric));
  return sorted;
}

String katanaTextFromHtml(String html) {
  return html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
