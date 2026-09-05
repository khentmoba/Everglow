import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/presentation/widgets/book_cover_card.dart';

BookItem _book(int i) {
  return BookItem(
    id: 'b$i',
    workKey: '/works/OL2712W',
    title: 'A Very Long Book Title Number $i That Must Ellipsize Instead Of Overflowing',
    status: 'to-read',
    addedAt: DateTime.utc(2026, 1, 1),
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
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (context, i) => BookCoverCard(item: _book(i), onTap: () {}),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('BookCoverCard grid has no overflow on a 360px phone', (tester) async {
    await _pumpGrid(tester, const Size(360, 800), 2);
    final first = tester.getRect(find.byType(BookCoverCard).first);
    expect(first.right, lessThanOrEqualTo(360.1));
  });

  testWidgets('BookCoverCard grid has no overflow on an 810px tablet', (tester) async {
    await _pumpGrid(tester, const Size(810, 1080), 4);
    final first = tester.getRect(find.byType(BookCoverCard).first);
    expect(first.right, lessThanOrEqualTo(810.1));
  });
}
