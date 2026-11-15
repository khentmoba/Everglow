import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../core/utils/connectivity_aware.dart';
import '../models/manga_item.dart';
import '../../../../core/utils/logger.dart';

class MangaDexService with ConnectivityAware {
  static const String _proxyUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaDex';

  static const String _proxyImageUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyMangaImage';

  static final MangaDexService _instance = MangaDexService._internal();
  factory MangaDexService() => _instance;
  MangaDexService._internal();

  Map<String, String> get _headers => {
    'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
    'Accept': 'application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        return {..._headers, 'Authorization': 'Bearer $token'};
      }
    } catch (e, st) {
      Logger.e(
        'MangaDexService: failed to get auth token, falling back unsigned',
        error: e,
        stackTrace: st,
      );
    }
    return _headers;
  }

  Uri _proxied(String apiPath) {
    return Uri.parse('$_proxyUrl?path=${Uri.encodeComponent(apiPath)}');
  }

  String proxiedImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    if (originalUrl.contains('proxyMangaImage')) return originalUrl;
    return '$_proxyImageUrl?url=${Uri.encodeComponent(originalUrl)}';
  }

  Future<List<MangaChapter>> getChapterFeed(
    String mangaId, {
    String language = 'en',
    int limit = 500,
    int offset = 0,
  }) async {
    if (mangaId.isEmpty) return [];
    final allChapters = <Map<String, dynamic>>[];
    var currentOffset = offset;
    var total = 0;

    do {
      final path =
          'manga/$mangaId/feed'
          '?translatedLanguage[]=$language'
          '&limit=$limit'
          '&offset=$currentOffset'
          '&order[chapter]=asc'
          '&includes[]=scanlation_group'
          '&contentRating[]=safe'
          '&contentRating[]=suggestive'
          '&contentRating[]=erotica';
      try {
        final headers = await _authHeaders();
        final response = await http
            .get(_proxied(path), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          if (body['result'] != 'ok') break;
          final data = body['data'] as List? ?? [];
          total = (body['total'] as num?)?.toInt() ?? 0;
          allChapters.addAll(data.whereType<Map<String, dynamic>>());
          currentOffset += data.length;
          if (data.length < limit) break;
        } else {
          break;
        }
      } catch (e) {
        Logger.e('MangaDex chapter feed error', error: e);
        break;
      }
    } while (currentOffset < total);

    if (allChapters.isEmpty) return [];

    final filtered = allChapters.where((d) {
      final attrs = d['attributes'] as Map<String, dynamic>? ?? {};
      final pages = (attrs['pages'] as num?)?.toInt() ?? 0;
      return pages > 0;
    }).toList();

    final chaptersToMap = filtered.isNotEmpty ? filtered : allChapters;

    return chaptersToMap.map((d) {
      final attrs = d['attributes'] as Map<String, dynamic>? ?? {};
      final rels = d['relationships'] as List? ?? [];
      String group = '';
      for (final rel in rels) {
        if (rel is Map && rel['type'] == 'scanlation_group') {
          group = (rel['attributes']?['name'] as String?) ?? '';
          break;
        }
      }
      return MangaChapter(
        id: d['id'] as String? ?? '',
        title: (attrs['title'] as String?) ?? '',
        chapter: (attrs['chapter'] as String?) ?? '',
        volume: (attrs['volume'] as String?) ?? '',
        pages: (attrs['pages'] as num?)?.toInt() ?? 0,
        translatedLanguage:
            (attrs['translatedLanguage'] as String?) ?? language,
        scanlationGroup: group,
        publishAt:
            DateTime.tryParse((attrs['publishAt'] as String?) ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  static String _extractTitle(Map<String, dynamic> attrs) {
    final title = attrs['title'] as Map<String, dynamic>?;
    if (title != null) {
      if (title['en'] is String && (title['en'] as String).isNotEmpty) {
        return title['en'] as String;
      }
      for (final v in title.values) {
        if (v is String && v.isNotEmpty) return v;
      }
    }
    final altTitles = attrs['altTitles'] as List?;
    if (altTitles != null && altTitles.isNotEmpty) {
      for (final alt in altTitles) {
        if (alt is Map) {
          for (final v in alt.values) {
            if (v is String && v.isNotEmpty) return v;
          }
        }
      }
    }
    return 'Untitled';
  }

  String _coverUrl(String mangaId, List<dynamic>? relationships) {
    if (mangaId.isEmpty) return '';
    if (relationships == null) return '';
    for (final rel in relationships) {
      if (rel is Map && rel['type'] == 'cover_art') {
        final relAttrs = rel['attributes'] as Map<String, dynamic>?;
        final fileName = relAttrs?['fileName'] as String?;
        if (fileName != null && fileName.isNotEmpty) {
          final raw =
              'https://uploads.mangadex.org/covers/$mangaId/$fileName.256.jpg';
          return proxiedImageUrl(raw);
        }
      }
    }
    return '';
  }

  static String _extractDescription(Map<String, dynamic> attrs) {
    final desc = attrs['description'] as Map<String, dynamic>?;
    if (desc == null) return '';
    if (desc['en'] is String && (desc['en'] as String).isNotEmpty) {
      return desc['en'] as String;
    }
    for (final v in desc.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  static String _mapStatus(String? status) {
    switch (status) {
      case 'ongoing':
        return 'ongoing';
      case 'completed':
        return 'completed';
      case 'hiatus':
        return 'on hiatus';
      case 'cancelled':
      case 'discontinued':
        return status ?? 'cancelled';
      default:
        return '';
    }
  }

  static List<String> _extractTags(List<dynamic>? tags) {
    if (tags == null) return [];
    final names = <String>[];
    for (final t in tags) {
      if (t is Map) {
        final tagAttrs = t['attributes'] as Map<String, dynamic>?;
        final nameMap = tagAttrs?['name'] as Map<String, dynamic>?;
        final name = nameMap?['en'] as String?;
        if (name != null && name.isNotEmpty) {
          names.add(name);
          if (names.length >= 8) break;
        }
      }
    }
    return names;
  }

  static String? _normaliseLang(String? lang) {
    if (lang == null || lang.isEmpty) return null;
    switch (lang) {
      case 'jp':
        return 'ja';
      case 'cn':
        return 'zh';
      default:
        return lang;
    }
  }

  MangaItem _mapMangaItem(Map<String, dynamic> data) {
    final mangaId = data['id'] as String? ?? '';
    final attrs = data['attributes'] as Map<String, dynamic>? ?? {};
    final relationships = data['relationships'] as List?;
    final rating = attrs['rating'] as Map<String, dynamic>?;

    var author = '';
    var artist = '';
    for (final relationship in relationships ?? const <dynamic>[]) {
      if (relationship is! Map) continue;
      final type = relationship['type'] as String?;
      final name = (relationship['attributes'] as Map?)?['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      if (type == 'author' && author.isEmpty) {
        author = name;
      } else if (type == 'artist' && artist.isEmpty) {
        artist = name;
      }
    }

    final altTitlesRaw = attrs['altTitles'] as List?;
    final altTitles = <String>[];
    if (altTitlesRaw != null) {
      for (final alt in altTitlesRaw) {
        if (alt is Map) {
          for (final v in alt.values) {
            if (v is String && v.isNotEmpty && !altTitles.contains(v)) {
              altTitles.add(v);
            }
          }
        }
      }
    }

    return MangaItem(
      id: '',
      mangaId: mangaId,
      mangaKakalotId: mangaId,
      title: _extractTitle(attrs),
      author: author,
      artist: artist,
      description: _extractDescription(attrs),
      coverUrl: _coverUrl(mangaId, relationships),
      year: (attrs['year'] as int?)?.toString() ?? '',
      status: _mapStatus(attrs['status'] as String?),
      originalLanguage: attrs['originalLanguage'] as String? ?? 'ja',
      tags: _extractTags(attrs['tags'] as List?),
      addedAt: DateTime.now(),
      rating: (rating?['bayesian'] as num?)?.toDouble() ?? 0,
      followCount: attrs['followedCount'] as int? ?? 0,
      altTitles: altTitles,
    );
  }

  Future<MangaItem?> getDetails(String mangaId) async {
    if (mangaId.isEmpty) return null;
    final path =
        'manga/$mangaId'
        '?includes[]=author'
        '&includes[]=artist'
        '&includes[]=cover_art'
        '&includes[]=tags';
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxied(path), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = body['data'];
        if (data is Map<String, dynamic>) return _mapMangaItem(data);
      }
    } catch (e) {
      Logger.e('MangaDex details error', error: e);
    }
    return null;
  }

  Future<List<MangaItem>> search({
    required String query,
    String? originalLanguage,
    int limit = 20,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];
    final offset = (page - 1) * limit;
    final lang = _normaliseLang(originalLanguage);
    final buf = StringBuffer(
      'manga?title=${Uri.encodeQueryComponent(query)}'
      '&limit=$limit&offset=$offset'
      '&includes[]=cover_art'
      '&includes[]=author'
      '&includes[]=artist'
      '&order[followedCount]=desc'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive'
      '&contentRating[]=erotica',
    );
    if (lang != null && lang.isNotEmpty) {
      buf.write('&originalLanguage[]=$lang');
    }
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxied(buf.toString()), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapMangaItem)
            .toList();
      }
    } catch (e) {
      Logger.e('MangaDex search error', error: e);
    }
    return [];
  }

  Future<List<MangaItem>> fetchPopular({
    String? originalLanguage,
    int limit = 20,
    int page = 1,
  }) async {
    final offset = (page - 1) * limit;
    final lang = _normaliseLang(originalLanguage);
    final buf = StringBuffer(
      'manga?limit=$limit&offset=$offset'
      '&includes[]=cover_art'
      '&includes[]=author'
      '&includes[]=artist'
      '&order[followedCount]=desc'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive'
      '&contentRating[]=erotica',
    );
    if (lang != null && lang.isNotEmpty) {
      buf.write('&originalLanguage[]=$lang');
    }
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxied(buf.toString()), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapMangaItem)
            .toList();
      }
    } catch (e) {
      Logger.e('MangaDex popular error', error: e);
    }
    return [];
  }

  Future<List<MangaItem>> fetchLatest({
    String? originalLanguage,
    int limit = 20,
    int page = 1,
  }) async {
    final offset = (page - 1) * limit;
    final lang = _normaliseLang(originalLanguage);
    final buf = StringBuffer(
      'manga?limit=$limit&offset=$offset'
      '&includes[]=cover_art'
      '&includes[]=author'
      '&includes[]=artist'
      '&order[latestUploadedChapter]=desc'
      '&contentRating[]=safe'
      '&contentRating[]=suggestive'
      '&contentRating[]=erotica',
    );
    if (lang != null && lang.isNotEmpty) {
      buf.write('&originalLanguage[]=$lang');
    }
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxied(buf.toString()), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return [];
        final data = body['data'] as List? ?? [];
        return data
            .whereType<Map<String, dynamic>>()
            .map(_mapMangaItem)
            .toList();
      }
    } catch (e) {
      Logger.e('MangaDex latest error', error: e);
    }
    return [];
  }

  Future<MangaChapterPages?> getChapterPages(String chapterId) async {
    if (chapterId.isEmpty) return null;
    final path = 'at-home/server/$chapterId?forcePort443=false';
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(_proxied(path), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['result'] != 'ok') return null;
        final baseUrl = body['baseUrl'] as String? ?? '';
        final chapter = body['chapter'] as Map<String, dynamic>?;
        if (chapter == null) return null;
        final hash = chapter['hash'] as String? ?? '';
        final filenames =
            (chapter['data'] as List?)?.whereType<String>().toList() ??
            const [];
        if (filenames.isEmpty) return null;
        return MangaChapterPages(
          chapterId: chapterId,
          baseUrl: baseUrl,
          hash: hash,
          filenames: filenames,
          expiresAt: DateTime.now().add(const Duration(minutes: 14)),
        );
      }
    } catch (e) {
      Logger.e('MangaDex chapter pages error', error: e);
    }
    return null;
  }

  Future<MangaChapterPages?> getChapterPagesProxied(String chapterId) async {
    final pages = await getChapterPages(chapterId);
    if (pages == null) return null;
    final proxiedFilenames = pages.filenames.map((f) {
      final directUrl = pages.urlForPage(pages.filenames.indexOf(f));
      return proxiedImageUrl(directUrl);
    }).toList();
    return MangaChapterPages(
      chapterId: pages.chapterId,
      baseUrl: '',
      hash: '',
      filenames: proxiedFilenames,
      expiresAt: pages.expiresAt,
    );
  }
}
