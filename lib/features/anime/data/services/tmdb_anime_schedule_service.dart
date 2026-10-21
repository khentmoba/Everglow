import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/utils/logger.dart';
import '../../../cinema/data/services/tmdb/tmdb_base.dart';
import '../models/animex_models.dart';

class TmdbAnimeScheduleService with TMDBBase {
  TmdbAnimeScheduleService({Future<http.Response> Function(Uri)? get})
    : _get = get;

  final Future<http.Response> Function(Uri)? _get;

  Future<List<AnimexScheduleEntry>> fetchDay(DateTime day) async {
    final date =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final entries = <AnimexScheduleEntry>[];
    final seen = <int>{};
    try {
      for (var page = 1; page <= 4; page++) {
        final url = Uri.parse('$tmdbBaseUrl/discover/tv').replace(
          queryParameters: {
            'with_genres': '16',
            'with_original_language': 'ja',
            'include_adult': 'false',
            'air_date.gte': date,
            'air_date.lte': date,
            'timezone': 'Asia/Tokyo',
            'sort_by': 'popularity.desc',
            'page': '$page',
          },
        );
        final response = await (_get ?? tmdbGet)(url);
        if (response.statusCode != 200) {
          throw StateError('TMDB anime schedule HTTP ${response.statusCode}');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rows = body['results'];
        if (rows is! List) {
          throw StateError('TMDB anime schedule missing results');
        }
        for (final row in rows.take(50).whereType<Map<String, dynamic>>()) {
          final id = (row['id'] as num?)?.toInt() ?? 0;
          if (id <= 0 || !detectAnime(row) || !seen.add(id)) continue;
          entries.add(
            AnimexScheduleEntry(
              media: mapResultToMediaItem(row, forcedMediaType: 'tv'),
              episode: null,
              airingAt: DateTime(day.year, day.month, day.day),
              hasExactTime: false,
            ),
          );
        }
        final totalPages = (body['total_pages'] as num?)?.toInt() ?? page;
        if (rows.isEmpty || page >= totalPages) break;
      }
      return entries;
    } catch (error, stack) {
      Logger.e('TMDB anime schedule failed', error: error, stackTrace: stack);
      throw StateError('Anime airing schedule unavailable');
    }
  }
}
