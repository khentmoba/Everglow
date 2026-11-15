part of 'katana_service.dart';

extension KatanaServiceCatalog on KatanaService {
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
    await Future<void>.delayed(Duration.zero);

    final hotBlocks = <String>[];
    if (hotStart >= 0) {
      hotBlocks.addAll(
        KatanaService._blocksOfClass(html, 'item', start: hotStart),
      );
    }
    final hot = _parseHotItems(hotBlocks);
    await Future<void>.delayed(Duration.zero);

    final hotUpdates = _parseHotUpdateRail(html);
    await Future<void>.delayed(Duration.zero);

    final genres = _parseGenres(html);
    return KatanaHomeData(
      hotUpdates: hotUpdates,
      latest: latest,
      hot: hot,
      genres: genres,
    );
  }

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

  Future<List<KatanaGenre>> fetchGenres() async {
    final html = await _fetchHtml(
      Uri.parse('${KatanaService._baseUrl}/genres'),
    );
    if (html == null) return const [];
    return _parseGenres(html);
  }
}
