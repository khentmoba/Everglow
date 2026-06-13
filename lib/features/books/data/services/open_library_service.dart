import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/books/data/models/book_item.dart';

/// Talks to the public Open Library REST APIs (no key required) and
/// to the personal `read_list` Firestore collection. Mirrors
/// [TMDBService] for the cinema feature.
///
/// Open Library endpoints used:
///   * Search  — `https://openlibrary.org/search.json?q=...&limit=20`
///   * Works   — `https://openlibrary.org/works/{olid}.json`
///   * Editions— `https://openlibrary.org/works/{olid}/editions.json`
///   * Covers  — `https://covers.openlibrary.org/b/id/{id}-L.jpg`
///   * Read source — derived from `ia` field: Internet Archive
///     borrowable copies, with a Project Gutenberg fallback when
///     possible.
class OpenLibraryService {
  final String _searchBase = 'https://openlibrary.org/search.json';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton
  static final OpenLibraryService _instance = OpenLibraryService._internal();
  factory OpenLibraryService() => _instance;
  OpenLibraryService._internal();

  // ── MAPPING ────────────────────────────────────────────────────────

  /// Map an Open Library `docs[]` entry to a [BookItem].
  BookItem _mapDocToBookItem(Map<String, dynamic> doc) {
    final workKey = (doc['key'] as String?) ?? '';
    final title = (doc['title'] as String?) ?? 'Untitled';
    final authorList = (doc['author_name'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final author = authorList.isNotEmpty ? authorList.first : '';

    final coverId = (doc['cover_i'] as num?)?.toInt();
    final coverUrl = BookItem.coverFromCoverId(coverId, size: 'L');

    final firstYear = (doc['first_publish_year'] as num?)?.toInt();
    final year = firstYear != null ? firstYear.toString() : '';

    final iaIds = (doc['ia'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final iaId = iaIds.isNotEmpty ? iaIds.first : '';

    final subjects = (doc['subject'] as List?)?.take(8).map((e) => e.toString()).toList() ??
        const <String>[];

    final readSource = _resolveReadSource(iaId: iaId, workKey: workKey);
    final readLabel = _readSourceLabel(iaId: iaId);

    return BookItem(
      id: '',
      workKey: workKey,
      iaId: iaId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      year: year,
      subjects: subjects,
      status: 'to-read',
      addedAt: DateTime.now(),
      readSourceUrl: readSource,
      readSourceLabel: readLabel,
    );
  }

  /// Derive a list of candidate read source URLs for a book, in
  /// priority order. The reader tries them one at a time and uses
  /// whichever responds successfully — that way a CORS block or
  /// 404 on the Internet Archive fallback still leaves us with a
  /// working Gutenberg or Open Library URL.
  ///
  /// Strategy:
  ///   1. If the `ia` id is a Project Gutenberg id (`pg1342` style),
  ///      hit the canonical plain text URL (CORS-friendly, public
  ///      domain, no auth).
  ///   2. Otherwise try the Internet Archive djvu text extraction.
  ///   3. As a last resort, the Open Library work page (HTML, always
  ///      available, but meant to be opened in a browser, not
  ///      inlined).
  List<String> _resolveReadSources({
    required String iaId,
    required String workKey,
  }) {
    final candidates = <String>[];
    if (iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      // Gutenberg plain text (most reliable, CORS-friendly).
      candidates.add('https://www.gutenberg.org/cache/epub/$id/pg$id.txt');
      // Alternate Gutenberg URL pattern.
      candidates.add('https://www.gutenberg.org/files/$id/$id-0.txt');
    } else if (iaId.isNotEmpty) {
      // Internet Archive djvu text. Works for ~70% of items.
      candidates.add('https://archive.org/download/$iaId/${iaId}_djvu.txt');
      // IA plain text fallback.
      candidates.add('https://archive.org/download/$iaId/$iaId.txt');
    }
    if (workKey.isNotEmpty) {
      candidates.add('https://openlibrary.org$workKey');
    }
    return candidates;
  }

  /// First candidate — used by the model and as the "Open in
  /// browser" fallback.
  String _resolveReadSource({required String iaId, required String workKey}) {
    return _resolveReadSources(iaId: iaId, workKey: workKey).firstOrNull ?? '';
  }

  String _readSourceLabel({required String iaId}) {
    if (iaId.startsWith('pg')) return 'Project Gutenberg';
    if (iaId.isNotEmpty) return 'Internet Archive';
    return 'Open Library';
  }

  // ── SEARCH / DISCOVERY ─────────────────────────────────────────────

  /// Search Open Library for books. Returns up to 20 results.
  Future<List<BookItem>> searchBooks(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
        '$_searchBase?q=${Uri.encodeComponent(query)}&limit=20');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List docs = data['docs'] ?? [];
        return docs
            .where((d) =>
                (d['title'] as String?)?.isNotEmpty == true &&
                ((d['key'] as String?)?.isNotEmpty == true ||
                    ((d['ia'] as List?)?.isNotEmpty == true)))
            .map((d) => _mapDocToBookItem(d as Map<String, dynamic>))
            .toList();
      } else {
        print('Open Library search failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Open Library search error: $e');
    }
    return [];
  }

  /// Trending / popular books. Open Library doesn't have a strict
  /// "trending" endpoint, so we use the `trending/daily` unofficial
  /// list (mostly the same set as `/search.json?q=*&sort=trending`).
  /// Falls back to a curated subject search if the request fails.
  Future<List<BookItem>> fetchTrending() async {
    return _subjectSearch('best', limit: 15);
  }

  /// Curated subject discovery row. Used for the "Romance",
  /// "Mystery" etc. carousel rows on the home tab.
  Future<List<BookItem>> discoverBySubject(String subject,
      {int limit = 12}) async {
    return _subjectSearch(subject, limit: limit);
  }

  Future<List<BookItem>> _subjectSearch(String subject,
      {int limit = 12}) async {
    final url = Uri.parse(
        '$_searchBase?subject=${Uri.encodeComponent(subject)}&limit=$limit&sort=trending');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List docs = data['docs'] ?? [];
        return docs
            .where((d) => (d['title'] as String?)?.isNotEmpty == true)
            .map((d) => _mapDocToBookItem(d as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Open Library subject search error ($subject): $e');
    }
    return [];
  }

  /// Fetch detailed metadata for a work. Used by the preview drawer
  /// when a book is opened.
  Future<Map<String, dynamic>?> fetchWorkDetails(String workKey) async {
    if (workKey.isEmpty) return null;
    // workKey is something like "/works/OL45804W"
    final url = Uri.parse('https://openlibrary.org$workKey.json');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Open Library work details error: $e');
    }
    return null;
  }

  /// Fetch a few editions for a work — used to find the edition
  /// with a real page count and a borrowable Internet Archive copy.
  Future<List<Map<String, dynamic>>> fetchEditions(String workKey) async {
    if (workKey.isEmpty) return [];
    final url = Uri.parse(
        'https://openlibrary.org$workKey/editions.json?limit=10');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List entries = data['entries'] ?? [];
        return entries.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Open Library editions error: $e');
    }
    return [];
  }

  // ── READ LIST PERSISTENCE ──────────────────────────────────────────

  Future<void> saveToReadList(BookItem item, String status, String userName) async {
    if (userName.isEmpty) {
      print('saveToReadList: userName is empty');
      return;
    }
    try {
      final collection = _firestore.collection('read_list');
      final existing = await collection
          .where('workKey', isEqualTo: item.workKey)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update({
          'status': status,
          'addedAt': Timestamp.now(),
        });
      } else {
        await collection.add(item
            .copyWith(status: status, userName: userName, addedAt: DateTime.now())
            .toFirestore());
      }
      print('Saved to read_list: ${item.title} ($userName)');
    } catch (e) {
      print('Error saving to read_list: $e');
    }
  }

