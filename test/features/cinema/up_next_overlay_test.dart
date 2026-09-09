import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/cinema/data/models/next_episode.dart';
import 'package:everglow/features/cinema/presentation/widgets/up_next_overlay.dart';

void main() {
  const next = NextEpisode(season: 1, episode: 2, name: 'The Middle');

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  group('UpNextOverlay', () {
    testWidgets('shows countdown, next label, and both actions', (
      tester,
    ) async {
      var played = false;
      var cancelled = false;

      await tester.pumpWidget(
        wrap(
          UpNextOverlay(
            next: next,
            secondsLeft: 7,
            totalSeconds: 10,
            onPlayNow: () => played = true,
            onCancel: () => cancelled = true,
          ),
        ),
      );

      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('S1 E2'), findsOneWidget);
      expect(find.text('The Middle'), findsOneWidget);
      expect(find.text('Next episode in 7...'), findsOneWidget);
      expect(find.text('Play now'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Play now'));
      expect(played, isTrue);

      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });

    testWidgets('hides the title line when TMDB has no name', (tester) async {
      await tester.pumpWidget(
        wrap(
          const UpNextOverlay(
            next: NextEpisode(season: 2, episode: 1),
            secondsLeft: 10,
            totalSeconds: 10,
            onPlayNow: _noop,
            onCancel: _noop,
          ),
        ),
      );

      expect(find.text('S2 E1'), findsOneWidget);
      expect(find.text('Next episode in 10...'), findsOneWidget);
    });
  });

  group('NextEpisodeButton', () {
    testWidgets('shows the next label and taps through', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(NextEpisodeButton(next: next, onTap: () => tapped = true)),
      );

      expect(find.text('Next: S1 E2'), findsOneWidget);
      await tester.tap(find.text('Next: S1 E2'));
      expect(tapped, isTrue);
    });
  });
}

void _noop() {}
