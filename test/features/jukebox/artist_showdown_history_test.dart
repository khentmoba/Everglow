import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/data/services/spotify_auth_service.dart';
import 'package:everglow/features/jukebox/data/services/spotify_player_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/artist_showdown_provider.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';
import 'package:everglow/features/jukebox/presentation/widgets/artist_showdown_card.dart';
import 'package:everglow/features/jukebox/presentation/widgets/artist_showdown_history_sheet.dart';

class _FakeSpotifyAuthService extends ChangeNotifier
    implements SpotifyAuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  String? get uid => 'test-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryFakeSync extends MusicSyncService {
  _HistoryFakeSync({
    required this.topTracks,
    required this.historyByUser,
  });

  final Map<String, List<TopMusicTrack>> topTracks;
  final Map<String, List<MusicStatus>> historyByUser;

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    int page = 1,
    String period = 'overall',
  }) async =>
      topTracks[username.toLowerCase()] ?? const [];

  @override
  Future<List<MusicStatus>> fetchRecentTracks(
    String username, {
    int limit = 5,
  }) async => const [];

  @override
  Future<List<MusicStatus>> fetchArtistHistory(
    String username, {
    required String artist,
    List<String> knownTracks = const [],
    int maxTracks = 12,
    int scrobblesPerTrack = 50,
    bool includeRecent = true,
  }) async =>
      historyByUser[username.toLowerCase()] ?? const [];

  @override
  Future<String?> fetchTrackArtwork({
    required String artist,
    required String track,
    String? mbid,
  }) async => null;

  // MusicStatsProvider enriches via fetchTrackMetadata (single call for
  // cover + album); without this the base implementation would attempt
  // real network calls in fake async.
  @override
  Future<TrackMetadata?> fetchTrackMetadata({
    required String artist,
    required String track,
    String? mbid,
  }) async => null;
}

Widget _buildHarness({
  required ArtistShowdownProvider showdown,
  MusicStatsProvider? stats,
  Widget? child,
}) {
  final spotifyAuth = _FakeSpotifyAuthService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ArtistShowdownProvider>.value(value: showdown),
      if (stats != null)
        ChangeNotifierProvider<MusicStatsProvider>.value(value: stats),
      ChangeNotifierProvider<SpotifyAuthService>.value(value: spotifyAuth),
      Provider<SpotifyPlayerService>(
        create: (_) => SpotifyPlayerService(spotifyAuth),
      ),
      ChangeNotifierProvider<AuthService>(create: (_) => _FakeAuthService()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child ?? const ArtistShowdownCard(),
      ),
    ),
  );
}

