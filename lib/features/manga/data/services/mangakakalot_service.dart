import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Scrapes mangakakalot.com for chapter data and page images. Catalog
/// browsing (search, popular, latest) is still handled by [ComickService].
///
/// MangaKakalot doesn't offer a public API — we scrape HTML pages:
///   * Search       — `GET /search/story/{title}`
///   * Chapter list — `GET /manga/{slug}`
///   * Page images  — `GET /chapter/{slug}/{chapterId}`
class MangaKakalotService {
  static const String _baseUrl = 'https://mangakakalot.com';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaKakalotImage';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final MangaKakalotService _instance = MangaKakalotService._internal();
  factory MangaKakalotService() => _instance;
  MangaKakalotService._internal();

  Map<String, String> get _headers => {
    'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
    'Accept': 'text/html,application/json',
  };

  final Map<String, MangaChapterPages> _pageCache = {};

  /// Search MangaKakalot by title and return the manga slug
  /// (e.g. "manga-abc123456789").
  Future<String> searchByTitle(String title) async {
    if (title.trim().isEmpty) return '';
    final uri = Uri.parse('$_baseUrl/search/story/${Uri.encodeComponent(title)}');
    try {
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 8),
          );
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
      print('MangaKakalot searchByTitle error: $e');
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
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode == 200) {
        return _parseChapterList(response.body, slug);
      }
    } catch (e) {
      print('MangaKakalot chapter feed error: $e');
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
      final id = href.startsWith('/') ? href.substring(1) : href;
      final numMatch = RegExp(r'chapter[_-]?([\d.]+)', caseSensitive: false)
          .firstMatch(href);
      final chapterNum = numMatch?.group(1) ?? '';
      chapters.add(MangaChapter(
        id: id,
        title: text,
        chapter: chapterNum,
        volume: '',
        pages: 0,
        translatedLanguage: 'en',
        scanlationGroup: '',
        publishAt: DateTime.now(),
      ));
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
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
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
      print('MangaKakalot chapter pages error: $e');
    }
    return null;
  }

  String proxiedImageUrl(String pageUrl) {
    if (pageUrl.isEmpty) return '';
    return '$_proxyImageUrl?url=${Uri.encodeComponent(pageUrl)}';
  }

  // ── LIBRARY (Firestore) ────────────────────────────────────────────

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

  /// Per-user stream of titles the user is currently reading
  /// (`libraryStatus == 'reading'`). Used by the dashboard's partner
  /// sub-row so each partner's active reads surface alongside the
  /// other's. Filtering is done in Dart so we don't need a composite
  /// Firestore index.
  Stream<List<MangaItem>> getReadingStream(String userName) {
    if (userName.isEmpty) return Stream.value(const <MangaItem>[]);
    return _firestore
        .collection('manga_library')
        .where('userName', isEqualTo: userName)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
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
                'altTitles': item.altTitles,
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
            altTitles: (data['altTitles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
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
