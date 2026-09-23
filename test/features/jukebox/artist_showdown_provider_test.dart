import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/jukebox/data/models/artist_suggestion.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/artist_showdown_provider.dart';

TopMusicTrack _track(String name, int plays, {String artist = 'Ethel Cain'}) =>
    TopMusicTrack(
      rank: 1,
      trackName: name,
      artistName: artist,
      playCount: plays,
      imageUrl: null,
      spotifyUrl: 'https://open.spotify.com/search/x',
    );

class _FakeSync extends MusicSyncService {
  _FakeSync({
    required this.byUser,
    this.artworkByTrack = const {},
    this.suggestions = const [],
    this.artistImages = const {},
    this.historyByUser = const {},
    this.exactPlaysByUser = const {},
    this.catalogTracks = const [],
    this.userArtistTracks = const {},
  });

  /// Last.fm username -> full all-time top tracks (provider filters by
  /// artist locally, mirroring the live `user.gettoptracks` path).
  final Map<String, List<TopMusicTrack>> byUser;
  final Map<String, String?> artworkByTrack;
  final List<ArtistSuggestion> suggestions;
  final Map<String, String?> artistImages;
  final Map<String, List<MusicStatus>> historyByUser;

  /// Last.fm username -> exact all-time artist playcount, as the live
  /// `artist.getInfo` call answers it. Absent means "Last.fm could not
  /// answer", which must fall back to the row sum.
  final Map<String, int> exactPlaysByUser;
  final List<TopMusicTrack> catalogTracks;
  final Map<String, List<TopMusicTrack>> userArtistTracks;
  int calls = 0;
  int artworkCalls = 0;
  int suggestionCalls = 0;
  int artistImageCalls = 0;
  int historyCalls = 0;
  int exactPlayCountCalls = 0;
  int catalogCalls = 0;
  int userArtistTrackCalls = 0;

  @override
  Future<List<TopMusicTrack>> fetchArtistCatalogTracksAll(
    String artist, {
    int pageSize = 50,
    int maxPages = 10,
  }) async {
    catalogCalls++;
    return catalogTracks;
  }

