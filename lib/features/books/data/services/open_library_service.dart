import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/connectivity_aware.dart';
import '../models/book_item.dart';
import '../../../../core/utils/logger.dart';

class OpenLibraryService with ConnectivityAware {
  final CatalogProxyClient _proxy = CatalogProxyClient();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final OpenLibraryService _instance = OpenLibraryService._internal();
  factory OpenLibraryService() => _instance;
  OpenLibraryService._internal();

  BookItem _mapDocToBookItem(Map<String, dynamic> doc) {
    final workKey = (doc['key'] as String?) ?? '';
    final title = (doc['title'] as String?) ?? 'Untitled';
    final authorList =
        (doc['author_name'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final author = authorList.isNotEmpty ? authorList.first : '';

    final coverId = (doc['cover_i'] as num?)?.toInt();
    final coverEditionKey = doc['cover_edition_key'] as String?;
    final coverUrl = coverId != null && coverId > 0
        ? BookItem.coverFromCoverId(coverId, size: 'L')
        : BookItem.coverFromOlid(coverEditionKey, size: 'L');

    final firstYearRaw = doc['first_publish_year'];
    final firstYear = firstYearRaw is num
        ? firstYearRaw.toInt()
        : int.tryParse(firstYearRaw?.toString() ?? '');
    final nowYear = DateTime.now().year;
    final year =
        (firstYear != null && firstYear >= 1400 && firstYear <= nowYear + 1)
        ? firstYear.toString()
        : '';

    final iaIds =
        (doc['ia'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final iaId = iaIds.isNotEmpty ? iaIds.first : '';

    final subjects =
        (doc['subject'] as List?)?.take(8).map((e) => e.toString()).toList() ??
        const <String>[];

    final publishers =
        (doc['publisher'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final isbns =
        (doc['isbn'] as List?)?.map((e) => e.toString()).toList() ??
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
      publisher: publishers.isNotEmpty ? publishers.first : '',
      isbn: isbns.isNotEmpty ? isbns.first : '',
      subjects: subjects,
      status: '',
      addedAt: DateTime.now(),
      readSourceUrl: readSource,
      readSourceLabel: readLabel,
    );
  }

  List<String> _resolveReadSources({
    required String iaId,
    required String workKey,
  }) {
    final candidates = <String>[];
    if (iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      candidates.add('https://www.gutenberg.org/cache/epub/$id/pg$id.txt');
      candidates.add('https://www.gutenberg.org/files/$id/$id-0.txt');
    } else if (iaId.isNotEmpty) {
      candidates.add('https://archive.org/download/$iaId/${iaId}_djvu.txt');
      candidates.add('https://archive.org/download/$iaId/$iaId.txt');
    }
    return candidates;
  }

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

  Future<List<BookItem>> searchBooks(String query) async {
    final page = await searchPaged(query, limit: 20);
    return page.items;
  }

  static const String _searchFields =
      'key,title,author_name,cover_i,cover_edition_key,first_publish_year,ia,subject,publisher,isbn';

  Future<OpenLibraryPage> searchPaged(
    String query, {
    int limit = 20,
    int offset = 0,
    String? title,
    String? author,
    String? publisher,
    String? isbn,
    String sort = '',
  }) async {
    final hasFilter =
        query.trim().isNotEmpty ||
        (title?.trim().isNotEmpty == true) ||
        (author?.trim().isNotEmpty == true) ||
        (publisher?.trim().isNotEmpty == true) ||
        (isbn?.trim().isNotEmpty == true);
    if (!hasFilter) return OpenLibraryPage.empty;

    try {
      final params = <String, String>{
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (title?.trim().isNotEmpty == true) 'title': title!.trim(),
        if (author?.trim().isNotEmpty == true) 'author': author!.trim(),
        if (publisher?.trim().isNotEmpty == true)
          'publisher': publisher!.trim(),
        if (isbn?.trim().isNotEmpty == true) 'isbn': isbn!.trim(),
        if (sort.isNotEmpty) 'sort': sort,
        'fields': _searchFields,
        'limit': '$limit',
        if (offset > 0) 'offset': '$offset',
      };
      final response = await _proxy.get(
        'openlibrary',
        'search.json',
        query: params,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List docs = data['docs'] ?? [];
        final total = (data['numFound'] as num?)?.toInt() ?? docs.length;
        await Future<void>.delayed(Duration.zero);
        final items = docs
            .where(
              (d) =>
                  (d['title'] as String?)?.isNotEmpty == true &&
                  ((d['key'] as String?)?.isNotEmpty == true ||
                      ((d['ia'] as List?)?.isNotEmpty == true)),
            )
            .map((d) => _mapDocToBookItem(d as Map<String, dynamic>))
            .toList();
        return OpenLibraryPage(items: items, total: total);
      } else {
        Logger.e('Open Library search failed (${response.statusCode})');
      }
    } catch (e) {
      Logger.e('Open Library search error', error: e);
    }
    return OpenLibraryPage.empty;
  }

  Future<List<BookItem>> fetchTrending() async {
    return _subjectSearch('best', limit: 15);
  }

  Future<List<BookItem>> fetchRecent({int limit = 15}) async {
    final nowYear = DateTime.now().year;
    final fromYear = nowYear - 6;
    final fetchLimit = (limit * 4).clamp(1, 100);
    try {
      final page = await searchPaged(
        'first_publish_year:[$fromYear TO $nowYear]',
        limit: fetchLimit,
        sort: 'trending',
      );
      final filtered = page.items.where((item) {
        if (item.coverUrl.isEmpty) return false;
        if (item.workKey.isEmpty || !item.workKey.endsWith('W')) {
          return false;
        }
        final y = int.tryParse(item.year) ?? 0;
        if (y < 1500 || y > nowYear + 1) return false;
        return true;
      }).toList();
      if (filtered.isNotEmpty) return filtered.take(limit).toList();
    } catch (e) {
      Logger.e('Open Library recent error', error: e);
    }
    final fallback = await _subjectSearch('fiction', limit: limit * 2);
    final usable = fallback.where((item) {
      if (item.coverUrl.isEmpty) return false;
      if (item.workKey.isEmpty || !item.workKey.endsWith('W')) {
        return false;
      }
      return true;
    }).toList();
    if (usable.isNotEmpty) return usable.take(limit).toList();
    return _subjectSearch('fiction', limit: limit);
  }

  Future<List<BookItem>> discoverBySubject(
    String subject, {
    int limit = 12,
    int offset = 0,
  }) async {
    return _subjectSearch(subject, limit: limit, offset: offset);
  }

  Future<List<BookItem>> _subjectSearch(
    String subject, {
    int limit = 12,
    int offset = 0,
  }) async {
    try {
      final response = await _proxy.get(
        'openlibrary',
        'search.json',
        query: {
          'subject': subject,
          'fields': _searchFields,
          'limit': '$limit',
          'sort': 'trending',
          if (offset > 0) 'offset': '$offset',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List docs = data['docs'] ?? [];
        await Future<void>.delayed(Duration.zero);
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

  Future<Map<String, dynamic>?> fetchWorkDetails(String workKey) async {
    if (workKey.isEmpty) return null;
    try {
      final clean = workKey.startsWith('/') ? workKey.substring(1) : workKey;
      final response = await _proxy.get('openlibrary', '$clean.json');
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      Logger.e('Open Library work details error', error: e);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchEditions(String workKey) async {
    if (workKey.isEmpty) return [];
    try {
      final clean = workKey.startsWith('/') ? workKey.substring(1) : workKey;
      final response = await _proxy.get(
        'openlibrary',
        '$clean/editions.json',
        query: {'limit': '10'},
      );
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

  Future<void> saveToReadList(
    BookItem item,
    String status,
    String userName,
  ) async {
    if (userName.isEmpty) {
      Logger.w('saveToReadList: userName is empty');
      return;
    }
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
      Logger.w(
        "saveToReadList: blocked partner status '$status' for $userName",
      );
      return;
    }
    try {
      final collection = _firestore.collection('read_list');
      final existing = await withGetTimeout(
        collection
            .where('workKey', isEqualTo: item.workKey)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'read list save lookup',
      );

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
      final existing = await withGetTimeout(
        collection
            .where('workKey', isEqualTo: workKey)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'read list remove lookup',
      );
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
      }
    } catch (e) {
      Logger.e('Error removing from read_list', error: e);
    }
  }

  Stream<List<BookItem>> getReadListStream(String userName, {int? limit}) {
    return withFirestoreTimeout(
      _firestore
          .collection('read_list')
          .where('userName', isEqualTo: userName)
          .limit(limit ?? 500)
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
              'publisher': item.publisher,
              'isbn': item.isbn,
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
                publisher: data['publisher'] ?? '',
                isbn: data['isbn'] ?? '',
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

  @Deprecated('Use fetchBookTextFromCandidates instead')
  Future<String> fetchBookText(String readSourceUrl) async {
    if (readSourceUrl.isEmpty) return '';
    final result = await fetchBookTextFromCandidates([readSourceUrl]);
    return result.text;
  }

  static const String _proxyUrl = String.fromEnvironment(
    'BOOK_PROXY_URL',
    defaultValue: 'https://everglow-1c6db.web.app/api/proxyBookText',
  );

  static const bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static String get _proxyEndpoint {
    if (_useFunctionsEmulator) {
      return 'http://localhost:5001/everglow-1c6db/us-central1/proxyBookText';
    }
    return _proxyUrl;
  }

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

  bool _looksLikeHtml(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    if (trimmed.toLowerCase().startsWith('<!doctype') ||
        trimmed.toLowerCase().startsWith('<html')) {
      return true;
    }
    return trimmed.startsWith('<') && trimmed.length < 4096;
  }
}

class OpenLibraryPage {
  final List<BookItem> items;
  final int total;

  const OpenLibraryPage({required this.items, required this.total});

  static const OpenLibraryPage empty = OpenLibraryPage(items: [], total: 0);

  bool get hasMore => items.length < total;
}

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
