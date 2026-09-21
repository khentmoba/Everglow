import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/shared/utils/catalog_proxy_client.dart';

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
            'name': 'Stick Season',
            'artist': {'name': 'Noah Kahan'},
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

    test('uses a smaller Last.fm cover when extralarge is blank', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['method'], 'track.getinfo');
        return _jsonResponse({
          'track': {
            'name': 'Fine Line',
            'artist': {'name': 'Harry Styles'},
            'album': {
              'image': [
                {'#text': '', 'size': 'small'},
                {'#text': '', 'size': 'extralarge'},
                {
                  '#text': 'https://lastfm.example/mega-cover.png',
                  'size': 'mega',
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
        artist: 'Harry Styles',
        track: 'Fine Line',
      );

      expect(artwork, 'https://lastfm.example/mega-cover.png');
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

    test('returns null when no iTunes title matches', () async {
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

      // A near-miss must never become the cover: the row falls back to
      // the music-note tile instead of wearing the wrong song's art.
      expect(artwork, isNull);
    });

    test('rejects the base version cover for a versioned title', () async {
      // Live regression: "Crush - Stripped" wore the base "Crush"
      // cover because iTunes has no exact "Stripped" title and the old
      // code guessed with the top result.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 2,
          'results': [
            _itunesResult(
              trackName: 'Crush',
              artistName: 'Ethel Cain',
              artwork: 'https://d.example/base-crush/100x100bb.jpg',
            ),
            _itunesResult(
              trackName: 'Crush - Stripped Back',
              artistName: 'Tribute Band',
              artwork: 'https://d.example/tribute/100x100bb.jpg',
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
        artist: 'Ethel Cain',
        track: 'Crush - Stripped',
      );

      expect(artwork, isNull);
    });

    test('rejects same-titled songs by a different artist', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Crush',
              artistName: 'David Archuleta',
              artwork: 'https://e.example/wrong-artist/100x100bb.jpg',
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
        artist: 'Ethel Cain',
        track: 'Crush',
      );

      expect(artwork, isNull);
    });

    test('retries track-only for ASCII artists and still checks both', () async {
      final requestedTerms = <String>[];
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        final term = request.url.queryParameters['term'] ?? '';
        requestedTerms.add(term);
        // Combined query comes up empty (iTunes quirk); the track-only
        // retry finds the exact song by the exact artist.
        if (term.contains('Ethel Cain')) {
          return _jsonResponse({'resultCount': 0, 'results': []});
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Strangers',
              artistName: 'Ethel Cain',
              artwork: 'https://f.example/strangers/100x100bb.jpg',
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
        artist: 'Ethel Cain',
        track: 'Strangers',
      );

      expect(artwork, 'https://f.example/strangers/600x600bb.jpg');
      expect(requestedTerms, ['Ethel Cain Strangers', 'Strangers']);
    });

    test('rejects a track-only retry hit by the wrong artist', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        final term = request.url.queryParameters['term'] ?? '';
        if (term.contains('Obscure')) {
          return _jsonResponse({'resultCount': 0, 'results': []});
        }
        // A cover band shares the title; without the artist check the
        // row would wear the original's cover.
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Hometown Show',
              artistName: 'Famous Original',
              artwork: 'https://g.example/original/100x100bb.jpg',
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
        artist: 'Obscure Cover Band',
        track: 'Hometown Show',
      );

      expect(artwork, isNull);
    });

    test('ignores Last.fm covers for a fuzzy-matched track', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          // Last.fm resolved "Crush - Stripped" to base "Crush".
          return _jsonResponse({
            'track': {
              'name': 'Crush',
              'artist': {'name': 'Ethel Cain'},
              'album': {
                'image': [
                  {
                    '#text': 'https://lastfm.example/base-crush.png',
                    'size': 'extralarge',
                  },
                ],
              },
            },
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
        artist: 'Ethel Cain',
        track: 'Crush - Stripped',
      );

      expect(artwork, isNull);
    });

    test('ignores Last.fm covers for the wrong artist', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _jsonResponse({
            'track': {
              'name': 'Crush',
              'artist': {'name': 'David Archuleta'},
              'album': {
                'image': [
                  {
                    '#text': 'https://lastfm.example/archuleta.png',
                    'size': 'extralarge',
                  },
                ],
              },
            },
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
        artist: 'Ethel Cain',
        track: 'Crush',
      );

      expect(artwork, isNull);
    });

    test('falls through to iTunes when the verified track has no art', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          // Last.fm knows the exact song but carries no cover.
          return _jsonResponse({
            'track': {
              'name': 'Strangers',
              'artist': {'name': 'Ethel Cain'},
              'album': {
                'image': [
                  {'#text': '', 'size': 'small'},
                  {'#text': '', 'size': 'extralarge'},
                ],
              },
            },
          });
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Strangers',
              artistName: 'Ethel Cain',
              artwork: 'https://h.example/strangers/100x100bb.jpg',
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
        artist: 'Ethel Cain',
        track: 'Strangers',
      );

      expect(artwork, 'https://h.example/strangers/600x600bb.jpg');
    });

    test('returns null when iTunes also comes up empty', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        if (request.url.path.contains('proxySpotifySearch')) {
          return _jsonResponse({'trackId': null, 'query': 'x'});
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

    test('falls back to Spotify when Last.fm and iTunes miss', () async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        if (request.url.path.contains('proxySpotifySearch')) {
          // Spotify carries the stripped single neither backend had.
          return _jsonResponse({
            'trackId': 'stripped123',
            'trackName': 'Crush - Stripped',
            'artistName': 'Ethel Cain',
            'imageUrl': 'https://i.scdn.co/image/stripped.png',
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
        artist: 'Ethel Cain',
        track: 'Crush - Stripped',
      );

      expect(artwork, 'https://i.scdn.co/image/stripped.png');
      expect(
        requestedPaths.where((p) => p.contains('proxySpotifySearch')),
        hasLength(1),
      );
    });

    test('rejects the Spotify top result when the title differs', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        if (request.url.path.contains('proxySpotifySearch')) {
          // No exact match server-side: the proxy answered base "Crush".
          return _jsonResponse({
            'trackId': 'base456',
            'trackName': 'Crush',
            'artistName': 'Ethel Cain',
            'imageUrl': 'https://i.scdn.co/image/base-crush.png',
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
        artist: 'Ethel Cain',
        track: 'Crush - Stripped',
      );

      expect(artwork, isNull);
    });

    test('rejects Spotify art by a different artist', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        if (request.url.path.contains('proxySpotifySearch')) {
          return _jsonResponse({
            'trackId': 'other789',
            'trackName': 'Crush',
            'artistName': 'David Archuleta',
            'imageUrl': 'https://i.scdn.co/image/archuleta.png',
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
        artist: 'Ethel Cain',
        track: 'Crush',
      );

      expect(artwork, isNull);
    });

    test('accepts a collab artist when the stored name is one member', () async {
      // Live regression: Clair's "Be Kind" (stored artist "Marshmello")
      // stayed on the fallback tile because iTunes lists the artist as
      // "Marshmello & Halsey" — same song, same cover, must match.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Be Kind',
              artistName: 'Marshmello & Halsey',
              artwork: 'https://i.example/bekind/100x100bb.jpg',
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
        artist: 'Marshmello',
        track: 'Be Kind',
      );
      expect(artwork, 'https://i.example/bekind/600x600bb.jpg');
    });

    test('accepts featured-artist tags in the track title', () async {
      // "Be Kind (with Halsey)" is the same recording as "Be Kind" —
      // the feat tag strips before comparing, unlike version words.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Be Kind (with Halsey)',
              artistName: 'Marshmello',
              artwork: 'https://j.example/bekind/100x100bb.jpg',
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
        artist: 'Marshmello',
        track: 'Be Kind',
      );
      expect(artwork, 'https://j.example/bekind/600x600bb.jpg');
    });

    test('still rejects version suffixes after feat stripping', () async {
      // Guard: feat stripping must not weaken the "Crush" vs
      // "Crush - Stripped" rejection — "Stripped" is a version.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Crush',
              artistName: 'Ethel Cain',
              artwork: 'https://k.example/base/100x100bb.jpg',
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
        artist: 'Ethel Cain',
        track: 'Crush - Stripped',
      );
      expect(artwork, isNull);
    });

    test('keeps mid-title with and version tails', () async {
      // "Be With You (Remix)" must not collapse to "Be" and match
      // plain "Be With You" — mid-title "with" is part of the song
      // name, and the version tail stays significant.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Be With You (Remix)',
              artistName: 'Test Artist',
              artwork: 'https://m.example/remix/100x100bb.jpg',
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
        artist: 'Test Artist',
        track: 'Be With You',
      );
      expect(artwork, isNull);
    });

    test('strips bare with when two words precede it', () async {
      // "Be Kind with Halsey" (no separator, no parens) is the same
      // song as "Be Kind" — the feature strips, the base matches.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Be Kind with Halsey',
              artistName: 'Marshmello',
              artwork: 'https://n.example/bekind/100x100bb.jpg',
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
        artist: 'Marshmello',
        track: 'Be Kind',
      );
      expect(artwork, 'https://n.example/bekind/600x600bb.jpg');
    });

    test('does not strip feat inside ordinary words', () async {
      // "Defeat" contains "feat" but is not a feature tag — the
      // marker needs a word boundary, so "Defeat the Night" never
      // collapses and mismatches its own title.
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Defeat the Night',
              artistName: 'Test Artist',
              artwork: 'https://o.example/defeat/100x100bb.jpg',
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
        artist: 'Test Artist',
        track: 'Defeat the Night',
      );
      expect(artwork, 'https://o.example/defeat/600x600bb.jpg');
    });

    test('fetchArtistSuggestions parses Last.fm artist.search rows', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['method'], 'artist.search');
        expect(request.url.queryParameters['artist'], 'lana del');
        return _jsonResponse({
          'results': {
            'artistmatches': {
              'artist': [
                {
                  'name': 'Lana Del Rey',
                  'listeners': '3264191',
                  'mbid': '153c9281-...',
                  'url': 'https://www.last.fm/music/Lana-Del-Rey',
                  'image': [
                    {'#text': '', 'size': 'small'},
                    {
                      '#text': 'https://lastfm.example/lana.png',
                      'size': 'extralarge',
                    },
                  ],
                },
                {
                  'name': 'Lana Del Rey & Cedric Gervais',
                  'listeners': '1200',
                  'mbid': '',
                  'url': 'https://www.last.fm/music/x',
                  'image': [],
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
      final results = await service.fetchArtistSuggestions('lana del');
      expect(results, hasLength(2));
      expect(results.first.name, 'Lana Del Rey');
      expect(results.first.listeners, 3264191);
      expect(results.first.imageUrl, 'https://lastfm.example/lana.png');
      expect(results.last.imageUrl, isNull);
    });

    test('fetchArtistSuggestions returns empty for short queries', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return _jsonResponse({});
      });
      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url,
      );
      expect(await service.fetchArtistSuggestions(''), isEmpty);
      expect(await service.fetchArtistSuggestions('a'), isEmpty);
      expect(called, isFalse);
    });

    test('fetchArtistImage returns the Spotify artist photo', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('proxySpotifySearch'));
        expect(request.url.queryParameters['type'], 'artist');
        expect(request.url.queryParameters['artist'], 'Lana Del Rey');
        return _jsonResponse({
          'artistId': '00FQb4jTyendYWaN8pLanx',
          'artistName': 'Lana Del Rey',
          'imageUrl': 'https://i.scdn.co/image/lana.png',
          'followers': 12345678,
        });
      });
      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );
      final photo = await service.fetchArtistImage('Lana Del Rey');
      expect(photo, 'https://i.scdn.co/image/lana.png');
    });

    test('fetchArtistImage returns null when Spotify has no photo', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return _jsonResponse({'artistId': null, 'query': 'Nobody'});
      });
      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url,
      );
      expect(await service.fetchArtistImage('Nobody'), isNull);
      expect(await service.fetchArtistImage('   '), isNull);
      expect(called, isTrue);
    });

    test('routes iTunes search through proxyCatalog client', () async {
      final requestedBases = <String>[];
      final requestedPaths = <String>[];
      final proxyClient = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _lastfmEmptyArtwork();
        }
        final base = request.url.queryParameters['base'] ?? '';
        final path = request.url.queryParameters['path'] ?? '';
        requestedBases.add(base);
        requestedPaths.add(path);
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            _itunesResult(
              trackName: 'Dulo Ng Hangganan',
              artistName: 'IV Of Spades',
              artwork:
                  'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/cover.jpg/'
                  '100x100bb.jpg',
            ),
          ],
        });
      });

      final proxy = CatalogProxyClient(client: proxyClient);
      final resp = await proxy.get(
        'itunes',
        'search',
        query: {
          'term': 'IV Of Spades Dulo Ng Hangganan',
          'entity': 'song',
          'media': 'music',
          'limit': '10',
        },
      );

      expect(resp.statusCode, 200);
      expect(requestedBases, ['itunes']);
      expect(requestedPaths.first, contains('search?'));
      expect(requestedPaths.first, contains('term=IV+Of+Spades'));
    });
  });

  group('MusicSyncService.fetchTrackMetadata and fetchTrackAlbum', () {
    test('extracts album name and artwork from Last.fm track.getinfo', () async {
      final client = MockClient((request) async {
        return _jsonResponse({
          'track': {
            'name': 'American Teenager',
            'artist': {'name': 'Ethel Cain'},
            'album': {
              'title': 'Preacher\'s Daughter',
              'image': [
                {'#text': '', 'size': 'small'},
                {'#text': 'https://lastfm-img.freetls.fastly.net/i/u/300x300/real.png', 'size': 'extralarge'},
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

      final meta = await service.fetchTrackMetadata(
        artist: 'Ethel Cain',
        track: 'American Teenager',
      );
      expect(meta, isNotNull);
      expect(meta?.albumName, 'Preacher\'s Daughter');
      expect(meta?.artworkUrl, 'https://lastfm-img.freetls.fastly.net/i/u/300x300/real.png');

      final album = await service.fetchTrackAlbum(
        artist: 'Ethel Cain',
        track: 'American Teenager',
      );
      expect(album, 'Preacher\'s Daughter');
    });

    test('extracts collectionName from iTunes when Last.fm has no album', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['method'] == 'track.getinfo') {
          return _jsonResponse({
            'track': {
              'name': 'Cruel Summer',
              'artist': {'name': 'Taylor Swift'},
            },
          });
        }
        return _jsonResponse({
          'resultCount': 1,
          'results': [
            {
              'trackName': 'Cruel Summer',
              'artistName': 'Taylor Swift',
              'collectionName': 'Lover',
              'artworkUrl100': 'https://is1-ssl.mzstatic.com/image/thumb/cover.jpg/100x100bb.jpg',
            },
          ],
        });
      });

      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url.replace(
          queryParameters: {...url.queryParameters, '__auth': 'test-token'},
        ),
      );

      final meta = await service.fetchTrackMetadata(
        artist: 'Taylor Swift',
        track: 'Cruel Summer',
      );
      expect(meta, isNotNull);
      expect(meta?.albumName, 'Lover');
      expect(meta?.artworkUrl, 'https://is1-ssl.mzstatic.com/image/thumb/cover.jpg/600x600bb.jpg');

      final album = await service.fetchTrackAlbum(
        artist: 'Taylor Swift',
        track: 'Cruel Summer',
      );
      expect(album, 'Lover');
    });
  });
}
