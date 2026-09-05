import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/anime/presentation/widgets/animex/animex_buttons.dart';

void main() {
  testWidgets('primary button renders label and fires tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeXPrimaryButton(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Play'), findsOneWidget);
    await tester.tap(find.text('Play'));
    expect(taps, 1);
  });

  testWidgets('all variants render without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AnimeXPrimaryButton(label: 'P'),
              AnimeXSecondaryButton(label: 'S'),
              AnimeXGhostButton(label: 'G'),
              AnimeXWatchNowButton(label: 'W'),
              AnimeXLoginButton(label: 'L', icon: Icons.login_rounded),
              AnimeXIconButton(icon: Icons.search_rounded, tooltip: 'Search'),
            ],
          ),
        ),
      ),
    );

    for (final label in ['P', 'S', 'G', 'W', 'L']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byTooltip('Search'), findsOneWidget);
  });
}
