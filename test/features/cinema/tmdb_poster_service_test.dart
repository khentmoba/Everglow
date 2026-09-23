import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_details_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_poster_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_search_service.dart';

class _TestDetailsService extends TMDBDetailsService {
  _TestDetailsService(this.handler);
  final Future<http.Response> Function(Uri url) handler;

  @override
  Future<http.Response> tmdbGet(Uri url) => handler(url);
}

class _TestSearchService extends TMDBSearchService {
  _TestSearchService(this.handler);
  final Future<http.Response> Function(Uri url) handler;

  @override
  Future<http.Response> tmdbGet(Uri url) => handler(url);
}

void main() {
  group('TMDBPosterService.healPoster', () {
    test(
      'heals "Yellow Jacket Televison" (0-poster TMDB movie 1714066) to "Yellowjackets" TV show',
      () async {
        final detailsService = _TestDetailsService((url) async {
          // Details lookup for 1714066: returns student movie with NO poster
          if (url.path.contains('/movie/1714066') ||
              url.path.contains('/tv/1714066')) {
            return http.Response(
              jsonEncode({
                'id': 1714066,
                'title': 'Yellow Jacket Televison',
                'poster_path': null,
                'backdrop_path': null,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });

        final searchService = _TestSearchService((url) async {
          final query = url.queryParameters['query'] ?? '';
          if (query == 'yellowjackets') {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 117488,
                    'name': 'Yellowjackets',
                    'media_type': 'tv',
                    'poster_path': '/xRnGrn7Z7SC0KIBodocoU1QgDZF.jpg',
                    'backdrop_path': '/ibFWJDWS8cTO6s2vZVd2uKDm8p.jpg',
                    'first_air_date': '2021-11-14',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          // The raw query "Yellow Jacket Televison" only returns the 0-poster movie
          if (query == 'Yellow Jacket Televison') {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 1714066,
                    'title': 'Yellow Jacket Televison',
                    'media_type': 'movie',
                    'poster_path': null,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'results': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final posterService = TMDBPosterService(detailsService, searchService);

        final unhealed = MediaItem(
          id: '', // Empty id skips Firestore call
          tmdbId: 1714066,
          title: 'Yellow Jacket Televison',
          mediaType: 'movie',
          posterPath: '',
          status: 'watching',
          addedAt: DateTime.now(),
        );

        final healed = await posterService.healPoster(unhealed);

        expect(healed, isNotNull);
        expect(healed!.tmdbId, 117488);
        expect(healed.mediaType, 'tv');
        expect(healed.title, 'Yellowjackets');
        expect(
          healed.posterPath,
          'https://image.tmdb.org/t/p/w500/xRnGrn7Z7SC0KIBodocoU1QgDZF.jpg',
        );
      },
    );

    test('heals by details when valid tmdbId has a poster', () async {
      final detailsService = _TestDetailsService((url) async {
        if (url.path.contains('/movie/550')) {
          return http.Response(
            jsonEncode({
              'id': 550,
              'title': 'Fight Club',
              'poster_path': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final searchService = _TestSearchService((url) async {
        return http.Response(jsonEncode({'results': []}), 200);
      });

      final posterService = TMDBPosterService(detailsService, searchService);

      final item = MediaItem(
        id: '',
        tmdbId: 550,
        title: 'Fight Club',
        mediaType: 'movie',
        posterPath: '',
        status: 'watched',
        addedAt: DateTime.now(),
      );

      final healed = await posterService.healPoster(item);
      expect(healed, isNotNull);
      expect(healed!.tmdbId, 550);
      expect(
        healed.posterPath,
        'https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
      );
    });

    test(
      'heals by details and corrects title when stored title had generic suffix',
      () async {
        final detailsService = _TestDetailsService((url) async {
          if (url.path.contains('/tv/117488')) {
            return http.Response(
              jsonEncode({
                'id': 117488,
                'name': 'Yellowjackets',
                'poster_path': '/9E2y5Q7WlCVTCxOXNYSoN4UMG8g.jpg',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });

        final posterService = TMDBPosterService(
          detailsService,
          _TestSearchService((_) async => http.Response('{}', 200)),
        );

        final item = MediaItem(
          id: '',
          tmdbId: 117488,
          title: 'Yellow Jacket Televison',
          mediaType: 'tv',
          posterPath: '',
          status: 'watching',
          addedAt: DateTime.now(),
        );

        final healed = await posterService.healPoster(item);
        expect(healed, isNotNull);
        expect(healed!.title, 'Yellowjackets');
        expect(healed.mediaType, 'tv');
        expect(healed.posterPath, contains('/9E2y5Q7WlCVTCxOXNYSoN4UMG8g.jpg'));
      },
    );

    test('returns null when no artwork is found anywhere', () async {
      final detailsService = _TestDetailsService((url) async {
        return http.Response(
          jsonEncode({'id': 999999, 'title': 'Unknown', 'poster_path': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final searchService = _TestSearchService((url) async {
        return http.Response(
          jsonEncode({'results': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final posterService = TMDBPosterService(detailsService, searchService);
      final item = MediaItem(
        id: '',
        tmdbId: 999999,
        title: 'Completely Fake Show 12345',
        mediaType: 'movie',
        posterPath: '',
        status: '',
        addedAt: DateTime.now(),
      );

      final healed = await posterService.healPoster(item);
      expect(healed, isNull);
    });
  });

  group('TMDBPosterService.backfillMissingPosters', () {
    test(
      'skips items with usable posters and heals items with blank posters',
      () async {
        final detailsService = _TestDetailsService((url) async {
          if (url.path.contains('/movie/550')) {
            return http.Response(
              jsonEncode({
                'id': 550,
                'title': 'Fight Club',
                'poster_path': '/fightclub.jpg',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });

        final posterService = TMDBPosterService(
          detailsService,
          _TestSearchService((_) async => http.Response('{}', 200)),
        );

        final items = [
          MediaItem(
            id: '',
            tmdbId: 100,
            title: 'Already Has Poster',
            mediaType: 'movie',
            posterPath: 'https://image.tmdb.org/t/p/w500/already.jpg',
            status: 'watched',
            addedAt: DateTime.now(),
          ),
          MediaItem(
            id: '',
            tmdbId: 550,
            title: 'Fight Club',
            mediaType: 'movie',
            posterPath: '',
            status: 'watching',
            addedAt: DateTime.now(),
          ),
        ];

        final backfilled = await posterService.backfillMissingPosters(items);
        expect(
          backfilled[0].posterPath,
          'https://image.tmdb.org/t/p/w500/already.jpg',
        );
        expect(
          backfilled[1].posterPath,
          'https://image.tmdb.org/t/p/w500/fightclub.jpg',
        );
      },
    );
  });
}
