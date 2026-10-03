import 'dart:convert';

import 'package:everglow/features/cinema/data/services/tmdb/tmdb_discovery_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb/tmdb_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Search extends TMDBSearchService {
  final http.Response response;
  Uri? requested;
  _Search(this.response);

  @override
  Future<http.Response> tmdbGet(Uri url) async {
    requested = url;
    return response;
  }
}

class _Discovery extends TMDBDiscoveryService {
  final http.Response response;
  Uri? requested;
  _Discovery(this.response);

  @override
  Future<http.Response> tmdbGet(Uri url) async {
    requested = url;
    return response;
  }
}

void main() {
  for (final response in [
    http.Response('offline', 503),
    http.Response('bad json', 200),
  ]) {
    test(
      'search keeps fallback empty-on-error and offers opt-in errors (${response.statusCode})',
      () async {
        final search = _Search(response);
        expect(await search.searchMedia('demo'), isEmpty);
        await expectLater(
          search.searchMedia('demo', failOnError: true),
          throwsA(isA<Exception>()),
        );
      },
    );
    test(
      'discovery keeps fallback empty-on-error and offers opt-in errors (${response.statusCode})',
      () async {
        final discovery = _Discovery(response);
        expect(await discovery.discoverMedia(mediaType: 'movie'), isEmpty);
        await expectLater(
          discovery.discoverMedia(mediaType: 'movie', failOnError: true),
          throwsA(isA<Exception>()),
        );
      },
    );
  }

  test(
    'multi-search forwards page, escapes titles, and excludes people',
    () async {
      final search = _Search(
        http.Response(
          jsonEncode({
            'results': [
              {'id': 1, 'media_type': 'movie', 'title': 'Demo film'},
              {'id': 2, 'media_type': 'tv', 'name': 'Demo series'},
              {'id': 3, 'media_type': 'person', 'name': 'Demo actor'},
            ],
          }),
          200,
        ),
      );
      final results = await search.searchMedia(
        'a & b',
        page: 2,
        failOnError: true,
      );
      expect(search.requested!.queryParameters, {
        'query': 'a & b',
        'page': '2',
      });
      expect(results.map((m) => m.mediaType), ['movie', 'tv']);
    },
  );

  test('discover forwards genre and page together', () async {
    final discovery = _Discovery(http.Response('{"results":[]}', 200));
    expect(
      await discovery.discoverMedia(
        mediaType: 'movie',
        withGenres: [28],
        page: 2,
        failOnError: true,
      ),
      isEmpty,
    );
    expect(discovery.requested!.path, endsWith('/discover/movie'));
    expect(discovery.requested!.queryParameters['with_genres'], '28');
    expect(discovery.requested!.queryParameters['page'], '2');
  });
}
