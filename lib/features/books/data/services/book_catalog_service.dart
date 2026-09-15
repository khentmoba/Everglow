import 'dart:math';

import '../models/book_item.dart';
import '../models/book_search_result.dart';
import './gutenberg_service.dart';
import './internet_archive_service.dart';
import './open_library_service.dart';

/// Sort modes copied from WeLib's search page.
enum BookSort { relevant, popular, newest, oldest, largest, smallest, random }

/// Z-Lib style advanced-search filters. Every field maps onto either
/// an Open Library query field (title / author / publisher / isbn)
/// or a client-side post-filter (year range, exact match) applied
/// after the three sources are merged.
class BookSearchFilters {
  final String? title;
  final String? author;
  final String? publisher;
  final String? isbn;
  final int? yearFrom;
  final int? yearTo;
  final bool exact;

  const BookSearchFilters({
    this.title,
    this.author,
    this.publisher,
    this.isbn,
    this.yearFrom,
    this.yearTo,
    this.exact = false,
  });

  static const BookSearchFilters none = BookSearchFilters();

  bool get isEmpty =>
      (title?.trim().isEmpty ?? true) &&
      (author?.trim().isEmpty ?? true) &&
      (publisher?.trim().isEmpty ?? true) &&
      (isbn?.trim().isEmpty ?? true) &&
      yearFrom == null &&
      yearTo == null &&
      !exact;

  bool get isNotEmpty => !isEmpty;

  /// Short human summary for the filter pill, e.g. "Author + 1940–1960".
  String get summary {
    final parts = <String>[];
    if (title?.trim().isNotEmpty == true) parts.add('Title');
    if (author?.trim().isNotEmpty == true) parts.add('Author');
    if (publisher?.trim().isNotEmpty == true) parts.add('Publisher');
    if (isbn?.trim().isNotEmpty == true) parts.add('ISBN');
    if (yearFrom != null || yearTo != null) {
      parts.add('${yearFrom ?? '…'}–${yearTo ?? '…'}');
    }
    if (exact) parts.add('Exact');
    return parts.join(' · ');
  }
}

/// One page of merged catalog results. `total` is the Open Library
/// catalog-wide match count; `hasMore` tells the list whether a
/// "Load more" row should be shown.
class CatalogPage {
  final List<BookSearchResult> results;
  final int total;
  final bool hasMore;

  const CatalogPage({
    required this.results,
    required this.total,
    required this.hasMore,
  });

  static const CatalogPage empty = CatalogPage(
    results: [],
    total: 0,
    hasMore: false,
  );
}

/// The "database" behind the WeLib-style search: merges Open Library
/// (discovery + metadata), Project Gutenberg (public-domain text +
/// downloads), and Internet Archive (public-domain downloads) into a
/// single result set, then applies filetype / language filters and
/// WeLib's sort modes.
class BookCatalogService {
  static final BookCatalogService _instance = BookCatalogService._internal();
  factory BookCatalogService() => _instance;
  BookCatalogService._internal();

  final OpenLibraryService _openLibrary = OpenLibraryService();
  final GutenbergService _gutenberg = GutenbergService();
  final InternetArchiveService _archive = InternetArchiveService();
  final Random _random = Random();

  static const List<String> supportedFiletypes = [
    'epub',
    'pdf',
    'txt',
    'mobi',
    'fb2',
    'html',
  ];

