part of 'katana_service.dart';

/// HTML parsers for [KatanaService].
extension KatanaServiceParse on KatanaService {
  static final RegExp _reHtmlTags = RegExp(r'<[^>]+>');
  static final RegExp _reWhitespace = RegExp(r'\s+');
  static final RegExp _reDataId = RegExp(r'data-id="(\d+)"');
  static final RegExp _reMangaHref = RegExp(
    r'href="https://mangakatana\.com/manga/([^"/]+)"',
  );
  static final RegExp _reStatus = RegExp(r'class="status (ongoing|completed)"');
  static final RegExp _reExpandedTitle = RegExp(
    r'<h3 class="title">.*?<a[^>]*href="[^"]*manga/[^"]+"[^>]*>([^<]+)</a>',
    dotAll: true,
  );
  static final RegExp _reDateDiv = RegExp(
    r'<div class="date">.*?</div>',
    dotAll: true,
  );
  static final RegExp _reSummaryDiv = RegExp(
    r'<div class="summary[^"]*">(.*?)</div>',
    dotAll: true,
  );
  static final RegExp _reGenreLink = RegExp(
    r'href="https://mangakatana\.com/genre/([a-z0-9-]+)"[^>]*>([^<]+)</a>',
  );
  static final RegExp _reExpandedChapters = RegExp(
    '<div class="chapter"><a href="[^"]*/(${KatanaService.chapterIdPattern})"[^>]*>([^<]*)</a></div>'
    r'\s*</div>\s*<div class="uk-width-2-10"><div class="update_time">([^<]*)</div>',
    dotAll: true,
  );
  static final RegExp _reChapterLink = RegExp(
    r'<a href="https://mangakatana\.com/manga/[^"]*/(' +
        KatanaService.chapterIdPattern +
        r')"[^>]*>([^<]*)</a>',
  );
  static final RegExp _reCompactTitle = RegExp(
    r'<h3 class="title">\s*<a[^>]*>([^<]+)</a>',
    dotAll: true,
  );
  static final RegExp _reCompactAltTitle = RegExp(
    r'class="title">([^<]+)</a>',
  );
  static final RegExp _reCompactChapter = RegExp(
    r'href="[^"]*/(' + KatanaService.chapterIdPattern + r')"[^>]*>(.*?)</a>',
    dotAll: true,
  );
  static final RegExp _reCompactAuthor = RegExp(
    r'class="author" href="[^"]*"[^>]*>([^<]+)</a>',
  );
  static final RegExp _reHotUpdateChapter = RegExp(
    r'<div class="chapter">\s*<a href="[^"]*/(' +
        KatanaService.chapterIdPattern +
        r')"[^>]*>(.*?)</a>',
    dotAll: true,
  );
  static final RegExp _reHotTitle = RegExp(
    r'<h3 class="title"><a href="[^"]*"[^>]*>([^<]+)</a>',
  );
  static final RegExp _reHotChapter = RegExp(
    r'<div class="chapter"><a href="[^"]*/(' +
        KatanaService.chapterIdPattern +
        r')"[^>]*>([^<]*)</a>',
  );
  static final RegExp _reWebpSrcset = RegExp(
    r'<source [^>]*srcset="((?:https?:)?//[^"\s]+)"',
  );
  static final RegExp _reImgSrc = RegExp(r'<img [^>]*src="((?:https?:)?//[^"]+)"');
  static final RegExp _reImgDataSrc = RegExp(
    r'<img [^>]*data-src="((?:https?:)?//[^"]+)"',
  );
  static final RegExp _reDetailTitle = RegExp(r'<h1 class="heading">([^<]+)</h1>');
  static final RegExp _reDetailStatus = RegExp(
    r'class="d-cell-small value status (ongoing|completed)"',
  );
  static final RegExp _reDetailLatest = RegExp(
    r'class="d-cell-small value new_chap">([^<]+)</div>',
  );
  static final RegExp _reDetailUpdate = RegExp(
    r'class="d-cell-small value updateAt">([^<]+)</div>',
  );
  static final RegExp _reDetailAlt = RegExp(
    r'<div class="d-cell-small label">Alt name\(s\):</div>\s*<div class="d-cell-small value"><div class="alt_name">([^<]+)</div>',
    dotAll: true,
  );
  static final RegExp _reDetailAuthorSec = RegExp(
    r'<div class="d-cell-small label">Author\(s\) / Artist\(s\):</div>.*?</div>',
    dotAll: true,
  );
  static final RegExp _reDetailAuthorLink = RegExp(
    r'<a class="author" href="[^"]*"[^>]*>([^<]+)</a>',
  );
  static final RegExp _reDetailGenreSec = RegExp(
    r'<div class="d-cell-small label">Genres:</div>.*?</div>',
    dotAll: true,
  );
  static final RegExp _reDetailSummary = RegExp(
    r'<div class="summary">\s*<div class="label">Description</div>\s*<p>(.*?)</p>',
    dotAll: true,
  );
  static final RegExp _reGenreChip = RegExp(
    r'href="https://mangakatana\.com/genre/([a-z0-9-]+)">([^<]+)</a> <span>\((\d+)\)</span>',
  );
  static final RegExp _reGenreNav = RegExp(
    r'href="https://mangakatana\.com/genre/([a-z0-9-]+)" data-desc="([^"]*)"><h3 class="nav_label">([^<]+)</h3>',
  );

