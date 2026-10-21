import 'dart:convert';

import 'package:everglow/features/anime/data/services/anilist_service.dart';
import 'package:everglow/features/anime/data/services/tmdb_anime_schedule_service.dart';
import 'package:everglow/features/anime/data/services/tmdb_anime_details.dart';
import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _anime(int id) => {
  'id': id,
  'name': 'Demo Anime $id',
  'original_language': 'ja',
  'genre_ids': [16],
  'first_air_date': '2020-01-01',
};

http.Response _page(List<Map<String, dynamic>> rows, {int pages = 1}) =>
    http.Response(jsonEncode({'results': rows, 'total_pages': pages}), 200);

void main() {
  test('TMDB details preserve season slots without inventing MAL IDs', () {
    final item = MediaItem(
      id: '',
      tmdbId: 42,
      title: 'Demo Anime',
      mediaType: 'tv',
      posterPath: '',
      status: '',
      addedAt: DateTime(2026),
    );
    final result = mapTmdbAnimeDetails(item, {
      'name': 'Demo Anime',
      'overview': 'Demo story',
      'seasons': [
        {'season_number': 2, 'episode_count': 2},
        {'season_number': 0, 'episode_count': 20},
        {'season_number': 1, 'episode_count': 3},
      ],
    });
    expect(result.detail.malId, isNull);
    expect(result.detail.id, 0);
    expect(result.detail.episodeCount, 5);
    expect(result.slots[4], (season: 2, episode: 1));
    final history = AnimexHistoryEntry.fromMediaItem(item);
    expect(history.key, 'animex-tmdb-tv-42');
    expect(mediaItemFromHistory(history).source, 'tmdb');
    final saved = AnimexPlaylistItem.fromJson(
      const AnimexPlaylistItem(
        source: 'tmdb',
        malId: 42,
        title: 'Demo',
        coverUrl: '',
      ).toJson(),
    );
    expect(saved.source, 'tmdb');
  });

  test('AniList outage uses independent date-only schedule', () async {
    final dates = <Uri>[];
    final fallback = TmdbAnimeScheduleService(
      get: (url) async {
        dates.add(url);
        return _page([_anime(42)]);
      },
    );
    final entries = await http.runWithClient(
      () => AniListService(
        scheduleFallback: fallback,
      ).fetchAiringSchedule(weekday: 3, now: DateTime(2026, 10, 22)),
      () => MockClient((_) async => http.Response('API disabled', 403)),
    );
    expect(entries.single.media.tmdbId, 42);
    expect(entries.single.media.source, 'tmdb');
    expect(entries.single.episode, isNull);
    expect(entries.single.hasExactTime, isFalse);
    expect(dates.single.queryParameters['air_date.gte'], '2026-10-22');
    expect(dates.single.queryParameters['air_date.lte'], '2026-10-22');
    expect(dates.single.queryParameters['timezone'], 'Asia/Tokyo');
    expect(
      dates.single.queryParameters.containsKey('first_air_date.gte'),
      isFalse,
    );
  });

  test('filters non-anime, deduplicates and bounds pagination', () async {
    var calls = 0;
    final service = TmdbAnimeScheduleService(
      get: (_) async {
        calls++;
        return _page([
          _anime(1),
          _anime(calls + 1),
          {..._anime(90), 'original_language': 'en'},
          {
            ..._anime(91),
            'genre_ids': [18],
          },
        ], pages: 1000);
      },
    );
    final entries = await service.fetchDay(DateTime(2026, 10, 22));
    expect(calls, 4);
    expect(entries.map((entry) => entry.media.tmdbId), [1, 2, 3, 4, 5]);
  });

  test('fallback failure throws instead of reporting an empty day', () async {
    final service = TmdbAnimeScheduleService(
      get: (_) async => http.Response('unavailable', 502),
    );
    await expectLater(
      service.fetchDay(DateTime(2026, 10, 22)),
      throwsStateError,
    );
  });
}
