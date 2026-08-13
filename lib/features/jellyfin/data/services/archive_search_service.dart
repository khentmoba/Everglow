import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/utils/logger.dart';
import '../models/archive_movie.dart';
import '../models/archive_video_file.dart';

/// Search client for the Internet Archive open-media catalog.
///
/// The advancedsearch API returns item metadata (identifier, title, year)
/// and the metadata API returns the files available inside each item.
/// We only surface playable video containers so the download screen can
/// offer real files instead of torrents, thumbnails, or XML metadata.
class ArchiveSearchService {
  static const String _searchBase = 'https://archive.org/advancedsearch.php';
  static const String _metadataBase = 'https://archive.org/metadata';

  Future<List<ArchiveMovie>> search(String query) async {
    final safeQuery = query.trim().replaceAll('"', '');
    if (safeQuery.isEmpty) return const [];

    final params =
        'q=${Uri.encodeComponent('title:($safeQuery) AND mediatype:movies')}'
        '&fl[]=identifier&fl[]=title&fl[]=year&fl[]=description'
        '&rows=24&page=1&output=json';
    final uri = Uri.parse('$_searchBase?$params');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        Logger.e('Archive search failed (${response.statusCode})');
        return const [];
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final docs = ((body['response'] as Map<String, dynamic>?)?['docs'])
              as List<dynamic>? ??
          const [];
      return docs
          .whereType<Map<String, dynamic>>()
          .map(ArchiveMovie.fromJson)
          .where((m) => m.identifier.isNotEmpty && m.title.isNotEmpty)
          .toList();
    } catch (e) {
      Logger.e('Archive search error', error: e);
      return const [];
    }
  }

  Future<List<ArchiveVideoFile>> filesFor(String identifier) async {
    final uri = Uri.parse('$_metadataBase/$identifier');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        Logger.e('Archive metadata failed (${response.statusCode})');
        return const [];
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final files = body['files'] as List<dynamic>? ?? const [];
      final candidates = files
          .whereType<Map<String, dynamic>>()
          .map((raw) {
            final name = raw['name'] as String? ?? '';
            return ArchiveVideoFile(
              identifier: identifier,
              name: name,
              format: raw['format'] as String? ?? '',
              sizeBytes: int.tryParse(raw['size']?.toString() ?? '') ?? 0,
              lengthSeconds: double.tryParse(raw['length']?.toString() ?? ''),
              width: int.tryParse(raw['width']?.toString() ?? ''),
              height: int.tryParse(raw['height']?.toString() ?? ''),
            );
          })
          .where((f) => f.isPlayableContainer && f.sizeBytes > 0)
          .toList();

      candidates.sort((a, b) {
        final aIsMp4 = a.extension == 'mp4' ? 0 : 1;
        final bIsMp4 = b.extension == 'mp4' ? 0 : 1;
        if (aIsMp4 != bIsMp4) return aIsMp4 - bIsMp4;
        return a.sizeBytes.compareTo(b.sizeBytes);
      });
      return candidates;
    } catch (e) {
      Logger.e('Archive metadata error', error: e);
      return const [];
    }
  }
}
