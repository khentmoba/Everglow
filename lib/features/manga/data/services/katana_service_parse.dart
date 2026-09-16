part of 'katana_service.dart';

/// HTML parsers for [KatanaService].
extension KatanaServiceParse on KatanaService {
  String _clean(String html) {
    final withoutTags = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
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
    final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
    final hrefMatch = RegExp(
      r'href="https://mangakatana\.com/manga/([^"/]+)"',
    ).firstMatch(block);
    if (hrefMatch == null) return null;

    final slug = hrefMatch.group(1)!;
    final id = idMatch?.group(1) ?? slug;

    final cover = _coverFrom(block);
    final statusM = RegExp(
      r'class="status (ongoing|completed)"',
    ).firstMatch(block);
    final status = statusM?.group(1) ?? 'ongoing';

    final titleM = RegExp(
      r'<h3 class="title">.*?<a[^>]*href="[^"]*manga/[^"]+"[^>]*>([^<]+)</a>',
      dotAll: true,
    ).firstMatch(block);
    final title = titleM != null
        ? _unescape.convert(titleM.group(1)!.trim())
        : slug;

    final dateM = RegExp(
      r'<div class="date">.*?</div>',
      dotAll: true,
    ).firstMatch(block);
    final updateText = dateM != null ? _clean(dateM.group(0)!) : '';

    final summaryM = RegExp(
      r'<div class="summary[^"]*">(.*?)</div>',
      dotAll: true,
    ).firstMatch(block);
    final summary = summaryM != null ? _clean(summaryM.group(1)!) : '';

    final genres = <KatanaGenre>[];
    for (final g in RegExp(
      r'href="https://mangakatana\.com/genre/([a-z0-9-]+)"[^>]*>([^<]+)</a>',
    ).allMatches(block)) {
      genres.add(
        KatanaGenre(
          slug: g.group(1)!,
          name: _unescape.convert(g.group(2)!.trim()),
        ),
      );
    }

    final latest = _parseChapterLink(block);

    final recent = <KatanaChapter>[];
    final chapterBlocks = RegExp(
      '<div class="chapter"><a href="[^"]*/(${KatanaService.chapterIdPattern})"[^>]*>([^<]*)</a></div>'
      r'\s*</div>\s*<div class="uk-width-2-10"><div class="update_time">([^<]*)</div>',
      dotAll: true,
    ).allMatches(block);
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
    final m = RegExp(
      r'<a href="https://mangakatana\.com/manga/[^"]*/(' +
          KatanaService.chapterIdPattern +
          r')"[^>]*>([^<]*)</a>',
    ).firstMatch(block);
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
      final hrefMatch = RegExp(
        r'href="https://mangakatana\.com/manga/([^"/]+)"',
      ).firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
      final titleM =
          RegExp(
            r'<h3 class="title">\s*<a[^>]*>([^<]+)</a>',
            dotAll: true,
          ).firstMatch(block) ??
          RegExp(r'class="title">([^<]+)</a>').firstMatch(block);
      final chapterM = RegExp(
        r'href="[^"]*/(' +
            KatanaService.chapterIdPattern +
            r')"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      final authors = <String>[];
      for (final a in RegExp(
        r'class="author" href="[^"]*"[^>]*>([^<]+)</a>',
      ).allMatches(block)) {
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
      final hrefMatch = RegExp(
        r'href="https://mangakatana\.com/manga/([^"/]+)"',
      ).firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final titleM = RegExp(
        r'<h3 class="title">\s*<a[^>]*>([^<]+)</a>',
        dotAll: true,
      ).firstMatch(block);
      final chapterM = RegExp(
        r'<div class="chapter">\s*<a href="[^"]*/(' +
            KatanaService.chapterIdPattern +
            r')"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(block);
      final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
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
      final hrefMatch = RegExp(
        r'href="https://mangakatana\.com/manga/([^"/]+)"',
      ).firstMatch(block);
      if (hrefMatch == null) continue;
      final slug = hrefMatch.group(1)!;
      final titleM = RegExp(
        r'<h3 class="title"><a href="[^"]*"[^>]*>([^<]+)</a>',
      ).firstMatch(block);
      final statusM = RegExp(
        r'class="status (ongoing|completed)"',
      ).firstMatch(block);
      final chapterM = RegExp(
        r'<div class="chapter"><a href="[^"]*/(' +
            KatanaService.chapterIdPattern +
            r')"[^>]*>([^<]*)</a>',
      ).firstMatch(block);
      final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(block);
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
    final webp = RegExp(
      r'<source [^>]*srcset="((?:https?:)?//[^"\s]+)"',
    ).firstMatch(block);
    if (webp != null) {
      raw = webp.group(1);
    } else {
      final img = RegExp(
        r'<img [^>]*src="((?:https?:)?//[^"]+)"',
      ).firstMatch(block);
      if (img != null) {
        raw = img.group(1);
      } else {
        final dataSrc = RegExp(
          r'<img [^>]*data-src="((?:https?:)?//[^"]+)"',
        ).firstMatch(block);
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
    final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(html);
    final titleM = RegExp(r'<h1 class="heading">([^<]+)</h1>').firstMatch(html);
    final cover = _coverFrom(html);
    final statusM = RegExp(
      r'class="d-cell-small value status (ongoing|completed)"',
    ).firstMatch(html);
    final latestM = RegExp(
      r'class="d-cell-small value new_chap">([^<]+)</div>',
    ).firstMatch(html);
    final updateM = RegExp(
      r'class="d-cell-small value updateAt">([^<]+)</div>',
    ).firstMatch(html);

    final altNames = <String>[];
    final altM = RegExp(
      r'<div class="d-cell-small label">Alt name\(s\):</div>\s*<div class="d-cell-small value"><div class="alt_name">([^<]+)</div>',
      dotAll: true,
    ).firstMatch(html);
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
    final authorM = RegExp(
      r'<div class="d-cell-small label">Author\(s\) / Artist\(s\):</div>.*?</div>',
      dotAll: true,
    ).firstMatch(html);
    if (authorM != null) {
      final section = authorM.group(0)!;
      var first = true;
      for (final a in RegExp(
        r'<a class="author" href="[^"]*"[^>]*>([^<]+)</a>',
      ).allMatches(section)) {
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
      r'<div class="d-cell-small label">Genres:</div>.*?</div>',
      dotAll: true,
    ).firstMatch(html);
    final genreSection = genreSectionM?.group(0) ?? html;
    for (final g in RegExp(
      r'href="https://mangakatana\.com/genre/([a-z0-9-]+)"[^>]*>([^<]+)</a>',
    ).allMatches(genreSection)) {
      genres.add(
        KatanaGenre(
          slug: g.group(1)!,
          name: _unescape.convert(g.group(2)!.trim()),
        ),
      );
    }

    final summaryM = RegExp(
      r'<div class="summary">\s*<div class="label">Description</div>\s*<p>(.*?)</p>',
      dotAll: true,
    ).firstMatch(html);

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
    final chipRe = RegExp(
      r'href="https://mangakatana\.com/genre/([a-z0-9-]+)">([^<]+)</a> <span>\((\d+)\)</span>',
    );
    for (final m in chipRe.allMatches(html)) {
      bySlug[m.group(1)!] = KatanaGenre(
        slug: m.group(1)!,
        name: _unescape.convert(m.group(2)!.trim()),
        count: int.tryParse(m.group(3)!) ?? 0,
      );
    }
    final navRe = RegExp(
      r'href="https://mangakatana\.com/genre/([a-z0-9-]+)" data-desc="([^"]*)"><h3 class="nav_label">([^<]+)</h3>',
    );
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
}
