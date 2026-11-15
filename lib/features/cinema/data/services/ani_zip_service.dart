import 'dart:async';
import 'dart:convert';
import '../../../../core/utils/connectivity_aware.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';

class AniZipService with ConnectivityAware {
  final CatalogProxyClient _proxy = CatalogProxyClient();

  static final AniZipService _instance = AniZipService._internal();
  factory AniZipService() => _instance;
  AniZipService._internal();

  Future<Map<String, dynamic>?> fetchMappings(int malId) async {
    if (malId <= 0) return null;
    try {
      final response = await _proxy.get(
        'anizip',
        'mappings',
        query: {'mal_id': '$malId'},
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        Logger.e(
          'ani.zip mappings?mal_id=$malId failed (${response.statusCode})',
        );
        return null;
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      Logger.e('ani.zip mappings?mal_id=$malId error', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchMappingsByAnilist(int anilistId) async {
    if (anilistId <= 0) return null;
    try {
      final response = await _proxy.get(
        'anizip',
        'mappings',
        query: {'anilist_id': '$anilistId'},
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        Logger.e(
          'ani.zip mappings?anilist_id=$anilistId failed (${response.statusCode})',
        );
        return null;
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      Logger.e('ani.zip mappings?anilist_id=$anilistId error', error: e);
      return null;
    }
  }

  Future<int?> fetchTmdbId(int malId) async {
    final data = await fetchMappings(malId);
    final mappings = data?['mappings'] as Map<String, dynamic>?;
    final raw = mappings?['themoviedb_id'];
    if (raw is String && raw.isNotEmpty) return int.tryParse(raw);
    if (raw is num) return raw.toInt();
    return null;
  }

  Future<String?> fetchImdbId(int malId) async {
    final data = await fetchMappings(malId);
    final mappings = data?['mappings'] as Map<String, dynamic>?;
    final raw = mappings?['imdb_id'] as String?;
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  Future<String?> fetchEpisodeImage(int malId, int episodeNumber) async {
    final data = await fetchMappings(malId);
    if (data == null) return null;
    final episodes = data['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return null;
    final entry = episodes[episodeNumber.toString()] as Map<String, dynamic>?;
    final img = entry?['image'] as String?;
    return (img != null && img.isNotEmpty) ? img : null;
  }

  Future<Map<int, String>> fetchEpisodeImages(int malId) async {
    final data = await fetchMappings(malId);
    final out = <int, String>{};
    if (data == null) return out;
    final episodes = data['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return out;
    episodes.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;
      final img = value['image'] as String?;
      if (img == null || img.isEmpty) return;
      final n = int.tryParse(key.toString());
      if (n == null) return;
      out[n] = img;
    });
    return out;
  }

  Future<Map<String, dynamic>?> fetchMappingsFresh(int malId) =>
      fetchMappings(malId);
}
