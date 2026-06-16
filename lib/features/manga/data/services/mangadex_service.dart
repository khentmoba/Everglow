import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Talks to the MangaDex API for chapter-page resolution and to the
/// personal `manga_library` Firestore collection. Catalog browsing
/// (search, popular, latest) is handled by [ComickService].
///
/// MangaDex endpoints used:
///   * Chapter feed   — `GET /manga/{id}/feed?translatedLanguage[]=en`
///   * Page URLs      — `GET /at-home/server/{chapterId}`
///
/// No API key is required. The at-home image server doesn't send CORS
/// headers, so on Flutter Web the reader proxies page images through
/// the `proxyMangaImage` Firebase Cloud Function.
class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';
  static const String _uploadsBase = 'https://uploads.mangadex.org';

  /// Cloud Function URL for proxying manga image requests. Mirrors the
  /// `proxyBookText` pattern from the books feature. The function
  /// fetches chapter images server-side so Flutter web is never
  /// blocked by CORS or hotlink protection.
  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaImage';

  /// Cloud Function URL for proxying MangaDex catalog API requests.
  /// The API at api.mangadex.org doesn't send CORS headers, so the
  /// browser drops the body on web. Routing every call through this
  /// proxy keeps Flutter web working the same way native does. The
  /// native platforms are unaffected (the proxy is just a passthrough)
  /// so we don't bother with a `kIsWeb` branch.
  static const String _proxyCatalogUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaDex';

  /// Rewrite a MangaDex API [Uri] into the proxied version. The proxy
  /// expects the original path-and-query string in a `path` query
  /// param, e.g. `?path=manga%3Flimit%3D20`.
  Uri _proxied(Uri apiUri) {
    final pathAndQuery = apiUri.path +
        (apiUri.hasQuery ? '?${apiUri.query}' : '');
    return Uri.parse(
      '$_proxyCatalogUrl?path=${Uri.encodeComponent(pathAndQuery)}',
    );
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final MangaDexService _instance = MangaDexService._internal();
  factory MangaDexService() => _instance;
  MangaDexService._internal();

  // Headers used on every MangaDex call. The descriptive User-Agent
  // is required by their API guidelines and helps us get a polite
  // rate-limit tier.
  Map<String, String> get _headers => {
    'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
    'Accept': 'application/json',
  };

  // In-memory cache for page-URL resolutions. The `baseUrl` returned
  // by `/at-home/server/{id}` is only valid for 15 minutes, so we
  // keep the resolution here and never let a stale URL escape.
  final Map<String, MangaChapterPages> _pageCache = {};

  /// Search MangaDex by title and return the first matching manga
  /// UUID. Used to link a Comick-discovered manga to its MangaDex
  /// counterpart for chapter page resolution.
  Future<String> searchByTitle(String title, {String language = 'ja'}) async {
    if (title.isEmpty) return '';
    final params = <String, List<String>>{
      'title': [title],
      'limit': ['1'],
      'includes[]': ['cover_art'],
      'contentRating[]': ['safe', 'suggestive'],
      'order[relevance]': ['desc'],
    };
    final uri = Uri.parse('$_baseUrl/manga').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final results = body['data'] as List? ?? [];
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>?;
          return first?['id'] as String? ?? '';
        }
      }
    } catch (e) {
      print('MangaDex searchByTitle error: $e');
    }
    return '';
  }

  /// Fetch the chapter feed for a manga. We default to English
  /// translations but allow overrides for the (rare) case where
  /// someone wants to read in another language. Results are ordered
  /// by chapter number descending so the most recent chapter is
  /// first in the list.
  Future<List<MangaChapter>> getChapterFeed(
    String mangaId, {
    String language = 'en',
    int limit = 500,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/manga/$mangaId/feed').replace(
      queryParameters: {
        'limit': ['$limit'],
        'offset': ['$offset'],
        'translatedLanguage[]': [language],
        'contentRating[]': ['safe', 'suggestive'],
        'order[chapter]': ['desc'],
        'includes[]': ['scanlation_group'],
      },
    );
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List? ?? const [];
        return data
            .whereType<Map<String, dynamic>>()
            .map((d) {
              final attrs = (d['attributes'] as Map?) ?? const {};
              return MangaChapter.fromApi(
                attrs.cast<String, dynamic>(),
                d,
              );
            })
            .where((c) => c.id.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('MangaDex chapter feed error: $e');
    }
    return [];
  }

  /// Fetch the page image filenames + baseUrl for a chapter. The
  /// `baseUrl` is valid for 15 minutes — we cache the result and
  /// hand the reader full URLs to consume.
  Future<MangaChapterPages?> getChapterPages(String chapterId) async {
    final cached = _pageCache[chapterId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }
    final uri = Uri.parse('$_baseUrl/at-home/server/$chapterId');
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final chapter = body['chapter'] as Map<String, dynamic>?;
        final baseUrl = body['baseUrl'] as String?;
        if (chapter == null || baseUrl == null) return null;
        final hash = chapter['hash'] as String? ?? '';
        final files = (chapter['data'] as List?)?.cast<String>() ?? const [];
        final result = MangaChapterPages(
          chapterId: chapterId,
          baseUrl: baseUrl,
          hash: hash,
          filenames: files,
          // The /at-home/server baseUrl is valid for 15 minutes; we
          // cap the cache a little earlier to be safe.
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
        _pageCache[chapterId] = result;
        return result;
      }
    } catch (e) {
      print('MangaDex chapter pages error: $e');
    }
    return null;
  }

  /// Build a proxied image URL for a chapter page. The reader uses
  /// this for every `Image.network` request on web so the browser
  /// doesn't get blocked by CORS. The proxy adds the right headers
  /// and forwards the request to the MangaDex at-home server.
  String proxiedImageUrl(String pageUrl) {
    if (pageUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(pageUrl)}';
  }

  /// Fetch all available tags. Used to render the filter chips on
  /// the search modal. We keep results in-memory after the first
  /// call since tags are stable and the user won't notice a 50ms
  /// difference on subsequent filter operations.
  List<Map<String, dynamic>>? _tagCache;
  Future<List<Map<String, dynamic>>> fetchTags() async {
    if (_tagCache != null) return _tagCache!;
    final uri = Uri.parse('$_baseUrl/manga/tag');
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = (body['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _tagCache = data;
        return data;
      }
    } catch (e) {
      print('MangaDex tags error: $e');
    }
    return const [];
  }

  // ── LIBRARY (Firestore) ────────────────────────────────────────────

  /// Save a manga to the user's library with the given status.
  /// Items are scoped per user so Khent, Clair, and Breyan each see
  /// only their own list. If the same mangaId is already in the
  /// user's library, we update the status instead of creating a
  /// duplicate row.
  Future<void> saveToLibrary(
    MangaItem item,
    String libraryStatus,
    String userName,
  ) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('manga_library');
      final existing = await collection
          .where('mangaId', isEqualTo: item.mangaId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update({
          'libraryStatus': libraryStatus,
          'addedAt': Timestamp.now(),
        });
      } else {
        await collection.add(item
            .copyWith(
              libraryStatus: libraryStatus,
              userName: userName,
              addedAt: DateTime.now(),
            )
            .toFirestore());
      }
    } catch (e) {
      print('Error saving to manga_library: $e');
    }
  }

  /// Remove a manga from the user's library entirely.
  Future<void> removeFromLibrary(String mangaId, String userName) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('manga_library');
      final existing = await collection
          .where('mangaId', isEqualTo: mangaId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
      }
    } catch (e) {
      print('Error removing from manga_library: $e');
    }
  }

  /// Persist reading progress for a manga. We store the last-read
  /// chapter id and 1-indexed page so the "Continue Reading" rail
  /// can resume exactly where the user left off.
  Future<void> saveReadingProgress({
    required String mangaId,
    required String userName,
    required String chapterId,
    required int page,
  }) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('manga_library');
      final existing = await collection
          .where('mangaId', isEqualTo: mangaId)
          .where('userName', isEqualTo: userName)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update({
          'lastReadChapterId': chapterId,
          'lastReadPage': page,
        });
      }
    } catch (e) {
      print('Error saving reading progress: $e');
    }
  }

  /// Stream of library items for a single user, ordered most-recent
  /// first. Side effect: caches the list locally for offline access.
  Stream<List<MangaItem>> getLibraryStream(String userName) {
    return _firestore
        .collection('manga_library')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MangaItem.fromFirestore(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      cacheLibrary(items, userName);
      return items;
    });
  }

  /// Stream of the combined library for the couple, deduplicated by
  /// `mangaId`. When both partners have the same title, `userName`
  /// becomes "userA,userB" and `libraryStatus` is the strongest
  /// active status across the two (reading > plan-to-read > completed
  /// > on-hold > dropped).
  Stream<List<MangaItem>> getCoupleLibraryStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    final controller = StreamController<List<MangaItem>>.broadcast();
    List<MangaItem> itemsA = const [];
    List<MangaItem> itemsB = const [];
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;

    void emit() {
      controller.add(_mergeCoupleItems(itemsA, itemsB));
    }

    controller.onListen = () {
      subA = _firestore
          .collection('manga_library')
          .where('userName', isEqualTo: userA)
          .snapshots()
          .listen((snapshot) {
        itemsA = snapshot.docs
            .map((doc) => MangaItem.fromFirestore(doc.data(), doc.id))
            .toList();
        emit();
      });
      subB = _firestore
          .collection('manga_library')
          .where('userName', isEqualTo: userB)
          .snapshots()
          .listen((snapshot) {
        itemsB = snapshot.docs
            .map((doc) => MangaItem.fromFirestore(doc.data(), doc.id))
            .toList();
        emit();
      });
    };

    controller.onCancel = () async {
      await subA?.cancel();
      await subB?.cancel();
    };

    return controller.stream;
  }

  static List<MangaItem> _mergeCoupleItems(
      List<MangaItem> itemsA, List<MangaItem> itemsB) {
    final byId = <String, _MangaMergedEntry>{};
    for (final item in itemsA) {
      byId[item.mangaId] = _MangaMergedEntry(primary: item, partner: null);
    }
    for (final item in itemsB) {
      final existing = byId[item.mangaId];
      if (existing == null) {
        byId[item.mangaId] = _MangaMergedEntry(primary: item, partner: null);
      } else {
        byId[item.mangaId] = _MangaMergedEntry(
            primary: existing.primary, partner: item);
      }
    }

    final merged = byId.values.map((entry) {
      if (entry.partner == null) return entry.primary;
      final a = entry.primary;
      final b = entry.partner!;
      final userName = '${a.userName},${b.userName}';
      final status = _mergeLibraryStatus(a.libraryStatus, b.libraryStatus);
      final addedAt = a.addedAt.isAfter(b.addedAt) ? a.addedAt : b.addedAt;
      return a.copyWith(
        userName: userName,
        libraryStatus: status,
        addedAt: addedAt,
      );
    }).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return merged;
  }

  /// Returns the most "active" library status across the two partners.
  /// Reading > plan-to-read > completed > on-hold > dropped > none.
  static String _mergeLibraryStatus(String a, String b) {
    const priority = [
      'reading',
      'plan-to-read',
      'completed',
      'on-hold',
      'dropped',
    ];
    for (final s in priority) {
      if (a == s || b == s) return s;
    }
    return 'none';
  }

  // ── LOCAL CACHE ────────────────────────────────────────────────────

  Future<void> cacheLibrary(List<MangaItem> items, String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = items
          .map((item) => {
                'id': item.id,
                'mangaId': item.mangaId,
                'title': item.title,
                'author': item.author,
                'artist': item.artist,
                'description': item.description,
                'coverUrl': item.coverUrl,
                'year': item.year,
                'status': item.status,
                'originalLanguage': item.originalLanguage,
                'contentRating': item.contentRating,
                'tags': item.tags,
                'userName': item.userName,
                'addedAt': item.addedAt.toIso8601String(),
                'libraryStatus': item.libraryStatus,
                'lastReadChapterId': item.lastReadChapterId,
                'lastReadPage': item.lastReadPage,
              })
          .toList();
      await prefs.setString(_cacheKey(userName), json.encode(listJson));
    } catch (e) {
      print('Error caching manga_library: $e');
    }
  }

  Future<List<MangaItem>> getCachedLibrary(String userName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(userName));
      if (raw != null) {
        final List decoded = json.decode(raw);
        return decoded.map((data) {
          return MangaItem(
            id: data['id'] ?? '',
            mangaId: data['mangaId'] ?? '',
            title: data['title'] ?? '',
            author: data['author'] ?? '',
            artist: data['artist'] ?? '',
            description: data['description'] ?? '',
            coverUrl: data['coverUrl'] ?? '',
            year: data['year'] ?? '',
            status: data['status'] ?? '',
            originalLanguage: data['originalLanguage'] ?? 'ja',
            contentRating: data['contentRating'] ?? 'safe',
            tags: (data['tags'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
            userName: data['userName'] ?? userName,
            addedAt: DateTime.tryParse(data['addedAt'] ?? '') ??
                DateTime.now(),
            libraryStatus: data['libraryStatus'] ?? 'none',
            lastReadChapterId: data['lastReadChapterId'] ?? '',
            lastReadPage: (data['lastReadPage'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      print('Error reading cached manga_library: $e');
    }
    return [];
  }

  String _cacheKey(String userName) => 'cached_manga_library::$userName';
}

class _MangaMergedEntry {
  final MangaItem primary;
  final MangaItem? partner;
  const _MangaMergedEntry({required this.primary, this.partner});
}
