import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/utils/logger.dart';
import '../models/book_search_result.dart';

/// Searches Project Gutenberg through the Gutendex API
/// (https://gutendex.com). All returned books are public domain, so
/// every title here has a legal plain-text read source and
/// downloadable epub / mobi / txt formats.
class GutenbergService {
  static final GutenbergService _instance = GutenbergService._internal();
  factory GutenbergService() => _instance;
  GutenbergService._internal();

  static const String _base = 'https://gutendex.com/books';

  Future<List<BookSearchResult>> search(
    String query, {
    String? language,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return const [];
    final params = <String, String>{
      'search': query.trim(),
      if (language != null && language.isNotEmpty) 'languages': language,
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? const [];
        return results
            .take(limit)
            .map((b) => _mapBook(b as Map<String, dynamic>))
            .where((b) => b.title.isNotEmpty)
            .toList();
      }
      Logger.e('Gutendex search failed (${response.statusCode})');
    } catch (e) {
      Logger.e('Gutendex search error', error: e);
    }
    return const [];
  }

  /// Most-downloaded public-domain books — the closest legal analog
  /// to WeLib's "Most Popular".
  Future<List<BookSearchResult>> mostPopular({int limit = 20}) async {
    final uri = Uri.parse('$_base?sort=popular');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? const [];
        return results
            .take(limit)
            .map((b) => _mapBook(b as Map<String, dynamic>))
            .where((b) => b.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      Logger.e('Gutendex popular error', error: e);
    }
    return const [];
  }

  Future<BookSearchResult?> fetchBook(int id) async {
    try {
      final response = await http.get(Uri.parse('$_base/$id'));
      if (response.statusCode == 200) {
        final book = json.decode(response.body) as Map<String, dynamic>;
        final mapped = _mapBook(book);
        return mapped.title.isNotEmpty ? mapped : null;
      }
    } catch (e) {
      Logger.e('Gutendex fetchBook error ($id)', error: e);
    }
    return null;
  }

  BookSearchResult _mapBook(Map<String, dynamic> book) {
    final id = (book['id'] as num?)?.toInt() ?? 0;
    final title = (book['title'] as String?)?.trim() ?? '';
    final authors = book['authors'] as List? ?? const [];
    final author = authors.isNotEmpty
        ? (((authors.first as Map<String, dynamic>)['name'] as String?) ?? '')
        : '';

    final formats = (book['formats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final coverUrl = _firstFormat(formats, 'image/jpeg') ?? '';

    final languages = (book['languages'] as List?)?.cast<String>() ?? const [];
    final language = languages.isNotEmpty ? _languageName(languages.first) : '';

    final downloads = (book['download_count'] as num?)?.toInt() ?? 0;

    final txtUrl = _firstFormat(formats, 'text/plain; charset=us-ascii') ??
        _firstFormat(formats, 'text/plain') ??
        (id > 0 ? 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt' : '');
    final epubUrl = _firstFormat(formats, 'application/epub+zip');
    final mobiUrl = _firstFormat(formats, 'application/x-mobipocket-ebook');
    final htmlUrl = _firstFormat(formats, 'text/html') ??
        _firstFormat(formats, 'text/html; charset=utf-8');
    final pdfUrl = _firstFormat(formats, 'application/pdf');

    final downloadUrls = <String, String>{
      if (txtUrl.isNotEmpty) 'txt': txtUrl,
      if (epubUrl != null && epubUrl.isNotEmpty) 'epub': epubUrl,
      if (mobiUrl != null && mobiUrl.isNotEmpty) 'mobi': mobiUrl,
      if (htmlUrl != null && htmlUrl.isNotEmpty) 'html': htmlUrl,
      if (pdfUrl != null && pdfUrl.isNotEmpty) 'pdf': pdfUrl,
    };

    final subjects = (book['subjects'] as List?)
            ?.map((e) => e.toString().replaceAll(RegExp(r'\s*--\s*'), ' · '))
            .where((s) => s.trim().isNotEmpty)
            .take(8)
            .toList() ??
        const <String>[];

    return BookSearchResult(
      title: title,
      author: author,
      coverUrl: coverUrl,
      language: language,
      filetype: epubUrl != null ? 'epub' : 'txt',
      rating: null,
      ratingCount: downloads > 0 ? downloads : null,
      description: '',
      subjects: subjects,
      sourceLabel: 'Project Gutenberg',
      gutenbergId: id,
      downloadUrls: downloadUrls,
      readCandidates: [if (txtUrl.isNotEmpty) txtUrl],
    );
  }

  String? _firstFormat(Map<String, dynamic> formats, String key) {
    final value = formats[key];
    if (value is String && value.isNotEmpty) return value;
    // Gutendex also exposes keys like "text/plain; charset=utf-8" —
    // fall back to prefix matching.
    for (final entry in formats.entries) {
      if (entry.key.startsWith(key)) {
        final v = entry.value;
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  String _languageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ru':
        return 'Russian';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'nl':
        return 'Dutch';
      case 'pl':
        return 'Polish';
      case 'sv':
        return 'Swedish';
      case 'ar':
        return 'Arabic';
      case 'tr':
        return 'Turkish';
      default:
        return code.toUpperCase();
    }
  }
}