  static const List<String> supportedLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Italian',
    'Portuguese',
    'Russian',
    'Dutch',
  ];

  Future<List<BookSearchResult>> search(
    String query, {
    String? filetype,
    String? language,
    BookSort sort = BookSort.relevant,
    int limit = 30,
    BookSearchFilters filters = BookSearchFilters.none,
    int offset = 0,
  }) async {
    final page = await searchPaged(
      query,
      filetype: filetype,
      language: language,
      sort: sort,
      limit: limit,
      offset: offset,
      filters: filters,
    );
    return page.results;
  }

  /// Z-Lib style paged search across the merged catalog.
  ///
  /// Page 1 fans out to all three sources (Open Library +
  /// Gutenberg + Internet Archive) and merges them. Deeper pages
  /// are Open Library only — it is the only source with true
  /// offset paging over millions of docs, and merging ranked pages
  /// from three APIs would duplicate and mis-order results.
  Future<CatalogPage> searchPaged(
    String query, {
    String? filetype,
    String? language,
    BookSort sort = BookSort.relevant,
    int limit = 30,
    int offset = 0,
    BookSearchFilters filters = BookSearchFilters.none,
  }) async {
    if (query.trim().isEmpty && filters.isEmpty) return CatalogPage.empty;
    final langCode = language == null ? null : _langCode(language);
    final q = query.trim();

    if (offset > 0) {
      final page = await _openLibrary.searchPaged(
        q,
        limit: limit,
        offset: offset,
        title: filters.title,
        author: filters.author,
        publisher: filters.publisher,
        isbn: filters.isbn,
      );
      var results = _fromOpenLibrary(page.items);
      results = _applyFilters(
        results,
        filetype: filetype,
        language: language,
        filters: filters,
        query: q,
      );
      results = _applySort(results, sort);
      return CatalogPage(
        results: results,
        total: page.total,
        hasMore: offset + page.items.length < page.total,
      );
    }

    final results = await Future.wait([
      _openLibrary
          .searchPaged(
            q,
            limit: limit,
            title: filters.title,
            author: filters.author,
            publisher: filters.publisher,
            isbn: filters.isbn,
          )
          .then((p) => (page: p, results: _fromOpenLibrary(p.items))),
      _gutenberg.search(
        _effectiveQuery(q, filters),
        language: _gutenbergLang(langCode),
        limit: limit,
      ),
      _archive.search(
        _effectiveQuery(q, filters),
        language: langCode,
        limit: limit,
      ),
    ]);

    final olPage = (results[0] as ({OpenLibraryPage page, List<BookSearchResult> results})).page;
    final olResults =
        (results[0] as ({OpenLibraryPage page, List<BookSearchResult> results})).results;
    final all = [
      ...olResults,
      ...(results[1] as List<BookSearchResult>),
      ...(results[2] as List<BookSearchResult>),
    ];
    var merged = _merge(all);
    merged = _applyFilters(
      merged,
      filetype: filetype,
      language: language,
      filters: filters,
      query: q,
    );
    merged = _applySort(merged, sort);
    final clipped = merged.take(limit).toList();
    return CatalogPage(
      results: clipped,
      total: olPage.total,
      hasMore: olPage.total > olResults.length || merged.length > limit,
    );
  }

  /// Gutenberg and Gutendex/IA only take a free-text query, so fold
  /// the structured filters into one best-effort string for them.
  /// The precise filtering still happens client-side in [_applyFilters].
  String _effectiveQuery(String query, BookSearchFilters filters) {
    final parts = <String>[
      query,
      if (filters.title?.trim().isNotEmpty == true) filters.title!.trim(),
      if (filters.author?.trim().isNotEmpty == true) filters.author!.trim(),
    ];
    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  /// Most Popular analog: Open Library trending plus Gutenberg's
  /// most-downloaded catalog, merged.
  Future<List<BookSearchResult>> mostPopular({int limit = 20}) async {
    final results = await Future.wait([
      _openLibrary.fetchTrending().then(_fromOpenLibrary),
      _gutenberg.mostPopular(limit: limit),
    ]);
    final merged = _merge(results.expand((r) => r).toList());
    return _applySort(merged, BookSort.popular).take(limit).toList();
  }

  /// Recently Added analog: recently *published* Open Library books
  /// with real covers (see `OpenLibraryService.fetchRecent`). Only OL
  /// tracks publish years at this scale, so this feed is OL-only by
  /// design. Cover-less stragglers are dropped so the rail never
  /// renders placeholder tiles.
  Future<List<BookSearchResult>> recentlyAdded({int limit = 20}) async {
    final items = await _openLibrary.fetchRecent(limit: limit);
    final mapped = _fromOpenLibrary(items);
    final withCovers = mapped.where((r) => r.coverUrl.isNotEmpty).toList();
    return withCovers.isNotEmpty ? withCovers : mapped;
  }

  /// Category browse: subject discovery mapped to catalog results.
  /// Powers both the home rails and the full category list pages.
  Future<List<BookSearchResult>> byCategory(String category, {int limit = 20}) {
    return byCategoryPaged(category, limit: limit);
  }

  /// Paged variant for category list pages (`offset` > 0 loads
  /// deeper Open Library subject pages).
  Future<List<BookSearchResult>> byCategoryPaged(
    String category, {
    int limit = 30,
    int offset = 0,
  }) async {
    final items = await _openLibrary.discoverBySubject(
      category,
      limit: limit,
      offset: offset,
    );
    return _fromOpenLibrary(items).map((r) {
      if (r.categories.contains(category)) return r;
      return r.copyWith(categories: [...r.categories, category]);
    }).toList();
  }



  /// Enrich a result with the full detail payload (description,
  /// publisher, size, real download URLs) for the detail page.
  Future<BookSearchResult> details(BookSearchResult result) async {
    var enriched = result;
    if (result.iaId.isNotEmpty) {
      enriched = (await _archive.fetchMetadata(result)) ?? result;
    } else if (result.gutenbergId > 0) {
      enriched = (await _gutenberg.fetchBook(result.gutenbergId)) ?? result;
    } else if (result.workKey.isNotEmpty) {
      final fetched = await Future.wait([
        _openLibrary.fetchWorkDetails(result.workKey),
        _openLibrary.fetchEditions(result.workKey),
      ]);
      final work = fetched[0] as Map<String, dynamic>?;
      final editions = fetched[1] as List<Map<String, dynamic>>;
      // First edition carrying physical details (pages, ISBN,
      // publisher) — feeds the Z-Lib style meta table.
      Map<String, dynamic>? edition;
      for (final e in editions) {
        if ((e['number_of_pages'] as num?) != null ||
            (e['isbn_13'] is List && (e['isbn_13'] as List).isNotEmpty) ||
            (e['isbn_10'] is List && (e['isbn_10'] as List).isNotEmpty) ||
            (e['publishers'] is List &&
                (e['publishers'] as List).isNotEmpty)) {
          edition = e;
          break;
        }
      }
      edition ??= editions.isNotEmpty ? editions.first : null;
      if (work != null) {
        final descRaw = work['description'];
        String desc = '';
        if (descRaw is String) {
          desc = descRaw;
        } else if (descRaw is Map && descRaw['value'] is String) {
          desc = descRaw['value'] as String;
        }
        final subjectsRaw = work['subjects'];
        final subjects = subjectsRaw is List
            ? subjectsRaw
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList()
            : const <String>[];
        final publisher =
            (work['publishers'] is List &&
                (work['publishers'] as List).isNotEmpty)
            ? (work['publishers'] as List).first.toString()
            : '';
        final editionPublishers = edition?['publishers'];
        final editionPublisher =
            editionPublishers is List && editionPublishers.isNotEmpty
            ? editionPublishers.first.toString()
            : '';
        final isbn13 = edition?['isbn_13'];
        final isbn10 = edition?['isbn_10'];
        enriched = enriched.copyWith(
          description: desc.isNotEmpty ? desc : result.description,
          subjects: subjects.isNotEmpty ? subjects : result.subjects,
          publisher: publisher.isNotEmpty
              ? publisher
              : (editionPublisher.isNotEmpty
                    ? editionPublisher
                    : result.publisher),
          pageCount:
              (edition?['number_of_pages'] as num?)?.toInt() ?? result.pageCount,
          isbn13: isbn13 is List && isbn13.isNotEmpty
              ? isbn13.first.toString()
              : result.isbn13,
          isbn: isbn10 is List && isbn10.isNotEmpty
              ? isbn10.first.toString()
              : result.isbn,
          year: (work['first_publish_date'] as String?)?.isNotEmpty == true
              ? work['first_publish_date'] as String
              : result.year,
        );
      }
    }
    return enriched;
  }

  /// Similar books: subject overlap via Open Library, falling back
  /// to the same author.
  Future<List<BookSearchResult>> similar(
    BookSearchResult result, {
    int limit = 10,
  }) async {
    final queries = <String>[
      if (result.subjects.isNotEmpty) result.subjects.first,
      if (result.author.isNotEmpty) result.author,
    ];
    for (final query in queries) {
      final items = await _openLibrary.discoverBySubject(query, limit: limit);
      if (items.isNotEmpty) {
        final mapped = _fromOpenLibrary(
          items,
        ).where((r) => r.id != result.id).take(limit).toList();
        if (mapped.isNotEmpty) return mapped;
      }
    }
    return const [];
  }

  /// True when this result can be read or downloaded in-app.
  bool get isSupportedCatalog => true;

  /// Compact count for result headers: 1234 -> "1.2K".
  static String compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ---------------------------------------------------------------------
  // Mapping + merge
  // ---------------------------------------------------------------------

  List<BookSearchResult> _fromOpenLibrary(List<BookItem> items) {
    return items.map((item) {
      final gutenberg = item.iaId.startsWith('pg') && item.iaId.length > 2
          ? int.tryParse(item.iaId.substring(2)) ?? 0
          : 0;
      final ia = !item.iaId.startsWith('pg') ? item.iaId : '';
      final readUrl = item.readSourceUrl;
      final isbn = item.isbn;
      return BookSearchResult(
        title: item.title,
        author: item.author,
        coverUrl: item.coverUrl,
        year: item.year,
        publisher: item.publisher,
        subjects: item.subjects,
        isbn: isbn.length == 10 ? isbn : '',
        isbn13: isbn.length == 13 ? isbn : '',
        sourceLabel: item.readSourceLabel.isNotEmpty
            ? item.readSourceLabel
            : 'Open Library',
        workKey: item.workKey,
        iaId: ia,
        gutenbergId: gutenberg,
        downloadUrls: gutenberg > 0
            ? {
                'txt':
                    'https://www.gutenberg.org/cache/epub/$gutenberg/pg$gutenberg.txt',
                'epub':
                    'https://www.gutenberg.org/ebooks/$gutenberg.epub3.images',
              }
            : (ia.isNotEmpty
                  ? {
                      'epub': 'https://archive.org/download/$ia/$ia.epub',
                      'pdf': 'https://archive.org/download/$ia/$ia.pdf',
                    }
                  : const <String, String>{}),
        readCandidates: readUrl.isNotEmpty ? [readUrl] : const [],
      );
    }).toList();
  }

  /// Merge duplicate titles across sources, preferring the record
  /// with the richest metadata and combining download URLs.
  List<BookSearchResult> _merge(List<BookSearchResult> results) {
    final byKey = <String, BookSearchResult>{};
    final order = <String>[];
    for (final result in results) {
      final key = _dedupeKey(result);
      if (key.isEmpty) continue;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = result;
        order.add(key);
      } else {
        byKey[key] = _richer(existing, result);
      }
    }
    return order.map((k) => byKey[k]!).toList();
  }

  BookSearchResult _richer(BookSearchResult a, BookSearchResult b) {
    final downloads = <String, String>{...a.downloadUrls, ...b.downloadUrls};
    final readCandidates = <String>[...a.readCandidates, ...b.readCandidates];
    final categories = <String>{...a.categories, ...b.categories}.toList();
    return a.copyWith(
      isbn: a.isbn.isEmpty ? b.isbn : a.isbn,
      isbn13: a.isbn13.isEmpty ? b.isbn13 : a.isbn13,
      categories: categories,
      description: a.description.isEmpty ? b.description : a.description,
      publisher: a.publisher.isEmpty ? b.publisher : a.publisher,
      filetype: a.filetype.isEmpty ? b.filetype : a.filetype,
      sizeMb: a.sizeMb ?? b.sizeMb,
      rating: a.rating ?? b.rating,
      ratingCount: a.ratingCount ?? b.ratingCount,
      language: a.language.isEmpty ? b.language : a.language,
      year: a.year.isEmpty ? b.year : a.year,
      sourceLabel: a.sourceLabel.isEmpty ? b.sourceLabel : a.sourceLabel,
      gutenbergId: a.gutenbergId > 0 ? a.gutenbergId : b.gutenbergId,
      iaId: a.iaId.isNotEmpty ? a.iaId : b.iaId,
      workKey: a.workKey.isNotEmpty ? a.workKey : b.workKey,
      downloadUrls: downloads,
      readCandidates: readCandidates.toSet().toList(),
    );
  }

  String _dedupeKey(BookSearchResult r) {
    final t = r.title.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final a = r.author.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return '';
    return '$t|$a';
  }

  List<BookSearchResult> _applyFilters(
    List<BookSearchResult> results, {
    String? filetype,
    String? language,
    BookSearchFilters filters = BookSearchFilters.none,
    String query = '',
  }) {
    return results.where((r) {
      if (filetype != null && filetype.isNotEmpty) {
        final has =
            r.downloadUrls.containsKey(filetype) ||
            r.filetype.toLowerCase() == filetype.toLowerCase();
        if (!has) return false;
      }
      if (language != null && language.isNotEmpty) {
        if (r.language.isEmpty ||
            r.language.toLowerCase() != language.toLowerCase()) {
          return false;
        }
      }
      // Structured filters: Open Library already applied them
      // server-side, but Gutenberg/IA results need them here.
      if (filters.title?.trim().isNotEmpty == true &&
          !r.title.toLowerCase().contains(filters.title!.trim().toLowerCase())) {
        return false;
      }
      if (filters.author?.trim().isNotEmpty == true &&
          !r.author.toLowerCase().contains(
            filters.author!.trim().toLowerCase(),
          )) {
        return false;
      }
      if (filters.publisher?.trim().isNotEmpty == true &&
          !r.publisher.toLowerCase().contains(
            filters.publisher!.trim().toLowerCase(),
          )) {
        return false;
      }
      if (filters.isbn?.trim().isNotEmpty == true) {
        final needle = filters.isbn!.trim().replaceAll('-', '');
        final hay = '${r.isbn}${r.isbn13}'.replaceAll('-', '');
        if (hay.isEmpty || !hay.contains(needle)) return false;
      }
      final year = _yearOf(r);
      if (filters.yearFrom != null && year < filters.yearFrom!) return false;
      if (filters.yearTo != null && year > 0 && year > filters.yearTo!) {
        return false;
      }
      // Exact match: the title or author must equal the query.
      if (filters.exact && query.isNotEmpty) {
        final q = query.trim().toLowerCase();
        if (r.title.trim().toLowerCase() != q &&
            r.author.trim().toLowerCase() != q) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<BookSearchResult> _applySort(
    List<BookSearchResult> results,
    BookSort sort,
  ) {
    final list = [...results];
    switch (sort) {
      case BookSort.relevant:
        break;
      case BookSort.popular:
        list.sort((a, b) => (b.ratingCount ?? 0).compareTo(a.ratingCount ?? 0));
        break;
      case BookSort.newest:
        list.sort((a, b) => _yearOf(b).compareTo(_yearOf(a)));
        break;
      case BookSort.oldest:
        list.sort((a, b) => _yearOf(a).compareTo(_yearOf(b)));
        break;
      case BookSort.largest:
        list.sort((a, b) => (b.sizeMb ?? 0).compareTo(a.sizeMb ?? 0));
        break;
      case BookSort.smallest:
        list.sort((a, b) => (a.sizeMb ?? 0).compareTo(b.sizeMb ?? 0));
        break;
      case BookSort.random:
        list.shuffle(_random);
        break;
    }
    return list;
  }

  int _yearOf(BookSearchResult r) {
    final match = RegExp(r'\d{4}').firstMatch(r.year);
    if (match == null) return 0;
    return int.parse(match.group(0)!);
  }

  String? _gutenbergLang(String? code) {
    if (code == null) return null;
    switch (code) {
      case 'eng':
        return 'en';
      case 'spa':
        return 'es';
      case 'fre':
        return 'fr';
      case 'ger':
        return 'de';
      case 'chi':
        return 'zh';
      case 'jpn':
        return 'ja';
      case 'rus':
        return 'ru';
      case 'ita':
        return 'it';
      case 'por':
        return 'pt';
      case 'dut':
        return 'nl';
      case 'pol':
        return 'pl';
      default:
        return null;
    }
  }

  String? _langCode(String language) {
    switch (language.toLowerCase()) {
      case 'english':
        return 'eng';
      case 'spanish':
        return 'spa';
      case 'french':
        return 'fre';
      case 'german':
        return 'ger';
      case 'chinese':
        return 'chi';
      case 'japanese':
        return 'jpn';
      case 'italian':
        return 'ita';
      case 'portuguese':
        return 'por';
      case 'russian':
        return 'rus';
      case 'dutch':
        return 'dut';
      default:
        return null;
    }
  }
}
