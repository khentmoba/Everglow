import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/connectivity_aware.dart';
import '../../../../core/utils/error_aware.dart';
import '../models/book_item.dart';
import '../../../../core/utils/logger.dart';

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
class OpenLibraryService with ConnectivityAware, ErrorAware {
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
    final authorList =
        (doc['author_name'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final author = authorList.isNotEmpty ? authorList.first : '';

    final coverId = (doc['cover_i'] as num?)?.toInt();
    final coverUrl = BookItem.coverFromCoverId(coverId, size: 'L');

    final firstYear = (doc['first_publish_year'] as num?)?.toInt();
    final year = firstYear != null ? firstYear.toString() : '';

    final iaIds =
        (doc['ia'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final iaId = iaIds.isNotEmpty ? iaIds.first : '';

    final subjects =
        (doc['subject'] as List?)?.take(8).map((e) => e.toString()).toList() ??
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
      status: '',
      addedAt: DateTime.now(),
      readSourceUrl: readSource,
      readSourceLabel: readLabel,
    );
  }

  /// Derive a list of candidate read source URLs for a book, in
  /// priority order. The reader tries them one at a time and uses
  /// whichever responds successfully — that way a CORS block or
  /// 404 on the Internet Archive fallback still leaves us with a
  /// working Gutenberg URL.
  ///
  /// Only **plain-text** sources are returned here. The Open Library
  /// work page is HTML and is intentionally excluded — including it
  /// would either swallow it as a "successful" empty-book read, or
  /// confuse the chapter splitter. It's still surfaced separately as
  /// the "open in browser" URL via [_resolveReadSource].
  ///
  /// Strategy:
  ///   1. If the `ia` id is a Project Gutenberg id (`pg1342` style),
  ///      hit the canonical plain text URL (public domain, no auth).
  ///      Requires the CORS proxy because gutenberg.org sends no
  ///      `Access-Control-Allow-Origin` header.
  ///   2. Otherwise try the Internet Archive djvu text extraction.
  ///      IA *does* send CORS headers, so direct browser fetches
  ///      succeed without the proxy — handy when the proxy is down.
  List<String> _resolveReadSources({
    required String iaId,
    required String workKey,
  }) {
    final candidates = <String>[];
    if (iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      // Gutenberg plain text (most reliable, public domain).
      candidates.add('https://www.gutenberg.org/cache/epub/$id/pg$id.txt');
      // Alternate Gutenberg URL pattern.
      candidates.add('https://www.gutenberg.org/files/$id/$id-0.txt');
    } else if (iaId.isNotEmpty) {
      // Internet Archive djvu text. Works for ~70% of items.
      candidates.add('https://archive.org/download/$iaId/${iaId}_djvu.txt');
      // IA plain text fallback.
      candidates.add('https://archive.org/download/$iaId/$iaId.txt');
    }
    return candidates;
  }

  /// First candidate — used by the model and as the "Open in
  /// browser" fallback. Falls back to the Open Library work page
  /// (HTML, browser-only) when no plain-text source is available,
  /// so the reader's "Open on Open Library" button still has
  /// somewhere to point.
  ///
  /// IMPORTANT: for non-Gutenberg Internet Archive ids, this points
  /// at the IA **details/borrow page** rather than the first
  /// candidate from [_resolveReadSources]. Modern copyrighted books
  /// on IA are borrow-only — the `${iaId}_djvu.txt` / `${iaId}.txt`
  /// files don't exist outside of an active loan, so using them as
  /// the "open in browser" URL would just open a 404. The details
  /// page is where the user can borrow and read the book in IA's
  /// built-in reader.
  String _resolveReadSource({required String iaId, required String workKey}) {
    if (iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      return 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt';
    }
    if (iaId.isNotEmpty) {
      return 'https://archive.org/details/$iaId';
    }
    if (workKey.isNotEmpty) return 'https://openlibrary.org$workKey';
    return '';
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
      '$_searchBase?q=${Uri.encodeComponent(query)}&limit=20',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List docs = data['docs'] ?? [];
        return docs
            .where(
              (d) =>
                  (d['title'] as String?)?.isNotEmpty == true &&
                  ((d['key'] as String?)?.isNotEmpty == true ||
                      ((d['ia'] as List?)?.isNotEmpty == true)),
            )
            .map((d) => _mapDocToBookItem(d as Map<String, dynamic>))
            .toList();
      } else {
        Logger.e('Open Library search failed (${response.statusCode})');
      }
    } catch (e) {
      Logger.e('Open Library search error', error: e);
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
  Future<List<BookItem>> discoverBySubject(
    String subject, {
    int limit = 12,
  }) async {
    return _subjectSearch(subject, limit: limit);
  }

  Future<List<BookItem>> _subjectSearch(
    String subject, {
    int limit = 12,
  }) async {
    final url = Uri.parse(
      '$_searchBase?subject=${Uri.encodeComponent(subject)}&limit=$limit&sort=trending',
    );
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
      Logger.e('Open Library subject search error ($subject)', error: e);
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
      Logger.e('Open Library work details error', error: e);
    }
    return null;
  }

  /// Fetch a few editions for a work — used to find the edition
  /// with a real page count and a borrowable Internet Archive copy.
  Future<List<Map<String, dynamic>>> fetchEditions(String workKey) async {
    if (workKey.isEmpty) return [];
    final url = Uri.parse(
      'https://openlibrary.org$workKey/editions.json?limit=10',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List entries = data['entries'] ?? [];
        return entries.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      Logger.e('Open Library editions error', error: e);
    }
    return [];
  }

  // ── READ LIST PERSISTENCE ──────────────────────────────────────────

  Future<void> saveToReadList(
    BookItem item,
    String status,
    String userName,
  ) async {
    if (userName.isEmpty) {
      Logger.w('saveToReadList: userName is empty');
      return;
    }
    // Guard: non-couple users may only use generic statuses.
    const coupleStatuses = {
      'read-khent',
      'read-clair',
      'read-both',
      'watching-khent',
      'watching-clair',
      'watching-both',
      'watched-khent',
      'watched-clair',
      'watched-both',
    };
    final isCouple = userName == 'khentsgdz' || userName == 'clairjassen';
    if (!isCouple && coupleStatuses.contains(status)) {
      Logger.w("saveToReadList: blocked partner status '$status' for $userName");
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
        await collection.add(
          item
              .copyWith(
                status: status,
                userName: userName,
                addedAt: DateTime.now(),
              )
              .toFirestore(),
        );
      }
      Logger.i('Saved to read_list: ${item.title} ($userName)');
    } catch (e) {
      Logger.e('Error saving to read_list', error: e);
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
      Logger.e('Error removing from read_list', error: e);
    }
  }

