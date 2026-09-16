import 'package:flutter_test/flutter_test.dart';

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
  _FakeSync({required this.byUser, this.artworkByTrack = const {}});

  /// Last.fm username -> full all-time top tracks (provider filters by
  /// artist locally, mirroring the live `user.gettoptracks` path).
  final Map<String, List<TopMusicTrack>> byUser;
  final Map<String, String?> artworkByTrack;
  int calls = 0;
  int artworkCalls = 0;

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    String period = 'overall',
  }) async {
    calls++;
    return byUser[username] ?? const [];
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
          (t) => t.trackName != 'Video Games' && t.trackName != 'Summertime Sadness',
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
      await _waitFor(
        () => provider.tracks.first.imageUrl == art,
      );
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
  });
}
