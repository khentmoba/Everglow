import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/play_zone/presentation/screens/play_zone_hub_screen.dart';
import 'package:everglow/shared/widgets/everglow/everglow_button.dart';

Widget _card() {
  return PlayZoneGameCard(
    title:
        'A Very Long Play Zone Game Title That Must Wrap Or Ellipsize Elegantly Without Overflowing',
    subtitle:
        'An extra long descriptive subtitle explaining game mechanics, rules, and couple interactions for Clair and Khent on small mobile screens.',
    badge: 'ARCADE · FAST 60 FPS',
    icon: Icons.sports_tennis_rounded,
    accent: Colors.amber,
    tags: const ['1v1 Matchmaking', 'Solo Tournament', 'Smooth Physics'],
    actions: [
      EverglowButton(
        label: 'Solo Tournament',
        icon: Icons.sports_tennis_rounded,
        onPressed: () {},
      ),
      EverglowButton.glass(
        label: '1v1 Match',
        icon: Icons.people_rounded,
        onPressed: () {},
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [_card(), _card()],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('PlayZoneGameCard has no overflow on a 360px phone', (
    tester,
  ) async {
    await _pump(tester, const Size(360, 800));
    final first = tester.getRect(find.byType(PlayZoneGameCard).first);
    expect(first.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('PlayZoneGameCard has no overflow on an 810px tablet', (
    tester,
  ) async {
    await _pump(tester, const Size(810, 1080));
    final first = tester.getRect(find.byType(PlayZoneGameCard).first);
    expect(first.right, lessThanOrEqualTo(810.1));
  });

  testWidgets('PlayZoneGameCard has no overflow on a 1200px desktop', (
    tester,
  ) async {
    await _pump(tester, const Size(1200, 900));
    final first = tester.getRect(find.byType(PlayZoneGameCard).first);
    expect(first.right, lessThanOrEqualTo(1200.1));
  });
}