  Stream<List<BookItem>> getReadListStream(String userName) {
    return withFirestoreTimeout(
      _firestore
          .collection('read_list')
          .where('userName', isEqualTo: userName)
          .limit(500)
          .snapshots()
          .map((snapshot) {
            final items =
                snapshot.docs
                    .map((doc) => BookItem.fromFirestore(doc.data(), doc.id))
                    .toList()
                  ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
            cacheReadList(items, userName);
            return items;
          }),
      label: 'read-list-$userName',
    );
  }

  // ── LOCAL CACHE ────────────────────────────────────────────────────

  Future<void> cacheReadList(List<BookItem> items, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = items
          .map(
            (item) => {
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
            },
          )
          .toList();
      await prefs.setString(_cacheKey(userName), json.encode(listJson));
    } catch (e) {
      Logger.e('Error caching read_list', error: e);
    }
  }

  Future<List<BookItem>> getCachedReadList(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(userName));
      if (raw != null) {
        final List decoded = json.decode(raw);
        return decoded
            .map(
              (data) => BookItem(
                id: data['id'] ?? '',
                workKey: data['workKey'] ?? '',
                editionKey: data['editionKey'] ?? '',
                iaId: data['iaId'] ?? '',
                title: data['title'] ?? '',
                author: data['author'] ?? '',
                coverUrl: data['coverUrl'] ?? '',
                year: data['year'] ?? '',
                pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
                subjects:
                    (data['subjects'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    const <String>[],
                status: data['status'] ?? 'to-read',
                userName: data['userName'] ?? userName,
                addedAt:
                    DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
              ),
            )
            .toList();
      }
    } catch (e) {
      Logger.e('Error reading cached read_list', error: e);
    }
    return [];
  }

  String _cacheKey(String userName) => 'cached_read_list::$userName';

  // ── READ SOURCE FETCH ──────────────────────────────────────────────

  /// Fetch the raw text of a book from its resolved read source.
  /// Returns the full plain text (used by the chapter splitter).
  @Deprecated('Use fetchBookTextFromCandidates instead')
  Future<String> fetchBookText(String readSourceUrl) async {
    if (readSourceUrl.isEmpty) return '';
    try {
      final response = await http.get(Uri.parse(readSourceUrl));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      Logger.e('fetchBookText error', error: e);
    }
    return '';
  }

  /// Cloud Function URL for proxying book text requests.
  /// Defaults to the Firebase Hosting rewrite for the deployed
  /// `proxyBookText` function (same-origin, so it works even when
  /// the raw Cloud Functions URL is IAM-restricted). When the app
  /// is built with `--dart-define=USE_FIREBASE_EMULATOR=true` it
  /// points at the local Functions emulator instead.
  static const String _proxyUrl = String.fromEnvironment(
    'BOOK_PROXY_URL',
    defaultValue: 'https://everglow-1c6db.web.app/api/proxyBookText',
  );

  static const bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// Resolved Cloud Function URL. Falls back to the local emulator
  /// endpoint when the emulator flag is on, otherwise the deployed
  /// production URL.
  static String get _proxyEndpoint {
    if (_useFunctionsEmulator) {
      return 'http://localhost:5001/everglow-1c6db/us-central1/proxyBookText';
    }
    return _proxyUrl;
  }

  /// Try each candidate read source URL via the Firebase Cloud
  /// Function proxy. The function fetches each URL server-side so
  /// Flutter web is never blocked by CORS.
  Future<FetchResult> fetchBookTextFromCandidates(
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) {
      return FetchResult.empty('No read source URLs available.');
    }
    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      final response = await http
          .post(
            Uri.parse(_proxyEndpoint),
            headers: {
              'Content-Type': 'application/json',
              if (idToken.isNotEmpty) 'Authorization': 'Bearer $idToken',
            },
            body: json.encode({'urls': candidates}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final text = data['text'] as String? ?? '';
        final usedUrl = data['usedUrl'] as String? ?? '';
        final attempted =
            (data['attempted'] as List?)?.map((e) => e.toString()).toList() ??
            candidates;
        final error = data['error'] as String?;
        if (text.isNotEmpty) {
          return FetchResult(
            text: text,
            usedUrl: usedUrl,
            attempted: attempted,
          );
        }
        return FetchResult.empty(error ?? 'Proxy returned empty response.');
      }
    } catch (e) {
      Logger.e('fetchBookTextFromCandidates proxy error', error: e);
    }
    // Fallback: direct fetch (may fail on web due to CORS, but works
    // in tests or when the proxy is unreachable).
    for (var i = 0; i < candidates.length; i++) {
      final url = candidates[i];
      try {
        final response = await http
            .get(Uri.parse(url), headers: const {'Accept': 'text/plain'})
            .timeout(const Duration(seconds: 20));
        final body = response.body;
        if (response.statusCode == 200 &&
            body.trim().isNotEmpty &&
            !_looksLikeHtml(body)) {
          return FetchResult(
            text: body,
            usedUrl: url,
            attempted: candidates.take(i + 1).toList(),
          );
        }
      } catch (e) {
        Logger.e('fetchBookText direct fallback $i failed ($url)', error: e);
      }
    }
    return FetchResult.empty(
      'Tried ${candidates.length} source(s); none responded with readable text.',
    );
  }

  /// Build the full ordered list of read source URLs for a book.
  /// Combines the model's stored URL with re-derived fallbacks.
  ///
  /// The model's `readSourceUrl` is the "open in browser" target —
  /// for borrowable Internet Archive items that's the details page
  /// (HTML), which the proxy would happily return as "text" and the
  /// chapter splitter would then choke on. We only fold it into the
  /// candidate list when it's an actual plain-text URL, so the
  /// in-app reader never accidentally renders raw HTML.
  List<String> buildReadSourceCandidates(BookItem item) {
    final sources = <String>[];
    final stored = item.readSourceUrl;
    if (stored.isNotEmpty && _looksLikePlainText(stored)) {
      sources.add(stored);
    }
    for (final url in _resolveReadSources(
      iaId: item.iaId,
      workKey: item.workKey,
    )) {
      if (!sources.contains(url)) sources.add(url);
    }
    return sources;
  }

  bool _looksLikePlainText(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.txt') || lower.contains('gutenberg.org');
  }

  /// Heuristic guard against proxied/redirected HTML pages being
  /// mistaken for book text (e.g. Internet Archive borrow pages).
  bool _looksLikeHtml(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    if (trimmed.toLowerCase().startsWith('<!doctype') ||
        trimmed.toLowerCase().startsWith('<html')) {
      return true;
    }
    // Borrow/error pages are typically short HTML or contain a title.
    return trimmed.startsWith('<') && trimmed.length < 4096;
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

  factory FetchResult.empty(String error) =>
      FetchResult(text: '', usedUrl: '', attempted: const [], error: error);

  bool get isSuccess => text.isNotEmpty;
}
