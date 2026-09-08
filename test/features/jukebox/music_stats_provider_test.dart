import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';

TopMusicTrack _topTrack(String name, int plays) => TopMusicTrack(
  rank: 1,
  trackName: name,
  artistName: 'Some Artist',
  playCount: plays,
  imageUrl: 'https://example.com/cover.png',
  spotifyUrl: 'https://open.spotify.com/search/x',
);

MusicStatus _recent(String name) => MusicStatus(
  username: 'khentsgdz',
  trackName: name,
  artistName: 'Some Artist',
  albumName: 'Some Album',
  imageUrl: 'https://example.com/cover.png',
  isPlaying: false,
  spotifyUrl: 'https://open.spotify.com/search/x',
  timestamp: DateTime.utc(2026, 9, 8),
);

class _FakeSync extends MusicSyncService {
  _FakeSync({
    this.topTracks = const [],
    this.recentTracks = const [],
    this.totalPlays = 0,
  });

  final List<TopMusicTrack> topTracks;
  final List<MusicStatus> recentTracks;
  final int totalPlays;

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    String period = 'overall',
  }) async => topTracks;

  @override
  Future<List<MusicStatus>> fetchRecentTracks(
    String username, {
    int limit = 5,
  }) async => recentTracks;

  @override
  Future<int> fetchUserTotalPlays(String username) async => totalPlays;
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
  group('MusicStatsProvider leaderboard', () {
    test('populates the Top 10 from fetchTopTracks', () async {
      final provider = MusicStatsProvider(
        syncService: _FakeSync(
          topTracks: [_topTrack('Dulo Ng Hangganan', 179)],
          recentTracks: [_recent('love.')],
          totalPlays: 4243,
        ),
      );
      addTearDown(provider.dispose);

      await _waitFor(() => !provider.isLoading);

      expect(provider.topTracks, hasLength(1));
      expect(provider.topTracks.first.trackName, 'Dulo Ng Hangganan');
      expect(provider.topTracks.first.playCount, 179);
      expect(provider.recentTracks, hasLength(1));
      expect(provider.khentTotalPlays, 4243);
      expect(provider.hasData, isTrue);
    });

    test('a failed boot fetch surfaces empty state without throwing', () async {
      final provider = MusicStatsProvider(
        syncService: _FakeSync(),
      );
      addTearDown(provider.dispose);

      await _waitFor(() => !provider.isLoading);

      expect(provider.topTracks, isEmpty);
      expect(provider.recentTracks, isEmpty);
      expect(provider.hasData, isFalse);
    });
  });
}
