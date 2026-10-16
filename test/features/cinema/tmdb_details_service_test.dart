import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:everglow/features/cinema/data/services/tmdb/tmdb_details_service.dart';

class _TestTMDBDetailsService extends TMDBDetailsService {
  _TestTMDBDetailsService(this.handler);
  final Future<http.Response> Function(Uri url) handler;

  @override
  Future<http.Response> tmdbGet(Uri url) => handler(url);
}

void main() {
  group('TMDBDetailsService.fetchMediaDetails', () {
    setUp(TMDBDetailsService.resetDetailsCacheForTests);

    test('concurrent and repeat callers share successful details', () async {
      var calls = 0;
      final response = Completer<http.Response>();
      final service = _TestTMDBDetailsService((url) {
        calls++;
        return response.future;
      });
      final first = service.fetchMediaDetails(123, 'movie');
      final second = service.fetchMediaDetails(123, 'movie');
      response.complete(http.Response('{"id":123}', 200));
      expect(await first, await second);
      expect((await service.fetchMediaDetails(123, 'movie'))?['id'], 123);
      expect(calls, 1);
    });

    test(
      'successful details cache evicts old titles after 80 entries',
      () async {
        var calls = 0;
        final service = _TestTMDBDetailsService((url) async {
          calls++;
          return http.Response('{"id":123}', 200);
        });
        for (var id = 0; id < 81; id++) {
          await service.fetchMediaDetails(id, 'movie');
        }
        await service.fetchMediaDetails(80, 'movie');
        expect(calls, 81);
        await service.fetchMediaDetails(0, 'movie');
        expect(calls, 82);
      },
    );

    test('returns details directly when primary mediaType succeeds', () async {
      final requestedUrls = <Uri>[];
      final service = _TestTMDBDetailsService((url) async {
        requestedUrls.add(url);
        return http.Response(
          jsonEncode({'id': 123, 'title': 'Some Movie'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final details = await service.fetchMediaDetails(123, 'movie');
      expect(details, isNotNull);
      expect(details?['id'], 123);
      expect(details?['title'], 'Some Movie');
      expect(requestedUrls, hasLength(1));
      expect(requestedUrls.first.path, contains('/movie/123'));
    });

    test(
      'falls back to alternate mediaType when primary mediaType returns 404',
      () async {
        final requestedUrls = <Uri>[];
        final service = _TestTMDBDetailsService((url) async {
          requestedUrls.add(url);
          if (url.path.contains('/tv/1714066')) {
            return http.Response(
              '{"status_code": 34, "status_message": "Not found"}',
              404,
            );
          }
          if (url.path.contains('/movie/1714066')) {
            return http.Response(
              jsonEncode({'id': 1714066, 'title': 'Yellow Jacket Televison'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });

        // Item mis-tagged as 'tv' instead of 'movie'
        final details = await service.fetchMediaDetails(1714066, 'tv');
        expect(details, isNotNull);
        expect(details?['id'], 1714066);
        expect(details?['title'], 'Yellow Jacket Televison');
        expect(requestedUrls, hasLength(2));
        expect(requestedUrls[0].path, contains('/tv/1714066'));
        expect(requestedUrls[1].path, contains('/movie/1714066'));
      },
    );

    test(
      'returns null when both primary and alternate mediaType return 404',
      () async {
        final requestedUrls = <Uri>[];
        final service = _TestTMDBDetailsService((url) async {
          requestedUrls.add(url);
          return http.Response(
            '{"status_code": 34, "status_message": "Not found"}',
            404,
          );
        });

        final details = await service.fetchMediaDetails(999999, 'tv');
        expect(details, isNull);
        expect(requestedUrls, hasLength(2));
        expect(requestedUrls[0].path, contains('/tv/999999'));
        expect(requestedUrls[1].path, contains('/movie/999999'));
      },
    );

    test(
      'remembers the corrected mediaType so repeat opens skip the 404 probe',
      () async {
        final requestedUrls = <Uri>[];
        final service = _TestTMDBDetailsService((url) async {
          requestedUrls.add(url);
          if (url.path.contains('/tv/1714066')) {
            return http.Response(
              '{"status_code": 34, "status_message": "Not found"}',
              404,
            );
          }
          return http.Response(
            jsonEncode({'id': 1714066, 'title': 'Yellow Jacket Televison'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final first = await service.fetchMediaDetails(1714066, 'tv');
        expect(first?['title'], 'Yellow Jacket Televison');
        expect(requestedUrls, hasLength(2));

        requestedUrls.clear();
        final second = await service.fetchMediaDetails(1714066, 'tv');
        expect(second?['title'], 'Yellow Jacket Televison');
        expect(requestedUrls, isEmpty);
      },
    );

    test('does not re-request ids that 404 on both mediaTypes', () async {
      var calls = 0;
      final service = _TestTMDBDetailsService((url) async {
        calls++;
        return http.Response(
          '{"status_code": 34, "status_message": "Not found"}',
          404,
        );
      });

      expect(await service.fetchMediaDetails(999999, 'tv'), isNull);
      expect(calls, 2);
      expect(await service.fetchMediaDetails(999999, 'tv'), isNull);
      expect(calls, 2);
    });

    test(
      'transient errors stay retryable and are not cached as dead',
      () async {
        var calls = 0;
        final service = _TestTMDBDetailsService((url) async {
          calls++;
          if (calls == 1) return http.Response('Bad gateway', 502);
          return http.Response(
            jsonEncode({'id': 123, 'title': 'Some Movie'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(await service.fetchMediaDetails(123, 'movie'), isNull);
        final retry = await service.fetchMediaDetails(123, 'movie');
        expect(retry?['title'], 'Some Movie');
        expect(calls, 2);
      },
    );
  });
}
