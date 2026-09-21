import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/models/top_music_track.dart';
import 'package:everglow/features/jukebox/data/services/spotify_auth_service.dart';
import 'package:everglow/features/jukebox/data/services/spotify_player_service.dart';
import 'package:everglow/features/jukebox/presentation/widgets/listen_along_popup.dart';
import 'package:everglow/features/jukebox/presentation/widgets/stats_track_rows.dart';

class _FakeSpotifyAuthService extends ChangeNotifier
    implements SpotifyAuthService {
  @override
  bool get isLinked => false;

  @override
  String? get spotifyUserId => null;

  @override
  String? get displayName => null;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<void> linkSpotify() async {}

  @override
  Future<bool> handleCallback(String code) async => true;

  @override
  Future<void> unlink() async {}

  @override
  Future<String?> getStoredAccessToken() async => null;

  @override
  Future<Map<String, dynamic>?> fetchCurrentlyPlaying() async => null;
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  String? get uid => 'test-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child) {
  final spotifyAuth = _FakeSpotifyAuthService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SpotifyAuthService>.value(
        value: spotifyAuth,
      ),
      Provider<SpotifyPlayerService>(
        create: (_) => SpotifyPlayerService(spotifyAuth),
      ),
      ChangeNotifierProvider<AuthService>(
        create: (_) => _FakeAuthService(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ListenAlongPopup album display', () {
    testWidgets('displays album name when provided in MusicStatus', (tester) async {
      final status = MusicStatus(
        username: 'khent',
        trackName: 'Cruel Summer',
        artistName: 'Taylor Swift',
        albumName: 'Lover',
        isPlaying: false,
        spotifyUrl: 'https://open.spotify.com/search/x',
      );

      await tester.pumpWidget(_wrap(ListenAlongPopup(status: status)));
      await tester.pump();

      expect(find.text('Cruel Summer'), findsOneWidget);
      expect(find.text('Taylor Swift'), findsOneWidget);
      expect(find.text('Lover'), findsOneWidget);
      expect(find.text('No Album'), findsNothing);
    });

    testWidgets('does not show No Album text when albumName is No Album or empty', (
      tester,
    ) async {
      final statusWithNoAlbum = MusicStatus(
        username: 'khent',
        trackName: 'Cruel Summer',
        artistName: 'Taylor Swift',
        albumName: 'No Album',
        isPlaying: false,
        spotifyUrl: 'https://open.spotify.com/search/x',
      );

      await tester.pumpWidget(_wrap(ListenAlongPopup(status: statusWithNoAlbum)));
      await tester.pump();

      expect(find.text('No Album'), findsNothing);

      final statusWithEmpty = MusicStatus(
        username: 'khent',
        trackName: 'Cruel Summer',
        artistName: 'Taylor Swift',
        albumName: '',
        isPlaying: false,
        spotifyUrl: 'https://open.spotify.com/search/x',
      );

      await tester.pumpWidget(_wrap(ListenAlongPopup(status: statusWithEmpty)));
      await tester.pump();

      expect(find.text('No Album'), findsNothing);
    });

    testWidgets('TopTrackRow passes albumName to ListenAlongPopup on tap', (
      tester,
    ) async {
      final track = const TopMusicTrack(
        rank: 1,
        trackName: 'Cruel Summer',
        artistName: 'Taylor Swift',
        playCount: 150,
        spotifyUrl: 'https://open.spotify.com/search/x',
        albumName: 'Lover',
      );

      await tester.pumpWidget(
        _wrap(
          TopTrackRow(
            track: track,
            username: 'khentsgdz',
            maxPlays: 150,
          ),
        ),
      );
      await tester.pump();

      // Tap the row to open ListenAlongPopup
      await tester.tap(find.text('Cruel Summer'));
      await tester.pump();

      expect(find.text('Lover'), findsOneWidget);
      expect(find.text('No Album'), findsNothing);
    });
  });
}
