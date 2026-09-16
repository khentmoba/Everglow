part of 'katana_service.dart';

/// Home / catalog / search / genre fetching for [KatanaService].
extension KatanaServiceCatalog on KatanaService {
  // ── Home ────────────────────────────────────────────────────────

  /// Aggregates the Manga Katana home page: the Hot Updates rail,
  /// Latest Updates items, the Hot Manga rail, and all genres.
  Future<KatanaHomeData> fetchHome() async {
    final html = await _fetchHtml(Uri.parse('${KatanaService._baseUrl}/'));
    if (html == null) return const KatanaHomeData();

    final hotStart = html.indexOf('Hot Manga');
    final latest = _parseExpandedItems(
      KatanaService._blocksOfClass(
        html,
        'item',
        start: html.indexOf('Latest Updates'),
        end: hotStart < 0 ? -1 : hotStart,
      ),
    );

    final hotBlocks = <String>[];
    if (hotStart >= 0) {
      hotBlocks.addAll(
        KatanaService._blocksOfClass(html, 'item', start: hotStart),
      );
    }
    final hot = _parseHotItems(hotBlocks);

    return KatanaHomeData(
      hotUpdates: _parseHotUpdateRail(html),
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
        uri = Uri.parse('${KatanaService._baseUrl}/latest$pagePath');
        break;
      case 'new':
        uri = Uri.parse('${KatanaService._baseUrl}/new-manga$pagePath');
        break;
      case 'genre':
        uri = Uri.parse('${KatanaService._baseUrl}/genre/$key$pagePath');
        break;
      case 'author':
        uri = Uri.parse('${KatanaService._baseUrl}/author/$key$pagePath');
        break;
      case 'search':
        // The site's search form submits `search` + `search_by`.
        // The old `s` param is silently ignored and the site
        // returns the home page instead of results.
        uri = Uri.parse(
          '${KatanaService._baseUrl}$pagePath',
        ).replace(queryParameters: {'search': query, 'search_by': searchBy});
        break;
      case 'directory':
      default:
        uri = Uri.parse('${KatanaService._baseUrl}/manga$pagePath');
        break;
    }

    if (mode == 'directory' || mode == 'genre' || mode == 'author') {
      uri = uri.replace(
        queryParameters: {
          'filter': '1',
          // The site's filter JS joins checked include genres with ','
          // but exclude genres with '_' — the server only honors the
          // underscore form for multiple excludes.
          'include': include.join(','),
          'exclude': exclude.join('_'),
          'genre_mode': genreMode,
          'chapters': chapters,
          'order_by': orderBy,
        },
      );
    }

    final html = await _fetchHtml(uri);
    if (html == null) {
      return KatanaPageResult(
        items: const [],
        page: page,
        hasNext: false,
        hasPrev: page > 1,
      );
    }

    final isSearch = mode == 'search';
    final items = isSearch
        ? _parseExpandedItems(_searchResultBlocks(html))
        : _parseExpandedItems(KatanaService._blocksOfClass(html, 'item'));

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
  Future<List<KatanaManga>> fetchSuggestions(
    String query, {
    String searchBy = 'm_name',
  }) async {
    if (query.trim().length < 3) return const [];
    final html = await _fetchHtml(
      Uri.parse(
        '${KatanaService._baseUrl}/',
      ).replace(queryParameters: {'search': query, 'search_by': searchBy}),
    );
    if (html == null) return const [];
    final items = _parseCompactItems(_searchResultBlocks(html));
    return items.take(8).toList();
  }

  // ── Genres ──────────────────────────────────────────────────────

  Future<List<KatanaGenre>> fetchGenres() async {
    final html = await _fetchHtml(
      Uri.parse('${KatanaService._baseUrl}/genres'),
    );
    if (html == null) return const [];
    return _parseGenres(html);
  }
}
