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

  /// Derive a read source URL for a book. We prefer Internet Archive
  /// borrowable copies (returned as `ia` ids in search results) since
  /// the archive exposes both an HTML reader and a plain text
  /// download we can render with `flutter_html`. We then fall back to
  /// Open Library's online reader page.
  String _resolveReadSource({required String iaId, required String workKey}) {
    if (iaId.isNotEmpty) {
      // Internet Archive: prefer the plain-text djvu extraction which
      // is line-oriented and renders cleanly in flutter_html.
      return 'https://archive.org/download/$iaId/${iaId}_djvu.txt';
    }
    if (workKey.isNotEmpty) {
      // Generic Open Library online reader.
      return 'https://openlibrary.org$workKey';
    }
    return '';
  }

  String _readSourceLabel({required String iaId}) {
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
}
