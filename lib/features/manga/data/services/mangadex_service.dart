import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Talks to the public MangaDex REST API and to the personal
/// `manga_library` Firestore collection. Mirrors `TMDBService` and
/// `OpenLibraryService` for the cinema and books features.
///
/// MangaDex endpoints used:
///   * Search         — `GET /manga?title=...&originalLanguage[]=ko`
///   * Details        — `GET /manga/{id}?includes[]=cover_art&author`
///   * Chapter feed   — `GET /manga/{id}/feed?translatedLanguage[]=en`
///   * Page URLs      — `GET /at-home/server/{chapterId}`
///   * Tags           — `GET /manga/tag`
///
/// No API key is required for read-only catalog browsing. We do need a
/// descriptive `User-Agent` header as per MangaDex's etiquette. The
/// at-home image server doesn't send CORS headers, so on Flutter Web
/// the reader proxies page images through the `proxyMangaImage`
/// Firebase Cloud Function.
class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';
  static const String _uploadsBase = 'https://uploads.mangadex.org';

  /// Cloud Function URL for proxying manga image requests. Mirrors the
  /// `proxyBookText` pattern from the books feature. The function
  /// fetches chapter images server-side so Flutter web is never
  /// blocked by CORS or hotlink protection.
  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaImage';

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

  // ── MAPPING ────────────────────────────────────────────────────────

  /// Pull the best available title out of a MangaDex title map.
  /// MangaDex returns titles in many languages under `attributes.title`
  /// as a map. We try English, then romaji, then the first available.
  String _pickTitle(Map<String, dynamic> attrs) {
    final dynamic titleRaw = attrs['title'];
    if (titleRaw is! Map) return 'Untitled';
    final title = titleRaw;
    final en = title['en'];
    if (en is String && en.isNotEmpty) return en;
    for (final entry in title.entries) {
      final v = entry.value;
      if (v is String && v.isNotEmpty) return v;
    }
    return 'Untitled';
  }

  /// Pull the best available description. MangaDex often ships
  /// descriptions only in the original language, so we fall back to
  /// whichever language is available.
  String _pickDescription(Map<String, dynamic> attrs) {
    final dynamic descRaw = attrs['description'];
    if (descRaw is! Map) return '';
    final desc = descRaw;
    final en = desc['en'];
    if (en is String && en.isNotEmpty) return en;
    for (final entry in desc.entries) {
      final v = entry.value;
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// Pull tag names out of a MangaDex relationship list. Tags come
  /// embedded as inline relationship objects with `attributes.name.en`.
  List<String> _extractTagNames(List<dynamic> relationships) {
    final names = <String>[];
    for (final rel in relationships) {
      if (rel is Map && rel['type'] == 'tag') {
        final attrs = rel['attributes'] as Map?;
        if (attrs == null) continue;
        final nameMap = attrs['name'] as Map?;
        String? name;
        if (nameMap != null) {
          name = (nameMap['en'] as String?) ??
              (nameMap.values.isNotEmpty ? nameMap.values.first.toString() : null);
        }
        if (name != null && name.isNotEmpty) names.add(name);
        if (names.length >= 8) break;
      }
    }
    return names;
  }

  /// Resolve the cover URL by finding the `cover_art` relationship
  /// and combining its `fileName` with the manga id.
  String _resolveCoverUrl(String mangaId, List<dynamic> relationships) {
    for (final rel in relationships) {
      if (rel is Map && rel['type'] == 'cover_art') {
        final attrs = rel['attributes'] as Map?;
        final fileName = attrs?['fileName'] as String?;
        if (fileName != null && fileName.isNotEmpty) {
          return '$_uploadsBase/covers/$mangaId/$fileName.256.jpg';
        }
      }
    }
    return '';
  }

  /// Pull the author and artist names from the relationship list.
  (String, String) _extractAuthorArtist(List<dynamic> relationships) {
    String author = '';
    String artist = '';
    for (final rel in relationships) {
      if (rel is Map) {
        final type = rel['type'] as String?;
        if (type == 'author' || type == 'artist') {
          final attrs = rel['attributes'] as Map?;
          final name = attrs?['name'] as String?;
          if (name == null || name.isEmpty) continue;
          if (type == 'author' && author.isEmpty) author = name;
          if (type == 'artist' && artist.isEmpty) artist = name;
        }
      }
    }
    return (author, artist);
  }

  /// Map a single MangaDex search/listing result to a `MangaItem`.
  /// Used by search, trending, and discovery endpoints — they all
  /// return the same shape.
  MangaItem _mapManga(Map<String, dynamic> data) {
    final id = data['id'] as String? ?? '';
    final attrsRaw = data['attributes'];
    final attrs = attrsRaw is Map
        ? Map<String, dynamic>.from(attrsRaw)
        : <String, dynamic>{};
    final relsRaw = data['relationships'];
    final rels = relsRaw is List ? relsRaw : const <dynamic>[];
    final (author, artist) = _extractAuthorArtist(rels);
    final year = attrs['year'];
    return MangaItem(
      id: '',
      mangaId: id,
      title: _pickTitle(attrs),
      author: author,
      artist: artist,
      description: _pickDescription(attrs),
      coverUrl: _resolveCoverUrl(id, rels),
      year: year is num ? year.toString() : (year is String ? year : ''),
      status: (attrs['status'] as String?) ?? '',
      originalLanguage: (attrs['originalLanguage'] as String?) ?? 'ja',
      contentRating: (attrs['contentRating'] as String?) ?? 'safe',
      tags: _extractTagNames(rels),
      addedAt: DateTime.now(),
    );
  }

  // ── SEARCH & DISCOVERY ─────────────────────────────────────────────

  /// Search MangaDex by title. Supports content-type filtering
  /// (manga/manhwa/manhua) via `originalLanguage` and tag filtering
  /// via `includedTagIds`.
  Future<List<MangaItem>> searchManga({
    required String query,
    int limit = 20,
    int offset = 0,
    String? originalLanguage, // 'ja' = manga, 'ko' = manhwa, 'zh' = manhua
    List<String>? includedTagIds,
    String contentRating = 'safe',
  }) async {
    if (query.trim().isEmpty) return [];
    final params = <String, List<String>>{
      'title': [query],
      'limit': ['$limit'],
      'offset': ['$offset'],
      'includes': ['cover_art', 'author', 'artist', 'tag'],
      'contentRating[]': contentRating == 'safe'
          ? ['safe', 'suggestive']
          : [contentRating],
      'order[relevance]': ['desc'],
    };
    if (originalLanguage != null && originalLanguage.isNotEmpty) {
      params['originalLanguage[]'] = [originalLanguage];
    }
    if (includedTagIds != null) {
      params['includedTags[]'] = includedTagIds;
    }
    final uri = Uri.parse('$_baseUrl/manga').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final results = (body['data'] as List?) ?? const [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(_mapManga)
            .toList();
      }
    } catch (e) {
      print('MangaDex search error: $e');
    }
    return [];
  }

  /// Fetch a list of popular manga. Mirrors `fetchTrending` for cinema.
  /// Supports the same content-type / language filter.
  Future<List<MangaItem>> fetchPopular({
    String? originalLanguage,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, List<String>>{
      'limit': ['$limit'],
      'offset': ['$offset'],
      'includes': ['cover_art', 'author', 'artist', 'tag'],
      'contentRating[]': ['safe', 'suggestive'],
      'order[followedCount]': ['desc'],
    };
    if (originalLanguage != null && originalLanguage.isNotEmpty) {
      params['originalLanguage[]'] = [originalLanguage];
    }
    final uri = Uri.parse('$_baseUrl/manga').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final results = (body['data'] as List?) ?? const [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(_mapManga)
            .toList();
      }
    } catch (e) {
      print('MangaDex popular error: $e');
    }
    return [];
  }

  /// Fetch recently updated manga. Used to back the "Latest Updates"
  /// carousel on the library home.
  Future<List<MangaItem>> fetchLatest({
    String? originalLanguage,
    int limit = 20,
  }) async {
    final params = <String, List<String>>{
      'limit': ['$limit'],
      'includes': ['cover_art', 'author', 'artist', 'tag'],
      'contentRating[]': ['safe', 'suggestive'],
      'order[latestUploadedChapter]': ['desc'],
    };
    if (originalLanguage != null && originalLanguage.isNotEmpty) {
      params['originalLanguage[]'] = [originalLanguage];
    }
    final uri = Uri.parse('$_baseUrl/manga').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final results = (body['data'] as List?) ?? const [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(_mapManga)
            .toList();
      }
    } catch (e) {
      print('MangaDex latest error: $e');
    }
    return [];
  }

  /// Fetch detailed info for a single manga. Includes cover_art,
  /// author, and artist relationships so the details drawer can
  /// render without a second round-trip.
  Future<MangaItem?> getMangaDetails(String mangaId) async {
    final uri = Uri.parse('$_baseUrl/manga/$mangaId').replace(
      queryParameters: {
        'includes': ['cover_art', 'author', 'artist', 'tag'],
      },
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data == null) return null;
        return _mapManga(data);
      }
    } catch (e) {
      print('MangaDex details error: $e');
    }
    return null;
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
        'includes': ['scanlation_group'],
      },
    );
    try {
      final response = await http.get(uri, headers: _headers);
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
      final response = await http.get(uri, headers: _headers);
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
      final response = await http.get(uri, headers: _headers);
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
