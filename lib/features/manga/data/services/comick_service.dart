import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:everglow/features/manga/data/models/manga_item.dart';

/// Talks to the public Comick API for catalog browsing (search, popular,
/// latest, details, cover images). Chapter pages still come from the
/// MangaDex API via [MangaDexService].
///
/// Comick endpoints used:
///   * Search    — `GET /v1.0/search?q=...&type=comic`
///   * Details   — `GET /comic/{hid}`
///   * Chapters  — `GET /comic/{id}/chapters?lang=en`
///
/// No API key required. The descriptive User-Agent helps with rate limiting.
class ComickService {
  static const String _baseUrl = 'https://api.comick.dev';
  static const String _coverBase = 'https://meo.comick.pictures';

  static const String _proxyUrl =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyComick';

  // Singleton
  static final ComickService _instance = ComickService._internal();
  factory ComickService() => _instance;
  ComickService._internal();

  Map<String, String> get _headers => {
    'User-Agent': 'Everglow/1.0 (https://github.com/everglow)',
    'Accept': 'application/json',
  };

  Uri _proxied(Uri apiUri) {
    final pathAndQuery = apiUri.path +
        (apiUri.hasQuery ? '?${apiUri.query}' : '');
    return Uri.parse(
      '$_proxyUrl?path=${Uri.encodeComponent(pathAndQuery)}',
    );
  }

  // ── MAPPING HELPERS ──────────────────────────────────────

  /// Status: 1=Ongoing, 2=Completed, 3=Cancelled, 4=On Hiatus
  static String _mapStatus(int? status) {
    switch (status) {
      case 1: return 'ongoing';
      case 2: return 'completed';
      case 3: return 'cancelled';
      case 4: return 'on hiatus';
      default: return '';
    }
  }

  static String _pickTitle(Map<String, dynamic> data) {
    final title = data['title'] as String?;
    if (title != null && title.isNotEmpty) return title;
    final titles = data['md_titles'] as List?;
    if (titles != null) {
      for (final t in titles) {
        if (t is Map) {
          final lang = t['lang'] as String?;
          final text = t['title'] as String?;
          if (lang == 'en' && text != null && text.isNotEmpty) return text;
        }
      }
      for (final t in titles) {
        if (t is Map) {
          final text = t['title'] as String?;
          if (text != null && text.isNotEmpty) return text;
        }
      }
    }
    return 'Untitled';
  }

  static String _pickDescription(dynamic desc) {
    if (desc is String && desc.isNotEmpty) return desc;
    if (desc is Map) {
      final en = desc['en'] as String?;
      if (en != null && en.isNotEmpty) return en;
      for (final entry in desc.entries) {
        final v = entry.value;
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return '';
  }

  static List<String> _extractGenres(List<dynamic>? genres) {
    if (genres == null) return [];
    final names = <String>[];
    for (final g in genres) {
      if (g is Map) {
        final genreMap = g['md_genres'] as Map?;
        if (genreMap != null) {
          final name = genreMap['name'] as String?;
          if (name != null && name.isNotEmpty) names.add(name);
        }
      }
      if (names.length >= 8) break;
    }
    return names;
  }

  static String _coverUrl(List<dynamic>? covers) {
    if (covers == null || covers.isEmpty) return '';
    final first = covers.first;
    if (first is Map) {
      final b2key = first['b2key'] as String?;
      if (b2key != null && b2key.isNotEmpty) {
        return '$_coverBase/$b2key';
      }
    }
    return '';
  }

  /// Map a search result item (from `/v1.0/search`) to [MangaItem].
  static MangaItem _mapSearchResult(Map<String, dynamic> data) {
    final hid = data['hid'] as String? ?? '';
    final country = data['country'] as String? ?? 'jp';
    final covers = data['md_covers'] as List?;

    String? desc;
    final descRaw = data['desc'];
    if (descRaw is String) desc = descRaw;

    final mangaDexId = data['md_id'] as String? ?? '';

    return MangaItem(
      id: '',
      mangaId: hid,
      mangaDexId: mangaDexId,
      title: _pickTitle(data),
      description: desc ?? '',
      coverUrl: _coverUrl(covers),
      year: (data['year'] as int?)?.toString() ?? '',
      status: _mapStatus(data['status'] as int?),
      originalLanguage: country,
      tags: _extractGenres(data['genres'] as List?),
      addedAt: DateTime.now(),
      comickId: data['id'] as int? ?? 0,
      comickSlug: (data['slug'] as String?) ?? '',
      rating: double.tryParse((data['bayesian_rating'] as String?) ?? '') ?? 0,
      followCount: data['user_follow_count'] as int? ?? 0,
    );
  }

  /// Map a detail response (from `/comic/{hid}`) to [MangaItem].
  static MangaItem _mapDetail(Map<String, dynamic> body) {
    final comic = body['comic'] as Map<String, dynamic>? ?? body;
    final hid = comic['hid'] as String? ?? '';
    final country = comic['country'] as String? ?? 'jp';
    final covers = comic['md_covers'] as List?;
    final genres = comic['md_comic_md_genres'] as List?;

    String author = '';
    String artist = '';
    final authors = comic['authors'] as List?;
    final artists = comic['artists'] as List?;
    if (authors != null && authors.isNotEmpty) {
      final first = authors.first;
      if (first is Map) author = first['name'] as String? ?? '';
    }
    if (artists != null && artists.isNotEmpty) {
      final first = artists.first;
      if (first is Map) artist = first['name'] as String? ?? '';
    }

    String desc = comic['desc'] as String? ?? '';
    if (desc.isEmpty) {
      desc = _pickDescription(comic['parsed']);
    }

    final mangaDexId = comic['md_id'] as String? ?? '';

    return MangaItem(
      id: '',
      mangaId: hid,
      mangaDexId: mangaDexId,
      title: _pickTitle(comic),
      author: author,
      artist: artist,
      description: desc,
      coverUrl: _coverUrl(covers),
      year: (comic['year'] as int?)?.toString() ?? '',
      status: _mapStatus(comic['status'] as int?),
      originalLanguage: country,
      tags: _extractGenres(genres),
      addedAt: DateTime.now(),
      comickId: comic['id'] as int? ?? 0,
      comickSlug: (comic['slug'] as String?) ?? '',
      rating: double.tryParse((comic['bayesian_rating'] as String?) ?? '') ?? 0,
      followCount: comic['user_follow_count'] as int? ?? 0,
    );
  }

  // ── API METHODS ──────────────────────────────────────────

  /// Search Comick by title. Supports content-type filtering via
  /// [country] (`jp`/`kr`/`cn`).
  Future<List<MangaItem>> search({
    required String query,
    String? country,
    int limit = 20,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];
    final params = <String, List<String>>{
      'q': [query],
      'limit': ['$limit'],
      'page': ['$page'],
      'type': ['comic'],
    };
    if (country != null && country.isNotEmpty) {
      params['country'] = [country];
    }
    final uri = Uri.parse('$_baseUrl/v1.0/search').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as List? ?? [];
        return body
            .whereType<Map<String, dynamic>>()
            .map(_mapSearchResult)
            .toList();
      }
    } catch (e) {
      print('Comick search error: $e');
    }
    return [];
  }

