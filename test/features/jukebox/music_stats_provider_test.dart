import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';

TopMusicTrack _artlessTrack(String name, int plays, int rank) => TopMusicTrack(
  rank: rank,
  trackName: name,
  artistName: 'Some Artist',
  playCount: plays,
  imageUrl: null,
  spotifyUrl: 'https://open.spotify.com/search/x',
);

/// Simulates a rate-limited boot: the first artwork lookup per track fails,
/// later lookups succeed. Guards against caching the miss forever.
class _FlakyArtworkSync extends MusicSyncService {
  _FlakyArtworkSync({required this.khentTracks, required this.clairTracks});

  final List<TopMusicTrack> khentTracks;
  final List<TopMusicTrack> clairTracks;
  final Map<String, int> artworkCalls = {};

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    String period = 'overall',
  }) async =>
      // Different tracks per user so neither lane can rescue the other
      // through the shared artwork cache.
      username == 'clairjassen' ? clairTracks : khentTracks;

  @override
  Future<List<MusicStatus>> fetchRecentTracks(
    String username, {
    int limit = 5,
  }) async => const [];

  @override
  Future<int> fetchUserTotalPlays(String username) async => 100;

  @override
  Future<String?> fetchTrackArtwork({
    required String artist,
    required String track,
    String? mbid,
  }) async {
    final key = '$artist $track';
    final calls = (artworkCalls[key] ?? 0) + 1;
    artworkCalls[key] = calls;
    if (calls == 1) return null;
    return 'https://img.example/${Uri.encodeComponent(track)}.png';
  }
}

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

    testWidgets('retries artwork after a transient enrichment failure', (
      tester,
    ) async {
      final sync = _FlakyArtworkSync(
        khentTracks: [_artlessTrack('Fine Line', 85, 1)],
        clairTracks: [_artlessTrack('Sweet Home', 84, 1)],
      );
      // Zero cooldown: pumped fake time never advances DateTime.now(), so
      // this stands in for the cooldown having expired in production.
      final provider = MusicStatsProvider(
        syncService: sync,
        artworkRetryCooldown: Duration.zero,
      );
      // Disposed inline (not via addTearDown): the framework's pending-timer
      // check runs before tear-downs, so the polling timers must already be
      // cancelled when the body returns.
      try {
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(provider.isLoading, isFalse);
        expect(provider.topTracks, hasLength(1));
        // First enrichment wave failed: no cover yet, but the miss must
        // stay retryable.
        expect(provider.topTracks.first.imageUrl, isNull);

        // The 10-minute top-tracks timer refreshes and re-enriches.
        await tester.pump(const Duration(minutes: 11));
        await tester.pump(const Duration(seconds: 1));

        expect(provider.topTracks.first.imageUrl, isNotNull);
        expect(sync.artworkCalls['Some Artist Fine Line'], greaterThan(1));
      } finally {
        provider.dispose();
      }
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
