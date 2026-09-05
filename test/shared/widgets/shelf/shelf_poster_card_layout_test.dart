import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';

Widget _card(int i) {
  return ShelfPosterCard(
    imageUrl: '',
    title: 'A Very Long Shelf Title Number ' + i.toString() + ' That Must Ellipsize Instead Of Overflowing',
    subtitle: '2026 - An extra long subtitle line for wrapping stress',
    badge: 'TOP 10',
    rankNumber: (i + 1).toDouble(),
    onTap: () {},
  );
}

Future<void> _pumpGrid(WidgetTester tester, Size size, int columns) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 0.66,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (context, i) => _card(i),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('ShelfPosterCard grid has no overflow on a 360px phone', (tester) async {
    await _pumpGrid(tester, const Size(360, 800), 2);
    final first = tester.getRect(find.byType(ShelfPosterCard).first);
    expect(first.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('ShelfPosterCard grid has no overflow on an 810px tablet', (tester) async {
    await _pumpGrid(tester, const Size(810, 1080), 4);
    final first = tester.getRect(find.byType(ShelfPosterCard).first);
    expect(first.right, lessThanOrEqualTo(810.1));
  });
}