  /// Fetch popular manga, optionally filtered by [country].
  Future<List<MangaItem>> fetchPopular({
    String? country,
    int limit = 20,
    int page = 1,
  }) async {
    final params = <String, List<String>>{
      'limit': ['$limit'],
      'page': ['$page'],
      'type': ['comic'],
      'sort': ['user_follow_count'],
      'order': ['desc'],
    };
    if (country != null && country.isNotEmpty) {
      params['country'] = [country];
    }
    final uri = Uri.parse('$_baseUrl/v1.0/search').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as List? ?? [];
        return body
            .whereType<Map<String, dynamic>>()
            .map(_mapSearchResult)
            .toList();
      }
    } catch (e) {
      print('Comick popular error: $e');
    }
    return [];
  }

  /// Fetch recently updated manga, optionally filtered by [country].
  Future<List<MangaItem>> fetchLatest({
    String? country,
    int limit = 20,
    int page = 1,
  }) async {
    final params = <String, List<String>>{
      'limit': ['$limit'],
      'page': ['$page'],
      'type': ['comic'],
      'sort': ['uploaded_at'],
      'order': ['desc'],
    };
    if (country != null && country.isNotEmpty) {
      params['country'] = [country];
    }
    final uri = Uri.parse('$_baseUrl/v1.0/search').replace(
      queryParameters: params,
    );
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as List? ?? [];
        return body
            .whereType<Map<String, dynamic>>()
            .map(_mapSearchResult)
            .toList();
      }
    } catch (e) {
      print('Comick latest error: $e');
    }
    return [];
  }

  /// Fetch full details for a single comic by its `hid`.
  Future<MangaItem?> getDetails(String hid) async {
    if (hid.isEmpty) return null;
    final uri = Uri.parse('$_baseUrl/comic/$hid');
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return _mapDetail(body);
      }
    } catch (e) {
      print('Comick details error: $e');
    }
    return null;
  }

  /// Fetch chapter feed for a comic by its Comick numeric [id].
  /// Returns chapters mapped to [MangaChapter] (only fields shared
  /// with MangaDex chapters). Chapter page resolution still goes
  /// through MangaDex.
  Future<List<MangaChapter>> getChapterFeed(int comickId, {
    String language = 'en',
    int limit = 500,
  }) async {
    final uri = Uri.parse('$_baseUrl/comic/$comickId/chapters').replace(
      queryParameters: {
        'limit': ['$limit'],
        'lang': [language],
      },
    );
    try {
      final response = await http.get(_proxied(uri), headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final chapters = body['chapters'] as List? ?? [];
        return chapters.whereType<Map<String, dynamic>>().map((d) {
          final groups = d['md_chapters_groups'] as List?;
          String groupName = '';
          if (groups != null && groups.isNotEmpty) {
            final first = groups.first as Map?;
            final group = first?['md_groups'] as Map?;
            groupName = group?['title'] as String? ?? '';
          }
          return MangaChapter(
            id: d['hid'] as String? ?? '',
            title: d['title'] as String? ?? '',
            chapter: (d['chap'] as dynamic)?.toString() ?? '',
            volume: (d['vol'] as dynamic)?.toString() ?? '',
            pages: 0,
            translatedLanguage: d['lang'] as String? ?? language,
            scanlationGroup: groupName,
            publishAt: DateTime.tryParse(
              (d['publish_at'] as String?) ?? '',
            ) ?? DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      print('Comick chapter feed error: $e');
    }
    return [];
  }
}
