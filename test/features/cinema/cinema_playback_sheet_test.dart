import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/cinema_playback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final episode = MediaItem(
    id: 'demo',
    tmdbId: 42,
    title: 'A very long fictional series title for our quiet evening',
    mediaType: 'tv',
    posterPath: '',
    backdropPath: '',
    year: '2026',
    status: 'watching-self',
    userName: 'demo',
    addedAt: DateTime(2026),
    currentSeason: 2,
    currentEpisode: 3,
    currentTimestamp: 1234,
    durationSeconds: 3600,
  );

  for (final width in [320.0, 430.0, 810.0]) {
    testWidgets('playback choices fit ${width}px with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.gamifiedTheme,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 932),
                textScaler: const TextScaler.linear(1.5),
              ),
              child: CinemaPlaybackSheet(item: episode),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resume at 0:20:34'), findsOneWidget);
      expect(find.text('Season 2, episode 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final action in {
    'Resume at 0:20:34': 'resume',
    'Restart this episode': 'restart',
    'Choose a different episode': 'episodes',
    'Mark series finished': 'finished',
    'Remove from Continue Watching': 'remove',
  }.entries) {
    testWidgets('${action.key} returns the intended action', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.gamifiedTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CinemaPlaybackSheet(item: episode),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action.key));
      await tester.pumpAndSettle();
      expect(selected, action.value);
      expect(tester.takeException(), isNull);
    });
  }
}
