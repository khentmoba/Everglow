import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/artist_showdown_provider.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';
import 'package:everglow/features/jukebox/presentation/widgets/artist_showdown_card.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';

TopMusicTrack _track(
  String artist,
  String name,
  int plays, {
  String? imageUrl,
}) => TopMusicTrack(
  rank: 1,
  trackName: name,
  artistName: artist,
  playCount: plays,
  imageUrl: imageUrl,
  spotifyUrl: 'https://open.spotify.com/search/x',
);

/// Finds a `Text.rich` span line (the song rows render counts as rich text,
/// so plain `find.text` never matches them).
Finder _richTextContaining(String needle) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.textSpan?.toPlainText().contains(needle) ?? false),
);

/// Serves both providers from each user's all-time top tracks. The showdown
/// filters by artist locally (live `user.gettoptracks` path); quick picks
/// read the same top-10s directly.
class _ShowdownFakeSync extends MusicSyncService {
  _ShowdownFakeSync({required this.topTracks});

  /// Last.fm username (lowercased) -> full top tracks.
  final Map<String, List<TopMusicTrack>> topTracks;

  @override
  Future<List<TopMusicTrack>> fetchArtistTracks(
    String username,
    String artist, {
    int limit = 200,
  }) async {
    // The showdown must NOT use the deprecated user.getartisttracks
    // endpoint (stale backend, no playcounts). Fail loudly on regression.
    throw UnimplementedError('showdown should filter fetchTopTracks');
  }

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
        topTracks: {
          'khentsgdz': [_track('Ethel Cain', 'Strangers', 10)],
          'clairjassen': [
            _track('Ethel Cain', 'Strangers', 25),
            _track('Ethel Cain', 'American Teenager', 40),
            _track('Lana Del Rey', 'Video Games', 99),
          ],
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
        topTracks: {
          'khentsgdz': [
            _track('Ethel Cain', 'Strangers', 10),
            _track('Lana Del Rey', 'Video Games', 7),
          ],
          'clairjassen': [
            _track('Ethel Cain', 'Strangers', 5),
            _track('Lana Del Rey', 'Video Games', 3),
          ],
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

    testWidgets('song rows spell out Khent and Clair', (tester) async {
      final sync = _ShowdownFakeSync(
        topTracks: {
          'khentsgdz': [_track('Ethel Cain', 'Strangers', 10)],
          'clairjassen': [_track('Ethel Cain', 'Strangers', 25)],
        },
      );
      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);
      try {
        await _pumpCard(tester, sync, showdown: showdown, stats: stats);

        expect(_richTextContaining('Khent'), findsOneWidget);
        expect(_richTextContaining('Clair'), findsOneWidget);
      } finally {
        showdown.dispose();
        stats.dispose();
      }
    });

    testWidgets('song rows attempt cover art and skip placeholders', (
      tester,
    ) async {
      const realArt = 'https://img.example/strangers.png';
      const placeholder =
          'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
          '2a96cbd8b46e442fc41c2b86b821562f.png';
      final sync = _ShowdownFakeSync(
        topTracks: {
          'khentsgdz': [
            _track('Ethel Cain', 'Strangers', 10, imageUrl: realArt),
            _track('Ethel Cain', 'Dust Bowl', 9, imageUrl: placeholder),
          ],
          'clairjassen': [
            _track('Ethel Cain', 'Strangers', 25, imageUrl: realArt),
            _track('Ethel Cain', 'Dust Bowl', 4, imageUrl: placeholder),
          ],
        },
      );
      final showdown = ArtistShowdownProvider(syncService: sync);
      final stats = MusicStatsProvider(syncService: sync);
      try {
        await _pumpCard(tester, sync, showdown: showdown, stats: stats);

        expect(
          find.byWidgetPredicate(
            (w) => w is AppNetworkImage && w.imageUrl == realArt,
          ),
          findsOneWidget,
        );
        // Placeholder cover falls back to the music-note tile.
        expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      } finally {
        showdown.dispose();
        stats.dispose();
      }
    });

    testWidgets('shows the empty state when nobody played the artist', (
      tester,
    ) async {
      final sync = _ShowdownFakeSync(topTracks: const {});
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
