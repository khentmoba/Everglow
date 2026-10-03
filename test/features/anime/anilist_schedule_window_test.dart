import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/data/services/anilist_service.dart';

int _seconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _body(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

http.Response _page(
  List<Map<String, dynamic>> entries, {
  bool hasNextPage = false,
}) => http.Response(
  jsonEncode({
    'data': {
      'Page': {
        'pageInfo': {'hasNextPage': hasNextPage},
        'airingSchedules': entries,
      },
    },
  }),
  200,
);

Map<String, dynamic> _entry(int id, DateTime at) => {
  'id': id,
  'airingAt': _seconds(at),
  'episode': 4,
  'media': {
    'id': id,
    'idMal': id + 1000,
    'title': {'english': 'Anime $id'},
    'format': 'TV',
  },
};

Future<List<AnimexScheduleEntry>> _fetch(
  DateTime now,
  Future<http.Response> Function(http.Request) respond, {
  int weekday = 0,
  int perPage = 50,
}) => http.runWithClient(
  () => AniListService().fetchAiringSchedule(
    weekday: weekday,
    perPage: perPage,
    now: now,
  ),
  () => MockClient(respond),
);

void main() {
  final now = DateTime(2026, 8, 19, 14); // Wednesday, device-local time.

  group('current local Monday–Sunday week', () {
    final cases = <(String, DateTime, int, DateTime)>[
      ('today', now, 2, DateTime(2026, 8, 19)),
      ('future Friday', now, 4, DateTime(2026, 8, 21)),
      ('past Monday', now, 0, DateTime(2026, 8, 17)),
      (
        'Sunday still uses this week’s Monday',
        DateTime(2026, 8, 23, 23, 59),
        0,
        DateTime(2026, 8, 17),
      ),
      (
        'Monday selects the upcoming Sunday, not yesterday',
        DateTime(2026, 8, 17),
        6,
        DateTime(2026, 8, 23),
      ),
      (
        'next Monday starts a new week',
        DateTime(2026, 8, 24),
        0,
        DateTime(2026, 8, 24),
      ),
      (
        'year-crossing Monday',
        DateTime(2027, 1, 1, 12),
        0,
        DateTime(2026, 12, 28),
      ),
      (
        'year-crossing Sunday',
        DateTime(2027, 1, 1, 12),
        6,
        DateTime(2027, 1, 3),
      ),
      (
        'UTC clock is converted to local before selecting the week',
        DateTime(2026, 8, 17, 1).toUtc(),
        0,
        DateTime(2026, 8, 17),
      ),
      (
        'spring clock-change Sunday uses calendar midnights',
        DateTime(2026, 3, 8, 12),
        6,
        DateTime(2026, 3, 8),
      ),
      (
        'autumn clock-change Sunday uses calendar midnights',
        DateTime(2026, 11, 1, 12),
        6,
        DateTime(2026, 11, 1),
      ),
    ];

    for (final (name, clock, weekday, start) in cases) {
      test(name, () async {
        final requests = <Map<String, dynamic>>[];
        final entries = await _fetch(clock, (request) async {
          requests.add(_body(request));
          return _page([]);
        }, weekday: weekday);

        expect(entries, isEmpty);
        expect(requests, hasLength(1));
        final variables = requests.single['variables'] as Map<String, dynamic>;
        final end = DateTime(start.year, start.month, start.day + 1);
        // AniList's greater/lesser filters are strict: include start midnight,
        // exclude the following midnight. Do not assume a day lasts 24 hours.
        expect(variables['airingAtGreater'], _seconds(start) - 1);
        expect(variables['airingAtLesser'], _seconds(end));
      });
    }
  });

  test('query includes past and future airings without a filter', () async {
    late Map<String, dynamic> requestBody;
    await _fetch(now, (request) async {
      requestBody = _body(request);
      return _page([]);
    });

    final query = requestBody['query'] as String;
    expect(query, isNot(contains('notYetAired')));
    expect(query, contains(r'$page: Int'));
    expect(query, contains(r'Page(page: $page, perPage: $perPage)'));
    expect(query, contains('sort: TIME'));
    expect(query, contains('hasNextPage'));
  });

  test('returns both aired and upcoming entries only inside the day', () async {
    final start = DateTime(2026, 8, 19);
    final end = DateTime(2026, 8, 20);
    final entries = await _fetch(now, (_) async {
      return _page([
        _entry(1, start.subtract(const Duration(seconds: 1))),
        _entry(2, start),
        _entry(3, DateTime(2026, 8, 19, 10)),
        _entry(4, DateTime(2026, 8, 19, 19)),
        _entry(5, end.subtract(const Duration(seconds: 1))),
        _entry(6, end),
        _entry(7, DateTime(2026, 8, 26, 10)), // Same weekday, different week.
      ]);
    }, weekday: 2);

    expect(entries.map((entry) => entry.media.anilistId), [2, 3, 4, 5]);
    expect(entries.first.airingAt, start);
    expect(entries.first.airingAt.isUtc, isFalse);
    expect(entries[1].airingAt.isBefore(now), isTrue);
    expect(entries[2].airingAt.isAfter(now), isTrue);
    expect(entries[2].episode, 4);
    expect(entries[2].media.tmdbId, 1004);
  });

  group('bounded pagination', () {
    test('follows hasNextPage then stops at the last page', () async {
      final requests = <Map<String, dynamic>>[];
      final entries = await _fetch(
        now,
        (request) async {
          final variables = _body(request)['variables'] as Map<String, dynamic>;
          requests.add(variables);
          final page = variables['page'] as int;
          return _page([
            _entry(page, DateTime(2026, 8, 19, page + 8)),
          ], hasNextPage: page == 1);
        },
        weekday: 2,
        perPage: 1,
      );

      expect(requests.map((request) => request['page']), [1, 2]);
      expect(entries.map((entry) => entry.media.anilistId), [1, 2]);
      expect(requests.map((request) => request['perPage']), [1, 1]);
      expect(requests.map((request) => request['airingAtGreater']).toSet(), {
        _seconds(DateTime(2026, 8, 19)) - 1,
      });
      expect(requests.map((request) => request['airingAtLesser']).toSet(), {
        _seconds(DateTime(2026, 8, 20)),
      });
    });

    test('hasNextPage forever is capped at four pages / 200 entries', () async {
      final pages = <int>[];
      final entries = await _fetch(
        now,
        (request) async {
          final variables = _body(request)['variables'] as Map<String, dynamic>;
          final page = variables['page'] as int;
          pages.add(page);
          return _page(
            List.generate(
              50,
              (index) => _entry((page - 1) * 50 + index + 1, now),
            ),
            hasNextPage: true,
          );
        },
        weekday: 2,
        perPage: 100,
      );

      expect(pages, [1, 2, 3, 4]);
      expect(entries, hasLength(200));
      expect(entries.last.media.anilistId, 200);
    });

    test('an empty page stops even if hasNextPage is true', () async {
      var calls = 0;
      final entries = await _fetch(now, (_) async {
        calls++;
        return _page([], hasNextPage: true);
      });
      expect(entries, isEmpty);
      expect(calls, 1);
    });

    for (final (perPage, expected) in [(100, 50), (51, 50), (0, 1), (-5, 1)]) {
      test('perPage $perPage is clamped to $expected', () async {
        late Map<String, dynamic> variables;
        await _fetch(now, (request) async {
          variables = _body(request)['variables'] as Map<String, dynamic>;
          return _page([]);
        }, perPage: perPage);
        expect(variables['perPage'], expected);
      });
    }

    test('even an oversized response cannot exceed the daily cap', () async {
      var calls = 0;
      final entries = await _fetch(now, (_) async {
        calls++;
        return _page(
          List.generate(75, (index) => _entry(calls * 100 + index, now)),
          hasNextPage: true,
        );
      }, weekday: 2);
      expect(calls, 4);
      expect(entries, hasLength(200));
    });
  });

  group('failures reach the existing retry UI', () {
    final responses = <(String, http.Response)>[
      ('HTTP failure', http.Response('unavailable', 503)),
      (
        'GraphQL errors, even with partial data',
        http.Response(
          jsonEncode({
            'errors': [
              {'message': 'API disabled'},
            ],
            'data': {
              'Page': {'airingSchedules': []},
            },
          }),
          200,
        ),
      ),
      ('null data', http.Response('{"data":null}', 200)),
      ('missing Page', http.Response('{"data":{}}', 200)),
      ('missing schedule', http.Response('{"data":{"Page":{}}}', 200)),
      ('invalid JSON', http.Response('not JSON', 200)),
    ];

    for (final (name, response) in responses) {
      test('$name throws instead of returning []', () async {
        await expectLater(_fetch(now, (_) async => response), throwsStateError);
      });
    }

    for (final error in [
      http.ClientException('offline'),
      TimeoutException('request timed out'),
    ]) {
      test('$error throws instead of returning []', () async {
        await expectLater(
          _fetch(now, (_) async => throw error),
          throwsStateError,
        );
      });
    }

    test('a later page failure does not return partial success', () async {
      var calls = 0;
      await expectLater(
        _fetch(now, (_) async {
          calls++;
          if (calls == 2) return http.Response('unavailable', 503);
          return _page([_entry(1, now)], hasNextPage: true);
        }, weekday: 2),
        throwsStateError,
      );
      expect(calls, 2);
    });
  });

  for (final weekday in [-1, 7]) {
    test('rejects weekday $weekday without requesting data', () async {
      var calls = 0;
      await expectLater(
        _fetch(now, (_) async {
          calls++;
          return _page([]);
        }, weekday: weekday),
        throwsRangeError,
      );
      expect(calls, 0);
    });
  }
}
