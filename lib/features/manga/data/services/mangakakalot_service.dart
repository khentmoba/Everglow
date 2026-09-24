import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/connectivity_aware.dart';
import '../models/manga_item.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import 'comick_service.dart';
import 'katana_service.dart';
import 'mangadex_service.dart';
import '../models/katana_models.dart';

/// Scrapes mangakakalot.com for chapter data and page images. Catalog
/// browsing (search, popular, latest) is still handled by [ComickService].
///
/// MangaKakalot doesn't offer a public API — we scrape HTML pages:
///   * Search       — `GET /search/story/{title}`
///   * Chapter list — `GET /manga/{slug}`
///   * Page images  — `GET /chapter/{slug}/{chapterId}`
class MangaKakalotService with ConnectivityAware {
  static const String _baseUrl = 'https://mangakakalot.com';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKakalotImage';

  static const String _proxyHtmlUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyFetchHtml';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final MangaKakalotService _instance = MangaKakalotService._internal();
  factory MangaKakalotService() => _instance;
  MangaKakalotService._internal();

  Map<String, String> get _headers => {
    'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
    'Accept': 'text/html,application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {..._headers, 'Authorization': 'Bearer $token'};
      }
    } catch (e, st) {
      Logger.e(
        'MangaKakalotService: failed to get auth token, falling back unsigned',
        error: e,
        stackTrace: st,
      );
    }
    return _headers;
  }

  final Map<String, MangaChapterPages> _pageCache = {};

  /// Rewrite a direct [Uri] through the [proxyFetchHtml] Cloud Function
  /// so the request works on Flutter Web (CORS-safe).
  Uri _proxiedFetch(Uri uri) {
    return Uri.parse(
      '$_proxyHtmlUrl?url=${Uri.encodeComponent(uri.toString())}',
    );
  }

  /// Search MangaKakalot by title and return the manga slug
  /// (e.g. "manga-abc123456789").
  Future<String> searchByTitle(String title) async {
    if (title.trim().isEmpty) return '';
    final uri = Uri.parse(
      '$_baseUrl/search/story/${Uri.encodeComponent(title)}',
    );
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxiedFetch(uri), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = response.body;
        final hrefReg = RegExp(r'<a[^>]*href="([^"]*)"[^>]*>');
        final matches = hrefReg.allMatches(body);
        for (final m in matches) {
          final href = m.group(1) ?? '';
          if (href.startsWith('/manga/')) {
            return href.replaceFirst('/manga/', '');
          }
        }
      }
    } catch (e) {
      Logger.e('MangaKakalot searchByTitle error', error: e);
    }
    return '';
  }

  /// Scrape the manga detail page for its chapter list.
  /// [slug] is the MangaKakalot slug (e.g. "manga-abc123456789").
  Future<List<MangaChapter>> getChapterFeed(
    String slug, {
    String language = 'en',
    int limit = 500,
    int offset = 0,
  }) async {
    if (slug.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/manga/$slug');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxiedFetch(uri), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return _parseChapterList(response.body, slug);
      }
    } catch (e) {
      Logger.e('MangaKakalot chapter feed error', error: e);
    }
    return [];
  }

  List<MangaChapter> _parseChapterList(String html, String slug) {
    final chapters = <MangaChapter>[];
    final linkReg = RegExp(
      r'<a[^>]*href="([^"]*\/chapter\/[^"]+)"[^>]*>([^<]*)',
    );
    final matches = linkReg.allMatches(html);
    final seen = <String>{};
    for (final m in matches) {
      final href = m.group(1)?.trim() ?? '';
      final text = m.group(2)?.trim() ?? '';
      if (href.isEmpty || !seen.add(href)) continue;
      // Detail pages also link other series' chapters (sidebars and
      // rails) — only keep links for the series we asked for.
      if (slug.isNotEmpty && !href.contains(slug)) continue;
      final id = href.startsWith('/') ? href.substring(1) : href;
      final numMatch = RegExp(
        r'chapter[_-]?([\d.]+)',
        caseSensitive: false,
      ).firstMatch(href);
      final chapterNum = numMatch?.group(1) ?? '';
      chapters.add(
        MangaChapter(
          id: id,
          title: text,
          chapter: chapterNum,
          volume: '',
          pages: 0,
          translatedLanguage: 'en',
          scanlationGroup: '',
          publishAt: DateTime.now(),
        ),
      );
    }
    return chapters;
  }

  /// Scrape a chapter page for image URLs.
  /// [chapterId] is the URL path (e.g. "chapter/{slug}/chapter_1").
  Future<MangaChapterPages?> getChapterPages(String chapterId) async {
    final cached = _pageCache[chapterId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }
    final uri = Uri.parse('$_baseUrl/$chapterId');
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxiedFetch(uri), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final imgReg = RegExp(r'<img[^>]*src="([^"]+)"[^>]*>');
        final matches = imgReg.allMatches(response.body);
        final urls = <String>[];
        for (final m in matches) {
          final src = m.group(1)?.trim() ?? '';
          if (src.isNotEmpty && !src.contains('ads') && !src.contains('logo')) {
            urls.add(src);
          }
        }
        if (urls.isEmpty) return null;
        final result = MangaChapterPages(
          chapterId: chapterId,
          baseUrl: '',
          hash: '',
          filenames: urls,
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
        _pageCache[chapterId] = result;
        return result;
      }
    } catch (e) {
      Logger.e('MangaKakalot chapter pages error', error: e);
    }
    return null;
  }

  String proxiedImageUrl(String pageUrl) {
    if (pageUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(pageUrl)}';
  }

  // ── LIBRARY (Firestore) ────────────────────────────────────────────

  /// Fill missing creator and catalog metadata for a library item.
  ///
  /// Older entries were saved from slim search results, so they can have a
  /// cover and title but no author. Resolve the source detail once and merge
  /// the useful fields back into the user's library document.
  Future<MangaItem?> enrichMetadata(MangaItem item, String userName) async {
    if (item.hasAuthor) return item;

    MangaItem? full;
    try {
      if (item.mangaId.startsWith('katana|')) {
        final slug = item.mangaKakalotId.isNotEmpty
            ? item.mangaKakalotId
            : item.mangaId.substring('katana|'.length);
        final detail = await KatanaService().fetchMangaDetail(slug);
        if (detail != null) full = _katanaMetadata(item, detail);
      } else if (item.comickId > 0 || item.comickSlug.isNotEmpty) {
        full = await ComickService().getDetails(item.mangaId);
        if (full == null || !full.hasAuthor) {
          full = await _findMangaDexMatch(item);
        }
      } else if (item.mangaKakalotId.isNotEmpty) {
        full = await MangaDexService().getDetails(item.mangaKakalotId);
        if (full == null || !full.hasAuthor) {
          full = await _findMangaDexMatch(item);
        }
      }
    } catch (e, st) {
      Logger.e(
        'Manga metadata enrichment failed for ${item.mangaId}',
        error: e,
        stackTrace: st,
      );
      return null;
    }

    if (full == null) return null;
    final merged = _mergeMetadata(item, full);
    final patch = _metadataPatch(merged);
    if (userName.isNotEmpty && patch.isNotEmpty) {
      try {
        final docs = await withGetTimeout(
          _firestore
              .collection('manga_library')
              .where('mangaId', isEqualTo: item.mangaId)
              .where('userName', isEqualTo: userName)
              .limit(1)
              .get(),
          label: 'manga metadata repair lookup',
        );
        if (docs.docs.isNotEmpty) {
          await docs.docs.first.reference.update(patch);
        }
      } catch (e, st) {
        Logger.e(
          'Manga metadata enrichment write failed for ${item.mangaId}',
          error: e,
          stackTrace: st,
        );
      }
    }
    return merged;
  }

  Future<MangaItem?> _findMangaDexMatch(MangaItem item) async {
    if (item.title.trim().isEmpty) return null;
    final results = await MangaDexService().search(query: item.title, limit: 5);
    final wanted = item.title.trim().toLowerCase();
    MangaItem? match;
    for (final candidate in results) {
      final names = [candidate.title, ...candidate.altTitles];
      if (names.any((name) => name.trim().toLowerCase() == wanted)) {
        match = candidate;
        break;
      }
    }
    if (match == null) return null;
    if (match.hasAuthor) return match;
    return MangaDexService().getDetails(match.mangaId);
  }

  MangaItem _katanaMetadata(MangaItem base, KatanaManga manga) {
    final hasTypeGenre = manga.genres.any((genre) {
      final value = '${genre.slug} ${genre.name}'.toLowerCase();
      return value.contains('manhwa') || value.contains('manhua');
    });
    return base.copyWith(
      title: manga.title.isNotEmpty ? manga.title : base.title,
      author: manga.authors.isNotEmpty ? manga.authors.first : base.author,
      artist: manga.artists.isNotEmpty ? manga.artists.first : base.artist,
      description: manga.summary.isNotEmpty ? manga.summary : base.description,
      coverUrl: manga.coverUrl.isNotEmpty
          ? KatanaService.proxyImageUrl(manga.coverUrl)
          : base.coverUrl,
      status: manga.status.isNotEmpty ? manga.status : base.status,
      originalLanguage: hasTypeGenre
          ? katanaLanguageForGenres(manga.genres)
          : base.originalLanguage,
      tags: manga.genres.isNotEmpty
          ? [for (final genre in manga.genres) genre.name]
          : base.tags,
      altTitles: manga.altNames.isNotEmpty ? manga.altNames : base.altTitles,
    );
  }

  MangaItem _mergeMetadata(MangaItem base, MangaItem full) {
    return base.copyWith(
      title: full.title.isNotEmpty ? full.title : base.title,
      author: full.author.isNotEmpty ? full.author : base.author,
      artist: full.artist.isNotEmpty ? full.artist : base.artist,
      description: full.description.isNotEmpty
          ? full.description
          : base.description,
      coverUrl: base.coverUrl.isNotEmpty ? base.coverUrl : full.coverUrl,
      year: full.year.isNotEmpty ? full.year : base.year,
      status: full.status.isNotEmpty ? full.status : base.status,
      originalLanguage: full.originalLanguage.isNotEmpty
          ? full.originalLanguage
          : base.originalLanguage,
      tags: full.tags.isNotEmpty ? full.tags : base.tags,
      rating: full.rating > 0 ? full.rating : base.rating,
      followCount: full.followCount > 0 ? full.followCount : base.followCount,
      altTitles: full.altTitles.isNotEmpty ? full.altTitles : base.altTitles,
      mangaKakalotId: full.mangaKakalotId.isNotEmpty
          ? full.mangaKakalotId
          : base.mangaKakalotId,
      comickId: full.comickId > 0 ? full.comickId : base.comickId,
      comickSlug: full.comickSlug.isNotEmpty
          ? full.comickSlug
          : base.comickSlug,
    );
  }

  Map<String, dynamic> _metadataPatch(MangaItem item) {
    final patch = <String, dynamic>{};
    void put(String key, String value) {
      if (value.trim().isNotEmpty) patch[key] = value;
    }

    put('title', item.title);
    put('author', item.author);
    put('artist', item.artist);
    put('description', item.description);
    put('coverUrl', item.coverUrl);
    put('year', item.year);
    put('status', item.status);
    put('originalLanguage', item.originalLanguage);
    if (item.tags.isNotEmpty) patch['tags'] = item.tags;
    if (item.altTitles.isNotEmpty) patch['altTitles'] = item.altTitles;
    if (item.rating > 0) patch['rating'] = item.rating;
    if (item.followCount > 0) patch['followCount'] = item.followCount;
    if (item.mangaKakalotId.isNotEmpty) {
      patch['mangaKakalotId'] = item.mangaKakalotId;
    }
    if (item.comickId > 0) patch['comickId'] = item.comickId;
    if (item.comickSlug.isNotEmpty) patch['comickSlug'] = item.comickSlug;
    return patch;
  }

  Future<void> saveToLibrary(
    MangaItem item,
    String libraryStatus,
    String userName,
  ) async {
    if (userName.isEmpty) return;
    try {
      final enriched = await enrichMetadata(item, userName);
      final saveItem = enriched ?? item;
      final collection = _firestore.collection('manga_library');
      final existing = await withGetTimeout(
        collection
            .where('mangaId', isEqualTo: saveItem.mangaId)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'manga save lookup',
      );
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update({
          'libraryStatus': libraryStatus,
          'addedAt': Timestamp.now(),
          ..._metadataPatch(saveItem),
        });
      } else {
        await collection.add(
          saveItem
              .copyWith(
                libraryStatus: libraryStatus,
                userName: userName,
                addedAt: DateTime.now(),
              )
              .toFirestore(),
        );
      }
    } catch (e) {
      Logger.e('Error saving to manga_library', error: e);
    }
  }

  Future<void> removeFromLibrary(String mangaId, String userName) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('manga_library');
      final existing = await withGetTimeout(
        collection
            .where('mangaId', isEqualTo: mangaId)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'manga remove lookup',
      );
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).delete();
      }
    } catch (e) {
      Logger.e('Error removing from manga_library', error: e);
    }
  }

  Future<void> saveReadingProgress({
    required String mangaId,
    required String userName,
    required String chapterId,
    required int page,
  }) async {
    if (userName.isEmpty) return;
    try {
      final collection = _firestore.collection('manga_library');
      final existing = await withGetTimeout(
        collection
            .where('mangaId', isEqualTo: mangaId)
            .where('userName', isEqualTo: userName)
            .limit(1)
            .get(),
        label: 'manga progress save lookup',
      );
      if (existing.docs.isNotEmpty) {
        await collection.doc(existing.docs.first.id).update({
          'lastReadChapterId': chapterId,
          'lastReadPage': page,
        });
      }
    } catch (e) {
      Logger.e('Error saving reading progress', error: e);
    }
  }

  Stream<List<MangaItem>> getLibraryStream(String userName) {
    return _firestore
        .collection('manga_library')
        .where('userName', isEqualTo: userName)
        .limit(500)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MangaItem.fromFirestore(doc.data(), doc.id))
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          cacheLibrary(items, userName);
          return items;
        });
  }

  /// Per-user stream of titles the user is currently reading
  /// (`libraryStatus == 'reading'`). Used by the dashboard's partner
  /// sub-row so each partner's active reads surface alongside the
  /// other's. Filtering is done in Dart so we don't need a composite
  /// Firestore index.
  Stream<List<MangaItem>> getReadingStream(String userName) {
    return getReadingPreviewStream(userName, limit: 500);
  }

  // Capped preview for the dashboard rail: each partner sub-row renders
  // up to 12 cards, so the default 500-doc stream is heavy on every
  // dashboard visit. Full library stays on getReadingStream / the
  // manga screens.
  Stream<List<MangaItem>> getReadingPreviewStream(
    String userName, {
    int limit = 24,
  }) {
    if (userName.isEmpty) return Stream.value(const <MangaItem>[]);
    return _firestore
        .collection('manga_library')
        .where('userName', isEqualTo: userName)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => MangaItem.fromFirestore(doc.data(), doc.id))
                  .where((i) => i.isReading)
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          return items;
        });
  }

  Stream<List<MangaItem>> getCoupleLibraryStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) {
    return getCoupleLibraryPreviewStream(
      userA: userA,
      userB: userB,
      limit: 500,
    );
  }

  // Capped preview for the dashboard header: it only shows the badge
  // count, but today it merges two 500-doc realtime streams to do it.
  // Default cap (24 per partner) is plenty for a count badge; the
  // manga screens keep the full stream.
  Stream<List<MangaItem>> getCoupleLibraryPreviewStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
    int limit = 24,
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
          .limit(limit)
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
          .limit(limit)
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
      await controller.close();
    };

    return controller.stream;
  }

  static List<MangaItem> _mergeCoupleItems(
    List<MangaItem> itemsA,
    List<MangaItem> itemsB,
  ) {
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
          primary: existing.primary,
          partner: item,
        );
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
    }).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return merged;
  }

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
          .map(
            (item) => {
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
              'altTitles': item.altTitles,
            },
          )
          .toList();
      await prefs.setString(_cacheKey(userName), json.encode(listJson));
    } catch (e) {
      Logger.e('Error caching manga_library', error: e);
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
            tags:
                (data['tags'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
            userName: data['userName'] ?? userName,
            addedAt: DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
            libraryStatus: data['libraryStatus'] ?? 'none',
            lastReadChapterId: data['lastReadChapterId'] ?? '',
            lastReadPage: (data['lastReadPage'] as num?)?.toInt() ?? 0,
            altTitles:
                (data['altTitles'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
          );
        }).toList();
      }
    } catch (e) {
      Logger.e('Error reading cached manga_library', error: e);
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
