import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/music_sync_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/music_stats_provider.dart';
import 'package:everglow/features/jukebox/presentation/widgets/music_stats_section.dart';
import 'package:everglow/features/jukebox/presentation/widgets/stats_track_rows.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';

/// Regression guard for the leaderboard thumbnails.
///
/// A row must attempt the network image whenever the track carries a usable
/// cover and fall back to the music-note tile only when the cover is missing
/// (or a Last.fm placeholder). Never `pumpAndSettle` here: podium shimmer
/// and sparkle badges animate forever by design.
TopMusicTrack _rowTrack({
  required String name,
  required int rank,
  String? imageUrl,
}) => TopMusicTrack(
  rank: rank,
  trackName: name,
  artistName: 'Some Artist',
  playCount: 100,
  imageUrl: imageUrl,
  spotifyUrl: 'https://open.spotify.com/search/x',
);

Future<void> _pumpRow(WidgetTester tester, TopMusicTrack track) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TopTrackRow(track: track, username: 'khentsgdz', maxPlays: 100),
      ),
    ),
  );
  await tester.pump();
}

Finder _networkImageWith(String url) => find.byWidgetPredicate(
  (w) => w is AppNetworkImage && w.imageUrl == url,
);

void main() {
  group('TopTrackRow thumbnails', () {
    testWidgets('podium row attempts the cover art', (tester) async {
      const url = 'https://img.example/cover.png';
      await _pumpRow(tester, _rowTrack(name: 'Fine Line', rank: 1, imageUrl: url));

      expect(_networkImageWith(url), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    });

    testWidgets('podium row falls back when the cover is missing', (
      tester,
    ) async {
      await _pumpRow(tester, _rowTrack(name: 'Fine Line', rank: 1));

      expect(find.byType(AppNetworkImage), findsNothing);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('podium row falls back for Last.fm placeholder art', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _rowTrack(
          name: 'Style',
          rank: 2,
          imageUrl:
              'https://lastfm-img.freetls.fastly.net/i/u/300x300/'
              '2a96cbd8b46e442fc41c2b86b821562f.png',
        ),
      );

      expect(find.byType(AppNetworkImage), findsNothing);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('non-podium row attempts the cover art', (tester) async {
      const url = 'https://img.example/cover5.png';
      await _pumpRow(tester, _rowTrack(name: 'Dust Bowl', rank: 5, imageUrl: url));

      expect(_networkImageWith(url), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    });

    testWidgets('non-podium row falls back when the cover is missing', (
      tester,
    ) async {
      await _pumpRow(tester, _rowTrack(name: 'Dust Bowl', rank: 5));

      expect(find.byType(AppNetworkImage), findsNothing);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });
  });

  group('MusicStatsSection thumbnails', () {
    testWidgets('art flows from the provider into each leaderboard', (
      tester,
    ) async {
      const khentArt = 'https://img.example/khent-cover.png';
      final sync = _SectionFakeSync(
        khentTracks: [
          _rowTrack(name: 'Fine Line', rank: 1, imageUrl: khentArt),
        ],
        // Clair's chart-topper has no cover anywhere: it must render the
        // fallback tile instead of an empty box.
        clairTracks: [_rowTrack(name: 'Sweet Home', rank: 1)],
      );
      final provider = MusicStatsProvider(syncService: sync);
      // Disposed inline (not via addTearDown): the pending-timer check runs
      // before tear-downs, so the polling timers must already be cancelled
      // when the body returns.
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChangeNotifierProvider.value(
                  value: provider,
                  child: const MusicStatsSection(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(provider.isLoading, isFalse);
        expect(_networkImageWith(khentArt), findsOneWidget);
        expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      } finally {
        provider.dispose();
      }
    });
  });
}

class _SectionFakeSync extends MusicSyncService {
  _SectionFakeSync({required this.khentTracks, required this.clairTracks});

  final List<TopMusicTrack> khentTracks;
  final List<TopMusicTrack> clairTracks;

  @override
  Future<List<TopMusicTrack>> fetchTopTracks(
    String username, {
    int limit = 10,
    String period = 'overall',
  }) async => username == 'clairjassen' ? clairTracks : khentTracks;

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