  Future<void> removeFromReadList(String workKey, String userName) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('read_list');
      final existing = await collection
          .where('workKey', isEqualTo: workKey)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
      }
    } catch (e) {
      print('Error removing from read_list: $e');
    }
  }

  Stream<List<BookItem>> getReadListStream(String userName) {
    return _firestore
        .collection('read_list')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => BookItem.fromFirestore(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      cacheReadList(items, userName);
      return items;
    });
  }

  // ── LOCAL CACHE ────────────────────────────────────────────────────

  Future<void> cacheReadList(List<BookItem> items, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = items
          .map((item) => {
                'id': item.id,
                'workKey': item.workKey,
                'editionKey': item.editionKey,
                'iaId': item.iaId,
                'title': item.title,
                'author': item.author,
                'coverUrl': item.coverUrl,
                'year': item.year,
                'pageCount': item.pageCount,
                'subjects': item.subjects,
                'status': item.status,
                'userName': item.userName,
                'addedAt': item.addedAt.toIso8601String(),
              })
          .toList();
      await prefs.setString(_cacheKey(userName), json.encode(listJson));
    } catch (e) {
      print('Error caching read_list: $e');
    }
  }

  Future<List<BookItem>> getCachedReadList(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(userName));
      if (raw != null) {
        final List decoded = json.decode(raw);
        return decoded
            .map((data) => BookItem(
                  id: data['id'] ?? '',
                  workKey: data['workKey'] ?? '',
                  editionKey: data['editionKey'] ?? '',
                  iaId: data['iaId'] ?? '',
                  title: data['title'] ?? '',
                  author: data['author'] ?? '',
                  coverUrl: data['coverUrl'] ?? '',
                  year: data['year'] ?? '',
                  pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
                  subjects: (data['subjects'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      const <String>[],
                  status: data['status'] ?? 'to-read',
                  userName: data['userName'] ?? userName,
                  addedAt:
                      DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
                ))
            .toList();
      }
    } catch (e) {
      print('Error reading cached read_list: $e');
    }
    return [];
  }

  String _cacheKey(String userName) => 'cached_read_list::$userName';

  // ── READ SOURCE FETCH ──────────────────────────────────────────────

  /// Fetch the raw text of a book from its resolved read source.
  /// Returns the full plain text (used by the chapter splitter).
  Future<String> fetchBookText(String readSourceUrl) async {
    if (readSourceUrl.isEmpty) return '';
    try {
      final response = await http.get(Uri.parse(readSourceUrl));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print('fetchBookText error: $e');
    }
    return '';
  }

  /// Try each candidate read source URL in order. Returns the first
  /// one that responds with a 2xx and a non-empty body. This makes
  /// the reader resilient to CORS blocks and 404s — the model
  /// stores the highest-priority URL, and the reader falls back
  /// automatically.
  Future<FetchResult> fetchBookTextFromCandidates(
      List<String> candidates) async {
    if (candidates.isEmpty) {
      return FetchResult.empty('No read source URLs available.');
    }
    for (var i = 0; i < candidates.length; i++) {
      final url = candidates[i];
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          return FetchResult(
            text: response.body,
            usedUrl: url,
            attempted: candidates.take(i + 1).toList(),
          );
        }
      } catch (e) {
        print('fetchBookText attempt $i failed ($url): $e');
        // Continue to next candidate.
      }
    }
    return FetchResult.empty(
        'Tried ${candidates.length} source(s); none responded with readable text.');
  }

  /// Build the full ordered list of read source URLs for a book.
  /// Combines the model's stored URL with re-derived fallbacks.
  List<String> buildReadSourceCandidates(BookItem item) {
    final sources = <String>[];
    if (item.readSourceUrl.isNotEmpty) sources.add(item.readSourceUrl);
    for (final url in _resolveReadSources(
        iaId: item.iaId, workKey: item.workKey)) {
      if (!sources.contains(url)) sources.add(url);
    }
    return sources;
  }
}

/// Result of [OpenLibraryService.fetchBookTextFromCandidates].
class FetchResult {
  final String text;
  final String usedUrl;
  final List<String> attempted;
  final String? error;

  const FetchResult({
    required this.text,
    required this.usedUrl,
    required this.attempted,
    this.error,
  });

  factory FetchResult.empty(String error) => FetchResult(
        text: '',
        usedUrl: '',
        attempted: const [],
        error: error,
      );

  bool get isSuccess => text.isNotEmpty;
}
