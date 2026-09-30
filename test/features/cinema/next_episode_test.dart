import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/data/models/next_episode.dart';
import 'package:everglow/features/cinema/data/services/next_episode_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';

/// Fake TMDB facade: [seasons] answers per-season episode lists ([] stands
/// in for a failed fetch, which the real service also reports as []).
class _FakeTmdb implements TMDBService {
  _FakeTmdb({required this.seasons, required this.show});
  final Map<int, List<Map<String, dynamic>>> seasons;
  final Map<String, dynamic>? show;

  @override
  Future<List<dynamic>> fetchSeasonEpisodes(int tvId, int seasonNumber) async =>
      seasons[seasonNumber] ?? [];

  @override
  Future<Map<String, dynamic>?> fetchTVShowDetails(int tvId) async => show;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('nextInSeason', () {
    test('returns the episode after the current one with details', () {
      final next = nextInSeason(
        season: 1,
        currentEpisode: 2,
        episodes: [
          {'episode_number': 1, 'name': 'Pilot'},
          {
            'episode_number': 2,
            'name': 'The Middle',
            'overview': 'mid',
            'still_path': '/mid.jpg',
          },
          {
            'episode_number': 3,
            'name': 'The End',
            'overview': 'end',
            'still_path': '/end.jpg',
          },
        ],
      );

      expect(next, isNotNull);
      expect(next!.season, 1);
      expect(next.episode, 3);
      expect(next.name, 'The End');
      expect(next.label, 'S1 E3');
    });

    test('returns null on the season finale', () {
      final next = nextInSeason(
        season: 1,
        currentEpisode: 10,
        episodes: [
          {'episode_number': 9, 'name': 'Penultimate'},
          {'episode_number': 10, 'name': 'Finale'},
        ],
      );

      expect(next, isNull);
    });

    test('ignores entries without an episode number', () {
      final next = nextInSeason(
        season: 2,
        currentEpisode: 1,
        episodes: [
          {'episode_number': 1, 'name': 'One'},
          {'name': 'Broken'},
          'not-a-map',
          {'episode_number': 2, 'name': 'Two'},
        ],
      );

      expect(next!.episode, 2);
      expect(next.name, 'Two');
    });
  });

  group('nextSeasonNumber', () {
    test('returns the next season in order', () {
      expect(
        nextSeasonNumber(currentSeason: 1, seasonNumbers: [3, 1, 2]),
        2,
      );
    });

    test('returns null on the last season', () {
      expect(
        nextSeasonNumber(currentSeason: 3, seasonNumbers: [1, 2, 3]),
        isNull,
      );
    });

    test('ignores season 0 specials', () {
      expect(
        nextSeasonNumber(currentSeason: 1, seasonNumbers: [0, 1, 2]),
        2,
      );
    });
  });

  group('firstInSeason', () {
    test('picks the lowest episode number with details', () {
      final first = firstInSeason(
        season: 2,
        episodes: [
          {'episode_number': 2, 'name': 'Second'},
          {'episode_number': 1, 'name': 'Premiere', 'overview': 'hi'},
        ],
      );

      expect(first, isNotNull);
      expect(first!.season, 2);
      expect(first.episode, 1);
      expect(first.name, 'Premiere');
    });

    test('returns null for an empty season', () {
      expect(firstInSeason(season: 2, episodes: []), isNull);
    });
  });

  group('unaired episodes', () {
    test('nextInSeason never offers an episode dated in the future', () {
      expect(
        nextInSeason(season: 1, currentEpisode: 1, episodes: [
          {'episode_number': 1, 'name': 'Released', 'air_date': '2020-01-01'},
          {'episode_number': 2, 'name': 'Not released', 'air_date': '2099-01-01'},
        ]),
        isNull,
      );
    });

    test('nextInSeason still offers episodes with no air date', () {
      final next = nextInSeason(season: 1, currentEpisode: 1, episodes: [
        {'episode_number': 1, 'name': 'One'},
        {'episode_number': 2, 'name': 'Two'},
      ]);
      expect(next?.episode, 2);
    });

    test('firstInSeason returns null when the premiere is unaired', () {
      expect(
        firstInSeason(season: 2, episodes: [
          {'episode_number': 1, 'name': 'Future premiere', 'air_date': '2099-01-01'},
          {'episode_number': 2, 'name': 'Later', 'air_date': '2020-01-01'},
        ]),
        isNull,
      );
    });
  });

  group('NextEpisodeService.resolve', () {
    Map<String, dynamic> show() => {
      'seasons': [
        {'season_number': 1},
        {'season_number': 2},
      ],
    };

    test('a failed season fetch is not treated as the finale', () async {
      final service = NextEpisodeService(
        tmdb: _FakeTmdb(
          seasons: {
            1: [],
            2: [
              {'episode_number': 1, 'name': 'Season 2 premiere'},
            ],
          },
          show: show(),
        ),
      );
      expect(
        await service.resolve(tmdbId: 42, season: 1, episode: 2),
        isNull,
      );
    });

    test('a real finale still crosses into the next season', () async {
      final service = NextEpisodeService(
        tmdb: _FakeTmdb(
          seasons: {
            1: [
              {'episode_number': 2, 'name': 'Finale'},
            ],
            2: [
              {'episode_number': 1, 'name': 'Premiere'},
            ],
          },
          show: show(),
        ),
      );
      final next = await service.resolve(tmdbId: 42, season: 1, episode: 2);
      expect(next?.season, 2);
      expect(next?.episode, 1);
    });
  });
}
