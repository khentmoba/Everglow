import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/books/data/models/book_search_result.dart';
import 'package:everglow/features/books/data/services/book_catalog_service.dart';
import 'package:everglow/features/books/presentation/widgets/advanced_search_sheet.dart';
import 'package:everglow/features/books/presentation/widgets/zlib_result_row.dart';

BookSearchResult _result() {
  return const BookSearchResult(
    title:
        'A Very Long Book Title That Must Ellipsize Gracefully Instead Of Overflowing The Dense Row',
    author: 'An Author With An Extremely Long Name That Also Must Ellipsize',
    year: '1925',
    language: 'English',
    publisher: 'A Publisher With A Long Name',
    filetype: 'epub',
    sizeMb: 2.9,
    sourceLabel: 'Project Gutenberg',
    downloadUrls: {'epub': 'https://example.com/book.epub'},
  );
}

Future<void> _pumpRow(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ZlibResultRow(
              result: _result(),
              onOpen: () {},
              onDownload: () {},
              onSave: () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('ZlibResultRow has no overflow on a 360px phone', (tester) async {
    await _pumpRow(tester, const Size(360, 800));
    final row = tester.getRect(find.byType(ZlibResultRow));
    expect(row.right, lessThanOrEqualTo(360.1));
    expect(find.textContaining('A Very Long Book Title'), findsOneWidget);
    expect(find.textContaining('EPUB, 2.9 MB'), findsOneWidget);
  });

  testWidgets('ZlibResultRow has no overflow on an 810px tablet', (
    tester,
  ) async {
    await _pumpRow(tester, const Size(810, 1080));
    final row = tester.getRect(find.byType(ZlibResultRow));
    expect(row.right, lessThanOrEqualTo(810.1));
  });

  testWidgets('AdvancedSearchSheet applies title + year range filters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    BookSearchFilters? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await AdvancedSearchSheet.open(
                  context,
                  BookSearchFilters.none,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Search'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Pride and Prejudice').hitTestable(),
      'Dune',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. 1900').hitTestable(),
      '1960',
    );
    await tester.tap(find.text('Search with these filters'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.title, 'Dune');
    expect(picked!.yearFrom, 1960);
    expect(picked!.summary.contains('Title'), isTrue);
  });

  testWidgets('AdvancedSearchSheet rejects out-of-range years', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    BookSearchFilters? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await AdvancedSearchSheet.open(
                  context,
                  BookSearchFilters.none,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. 1900').hitTestable(),
      '99',
    );
    await tester.tap(find.text('Search with these filters'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.yearFrom, isNull);
    expect(picked!.isEmpty, isTrue);
  });
}
