import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/artist_showdown_provider.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';
import 'package:everglow/features/jukebox/presentation/widgets/artist_showdown_card.dart';

TopMusicTrack _track(String artist, String name, int plays) => TopMusicTrack(
  rank: 1,
  trackName: name,
  artistName: artist,
  playCount: plays,
  imageUrl: null,
  spotifyUrl: 'https://open.spotify.com/search/x',
);

/// Serves both providers: artist tracks per user per artist (showdown) and
/// top tracks per user (quick picks).
class _ShowdownFakeSync extends MusicSyncService {
  _ShowdownFakeSync({
    required this.artistTracks,
    this.topTracks = const {},
  });

  /// '$username|$artist'.toLowerCase() -> tracks.
  final Map<String, List<TopMusicTrack>> artistTracks;
  final Map<String, List<TopMusicTrack>> topTracks;

  @override
  Future<List<TopMusicTrack>> fetchArtistTracks(
    String username,
    String artist, {
    int limit = 200,
  }) async =>
      artistTracks['${username.toLowerCase()}|${artist.toLowerCase()}'] ??
      const [];

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    String period = 'overall',
  }) async =>
      topTracks[username.toLowerCase()] ?? const [];

  @override
  Future<List<MusicStatus>> fetchRecentTracks(
    String username, {
    int limit = 5,
  }) async => const [];

  @override
  Future<int> fetchUserTotalPlays(String username) async => 0;

  @override
  Future<String?> fetchTrackArtwork({
    required String artist,
    required String track,
    String? mbid,
  }) async => null;
}

Future<void> _pumpCard(
  WidgetTester tester,
  MusicSyncService sync, {
  required ArtistShowdownProvider showdown,
  required MusicStatsProvider stats,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: showdown),
              ChangeNotifierProvider.value(value: stats),
            ],
            child: const ArtistShowdownCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('ArtistShowdownCard', () {
    testWidgets('renders the head-to-head total and song rows', (
      tester,
    ) async {
      final sync = _ShowdownFakeSync(
        artistTracks: {
          'khentsgdz|ethel cain': [_track('Ethel Cain', 'Strangers', 10)],
          'clairjassen|ethel cain': [
            _track('Ethel Cain', 'Strangers', 25),
            _track('Ethel Cain', 'American Teenager', 40),
          ],
        },
        topTracks: {
          'khentsgdz': [_track('Ethel Cain', 'Strangers', 10)],
          'clairjassen': [_track('Lana Del Rey', 'Video Games', 99)],
        },
      );
      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);
      // Disposed inline (not via addTearDown): the pending-timer check runs
      // before tear-downs, so polling timers must be cancelled already.
      try {
        await _pumpCard(tester, sync, showdown: showdown, stats: stats);

        expect(showdown.isLoading, isFalse);
        expect(find.text('ARTIST SHOWDOWN'), findsOneWidget);
        expect(find.text('10'), findsOneWidget); // Khent total
        expect(find.text('65'), findsOneWidget); // Clair total
        expect(find.text('American Teenager'), findsOneWidget);
        expect(find.text('Strangers'), findsOneWidget);
        // Leader crown sits on Clair's block.
        expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
        // Quick picks: Ethel pinned first, then Top-10 artists.
        expect(find.text('Ethel Cain'), findsWidgets);
        expect(find.text('Lana Del Rey'), findsOneWidget);
      } finally {
        showdown.dispose();
        stats.dispose();
      }
    });

    testWidgets('tapping a quick pick switches artists', (tester) async {
      final sync = _ShowdownFakeSync(
        artistTracks: {
          'khentsgdz|ethel cain': [_track('Ethel Cain', 'Strangers', 10)],
          'clairjassen|ethel cain': [_track('Ethel Cain', 'Strangers', 5)],
          'khentsgdz|lana del rey': [_track('Lana Del Rey', 'Video Games', 7)],
          'clairjassen|lana del rey': [
            _track('Lana Del Rey', 'Video Games', 3),
          ],
        },
        topTracks: {
          'khentsgdz': [_track('Lana Del Rey', 'Video Games', 7)],
          'clairjassen': const [],
        },
      );
      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);
      try {
        await _pumpCard(tester, sync, showdown: showdown, stats: stats);
        expect(showdown.artist, 'Ethel Cain');

        await tester.tap(find.text('Lana Del Rey').first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(showdown.artist, 'Lana Del Rey');
        expect(find.text('Video Games'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      } finally {
        showdown.dispose();
        stats.dispose();
      }
    });

    testWidgets('shows the empty state when nobody played the artist', (
      tester,
    ) async {
      final sync = _ShowdownFakeSync(artistTracks: const {});
      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);
      try {
        await _pumpCard(tester, sync, showdown: showdown, stats: stats);

        expect(find.text('No Ethel Cain plays yet'), findsOneWidget);
        expect(find.text('Play one and take the lead.'), findsOneWidget);
      } finally {
        showdown.dispose();
        stats.dispose();
      }
    });
  });
}
