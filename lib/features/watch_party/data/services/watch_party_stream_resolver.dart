import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/watch_party_room.dart';

/// One subtitle track returned by the Everglow stream resolver.
class WatchPartySubtitle {
  final String url;
  final String label;

  const WatchPartySubtitle({required this.url, required this.label});
}

/// The playable stream for a room: a real HLS manifest plus its subtitle
/// tracks. The watch party plays this in our own `<video>`, so play,
/// pause, seek, and captions are exact instead of an iframe best effort.
class WatchPartyStream {
  final String src;
  final List<WatchPartySubtitle> subtitles;
  final String title;

  const WatchPartyStream({
    required this.src,
    required this.subtitles,
    required this.title,
  });
}

/// Resolves a room's movie/episode through Everglow's own streaming
/// Worker. The Worker already serves the cinema and anime player pages;
/// `format=json` returns the same resolved manifest without the HTML, so
/// the watch party can drive the stream itself.
class WatchPartyStreamResolver {
  WatchPartyStreamResolver({http.Client? client, this.timeout = const Duration(seconds: 25)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const String workerBase =
      'https://everglow-stream.khentplaysmoba.workers.dev/proxyAnime';

  /// The request the room turns into. Kept pure so it can be asserted
  /// without the network.
  Uri uriFor(WatchPartyRoom room) {
    final query = <String, String>{'format': 'json'};
    if (room.isAnime) {
      final malId = room.malId ?? room.tmdbId;
      if (malId <= 0) {
        throw StateError('Anime room has no MAL id');
      }
      query.addAll({
        'source': 'megaplay',
        'malId': '$malId',
        'ep': '${room.mediaType == 'movie' ? 1 : (room.episode ?? 1)}',
        'audio': 'sub',
      });
    } else {
      if (room.tmdbId <= 0) {
        throw StateError('Cinema room has no TMDB id');
      }
      query.addAll({
        'source': 'cinema',
        'type': room.mediaType,
        'tmdbId': '${room.tmdbId}',
        's': '${room.season ?? 1}',
        'e': '${room.episode ?? 1}',
      });
      if (room.title.isNotEmpty) query['title'] = room.title;
    }
    return Uri.parse(workerBase).replace(queryParameters: query);
  }

  Future<WatchPartyStream> resolve(WatchPartyRoom room) async {
    final uri = uriFor(room);
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError('Stream resolver answered ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Stream resolver returned an unexpected body');
    }
    return parse(decoded);
  }

  static WatchPartyStream parse(Map<String, dynamic> json) {
    final src = json['src'];
    if (src is! String || src.isEmpty || !src.startsWith('https://')) {
      throw StateError('Stream resolver returned no playable URL');
    }
    final subtitles = <WatchPartySubtitle>[];
    final rawTracks = json['tracks'];
    if (rawTracks is List) {
      for (final raw in rawTracks) {
        if (raw is! Map) continue;
        final file = raw['file'] ?? raw['url'];
        if (file is! String || file.isEmpty || !file.startsWith('https://')) {
          continue;
        }
        final label = (raw['label'] ?? raw['lang'] ?? 'Subtitles').toString();
        subtitles.add(
          WatchPartySubtitle(
            url: file,
            label: label.trim().isEmpty ? 'Subtitles' : label.trim(),
          ),
        );
      }
    }
    return WatchPartyStream(
      src: src,
      subtitles: subtitles,
      title: (json['title'] as String?) ?? '',
    );
  }

  void dispose() => _client.close();
}
