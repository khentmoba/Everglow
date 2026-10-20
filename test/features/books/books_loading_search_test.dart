import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/books/data/models/book_search_result.dart';
import 'package:everglow/features/books/data/services/book_catalog_service.dart';
import 'package:everglow/features/books/presentation/screens/books_screen.dart';

class _Auth extends ChangeNotifier implements AuthService {
  @override
  bool get isCoupleUser => false;
  @override
  bool get isCinemaOnlyUser => true;
  @override
  String? get currentUser => 'demo';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog implements BookCatalogService {
  int homeCalls = 0;
  int searchCalls = 0;
  final recent = Completer<List<BookSearchResult>>();
  final requests = <String, Completer<CatalogPage>>{};
  final partials = <String, void Function(CatalogPage)>{};
  @override
  Future<List<BookSearchResult>> mostPopular({int limit = 20}) {
    homeCalls++;
    return Future.value([
      const BookSearchResult(title: 'Available popular book'),
    ]);
  }

  @override
  Future<List<BookSearchResult>> recentlyAdded({int limit = 20}) {
    homeCalls++;
    return recent.future;
  }

  @override
  Future<CatalogPage> searchPaged(
    String query, {
    void Function(CatalogPage page)? onPartial,
    String? filetype,
    String? language,
    BookSort sort = BookSort.relevant,
    int limit = 30,
    int offset = 0,
    BookSearchFilters filters = BookSearchFilters.none,
  }) {
    searchCalls++;
    if (onPartial != null) partials[query] = onPartial;
    return (requests[query] = Completer<CatalogPage>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(
    WidgetTester tester,
    _Catalog catalog, {
    String query = '',
  }) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          home: BooksScreen(catalog: catalog, initialQuery: query),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'search deep link skips home feeds and rejects a late older response',
    (tester) async {
      final catalog = _Catalog();
      await mount(tester, catalog, query: 'old');
      expect(catalog.homeCalls, 0);
      await tester.enterText(find.byType(TextField).first, 'new');
      await tester.pump(const Duration(milliseconds: 501));
      catalog.requests['new']!.complete(
        const CatalogPage(
          results: [BookSearchResult(title: 'New result')],
          total: 1,
          hasMore: false,
        ),
      );
      await tester.pump();
      catalog.requests['old']!.complete(
        const CatalogPage(
          results: [BookSearchResult(title: 'Old result')],
          total: 1,
          hasMore: false,
        ),
      );
      await tester.pump();
      expect(find.text('New result'), findsOneWidget);
      expect(find.text('Old result'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('first library results show while slower ones finish', (
    tester,
  ) async {
    final catalog = _Catalog();
    await mount(tester, catalog, query: 'sea');
    catalog.partials['sea']!(
      const CatalogPage(
        results: [BookSearchResult(title: 'Fast library book')],
        total: 1,
        hasMore: false,
      ),
    );
    await tester.pump();
    expect(find.text('Fast library book'), findsWidgets);
    expect(find.text('SEARCHING MORE LIBRARIES...'), findsOneWidget);
    catalog.requests['sea']!.complete(
      const CatalogPage(
        results: [
          BookSearchResult(title: 'Fast library book'),
          BookSearchResult(title: 'Slow library book'),
        ],
        total: 2,
        hasMore: false,
      ),
    );
    await tester.pump();
    expect(find.text('Slow library book'), findsWidgets);
    expect(find.text('FULL DATABASE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('changing a filter cancels the pending typing debounce', (
    tester,
  ) async {
    final catalog = _Catalog();
    await mount(tester, catalog, query: 'old');
    catalog.requests['old']!.complete(
      const CatalogPage(results: [], total: 0, hasMore: false),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'new');
    await tester.tap(find.text('EPUB'));
    await tester.pump();
    expect(catalog.searchCalls, 2);
    await tester.pump(const Duration(milliseconds: 501));
    expect(catalog.searchCalls, 2);
    catalog.requests['new']!.complete(
      const CatalogPage(results: [], total: 0, hasMore: false),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('available home row renders while the recent feed is pending', (
    tester,
  ) async {
    final catalog = _Catalog();
    await mount(tester, catalog);
    await tester.pump(const Duration(seconds: 1));
    expect(catalog.homeCalls, 2);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Available popular book'), findsWidgets);
    catalog.recent.complete([]);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