  String _clean(String html) {
    final withoutTags = html
        .replaceAll(_reHtmlTags, ' ')
        .replaceAll(_reWhitespace, ' ')
        .trim();
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
    final idMatch = _reDataId.firstMatch(block);
    final hrefMatch = _reMangaHref.firstMatch(block);
    if (hrefMatch == null) return null;

    final slug = hrefMatch.group(1)!;
    final id = idMatch?.group(1) ?? slug;

    final cover = _coverFrom(block);
    final statusM = _reStatus.firstMatch(block);
    final status = statusM?.group(1) ?? 'ongoing';

    final titleM = _reExpandedTitle.firstMatch(block);
    final title = titleM != null
        ? _unescape.convert(titleM.group(1)!.trim())
        : slug;

    final dateM = _reDateDiv.firstMatch(block);
    final updateText = dateM != null ? _clean(dateM.group(0)!) : '';

    final summaryM = _reSummaryDiv.firstMatch(block);
    final summary = summaryM != null ? _clean(summaryM.group(1)!) : '';

    final genres = <KatanaGenre>[];
    for (final g in _reGenreLink.allMatches(block)) {
      genres.add(
        KatanaGenre(
          slug: g.group(1)!,
          name: _unescape.convert(g.group(2)!.trim()),
        ),
      );
    }

    final latest = _parseChapterLink(block);

    final recent = <KatanaChapter>[];
    final chapterBlocks = _reExpandedChapters.allMatches(block);
    for (final m in chapterBlocks) {
      recent.add(
        KatanaChapter(
          id: m.group(1)!,
          num: katanaChapterNumFromId(m.group(1)!),
          title: _unescape.convert(m.group(2)!.trim()),
          updateAt: KatanaService._parseKatanaDate(m.group(3) ?? ''),
        ),
      );
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
    final m = _reChapterLink.firstMatch(block);
    if (m == null) return null;
    final id = m.group(1)!;
    return KatanaChapter(
      id: id,
      num: katanaChapterNumFromId(id),
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
      final hrefMatch = _reMangaHref.firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final idMatch = _reDataId.firstMatch(block);
      final titleM =
          _reCompactTitle.firstMatch(block) ??
          _reCompactAltTitle.firstMatch(block);
      final chapterM = _reCompactChapter.firstMatch(block);
      final authors = <String>[];
      for (final a in _reCompactAuthor.allMatches(block)) {
        authors.add(_unescape.convert(a.group(1)!.trim()));
      }
      final chapterTitle = chapterM != null ? _clean(chapterM.group(2)!) : '';
      items.add(
        KatanaManga(
          slug: slug,
          id: idMatch?.group(1) ?? slug,
          title: titleM != null
              ? _unescape.convert(titleM.group(1)!.trim())
              : slug,
          coverUrl: _coverFrom(block),
          latestChapter: chapterM != null
              ? KatanaChapter(
                  id: chapterM.group(1)!,
                  num: katanaChapterNumFromId(chapterM.group(1)!),
                  title: chapterTitle,
                )
              : null,
          authors: authors,
        ),
      );
    }
    return items;
  }

  /// Parses the Hot Updates rail at the very top of the home page
  /// (`#hot_update .slick_book`, desktop only on the site): compact
  /// cover + title + latest chapter, no status badge and no summary.
  /// The item markup differs slightly from the Hot Manga widget
  /// (whitespace inside `h3.title`, an `<i>` icon inside the chapter
  /// link), so it gets its own tolerant parser.
  List<KatanaManga> _parseHotUpdateRail(String html) {
    final start = html.indexOf('id="hot_update"');
    if (start < 0) return const [];
    final end = html.indexOf('id="wrap_content"', start);
    final blocks = KatanaService._blocksOfClass(
      html,
      'item',
      start: start,
      end: end,
    );
    final items = <KatanaManga>[];
    for (final block in blocks) {
      final hrefMatch = _reMangaHref.firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final titleM = _reCompactTitle.firstMatch(block);
      final chapterM = _reHotUpdateChapter.firstMatch(block);
      final idMatch = _reDataId.firstMatch(block);
      items.add(
        KatanaManga(
          slug: slug,
          id: idMatch?.group(1) ?? slug,
          title: titleM != null
              ? _unescape.convert(titleM.group(1)!.trim())
              : slug,
          coverUrl: _coverFrom(block),
          latestChapter: chapterM != null
              ? KatanaChapter(
                  id: chapterM.group(1)!,
                  num: katanaChapterNumFromId(chapterM.group(1)!),
                  title: _clean(chapterM.group(2)!),
                )
              : null,
        ),
      );
    }
    return items;
  }

  /// Parses the Hot Manga rail (compact cover + title + status +
  /// latest chapter).
  List<KatanaManga> _parseHotItems(List<String> blocks) {
    final items = <KatanaManga>[];
    for (final block in blocks) {
      final hrefMatch = _reMangaHref.firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final titleM = _reHotTitle.firstMatch(block);
      final statusM = _reStatus.firstMatch(block);
      final chapterM = _reHotChapter.firstMatch(block);
      final idMatch = _reDataId.firstMatch(block);
      items.add(
        KatanaManga(
          slug: slug,
          id: idMatch?.group(1) ?? slug,
          title: titleM != null
              ? _unescape.convert(titleM.group(1)!.trim())
              : slug,
          coverUrl: _coverFrom(block),
          status: statusM?.group(1) ?? 'ongoing',
          latestChapter: chapterM != null
              ? KatanaChapter(
                  id: chapterM.group(1)!,
                  num: katanaChapterNumFromId(chapterM.group(1)!),
                  title: _unescape.convert(chapterM.group(2)!.trim()),
                )
              : null,
        ),
      );
    }
    return items;
  }

  String _coverFrom(String block) {
    String? raw;
    final webp = _reWebpSrcset.firstMatch(block);
    if (webp != null) {
      raw = webp.group(1);
    } else {
      final img = _reImgSrc.firstMatch(block);
      if (img != null) {
        raw = img.group(1);
      } else {
        final dataSrc = _reImgDataSrc.firstMatch(block);
        if (dataSrc != null) {
          raw = dataSrc.group(1);
        }
      }
    }
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('//')) {
      raw = 'https:$raw';
    }
    return KatanaService.proxyImageUrl(raw);
  }

