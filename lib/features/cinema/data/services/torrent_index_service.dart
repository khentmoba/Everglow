import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/agent/agent_mode.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/catalog_proxy_client.dart';
import 'tmdb_service.dart';

@immutable
class TorrentCopy {
  const TorrentCopy({
    required this.infoHash,
    required this.filename,
    required this.quality,
    required this.size,
    required this.seeders,
    required this.provider,
    required this.magnet,
  });

  final String infoHash;
  final String filename;

  final String quality;

  final String size;
  final int seeders;

  final String provider;

  final String magnet;
}

class TorrentSearch {
  const TorrentSearch({this.copies = const [], this.reason});

  final List<TorrentCopy> copies;
  final String? reason;

  bool get isEmpty => copies.isEmpty;
}

class TorrentIndexService {
  TorrentIndexService({CatalogProxyClient? client, TMDBService? tmdb})
    : _client = client ?? CatalogProxyClient(),
      _tmdb = tmdb ?? TMDBService();

  static const String _index = 'torrentio';

  static const int maxCopies = 12;

  static const List<String> _fallbackTrackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.stealth.si:80/announce',
    'udp://tracker.torrent.eu.org:451/announce',
  ];

  final CatalogProxyClient _client;
  final TMDBService _tmdb;

  Future<String?> imdbIdFor({required int tmdbId, required String mediaType}) =>
      _tmdb.fetchImdbId(tmdbId, mediaType);

  Future<TorrentSearch> search({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return const TorrentSearch(copies: demoCopies);
    }
    if (mediaType == 'tv' && (season == null || episode == null)) {
      return const TorrentSearch(reason: 'Open an episode to download it.');
    }
    final imdbId = await imdbIdFor(tmdbId: tmdbId, mediaType: mediaType);
    if (imdbId == null) {
      return const TorrentSearch(reason: 'No IMDB match for this title yet.');
    }
    final path = mediaType == 'tv'
        ? 'stream/series/$imdbId:$season:$episode.json'
        : 'stream/movie/$imdbId.json';
    try {
      final response = await _client.get(
        _index,
        path,
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        Logger.e('[TorrentIndex] $path returned ${response.statusCode}');
        return const TorrentSearch(
          reason: "Couldn't reach the download index.",
        );
      }
      final copies = parseCopies(response.body);
      return copies.isEmpty
          ? const TorrentSearch(reason: 'No copies found for this title.')
          : TorrentSearch(copies: copies);
    } catch (e) {
      Logger.e('[TorrentIndex] $path failed', error: e);
      return const TorrentSearch(reason: "Couldn't reach the download index.");
    }
  }

  @visibleForTesting
  static List<TorrentCopy> parseCopies(String body) {
    dynamic decoded;
    try {
      decoded = json.decode(body);
    } catch (e) {
      Logger.e('[TorrentIndex] payload was not JSON', error: e);
      return const [];
    }
    if (decoded is! Map) return const [];
    final streams = decoded['streams'];
    if (streams is! List) return const [];

    final byHash = <String, TorrentCopy>{};
    for (final raw in streams) {
      if (raw is! Map) continue;
      final hash = (raw['infoHash'] ?? '').toString().trim();
      if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) continue;
      final name = (raw['name'] ?? '').toString();
      final title = (raw['title'] ?? '').toString();
      final hints = raw['behaviorHints'];
      final hintFile = hints is Map ? (hints['filename'] ?? '').toString() : '';
      final filename = hintFile.isNotEmpty
          ? hintFile
          : _filenameFrom(title, name);
      final seeders = _intAfter(title, '👤');
      final size = _valueAfter(title, '💾');
      final provider = _valueAfter(title, '⚙️');
      final copy = TorrentCopy(
        infoHash: hash.toLowerCase(),
        filename: filename,
        quality: _quality(name),
        size: size,
        seeders: seeders,
        provider: provider,
        magnet: magnetFor(
          hash: hash,
          filename: filename,
          trackers: _trackers(raw['sources']),
        ),
      );
      final known = byHash[copy.infoHash];
      if (known == null || copy.seeders > known.seeders) {
        byHash[copy.infoHash] = copy;
      }
    }

    final sorted = byHash.values.toList()
      ..sort((a, b) => b.seeders.compareTo(a.seeders));
    return sorted.take(maxCopies).toList();
  }

  static String magnetFor({
    required String hash,
    required String filename,
    List<String> trackers = const [],
  }) {
    final peers = trackers.isEmpty ? _fallbackTrackers : trackers;
    final parts = <String>[
      'xt=urn:btih:${hash.toLowerCase()}',
      if (filename.isNotEmpty) 'dn=${Uri.encodeComponent(filename)}',
      for (final tracker in peers.take(6)) 'tr=${Uri.encodeComponent(tracker)}',
    ];
    return 'magnet:?${parts.join('&')}';
  }

  static const List<TorrentCopy> demoCopies = [
    TorrentCopy(
      infoHash: '00000000000000000000000000000000000000a1',
      filename: 'Moonlit.Cinema.2025.1080p.WEB-DL.mp4',
      quality: '1080p',
      size: '2.04 GB',
      seeders: 1284,
      provider: 'Demo',
      magnet:
          'magnet:?xt=urn:btih:00000000000000000000000000000000000000a1'
          '&dn=Moonlit.Cinema.2025.1080p.WEB-DL.mp4',
    ),
    TorrentCopy(
      infoHash: '00000000000000000000000000000000000000a2',
      filename: 'Moonlit.Cinema.2025.720p.WEB-DL.mp4',
      quality: '720p',
      size: '980.12 MB',
      seeders: 412,
      provider: 'Demo',
      magnet:
          'magnet:?xt=urn:btih:00000000000000000000000000000000000000a2'
          '&dn=Moonlit.Cinema.2025.720p.WEB-DL.mp4',
    ),
    TorrentCopy(
      infoHash: '00000000000000000000000000000000000000a3',
      filename: 'Moonlit.Cinema.2025.2160p.HDR.mkv',
      quality: '4K',
      size: '15.80 GB',
      seeders: 96,
      provider: 'Demo',
      magnet:
          'magnet:?xt=urn:btih:00000000000000000000000000000000000000a3'
          '&dn=Moonlit.Cinema.2025.2160p.HDR.mkv',
    ),
  ];

  static String _quality(String name) {
    final label = name.split('\n').skip(1).join(' ').toLowerCase();
    if (label.contains('4k') || label.contains('2160')) return '4K';
    if (label.contains('1080')) return '1080p';
    if (label.contains('720')) return '720p';
    if (label.contains('480')) return '480p';
    for (final rip in const ['remux', 'bluray', 'bdrip', 'webrip', 'web-dl']) {
      if (label.contains(rip)) return rip == 'bluray' ? 'BluRay' : rip;
    }
    return '';
  }

  static int _intAfter(String text, String marker) {
    final match = RegExp('$marker\\s*(\\d+)').firstMatch(text);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }

  static String _valueAfter(String text, String marker) {
    final match = RegExp('$marker\\s*([^\\n]+)').firstMatch(text);
    if (match == null) return '';
    final value = match.group(1)!.trim();
    return value.split('👤').first.split('💾').first.split('⚙️').first.trim();
  }

  static String _filenameFrom(String title, String name) {
    for (final line in title.split('\n')) {
      final trimmed = line.trim();
      if (RegExp(
        r'\.(mkv|mp4|avi|mov|m4v|webm|ts)$',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        return trimmed;
      }
    }
    for (final line in title.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && _intAfter(trimmed, '👤') == 0) return trimmed;
    }
    return name.split('\n').first.trim();
  }

  static List<String> _trackers(dynamic sources) {
    if (sources is! List) return const [];
    final out = <String>[];
    for (final source in sources) {
      final value = source.toString();
      if (!value.startsWith('tracker:')) continue;
      final tracker = value.substring('tracker:'.length).trim();
      if (tracker.startsWith('http') || tracker.startsWith('udp')) {
        out.add(tracker);
      }
    }
    return out;
  }
}