void main() {
  group('ArtistShowdown History Sheet & Integration', () {
    final khentPlay1 = MusicStatus(
      username: 'khentsgdz',
      trackName: 'American Teenager',
      artistName: 'Ethel Cain',
      albumName: 'Preacher\'s Daughter',
      isPlaying: false,
      spotifyUrl: 'https://spotify/american',
      timestamp: DateTime(2026, 9, 21, 14, 30),
    );
    final khentPlay2 = MusicStatus(
      username: 'khentsgdz',
      trackName: 'Strangers',
      artistName: 'Ethel Cain',
      albumName: 'Preacher\'s Daughter',
      isPlaying: false,
      spotifyUrl: 'https://spotify/strangers',
      timestamp: DateTime(2026, 9, 20, 10, 15),
    );
    final clairPlay1 = MusicStatus(
      username: 'clairjassen',
      trackName: 'American Teenager',
      artistName: 'Ethel Cain',
      albumName: 'Preacher\'s Daughter',
      isPlaying: false,
      spotifyUrl: 'https://spotify/american',
      timestamp: DateTime(2026, 9, 21, 16, 45),
    );

    testWidgets('ArtistShowdownCard displays History button in header and banner', (tester) async {
      final sync = _HistoryFakeSync(
        topTracks: const {
          'khentsgdz': [
            TopMusicTrack(
              rank: 1,
              trackName: 'American Teenager',
              artistName: 'Ethel Cain',
              playCount: 15,
              spotifyUrl: 'https://spotify',
            ),
          ],
          'clairjassen': [
            TopMusicTrack(
              rank: 1,
              trackName: 'American Teenager',
              artistName: 'Ethel Cain',
              playCount: 20,
              spotifyUrl: 'https://spotify',
            ),
          ],
        },
        historyByUser: {
          'khentsgdz': [khentPlay1, khentPlay2],
          'clairjassen': [clairPlay1],
        },
      );

      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);

      await tester.pumpWidget(_buildHarness(showdown: showdown, stats: stats));
      await tester.pump();
      await tester.pumpAndSettle();

      // Header button
      expect(find.text('History'), findsOneWidget);
      // Main banner
      expect(find.text('LISTENING HISTORY'), findsOneWidget);
      expect(find.text('When Khent & Clair played Ethel Cain'), findsOneWidget);
      expect(find.text('View timeline'), findsOneWidget);

      showdown.dispose();
      stats.dispose();
    });

    testWidgets('Tapping History button opens the history sheet with scrobbles', (tester) async {
      final sync = _HistoryFakeSync(
        topTracks: const {
          'khentsgdz': [
            TopMusicTrack(
              rank: 1,
              trackName: 'American Teenager',
              artistName: 'Ethel Cain',
              playCount: 15,
              spotifyUrl: 'https://spotify',
            ),
          ],
          'clairjassen': [
            TopMusicTrack(
              rank: 1,
              trackName: 'American Teenager',
              artistName: 'Ethel Cain',
              playCount: 20,
              spotifyUrl: 'https://spotify',
            ),
          ],
        },
        historyByUser: {
          'khentsgdz': [khentPlay1, khentPlay2],
          'clairjassen': [clairPlay1],
        },
      );

      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);

      await tester.pumpWidget(_buildHarness(showdown: showdown, stats: stats));
      await tester.pumpAndSettle();

      // Tap View timeline banner
      await tester.tap(find.text('View timeline'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify sheet is open
      expect(find.text('LISTENING TIMELINE'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.text('Khent'), findsWidgets);
      expect(find.text('Clair'), findsWidgets);

      // Verify scrobble information rendered
      expect(find.text('American Teenager'), findsWidgets);
      expect(find.text('Strangers'), findsWidgets);
      expect(find.text('KHENT'), findsWidgets);
      expect(find.text('CLAIR'), findsWidgets);

      showdown.dispose();
      stats.dispose();
    });

    testWidgets('History sheet filter switches between Both, Khent, and Clair', (tester) async {
      final sync = _HistoryFakeSync(
        topTracks: const {
          'khentsgdz': [
            TopMusicTrack(
              rank: 1,
              trackName: 'American Teenager',
              artistName: 'Ethel Cain',
              playCount: 15,
              spotifyUrl: 'https://spotify',
            ),
          ],
          'clairjassen': [],
        },
        historyByUser: {
          'khentsgdz': [khentPlay2], // Strangers only
          'clairjassen': [clairPlay1], // American Teenager only
        },
      );

      final showdown = ArtistShowdownProvider(syncService: sync);
      await showdown.loadArtistHistory();

      await tester.pumpWidget(_buildHarness(
        showdown: showdown,
        child: const ArtistShowdownHistorySheet(),
      ));
      await tester.pumpAndSettle();

      // Both are visible initially in the timeline
      expect(find.text('Strangers'), findsWidgets);
      expect(find.text('American Teenager'), findsWidgets);

      // Tap Khent filter pill
      await tester.tap(find.text('Khent'));
      await tester.pumpAndSettle();

      // Strangers (Khent) remains in timeline, American Teenager (Clair) is gone from timeline
      expect(find.text('Strangers'), findsWidgets);
      // Only the filter chip remains for American Teenager, timeline item is gone
      expect(find.text('CLAIR'), findsNothing);
      expect(find.text('KHENT'), findsOneWidget);

      // Tap Clair filter pill
      await tester.tap(find.text('Clair'));
      await tester.pumpAndSettle();

      // American Teenager (Clair) is in timeline, Strangers (Khent) is gone from timeline
      expect(find.text('American Teenager'), findsWidgets);
      expect(find.text('KHENT'), findsNothing);
      expect(find.text('CLAIR'), findsOneWidget);

      showdown.dispose();
    });

    testWidgets('History sheet displays empty state when no plays are found', (tester) async {
      final sync = _HistoryFakeSync(
        topTracks: const {},
        historyByUser: const {},
      );

      final showdown = ArtistShowdownProvider(syncService: sync);
      await showdown.loadArtistHistory();

      await tester.pumpWidget(_buildHarness(
        showdown: showdown,
        child: const ArtistShowdownHistorySheet(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No history found'), findsOneWidget);
      expect(
        find.text('Neither Khent nor Clair have scrobbled Ethel Cain yet, or timestamps have not synced.'),
        findsOneWidget,
      );

      showdown.dispose();
    });
  });
}
