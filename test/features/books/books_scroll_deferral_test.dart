import 'dart:async';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/books/data/models/book_search_result.dart';
import 'package:everglow/features/books/data/services/book_catalog_service.dart';
import 'package:everglow/features/books/presentation/screens/books_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => 'demo';

  @override
  bool get isCoupleUser => false;

  @override
  bool get isCinemaOnlyUser => false;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedRecentCatalog implements BookCatalogService {
  final Completer<List<BookSearchResult>> recentCompleter =
      Completer<List<BookSearchResult>>();

  @override
  Future<List<BookSearchResult>> mostPopular({int limit = 20}) async => const [
    BookSearchResult(title: 'Immediate Popular Book', author: 'Author A'),
  ];

  @override
  Future<List<BookSearchResult>> recentlyAdded({int limit = 20}) =>
      recentCompleter.future;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'BooksScreen defers committing arriving feed rows while vertically scrolling and flushes on scroll end',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _DelayedRecentCatalog();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _FakeAuth(),
          child: MaterialApp(home: BooksScreen(catalog: catalog)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Immediate Popular Book'), findsWidgets);
      expect(find.text('Deferred Recent Book'), findsNothing);

      final scrollCenter = tester.getCenter(find.byType(CustomScrollView).first);
      final gesture = await tester.startGesture(scrollCenter);
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();

      catalog.recentCompleter.complete(const [
        BookSearchResult(title: 'Deferred Recent Book', author: 'Author B'),
      ]);
      await tester.pump();
      expect(find.text('Deferred Recent Book'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Deferred Recent Book'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
