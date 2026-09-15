import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/artist_showdown_provider.dart';

TopMusicTrack _track(String name, int plays) => TopMusicTrack(
  rank: 1,
  trackName: name,
  artistName: 'Ethel Cain',
  playCount: plays,
  imageUrl: null,
  spotifyUrl: 'https://open.spotify.com/search/x',
);

class _FakeSync extends MusicSyncService {
  _FakeSync({required this.byUser});

  /// Last.fm username -> tracks for that user.
  final Map<String, List<TopMusicTrack>> byUser;
  int calls = 0;

  @override
  Future<List<TopMusicTrack>> fetchArtistTracks(
    String username,
    String artist, {
    int limit = 200,
  }) async {
    calls++;
    return byUser[username] ?? const [];
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
          'khentsgdz': [_track('A', 3)],
          'clairjassen': [_track('A', 4)],
        },
      );
      final provider = ArtistShowdownProvider(syncService: sync);
      await _waitFor(() => !provider.isLoading);
      expect(sync.calls, 2);

      await provider.selectArtist('Lana Del Rey');
      await _waitFor(() => !provider.isLoading);
      expect(provider.artist, 'Lana Del Rey');
      expect(sync.calls, 4);

      await provider.selectArtist('Ethel Cain');
      expect(provider.artist, 'Ethel Cain');
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
  });
}
