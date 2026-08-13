import 'dart:math';

import '../models/book_item.dart';
import '../models/book_search_result.dart';
import './gutenberg_service.dart';
import './internet_archive_service.dart';
import './open_library_service.dart';

/// Sort modes copied from WeLib's search page.
enum BookSort { relevant, popular, newest, oldest, largest, smallest, random }

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
  }) async {
    if (query.trim().isEmpty) return const [];
    final langCode = language == null ? null : _langCode(language);

    final results = await Future.wait([
      _openLibrary.searchBooks(query).then(_fromOpenLibrary),
      _gutenberg.search(query, language: _gutenbergLang(langCode), limit: limit),
      _archive.search(query, language: langCode, limit: limit),
    ]);

    var merged = _merge(results.expand((r) => r).toList());
    merged = _applyFilters(merged, filetype: filetype, language: language);
    merged = _applySort(merged, sort);
    return merged.take(limit).toList();
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

  /// Enrich a result with the full detail payload (description,
  /// publisher, size, real download URLs) for the detail page.
  Future<BookSearchResult> details(BookSearchResult result) async {
    var enriched = result;
    if (result.iaId.isNotEmpty) {
      enriched = (await _archive.fetchMetadata(result)) ?? result;
    } else if (result.gutenbergId > 0) {
      enriched = (await _gutenberg.fetchBook(result.gutenbergId)) ?? result;
    } else if (result.workKey.isNotEmpty) {
      final work = await _openLibrary.fetchWorkDetails(result.workKey);
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
            ? subjectsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
            : const <String>[];
        final publisher = (work['publishers'] is List &&
                (work['publishers'] as List).isNotEmpty)
            ? (work['publishers'] as List).first.toString()
            : '';
        enriched = enriched.copyWith(
          description: desc.isNotEmpty ? desc : result.description,
          subjects: subjects.isNotEmpty ? subjects : result.subjects,
          publisher: publisher.isNotEmpty ? publisher : result.publisher,
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
  Future<List<BookSearchResult>> similar(BookSearchResult result,
      {int limit = 10}) async {
    final queries = <String>[
      if (result.subjects.isNotEmpty) result.subjects.first,
      if (result.author.isNotEmpty) result.author,
    ];
    for (final query in queries) {
      final items = await _openLibrary.discoverBySubject(query, limit: limit);
      if (items.isNotEmpty) {
        final mapped = _fromOpenLibrary(items)
            .where((r) => r.id != result.id)
            .take(limit)
            .toList();
        if (mapped.isNotEmpty) return mapped;
      }
    }
    return const [];
  }

  /// True when this result can be read or downloaded in-app.
  bool get isSupportedCatalog => true;

  // ---------------------------------------------------------------------
  // Mapping + merge
  // ---------------------------------------------------------------------

  List<BookSearchResult> _fromOpenLibrary(List<BookItem> items) {
    return items.map((item) {
      final gutenberg = item.iaId.startsWith('pg') &&
              item.iaId.length > 2
          ? int.tryParse(item.iaId.substring(2)) ?? 0
          : 0;
      final ia = !item.iaId.startsWith('pg') ? item.iaId : '';
      final readUrl = item.readSourceUrl;
      return BookSearchResult(
        title: item.title,
        author: item.author,
        coverUrl: item.coverUrl,
        year: item.year,
        subjects: item.subjects,
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
                    'epub':
                        'https://archive.org/download/$ia/$ia.epub',
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
    final readCandidates = <String>[
      ...a.readCandidates,
      ...b.readCandidates,
    ];
    return a.copyWith(
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
  }) {
    return results.where((r) {
      if (filetype != null && filetype.isNotEmpty) {
        final has = r.downloadUrls.containsKey(filetype) ||
            r.filetype.toLowerCase() == filetype.toLowerCase();
        if (!has) return false;
      }
      if (language != null && language.isNotEmpty) {
        if (r.language.isEmpty ||
            r.language.toLowerCase() != language.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<BookSearchResult> _applySort(
      List<BookSearchResult> results, BookSort sort) {
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
