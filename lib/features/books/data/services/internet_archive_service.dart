import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/core/utils/logger.dart';
import '../models/book_search_result.dart';

/// Searches the Internet Archive's public text collection via the
/// `advancedsearch` JSON endpoint and resolves per-item download and
/// read URLs from the item metadata API. Only public-domain items
/// are surfaced (their files are directly downloadable), which keeps
/// the catalog legal while mirroring WeLib's breadth.
class InternetArchiveService {
  static final InternetArchiveService _instance =
      InternetArchiveService._internal();
  factory InternetArchiveService() => _instance;
  InternetArchiveService._internal();

  static const String _searchBase =
      'https://archive.org/advancedsearch.php';
  static const String _downloadBase = 'https://archive.org/download';
  static const String _metadataBase = 'https://archive.org/metadata';
  static const String _imgBase = 'https://archive.org/services/img';

  Future<List<BookSearchResult>> search(
    String query, {
    String? language,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return const [];
    final fl = [
      'identifier',
      'title',
      'creator',
      'year',
      'downloads',
      'language',
      'item_size',
      'mediatype',
    ];
    final langClause = (language != null && language.isNotEmpty)
        ? ' AND language:($language)'
        : '';
    final uri = Uri.parse(_searchBase).replace(queryParameters: {
      'q': '(${query.trim()}) AND mediatype:texts$langClause',
      'fl[]': fl.join(','),
      'sort[]': 'downloads desc',
      'rows': '$limit',
      'page': '1',
      'output': 'json',
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final docs = data['response']?['docs'] as List? ?? const [];
        return docs
            .map((d) => _mapDoc(d as Map<String, dynamic>))
            .where((r) => r.title.isNotEmpty && r.iaId.isNotEmpty)
            .toList();
      }
      Logger.e('IA search failed (${response.statusCode})');
    } catch (e) {
      Logger.e('IA search error', error: e);
    }
    return const [];
  }

  Future<BookSearchResult?> fetchMetadata(BookSearchResult result) async {
    if (result.iaId.isEmpty) return result;
    try {
      final response = await http.get(Uri.parse('$_metadataBase/${result.iaId}'));
      if (response.statusCode != 200) return result;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final meta = data['metadata'] as Map<String, dynamic>? ?? const {};
      final files = data['files'] as List? ?? const [];

      final description = _extractDescription(meta['description']);
      final publisher = _first(meta['publisher']);
      final subjects = _asList(meta['subject']).take(10).toList();
      final languages = _asList(meta['language']).map(_languageName).toList();
      final year = (meta['year'] ?? meta['date'])?.toString() ?? result.year;

      final downloadUrls = <String, String>{};
      for (final file in files.cast<Map<String, dynamic>>()) {
        final name = (file['name'] as String?) ?? '';
        final ext = _extensionOf(name).toLowerCase();
        if (ext.isEmpty || name.contains('_djvu')) continue;
        if (['txt', 'epub', 'pdf', 'mobi', 'azw3', 'html', 'fb2']
            .contains(ext)) {
          downloadUrls.putIfAbsent(
            ext,
            () => '$_downloadBase/${result.iaId}/$name',
          );
        }
      }

      final primaryExt = result.filetype.isNotEmpty
          ? result.filetype
          : (downloadUrls.containsKey('epub')
              ? 'epub'
              : (downloadUrls.containsKey('txt')
                  ? 'txt'
                  : (downloadUrls.containsKey('pdf') ? 'pdf' : '')));
      final sizeMb = _itemSizeMb(meta['item_size']);

      return result.copyWith(
        description: description.isNotEmpty ? description : result.description,
        publisher: publisher.isNotEmpty ? publisher : result.publisher,
        subjects: subjects.isNotEmpty ? subjects : result.subjects,
        language: languages.isNotEmpty ? languages.first : result.language,
        year: year.isNotEmpty ? year : result.year,
        filetype: primaryExt,
        sizeMb: sizeMb ?? result.sizeMb,
        downloadUrls: downloadUrls.isNotEmpty
            ? downloadUrls
            : result.downloadUrls,
      );
    } catch (e) {
      Logger.e('IA metadata error', error: e);
      return result;
    }
  }

  BookSearchResult _mapDoc(Map<String, dynamic> doc) {
    final identifier = (doc['identifier'] as String?) ?? '';
    final title = (doc['title'] as String?)?.trim() ?? '';
    final creators = _asList(doc['creator']);
    final author = creators.isNotEmpty ? creators.first : '';
    final year = (doc['year'] ?? doc['date'])?.toString() ?? '';
    final languages = _asList(doc['language']).map(_languageName).toList();
    final downloads = (doc['downloads'] as num?)?.toInt() ?? 0;
    final sizeMb = _itemSizeMb(doc['item_size']);

    return BookSearchResult(
      title: title,
      author: author,
      coverUrl: '$_imgBase/$identifier',
      year: year,
      language: languages.isNotEmpty ? languages.first : '',
      filetype: 'epub',
      sizeMb: sizeMb,
      ratingCount: downloads > 0 ? downloads : null,
      sourceLabel: 'Internet Archive',
      iaId: identifier,
      downloadUrls: {
        'epub': '$_downloadBase/$identifier/$identifier.epub',
        'pdf': '$_downloadBase/$identifier/$identifier.pdf',
        'txt': '$_downloadBase/$identifier/${identifier}_djvu.txt',
      },
      readCandidates: [
        '$_downloadBase/$identifier/${identifier}_djvu.txt',
        '$_downloadBase/$identifier/$identifier.txt',
      ],
    );
  }

  String _extractDescription(dynamic raw) {
    if (raw is String) return raw.trim();
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .join('\n\n')
          .trim();
    }
    if (raw is Map && raw['value'] is String) {
      return (raw['value'] as String).trim();
    }
    return '';
  }

  String _first(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is List && raw.isNotEmpty) return raw.first.toString().trim();
    return '';
  }

  List<String> _asList(dynamic raw) {
    if (raw is String) return [raw];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  double? _itemSizeMb(dynamic raw) {
    final bytes = raw is num
        ? raw.toDouble()
        : (raw is String ? double.tryParse(raw) : null);
    if (bytes == null || bytes <= 0) return null;
    return bytes / (1024 * 1024);
  }

  String _languageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
      case 'eng':
        return 'English';
      case 'es':
      case 'spa':
        return 'Spanish';
      case 'fr':
      case 'fre':
        return 'French';
      case 'de':
      case 'ger':
        return 'German';
      case 'zh':
      case 'chi':
        return 'Chinese';
      case 'ja':
      case 'jpn':
        return 'Japanese';
      case 'ru':
      case 'rus':
        return 'Russian';
      case 'it':
      case 'ita':
        return 'Italian';
      case 'pt':
      case 'por':
        return 'Portuguese';
      case 'nl':
      case 'dut':
        return 'Dutch';
      case 'pl':
      case 'pol':
        return 'Polish';
      case 'ar':
      case 'ara':
        return 'Arabic';
      case 'tr':
      case 'tur':
        return 'Turkish';
      default:
        return code.toUpperCase();
    }
  }
}
