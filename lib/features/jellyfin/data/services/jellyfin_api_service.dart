import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/env_config.dart';
import '../../../../core/utils/logger.dart';
import '../models/jellyfin_media_item.dart';

/// Read-only client for the self-hosted Jellyfin server.
///
/// The server address is kept here so the Watch Together tab can list
/// the user's own library and turn any movie into a synchronized HLS
/// party stream. The API key comes from the runtime JELLYFIN_API_KEY
/// env setting instead of source code.
class JellyfinApiService {
  static const String defaultBaseUrl = 'http://localhost:8096';

  final String baseUrl;
  final String? apiKey;

  const JellyfinApiService({
    this.baseUrl = defaultBaseUrl,
    this.apiKey,
  });

  /// Resolves the key from an explicit constructor value or the runtime
  /// env setting. There is intentionally no hardcoded fallback.
  String get _effectiveApiKey => apiKey ?? EnvConfig.jellyfinApiKey;

  bool get hasConfiguredKey => _effectiveApiKey.isNotEmpty;

  String _authQuery() => 'api_key=$_effectiveApiKey';

  /// Resolves the first (admin) user id. Jellyfin's item endpoints are
  /// user-scoped, so the app needs this before listing movies.
  Future<String?> _resolveUserId() async {
    final uri = Uri.parse('$baseUrl/Users?${_authQuery()}');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        Logger.e('Jellyfin users failed (${response.statusCode})');
        return null;
      }
      final list = json.decode(response.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      return first['Id'] as String?;
    } catch (e) {
      Logger.e('Jellyfin users error', error: e);
      return null;
    }
  }

  /// Lists movies currently indexed by Jellyfin.
  ///
  /// Returns `null` when the server can't be reached (so the UI can tell
  /// "server down" apart from "library empty").
  Future<List<JellyfinMediaItem>?> fetchMovies() async {
    final userId = await _resolveUserId();
    if (userId == null) return null;

    final uri = Uri.parse(
      '$baseUrl/Users/$userId/Items?${_authQuery()}'
      '&includeItemTypes=Movie&recursive=true'
      '&fields=Overview,RunTimeTicks,PrimaryImageAspectRatio&limit=200',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        Logger.e('Jellyfin items failed (${response.statusCode})');
        return null;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final items = body['Items'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(JellyfinMediaItem.fromJson)
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList();
    } catch (e) {
      Logger.e('Jellyfin items error', error: e);
      return null;
    }
  }

  /// HLS master playlist for a movie. The existing watch-party player
  /// feeds this to hls.js for real play/pause/seek sync.
  String streamUrlFor(String itemId) {
    return '$baseUrl/Videos/$itemId/master.m3u8?${_authQuery()}'
        '&MediaSourceId=$itemId&AudioCodec=copy';
  }

  /// Primary poster image for a library item.
  String posterUrlFor(String itemId, {String? tag}) {
    var url =
        '$baseUrl/Items/$itemId/Images/Primary?${_authQuery()}'
        '&maxWidth=300&maxHeight=450&quality=90';
    if (tag != null && tag.isNotEmpty) {
      url += '&tag=${Uri.encodeQueryComponent(tag)}';
    }
    return url;
  }

  /// Resolves the first text subtitle track index for a movie.
  ///
  /// Jellyfin indexes both embedded subtitles and sidecar `.srt` files as
  /// subtitle media streams. The watch party can then request that track as
  /// WebVTT, which browsers render natively on the `<video>` element.
  Future<int?> fetchDefaultSubtitleIndex(String itemId) async {
    final userId = await _resolveUserId();
    if (userId == null) return null;

    final uri = Uri.parse(
      '$baseUrl/Items/$itemId/PlaybackInfo?${_authQuery()}'
      '&userId=$userId&MediaSourceId=$itemId',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        Logger.e('Jellyfin playback info failed (${response.statusCode})');
        return null;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final sources = body['MediaSources'] as List<dynamic>? ?? const [];
      if (sources.isEmpty) return null;
      final streams =
          (sources.first as Map<String, dynamic>)['MediaStreams']
              as List<dynamic>? ??
          const [];

      int? fallback;
      for (final raw in streams.whereType<Map<String, dynamic>>()) {
        if (raw['Type'] != 'Subtitle') continue;
        if (raw['IsTextSubtitleStream'] != true) continue;
        final index = raw['Index'] is num
            ? (raw['Index'] as num).toInt()
            : null;
        if (index == null) continue;
        fallback ??= index;
        if (raw['IsDefault'] == true) return index;
      }
      return fallback;
    } catch (e) {
      Logger.e('Jellyfin playback info error', error: e);
      return null;
    }
  }

  /// WebVTT subtitle URL for a movie's subtitle track index.
  String subtitleUrlFor(String itemId, int index) {
    return '$baseUrl/Videos/$itemId/$itemId/Subtitles/'
        '$index/0/stream.vtt?${_authQuery()}';
  }
}
