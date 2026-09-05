import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/feature_section.dart';

Widget _section() {
  return FeatureSection(
    icon: Icons.history_rounded,
    hue: Colors.amber,
    title: 'A Very Long Dashboard Section Title That Must Ellipsize Instead Of Overflowing',
    subtitle: 'An extra long subtitle line that exercises wrapping on narrow phone screens',
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () {},
    child: const Text(
      'Body copy that pads out the card so the header, trailing chevron, and content all share one tight row.',
    ),
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
          children: [_section(), _section()],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('FeatureSection has no overflow on a 360px phone', (tester) async {
    await _pump(tester, const Size(360, 800));
    final first = tester.getRect(find.byType(FeatureSection).first);
    expect(first.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('FeatureSection has no overflow on an 810px tablet', (tester) async {
    await _pump(tester, const Size(810, 1080));
    final first = tester.getRect(find.byType(FeatureSection).first);
    expect(first.right, lessThanOrEqualTo(810.1));
  });
}
