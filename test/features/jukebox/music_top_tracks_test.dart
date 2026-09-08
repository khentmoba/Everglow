import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(jsonEncode(body), status, headers: _jsonHeaders);
}

MusicSyncService _service(Future<http.Response> Function() respond) {
  return MusicSyncService(
    client: MockClient((_) => respond()),
    signUrl: (url) async => url.replace(
      queryParameters: {...url.queryParameters, '__auth': 'test-token'},
    ),
  );
}

Map<String, dynamic> _topTrackEntry({String rank = '1'}) => {
  'name': 'Only Song',
  'playcount': '42',
  'artist': {'name': 'Solo Artist'},
  'mbid': '',
  'image': [
    {'#text': '', 'size': 'small'},
    {'#text': '', 'size': 'extralarge'},
  ],
  '@attr': {'rank': rank},
};

Map<String, dynamic> _recentEntry() => {
  'artist': {'#text': 'Solo Artist'},
  'name': 'Only Song',
  'album': {'#text': 'Only Album'},
  'image': [
    {'#text': '', 'size': 'small'},
    {'#text': '', 'size': 'extralarge'},
  ],
  'date': {'uts': '1700000000'},
};

void main() {
  setUp(MusicSyncService.resetInvalidUsers);

  group('MusicSyncService single-object responses', () {
    test('fetchTopTracks parses a lone track object', () async {
      final service = _service(
        () async => _jsonResponse({
          'toptracks': {'track': _topTrackEntry()},
        }),
      );
      final tracks = await service.fetchTopTracks('khentsgdz');
      expect(tracks, hasLength(1));
      expect(tracks.first.trackName, 'Only Song');
      expect(tracks.first.rank, 1);
      expect(tracks.first.playCount, 42);
    });

    test('fetchRecentTracks parses a lone scrobble object', () async {
      final service = _service(
        () async => _jsonResponse({
          'recenttracks': {'track': _recentEntry()},
        }),
      );
      final tracks = await service.fetchRecentTracks('khentsgdz');
      expect(tracks, hasLength(1));
      expect(tracks.first.trackName, 'Only Song');
    });
  });

  group('MusicSyncService Last.fm error payloads', () {
    test('fetchTopTracks returns empty on an HTTP-200 error payload', () async {
      final service = _service(
        () async => _jsonResponse({
          'error': 29,
          'message': 'Rate limit exceeded - too many requests',
        }),
      );
      expect(await service.fetchTopTracks('khentsgdz'), isEmpty);
    });

    test('fetchRecentTracks returns empty on an HTTP-200 error payload', () async {
      final service = _service(
        () async => _jsonResponse({
          'error': 16,
          'message': 'There was a temporary error processing your request',
        }),
      );
      expect(await service.fetchRecentTracks('khentsgdz'), isEmpty);
    });

    test('fetchTopTracks marks the user invalid only on 404', () async {
      final notFound = _service(
        () async => _jsonResponse({
          'error': 6,
          'message': 'User not found',
        }, status: 404),
      );
      expect(await notFound.fetchTopTracks('ghost-user-xyz'), isEmpty);
      expect(notFound.isUserInvalid('ghost-user-xyz'), isTrue);

      final rateLimited = _service(
        () async => _jsonResponse({'error': 29, 'message': 'slow down'}),
      );
      expect(await rateLimited.fetchTopTracks('khentsgdz'), isEmpty);
      expect(rateLimited.isUserInvalid('khentsgdz'), isFalse);
    });
  });
}
