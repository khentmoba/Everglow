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

Map<String, dynamic> _artistTrackEntry({
  required String name,
  required String playcount,
  String rank = '1',
}) => {
  'name': name,
  'playcount': playcount,
  // The artist node shape varies for this method — the service must not
  // depend on it (it forces the queried artist onto each result).
  'artist': {'#text': 'Ethel Cain'},
  'mbid': '',
  'image': [
    {'#text': '', 'size': 'small'},
    {'#text': 'https://lastfm.example/cover.png', 'size': 'extralarge'},
  ],
  '@attr': {'rank': rank},
};

void main() {
  setUp(MusicSyncService.resetInvalidUsers);

  group('MusicSyncService.fetchArtistTracks', () {
    test('parses the artisttracks node with the queried artist forced', () async {
      final service = _service(
        () async => _jsonResponse({
          'artisttracks': {
            'track': [
              _artistTrackEntry(
                name: 'American Teenager',
                playcount: '42',
                rank: '1',
              ),
              _artistTrackEntry(
                name: 'Strangers',
                playcount: '17',
                rank: '2',
              ),
            ],
          },
        }),
      );
      final tracks = await service.fetchArtistTracks(
        'khentsgdz',
        'Ethel Cain',
      );
      expect(tracks, hasLength(2));
      expect(tracks.first.trackName, 'American Teenager');
      expect(tracks.first.artistName, 'Ethel Cain');
      expect(tracks.first.playCount, 42);
      expect(tracks.first.rank, 1);
      expect(tracks.first.imageUrl, 'https://lastfm.example/cover.png');
      expect(
        tracks.first.spotifyUrl,
        contains(Uri.encodeComponent('Ethel Cain American Teenager')),
      );
      expect(tracks[1].trackName, 'Strangers');
      expect(tracks[1].playCount, 17);
    });

    test('parses a lone track object', () async {
      final service = _service(
        () async => _jsonResponse({
          'artisttracks': {
            'track': _artistTrackEntry(
              name: 'Only Song',
              playcount: '5',
            ),
          },
        }),
      );
      final tracks = await service.fetchArtistTracks(
        'khentsgdz',
        'Ethel Cain',
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.trackName, 'Only Song');
      expect(tracks.first.playCount, 5);
    });

    test('returns empty on an HTTP-200 error payload', () async {
      final service = _service(
        () async => _jsonResponse({
          'error': 6,
          'message': 'Artist not found',
        }),
      );
      expect(
        await service.fetchArtistTracks('khentsgdz', 'No Such Artist'),
        isEmpty,
      );
    });

    test('returns empty without calling the API for blank input', () async {
      var calls = 0;
      final service = MusicSyncService(
        client: MockClient((_) async {
          calls++;
          return _jsonResponse({'artisttracks': {'track': []}});
        }),
        signUrl: (url) async => url,
      );
      expect(await service.fetchArtistTracks('', 'Ethel Cain'), isEmpty);
      expect(await service.fetchArtistTracks('khentsgdz', ''), isEmpty);
      expect(calls, 0);
    });
  });
}
