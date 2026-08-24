import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(jsonEncode(body), status, headers: _jsonHeaders);
}

/// Mirrors Last.fm's real `track.getinfo` response for tracks with no
/// artwork: an album object whose image entries are all empty strings.
http.Response _lastfmEmptyArtwork() {
  return _jsonResponse({
    'track': {
      'album': {
        'title': 'Pinipili',
        'image': [
          {'#text': '', 'size': 'small'},
          {'#text': '', 'size': 'extralarge'},
        ],
      },
    },
  });
}

Map<String, dynamic> _itunesResult({
  required String trackName,
  required String artistName,
  required String artwork,
}) {
  return {
    'trackName': trackName,
    'artistName': artistName,
    'artworkUrl100': artwork,
  };
}

void main() {
  group('MusicSyncService.fetchTrackArtwork', () {
    test('falls back to iTunes when Last.fm has no artwork', () async {
      final requestedTerms = <String>[];
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        final term = request.url.queryParameters['term'] ?? '';
        requestedTerms.add(term);
        // The combined artist + track query misses because Last.fm stored
        // the mangled artist name; the track-only retry hits.
        if (term.contains('Mat')) {
          return _jsonResponse({'resultCount': 0, 'results': []});
        }
        if (term.contains('Pinipili')) {
          return _jsonResponse({
            'resultCount': 2,
            'results': [
              _itunesResult(
                trackName: 'Pinipili',
                artistName: 'MATEO',
                artwork:
                    'https://is1-ssl.mzstatic.com/image/thumb/cover.jpg/'
                    '100x100bb.jpg',
              ),
              _itunesResult(
                trackName: 'Binibining Pinipili',
                artistName: 'Ewon',
                artwork:
                    'https://is1-ssl.mzstatic.com/image/thumb/wrong.jpg/'
                    '100x100bb.jpg',
              ),
            ],
          });
        }
        return _jsonResponse({'resultCount': 0, 'results': []});
      });

      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );
      final artwork = await service.fetchTrackArtwork(
        artist: 'Mat\u00c3\u00a9o',
        track: 'Pinipili',
      );

      expect(artwork, isNotNull);
      expect(
        artwork,
        'https://is1-ssl.mzstatic.com/image/thumb/cover.jpg/600x600bb.jpg',
      );
      expect(requestedTerms, ['Mat\u00c3\u00a9o Pinipili', 'Pinipili']);
    });

    test('uses Last.fm artwork and skips iTunes when available', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['method'], 'track.getinfo');
        return _jsonResponse({
          'track': {
            'album': {
              'image': [
                {
                  '#text': 'https://lastfm.example/real-cover.png',
                  'size': 'extralarge',
                },
              ],
            },
          },
        });
      });

      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );
      final artwork = await service.fetchTrackArtwork(
        artist: 'Noah Kahan',
        track: 'Stick Season',
      );

      expect(artwork, 'https://lastfm.example/real-cover.png');
    });

    test('prefers an exact track-name match over iTunes ordering', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 2,
          'results': [
            _itunesResult(
              trackName: 'Something Else',
              artistName: 'Other Artist',
              artwork: 'https://a.example/100x100bb.jpg',
            ),
            _itunesResult(
              trackName: 'Pinipili',
              artistName: 'MATEO',
              artwork: 'https://b.example/100x100bb.jpg',
            ),
          ],
        });
      });

      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );
      final artwork = await service.fetchTrackArtwork(
        artist: 'Mateo',
        track: 'Pinipili',
      );

      expect(artwork, 'https://b.example/600x600bb.jpg');
    });

    test('falls back to the top result when no title matches', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Nearest Neighbour',
              artistName: 'Someone',
              artwork: 'https://c.example/100x100bb.jpg',
            ),
          ],
        });
      });

      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );
      final artwork = await service.fetchTrackArtwork(
        artist: 'Someone',
        track: 'Missing Track',
      );

      expect(artwork, 'https://c.example/600x600bb.jpg');
    });

    test('returns null when iTunes also comes up empty', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({'resultCount': 0, 'results': []});
      });

      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );
      final artwork = await service.fetchTrackArtwork(
        artist: 'Nobody',
        track: 'Nothing',
      );

      expect(artwork, isNull);
    });
  });
}
