import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
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

    test(
      'retries track-only for ASCII artists and still checks both',
      () async {
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
      },
    );

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

    test(
      'falls through to iTunes when the verified track has no art',
      () async {
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
      },
    );

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

    test(
      'accepts a collab artist when the stored name is one member',
      () async {
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
      },
    );

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
                {
                  '#text':
                      'https://lastfm-img.freetls.fastly.net/i/u/300x300/real.png',
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

      final meta = await service.fetchTrackMetadata(
        artist: 'Ethel Cain',
        track: 'American Teenager',
      );
      expect(meta, isNotNull);
      expect(meta?.albumName, 'Preacher\'s Daughter');
      expect(
        meta?.artworkUrl,
        'https://lastfm-img.freetls.fastly.net/i/u/300x300/real.png',
      );

      final album = await service.fetchTrackAlbum(
        artist: 'Ethel Cain',
        track: 'American Teenager',
      );
      expect(album, 'Preacher\'s Daughter');
    });

    test(
      'extracts collectionName from iTunes when Last.fm has no album',
      () async {
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
                'artworkUrl100':
                    'https://is1-ssl.mzstatic.com/image/thumb/cover.jpg/100x100bb.jpg',
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
        expect(
          meta?.artworkUrl,
          'https://is1-ssl.mzstatic.com/image/thumb/cover.jpg/600x600bb.jpg',
        );

        final album = await service.fetchTrackAlbum(
          artist: 'Taylor Swift',
          track: 'Cruel Summer',
        );
        expect(album, 'Lover');
      },
    );
  });

  group('MusicSyncService.fetchTrackScrobbles and fetchArtistHistory', () {
    test(
      'fetchTrackScrobbles parses track scrobbles with timestamps and album',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.queryParameters['method'],
            'user.gettrackscrobbles',
          );
          expect(request.url.queryParameters['artist'], 'Ethel Cain');
          expect(request.url.queryParameters['track'], 'American Teenager');
          return _jsonResponse({
            'trackscrobbles': {
              'track': [
                {
                  'name': 'American Teenager',
                  'artist': {'#text': 'Ethel Cain'},
                  'album': {'#text': 'Preacher\'s Daughter'},
                  'image': [
                    {
                      '#text': 'https://lastfm.example/art.jpg',
                      'size': 'large',
                    },
                  ],
                  'date': {'uts': '1689000000', '#text': '10 Jul 2023, 14:40'},
                },
                {
                  'name': 'American Teenager',
                  'artist': {'#text': 'Ethel Cain'},
                  'album': {'#text': 'Preacher\'s Daughter'},
                  'date': {'uts': '1688000000', '#text': '29 Jun 2023, 14:40'},
                },
              ],
            },
          });
        });

        final service = MusicSyncService(
          client: client,
          signUrl: (url) async => url.replace(
            queryParameters: {...url.queryParameters, '__auth': 'test-token'},
          ),
        );

        final scrobbles = await service.fetchTrackScrobbles(
          'khentsgdz',
          artist: 'Ethel Cain',
          track: 'American Teenager',
        );

        expect(scrobbles.length, 2);
        expect(scrobbles.first.trackName, 'American Teenager');
        expect(scrobbles.first.artistName, 'Ethel Cain');
        expect(scrobbles.first.albumName, 'Preacher\'s Daughter');
        expect(scrobbles.first.imageUrl, 'https://lastfm.example/art.jpg');
        expect(
          scrobbles.first.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1689000000 * 1000),
        );
      },
    );

    test(
      'fetchTrackScrobbles returns empty on invalid inputs or 404',
      () async {
        final client = MockClient(
          (request) async => _jsonResponse({}, status: 404),
        );
        final service = MusicSyncService(
          client: client,
          signUrl: (url) async => url,
        );

        expect(
          await service.fetchTrackScrobbles('', artist: 'A', track: 'T'),
          isEmpty,
        );
        expect(
          await service.fetchTrackScrobbles('u', artist: '', track: 'T'),
          isEmpty,
        );
        expect(
          await service.fetchTrackScrobbles('u', artist: 'A', track: ''),
          isEmpty,
        );
        expect(
          await service.fetchTrackScrobbles('u', artist: 'A', track: 'T'),
          isEmpty,
        );
      },
    );

    test(
      'fetchTopTracksPaged walks full pages and stops on a short one',
      () async {
        final requestedPages = <String>[];
        final client = MockClient((request) async {
          final page = request.url.queryParameters['page'] ?? '1';
          requestedPages.add(page);
          // Page 1 is full (200 rows), page 2 is the tail (3 rows).
          final count = page == '1' ? 200 : 3;
          return _jsonResponse({
            'toptracks': {
              'track': List.generate(
                count,
                (i) => {
                  'name': 'Song $page-$i',
                  'playcount': '5',
                  'artist': {'name': 'Ethel Cain'},
                  'mbid': '',
                },
              ),
            },
          });
        });
        final service = MusicSyncService(
          client: client,
          signUrl: (url) async => url,
        );

        final tracks = await service.fetchTopTracksPaged('clairjassen');
        expect(tracks, hasLength(203));
        expect(requestedPages, ['1', '2']);
      },
    );

    test(
      'fetchTopTracksPaged stops at the page cap when pages stay full',
      () async {
        final requestedPages = <String>[];
        final client = MockClient((request) async {
          requestedPages.add(request.url.queryParameters['page'] ?? '1');
          return _jsonResponse({
            'toptracks': {
              'track': List.generate(
                200,
                (i) => {
                  'name': 'Song $i',
                  'playcount': '5',
                  'artist': {'name': 'Some Artist'},
                  'mbid': '',
                },
              ),
            },
          });
        });
        final service = MusicSyncService(
          client: client,
          signUrl: (url) async => url,
        );

        final tracks = await service.fetchTopTracksPaged(
          'clairjassen',
          pageSize: 200,
          maxPages: 3,
        );
        expect(tracks, hasLength(600));
        expect(requestedPages, ['1', '2', '3']);
      },
    );

    test('fetchTrackScrobblesAll walks every page up to totalPages', () async {
      final requestedPages = <String>[];
      final client = MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        requestedPages.add('$page');
        // Three pages of 2 rows each, as Last.fm reports via @attr.
        return _jsonResponse({
          'trackscrobbles': {
            '@attr': {
              'page': '$page',
              'perPage': '2',
              'totalPages': '3',
              'total': '6',
            },
            'track': List.generate(
              2,
              (i) => {
                'name': 'Strangers',
                'artist': {'#text': 'Ethel Cain'},
                'date': {'uts': '${1690000000 + page * 10 + i}'},
              },
            ),
          },
        });
      });
      final service = MusicSyncService(
        client: client,
        signUrl: (url) async => url,
      );

      final scrobbles = await service.fetchTrackScrobblesAll(
        'clairjassen',
        artist: 'Ethel Cain',
        track: 'Strangers',
        pageSize: 2,
      );
      expect(scrobbles, hasLength(6));
      expect(requestedPages, ['1', '2', '3']);
    });

    test(
      'fetchTrackScrobblesAll keeps paging when rows drop but pages remain',
      () async {
        // A page can parse to fewer rows than it holds (undated entries are
        // dropped). That must not be mistaken for the end of the list, or long
        // histories get truncated — the original bug.
        final requestedPages = <String>[];
        final client = MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          requestedPages.add('$page');
          return _jsonResponse({
            'trackscrobbles': {
              '@attr': {
                'page': '$page',
                'perPage': '3',
                'totalPages': '2',
                'total': '6',
              },
              'track': [
                // Two undated rows (dropped) and one real scrobble per page.
                {
                  'name': 'Strangers',
                  'artist': {'#text': 'Ethel Cain'},
                },
                {
                  'name': 'Strangers',
                  'artist': {'#text': 'Ethel Cain'},
                },
                {
                  'name': 'Strangers',
                  'artist': {'#text': 'Ethel Cain'},
                  'date': {'uts': '${1690000000 + page * 10}'},
                },
              ],
            },
          });
        });
        final service = MusicSyncService(
          client: client,
          signUrl: (url) async => url,
        );

        final scrobbles = await service.fetchTrackScrobblesAll(
          'clairjassen',
          artist: 'Ethel Cain',
          track: 'Strangers',
          pageSize: 3,
        );
        expect(scrobbles, hasLength(2));
        expect(requestedPages, ['1', '2']);
      },
    );

    test(
      'fetchArtistHistory aggregates tracks + recent, deduplicates and sorts newest first',
      () async {
        final client = MockClient((request) async {
          final method = request.url.queryParameters['method'];
          if (method == 'user.gettrackscrobbles') {
            final track = request.url.queryParameters['track'];
            if (track == 'American Teenager') {
              return _jsonResponse({
                'trackscrobbles': {
                  'track': [
                    {
                      'name': 'American Teenager',
                      'artist': {'#text': 'Ethel Cain'},
                      'album': {'#text': 'Preacher\'s Daughter'},
                      'date': {'uts': '1690000000'}, // older
                    },
                  ],
                },
              });
            }
            if (track == 'Strangers') {
              return _jsonResponse({
                'trackscrobbles': {
                  'track': [
                    {
                      'name': 'Strangers',
                      'artist': {'#text': 'Ethel Cain'},
                      'album': {'#text': 'Preacher\'s Daughter'},
                      'date': {'uts': '1695000000'}, // newer
                    },
                  ],
                },
              });
            }
          } else if (method == 'user.getrecenttracks') {
            return _jsonResponse({
              'recenttracks': {
                'track': [
                  // Duplicate of Strangers scrobble at 1695000000
                  {
                    'name': 'Strangers',
                    'artist': {'#text': 'Ethel Cain'},
                    'album': {'#text': 'Preacher\'s Daughter'},
                    'date': {'uts': '1695000000'},
                  },
                  // Brand new recent play at 1700000000
                  {
                    'name': 'Sun Bleached Flies',
                    'artist': {'#text': 'Ethel Cain'},
                    'album': {'#text': 'Preacher\'s Daughter'},
                    'date': {'uts': '1700000000'},
                  },
                  // Different artist - should be filtered out
                  {
                    'name': 'Cardigan',
                    'artist': {'#text': 'Taylor Swift'},
                    'album': {'#text': 'Folklore'},
                    'date': {'uts': '1700000001'},
                  },
                ],
              },
            });
          }
          return _jsonResponse({}, status: 400);
        });

        final service = MusicSyncService(
          client: client,
          signUrl: (url) async => url,
        );

        final history = await service.fetchArtistHistory(
          'khentsgdz',
          artist: 'Ethel Cain',
          knownTracks: ['American Teenager', 'Strangers'],
        );

        // Total 3 unique: Sun Bleached Flies (1700000000), Strangers (1695000000), American Teenager (1690000000)
        expect(history.length, 3);
        expect(history[0].trackName, 'Sun Bleached Flies');
        expect(history[1].trackName, 'Strangers');
        expect(history[2].trackName, 'American Teenager');
      },
    );
  });

  group('MusicSyncService uncapped per-artist catalog and playcounts', () {
    test(
      'fetchArtistCatalogTracks parses toptracks node for specific artist',
      () async {
        final client = MockClient((request) async {
          expect(request.url.queryParameters['method'], 'artist.gettoptracks');
          expect(request.url.queryParameters['artist'], 'Ethel Cain');
          return _jsonResponse({
            'toptracks': {
              'track': [
                {
                  'name': 'American Teenager',
                  'playcount': '500000',
                  '@attr': {'rank': '1'},
                  'image': [
                    {
                      '#text': 'https://lastfm.example/art.png',
                      'size': 'extralarge',
                    },
                  ],
                },
                {
                  'name': 'Strangers',
                  'playcount': '400000',
                  '@attr': {'rank': '2'},
                },
              ],
            },
          });
        });

        final service = MusicSyncService(
          client: client,
          signUrl: (u) async => u,
        );
        final tracks = await service.fetchArtistCatalogTracks('Ethel Cain');

        expect(tracks, hasLength(2));
        expect(tracks[0].trackName, 'American Teenager');
        expect(tracks[0].artistName, 'Ethel Cain');
        expect(tracks[0].imageUrl, 'https://lastfm.example/art.png');
        expect(tracks[1].trackName, 'Strangers');
      },
    );

    test('fetchArtistCatalogTracksAll walks pages and deduplicates', () async {
      final client = MockClient((request) async {
        final page = request.url.queryParameters['page'] ?? '1';
        if (page == '1') {
          return _jsonResponse({
            'toptracks': {
              'track': [
                {
                  'name': 'Track 1',
                  '@attr': {'rank': '1'},
                },
                {
                  'name': 'Track 2',
                  '@attr': {'rank': '2'},
                },
              ],
            },
          });
        }
        return _jsonResponse({
          'toptracks': {
            'track': [
              {
                'name': 'Track 3',
                '@attr': {'rank': '3'},
              },
            ],
          },
        });
      });

      final service = MusicSyncService(client: client, signUrl: (u) async => u);
      final tracks = await service.fetchArtistCatalogTracksAll(
        'Ethel Cain',
        pageSize: 2,
        maxPages: 3,
      );

      expect(tracks, hasLength(3));
      expect(tracks.map((t) => t.trackName), ['Track 1', 'Track 2', 'Track 3']);
    });

    test(
      'fetchTrackUserPlayCount returns exact integer scrobble count including 1,000,000',
      () async {
        final client = MockClient((request) async {
          expect(request.url.queryParameters['method'], 'track.getinfo');
          expect(request.url.queryParameters['username'], 'khentsgdz');
          expect(request.url.queryParameters['artist'], 'Ethel Cain');
          expect(request.url.queryParameters['track'], 'American Teenager');
          return _jsonResponse({
            'track': {'name': 'American Teenager', 'userplaycount': '1000000'},
          });
        });

        final service = MusicSyncService(
          client: client,
          signUrl: (u) async => u,
        );
        final count = await service.fetchTrackUserPlayCount(
          username: 'khentsgdz',
          artist: 'Ethel Cain',
          track: 'American Teenager',
        );

        expect(count, 1000000);
      },
    );

    test(
      'fetchUserArtistTracks returns only songs with plays > 0 sorted descending',
      () async {
        final client = MockClient((request) async {
          final track = request.url.queryParameters['track'];
          final plays = track == 'Strangers'
              ? '29'
              : (track == 'Sun Bleached Flies' ? '26' : '0');
          return _jsonResponse({
            'track': {'name': track, 'userplaycount': plays},
          });
        });

        final service = MusicSyncService(
          client: client,
          signUrl: (u) async => u,
        );
        final candidates = [
          const TopMusicTrack(
            rank: 1,
            trackName: 'Strangers',
            artistName: 'Ethel Cain',
            playCount: 0,
            imageUrl: null,
            spotifyUrl: 'https://spotify/strangers',
          ),
          const TopMusicTrack(
            rank: 2,
            trackName: 'Unplayed Song',
            artistName: 'Ethel Cain',
            playCount: 0,
            imageUrl: null,
            spotifyUrl: 'https://spotify/unplayed',
          ),
          const TopMusicTrack(
            rank: 3,
            trackName: 'Sun Bleached Flies',
            artistName: 'Ethel Cain',
            playCount: 0,
            imageUrl: null,
            spotifyUrl: 'https://spotify/sun',
          ),
        ];

        final results = await service.fetchUserArtistTracks(
          'khentsgdz',
          'Ethel Cain',
          candidateTracks: candidates,
        );

        expect(results, hasLength(2));
        expect(results[0].trackName, 'Strangers');
        expect(results[0].playCount, 29);
        expect(results[0].rank, 1);
        expect(results[1].trackName, 'Sun Bleached Flies');
        expect(results[1].playCount, 26);
        expect(results[1].rank, 2);
      },
    );
  });
}