  KatanaManga? _parseDetail(String html, String slug) {
    final idMatch = _reDataId.firstMatch(html);
    final titleM = _reDetailTitle.firstMatch(html);
    final cover = _coverFrom(html);
    final statusM = _reDetailStatus.firstMatch(html);
    final latestM = _reDetailLatest.firstMatch(html);
    final updateM = _reDetailUpdate.firstMatch(html);

    final altNames = <String>[];
    final altM = _reDetailAlt.firstMatch(html);
    if (altM != null) {
      altNames.addAll(
        _unescape
            .convert(altM.group(1)!.trim())
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final authors = <String>[];
    final artists = <String>[];
    final authorM = _reDetailAuthorSec.firstMatch(html);
    if (authorM != null) {
      final section = authorM.group(0)!;
      var first = true;
      for (final a in _reDetailAuthorLink.allMatches(section)) {
        if (first) {
          authors.add(_unescape.convert(a.group(1)!.trim()));
        } else {
          artists.add(_unescape.convert(a.group(1)!.trim()));
        }
        first = false;
      }
    }

    final genres = <KatanaGenre>[];
    final genreSectionM = _reDetailGenreSec.firstMatch(html);
    final genreSection = genreSectionM?.group(0) ?? html;
    for (final g in _reGenreLink.allMatches(genreSection)) {
      genres.add(
        KatanaGenre(
          slug: g.group(1)!,
          name: _unescape.convert(g.group(2)!.trim()),
        ),
      );
    }

    final summaryM = _reDetailSummary.firstMatch(html);

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
          ? KatanaChapter(
              id: 'latest',
              num: '',
              title: latestM.group(1)!.trim(),
            )
          : null,
      updateAt: _parseRelativeTime(updateM?.group(1)?.trim() ?? ''),
      chapters: chapters,
    );
  }

  /// Parses genre links with counts (home Genres widget / directory
  /// sidebar / genres page) and merges descriptions from the nav menu.
  List<KatanaGenre> _parseGenres(String html) {
    final bySlug = <String, KatanaGenre>{};
    for (final m in _reGenreChip.allMatches(html)) {
      bySlug[m.group(1)!] = KatanaGenre(
        slug: m.group(1)!,
        name: _unescape.convert(m.group(2)!.trim()),
        count: int.tryParse(m.group(3)!) ?? 0,
      );
    }
    for (final m in _reGenreNav.allMatches(html)) {
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
}