  @override
  Future<List<TopMusicTrack>> fetchUserArtistTracks(
    String username,
    String artist, {
    required List<TopMusicTrack> candidateTracks,
    int batchSize = 6,
  }) async {
    userArtistTrackCalls++;
    return userArtistTracks[username] ?? const [];
  }

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    int page = 1,
    String period = 'overall',
  }) async {
    calls++;
    if (page > 1) return const [];
    return byUser[username] ?? const [];
  }

  @override
  Future<int?> fetchArtistPlayCount(String username, String artist) async {
    exactPlayCountCalls++;
    return exactPlaysByUser[username];
  }

  @override
  Future<String?> fetchTrackArtwork({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    artworkCalls++;
    if (artworkByTrack.containsKey(track)) return artworkByTrack[track];
    return null;
  }

  @override
  Future<List<ArtistSuggestion>> fetchArtistSuggestions(
    String query, {
    int limit = 6,
  }) async {
    suggestionCalls++;
    final q = query.trim().toLowerCase();
    return suggestions.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<String?> fetchArtistImage(String artistName) async {
    artistImageCalls++;
    final key = artistName.trim().toLowerCase();
    if (artistImages.containsKey(key)) return artistImages[key];
    return null;
  }

  @override
  Future<List<MusicStatus>> fetchArtistHistory(
    String username, {
    required String artist,
    List<String> knownTracks = const [],
    int maxTracks = 12,
    int scrobblesPerTrack = 50,
    bool includeRecent = true,
  }) async {
    historyCalls++;
    return historyByUser[username] ?? const [];
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('ArtistShowdownProvider', () {
    test('loads Ethel Cain by default with totals and leader', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('American Teenager', 42)],
          'clairjassen': [
            _track('American Teenager', 67),
            _track('Strangers', 12),
          ],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      expect(provider.artist, 'Ethel Cain');
      expect(provider.khentTotal, 42);
      expect(provider.clairTotal, 79);
      expect(provider.leader, 'clair');
      expect(provider.tracks, hasLength(2));
      // Sorted by combined plays: American Teenager (109) first.
      expect(provider.tracks.first.trackName, 'American Teenager');
      expect(provider.tracks.first.khentPlays, 42);
      expect(provider.tracks.first.clairPlays, 67);
      expect(provider.tracks.first.leader, 'clair');
      expect(provider.tracks.last.trackName, 'Strangers');
      expect(provider.tracks.last.khentPlays, 0);
      expect(provider.tracks.last.leader, 'clair');
      provider.dispose();
    });

    test(
      'loads artist using uncapped per-artist catalog tracks without fetching other artists',
      () async {
        final sync = _FakeSync(
          byUser: {
            'khentsgdz': [
              _track('Other Artist Track', 9999, artist: 'Other Artist'),
            ],
            'clairjassen': [
              _track('Another Artist Track', 8888, artist: 'Another Artist'),
            ],
          },
          catalogTracks: [
            _track('Strangers', 0),
            _track('Sun Bleached Flies', 0),
            _track('Rare B-Side', 0),
          ],
          userArtistTracks: {
            'khentsgdz': [
              _track('Strangers', 1000000),
              _track('Rare B-Side', 1),
            ],
            'clairjassen': [
              _track('Sun Bleached Flies', 20),
              _track('Strangers', 5),
            ],
          },
          exactPlaysByUser: {'khentsgdz': 1000001, 'clairjassen': 25},
        );
        final provider = ArtistShowdownProvider(syncService: sync);
        await _waitFor(() => !provider.isLoading);

        expect(provider.artist, 'Ethel Cain');
        // Exactly 1,000,001 plays for Khent — uncapped!
        expect(provider.khentTotal, 1000001);
        expect(provider.clairTotal, 25);
        expect(provider.leader, 'khent');
        // All 3 tracks are shown, including the 1-play song and the 1,000,000 play song
        expect(provider.tracks, hasLength(3));
        expect(provider.tracks[0].trackName, 'Strangers');
        expect(provider.tracks[0].khentPlays, 1000000);
        expect(provider.tracks[0].clairPlays, 5);
        expect(provider.tracks[1].trackName, 'Sun Bleached Flies');
        expect(provider.tracks[1].clairPlays, 20);
        expect(provider.tracks[2].trackName, 'Rare B-Side');
        expect(provider.tracks[2].khentPlays, 1);

        // Verify zero calls were made to fetchTopTracks (zero other artists fetched!)
        expect(sync.calls, 0);
        expect(sync.catalogCalls, greaterThanOrEqualTo(1));
        expect(sync.userArtistTrackCalls, 2);

        // Entire total is accounted for by the individual song rows
        expect(provider.hasOtherPlays, isFalse);
        expect(provider.khentOtherPlays, 0);
        expect(provider.clairOtherPlays, 0);
        provider.dispose();
      },
    );

    // Regression: totals used to be summed from a single top-track page, so
    // plays of songs below that page silently vanished and counts only shrank
    // (Clair's Ethel Cain dropped to 103). The exact artist playcount from
    // `artist.getInfo` must win, and the leftover must stay visible as
    // "Other songs" instead of disappearing.
    test('uses the exact artist playcount and reports other songs', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('American Teenager', 42)],
          'clairjassen': [_track('American Teenager', 67)],
        },
        exactPlaysByUser: {'khentsgdz': 42, 'clairjassen': 118},
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      // Exact counts, not the row sums (67 is what the visible page held).
      expect(provider.khentTotal, 42);
      expect(provider.clairTotal, 118);
      expect(provider.leader, 'clair');
      expect(sync.exactPlayCountCalls, 2);

      // 118 - 67 plays belong to songs below the fetched top tracks.
      expect(provider.clairOtherPlays, 51);
      expect(provider.khentOtherPlays, 0);
      expect(provider.hasOtherPlays, isTrue);
      provider.dispose();
    });

    test('falls back to row sums when Last.fm cannot answer', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('American Teenager', 42)],
          'clairjassen': [
            _track('American Teenager', 67),
            _track('Strangers', 12),
          ],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      expect(provider.khentTotal, 42);
      expect(provider.clairTotal, 79);
      expect(provider.hasOtherPlays, isFalse);
      provider.dispose();
    });

    test('never reports less than the rows it is showing', () async {
      // A stale exact count (e.g. a rounded upstream value) must not make the
      // headline disagree with the visible table downward.
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('American Teenager', 42)],
          'clairjassen': [
            _track('American Teenager', 67),
            _track('Strangers', 12),
          ],
        },
        exactPlaysByUser: {'khentsgdz': 42, 'clairjassen': 50},
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      expect(provider.clairTotal, 79);
      expect(provider.hasOtherPlays, isFalse);
      provider.dispose();
    });

    test('ignores tracks by other artists', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [
            _track('American Teenager', 42),
            _track('Video Games', 999, artist: 'Lana Del Rey'),
          ],
          'clairjassen': [
            _track('Strangers', 12),
            _track('Summertime Sadness', 500, artist: 'Lana Del Rey'),
          ],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      expect(provider.khentTotal, 42);
      expect(provider.clairTotal, 12);
      expect(provider.tracks, hasLength(2));
      expect(
        provider.tracks.every(
          (t) =>
              t.trackName != 'Video Games' &&
              t.trackName != 'Summertime Sadness',
        ),
        isTrue,
      );
      provider.dispose();
    });

    test('merges case-insensitive duplicates into one row', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('strangers', 10)],
          'clairjassen': [_track('Strangers', 5)],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      expect(provider.tracks, hasLength(1));
      expect(provider.tracks.first.khentPlays, 10);
      expect(provider.tracks.first.clairPlays, 5);
      provider.dispose();
    });

    test('reports a tie when totals match', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('A', 10)],
          'clairjassen': [_track('B', 10)],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      expect(provider.leader, isNull);
      expect(provider.hasData, isTrue);
      expect(provider.khentShare, 0.5);
      provider.dispose();
    });

    test('caches per artist so switching back never refetches', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [
            _track('A', 3),
            _track('Video Games', 7, artist: 'Lana Del Rey'),
          ],
          'clairjassen': [
            _track('A', 4),
            _track('Video Games', 3, artist: 'Lana Del Rey'),
          ],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);
      expect(provider.khentTotal, 3);
      expect(provider.clairTotal, 4);
      expect(sync.calls, 2);

      await provider.selectArtist('Lana Del Rey');
      await _waitFor(() => !provider.isLoading);
      expect(provider.artist, 'Lana Del Rey');
      expect(provider.khentTotal, 7);
      expect(provider.clairTotal, 3);
      expect(sync.calls, 4);

      await provider.selectArtist('Ethel Cain');
      expect(provider.artist, 'Ethel Cain');
      expect(provider.khentTotal, 3);
      expect(provider.clairTotal, 4);
      expect(sync.calls, 4);
      provider.dispose();
    });

    test('ignores blank artists', () async {
      final sync = _FakeSync(byUser: const {});
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);
      final calls = sync.calls;
      await provider.selectArtist('   ');
      expect(provider.artist, 'Ethel Cain');
      expect(sync.calls, calls);
      provider.dispose();
    });

    test('enriches missing artwork in the background', () async {
      const art = 'https://img.example/ethel-strangers.png';
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('Strangers', 10)],
          'clairjassen': [_track('Strangers', 5)],
        },
        artworkByTrack: {'Strangers': art},
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);
      // Table shows immediately, even before artwork lands.
      expect(provider.tracks, hasLength(1));
      await _waitFor(() => provider.tracks.first.imageUrl == art);
      expect(sync.artworkCalls, greaterThanOrEqualTo(1));
      // Totals are untouched by the enrichment pass.
      expect(provider.khentTotal, 10);
      expect(provider.clairTotal, 5);
      provider.dispose();
    });

    test('leaves rows coverless when artwork lookup fails', () async {
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('Strangers', 10)],
          'clairjassen': [_track('Strangers', 5)],
        },
        artworkByTrack: {'Strangers': null},
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);
      // Give the background pass a moment to run and give up quietly.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(provider.tracks.first.imageUrl, isNull);
      expect(provider.hasData, isTrue);
      provider.dispose();
    });

    test('searchArtists caches per query and clears on short input', () async {
      const lana = ArtistSuggestion(
        name: 'Lana Del Rey',
        listeners: 3000000,
        url: '',
      );
      final sync = _FakeSync(byUser: const {}, suggestions: const [lana]);
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      await provider.searchArtists('lana del');
      expect(provider.suggestions, hasLength(1));
      expect(provider.suggestions.first.name, 'Lana Del Rey');
      expect(provider.isSearching, isFalse);
      expect(sync.suggestionCalls, 1);

      // Cached: second identical query never hits the service.
      await provider.searchArtists('Lana Del');
      expect(provider.suggestions, hasLength(1));
      expect(sync.suggestionCalls, 1);

      // Short input hides the dropdown without a fetch.
      await provider.searchArtists('a');
      expect(provider.suggestions, isEmpty);
      expect(provider.isSearching, isFalse);
      expect(sync.suggestionCalls, 1);

      provider.clearSuggestions();
      expect(provider.suggestions, isEmpty);
      provider.dispose();
    });

    test('selectArtist clears open suggestions', () async {
      const lana = ArtistSuggestion(
        name: 'Lana Del Rey',
        listeners: 10,
        url: '',
      );
      final sync = _FakeSync(
        byUser: {
          'khentsgdz': [_track('Video Games', 7, artist: 'Lana Del Rey')],
          'clairjassen': [_track('Video Games', 3, artist: 'Lana Del Rey')],
        },
        suggestions: const [lana],
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);
      await provider.searchArtists('lana');
      expect(provider.suggestions, isNotEmpty);
      await provider.selectArtist('Lana Del Rey');
      expect(provider.suggestions, isEmpty);
      expect(provider.artist, 'Lana Del Rey');
      provider.dispose();
    });

    test('enriches suggestion photos from Spotify in the background', () async {
      const lana = ArtistSuggestion(
        name: 'Lana Del Rey',
        listeners: 3000000,
        url: '',
      );
      const photo = 'https://i.scdn.co/image/lana.png';
      final sync = _FakeSync(
        byUser: const {},
        suggestions: const [lana],
        artistImages: const {'lana del rey': photo},
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      await provider.searchArtists('lana del');
      expect(provider.suggestions, hasLength(1));
      await _waitFor(() => provider.suggestions.first.imageUrl == photo);
      expect(sync.artistImageCalls, 1);
      // The per-query cache holds the enriched rows, so retyping is instant.
      await provider.searchArtists('Lana Del');
      expect(provider.suggestions.first.imageUrl, photo);
      expect(sync.suggestionCalls, 1);
      provider.dispose();
    });

    test('reuses artist photos across overlapping queries', () async {
      const lana = ArtistSuggestion(
        name: 'Lana Del Rey',
        listeners: 1,
        url: '',
      );
      const photo = 'https://i.scdn.co/image/lana.png';
      final sync = _FakeSync(
        byUser: const {},
        suggestions: const [lana],
        artistImages: const {'lana del rey': photo},
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      await provider.searchArtists('lana del');
      await _waitFor(() => provider.suggestions.first.imageUrl == photo);
      expect(sync.artistImageCalls, 1);

      // A different query returning the same artist reuses the photo
      // without another Spotify lookup.
      await provider.searchArtists('lana');
      await _waitFor(() => provider.suggestions.first.imageUrl == photo);
      expect(sync.artistImageCalls, 1);
      provider.dispose();
    });

    test('leaves suggestions photo-less when Spotify has no image', () async {
      const lana = ArtistSuggestion(
        name: 'Lana Del Rey',
        listeners: 1,
        url: '',
      );
      final sync = _FakeSync(byUser: const {}, suggestions: const [lana]);
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);

      await provider.searchArtists('lana');
      expect(provider.suggestions, hasLength(1));
      // Give the background pass a moment to run and give up quietly.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(provider.suggestions.first.imageUrl, isNull);
      expect(sync.artistImageCalls, 1);
      provider.dispose();
    });

    test(
      'loadArtistHistory fetches and caches history for Khent and Clair',
      () async {
        final khentScrobble = MusicStatus(
          username: 'khentsgdz',
          trackName: 'American Teenager',
          artistName: 'Ethel Cain',
          albumName: 'Preacher\'s Daughter',
          isPlaying: false,
          spotifyUrl: 'https://spotify/american',
          timestamp: DateTime(2026, 9, 20, 10, 30),
        );
        final clairScrobble = MusicStatus(
          username: 'clairjassen',
          trackName: 'Strangers',
          artistName: 'Ethel Cain',
          albumName: 'Preacher\'s Daughter',
          isPlaying: false,
          spotifyUrl: 'https://spotify/strangers',
          timestamp: DateTime(2026, 9, 21, 14, 15),
        );

        final sync = _FakeSync(
          byUser: {
            'khentsgdz': [_track('American Teenager', 10)],
            'clairjassen': [_track('Strangers', 8)],
          },
          artworkByTrack: {'American Teenager': 'https://itunes/american.png'},
          historyByUser: {
            'khentsgdz': [khentScrobble],
            'clairjassen': [clairScrobble],
          },
        );

        final provider = ArtistShowdownProvider(syncService: sync);
        await _waitFor(() => !provider.isLoading);

        expect(provider.hasHistory, isFalse);
        expect(provider.isLoadingHistory, isFalse);

        await provider.loadArtistHistory();

        expect(provider.isLoadingHistory, isFalse);
        expect(provider.hasHistory, isTrue);
        expect(provider.khentHistory, hasLength(1));
        expect(provider.clairHistory, hasLength(1));
        // Enriched artwork from showdown tracks is attached to khent's scrobble:
        expect(
          provider.khentHistory.first.imageUrl,
          'https://itunes/american.png',
        );
        expect(
          provider.khentHistory.first.timestamp,
          DateTime(2026, 9, 20, 10, 30),
        );
        expect(
          provider.clairHistory.first.timestamp,
          DateTime(2026, 9, 21, 14, 15),
        );
        expect(sync.historyCalls, 2);

        // Subsequent call uses cache
        await provider.loadArtistHistory();
        expect(sync.historyCalls, 2);

        // forceRefresh bypasses cache
        await provider.loadArtistHistory(forceRefresh: true);
        expect(sync.historyCalls, 4);

        provider.dispose();
      },
    );
  });
}
