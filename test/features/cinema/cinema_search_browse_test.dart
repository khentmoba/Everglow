import 'dart:async';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_browse_tab.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_search_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  final String query;
  final int page;
  final List<int>? genres;
  final Completer<List<MediaItem>> result = Completer();
  _Request(this.query, this.page, [this.genres]);
}

class _TMDB implements TMDBService {
  final searches = <_Request>[];
  final discoveries = <_Request>[];

  @override
  Future<List<MediaItem>> searchMedia(
    String query, {
    int page = 1,
    bool failOnError = false,
  }) {
    final request = _Request(query, page);
    searches.add(request);
    return request.result.future;
  }

  @override
  Future<List<MediaItem>> discoverMedia({
    required String mediaType,
    String? sortBy,
    List<int>? withGenres,
    int? yearGte,
    int? yearLte,
    double? voteAverageGte,
    int? voteCountGte,
    String? withOriginalLanguage,
    int page = 1,
    bool failOnError = false,
  }) {
    final request = _Request(mediaType, page, withGenres);
    discoveries.add(request);
    return request.result.future;
  }

  @override
  Future<List<MediaItem>> discoverByGenre({
    required int genreId,
    required String mediaType,
    String sortBy = 'popularity.desc',
  }) => discoverMedia(mediaType: mediaType, withGenres: [genreId]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem _item(int id, {String? year, String type = 'movie'}) => MediaItem(
  id: '',
  tmdbId: id,
  title: 'Demo title $id',
  mediaType: type,
  posterPath: '',
  year: year ?? '${DateTime.now().year}',
  status: '',
  addedAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester,
  Widget tab, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: tab),
      ),
    ),
  );
  await tester.pump();
}

CinemaSearchTab _search(_TMDB service) => CinemaSearchTab(
  service: service,
  trendingGlobal: [_item(999)],
  onMediaTap: (_) {},
  onSwitchTab: (_) {},
);

Future<void> _query(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 501));
}

void main() {
  testWidgets('clear rejects the pending search response', (tester) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await _query(tester, 'old');
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    service.searches.single.result.complete([_item(1)]);
    await tester.pump();
    expect(find.text('Popular Searches'), findsOneWidget);
    expect(find.text('Demo title 1'), findsNothing);
  });

  testWidgets('editing rejects an old response before debounce fires', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await _query(tester, 'old');
    await tester.enterText(find.byType(TextField), 'new');
    service.searches.single.result.complete([_item(1)]);
    await tester.pump();
    expect(find.text('Demo title 1'), findsNothing);
    await tester.pump(const Duration(milliseconds: 501));
    service.searches.last.result.complete([_item(2)]);
    await tester.pump();
    expect(find.text('Demo title 2'), findsOneWidget);
  });

  testWidgets('search has no pretend ratings and offers the current year', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await _query(tester, 'demo');
    service.searches.single.result.complete([_item(1)]);
    await tester.pump();
    expect(find.text('8.0+'), findsNothing);
    expect(find.text('9.0+'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(-240, 0));
    await tester.pumpAndSettle();
    final year = find.widgetWithText(TextButton, '${DateTime.now().year}');
    expect(year, findsOneWidget);
    expect(tester.getSize(year).height, greaterThanOrEqualTo(48));
  });

  testWidgets('genre load more requests page two and keeps the grid', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(
      tester,
      CinemaBrowseTab(
        service: service,
        initialOptionId: 'genre-movie-28',
        onMediaTap: (_) {},
      ),
    );
    service.discoveries.single.result.complete(List.generate(20, _item));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Load More'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Load More'));
    await tester.pump();
    expect(service.discoveries.last.page, 2);
    expect(service.discoveries.last.genres, [28]);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(
      tester
          .widget<SliverGrid>(find.byType(SliverGrid))
          .delegate
          .estimatedChildCount,
      20,
    );
    service.discoveries.last.result.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('No titles found for this filter.'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(service.discoveries.last.page, 2);
    service.discoveries.last.result.complete([_item(19), _item(20), _item(20)]);
    await tester.pump();
    expect(
      tester
          .widget<SliverGrid>(find.byType(SliverGrid))
          .delegate
          .estimatedChildCount,
      21,
    );
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('Clear cancels debounce and whitespace returns to landing', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await tester.enterText(find.byType(TextField), 'demo');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(seconds: 1));
    expect(service.searches, isEmpty);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump(const Duration(seconds: 1));
    expect(service.searches, isEmpty);
    expect(find.text('Popular Searches'), findsOneWidget);
  });

  testWidgets('newest response wins even when an older request fails', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await _query(tester, 'old');
    await _query(tester, 'new');
    service.searches.last.result.complete([_item(2)]);
    await tester.pump();
    service.searches.first.result.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('Demo title 2'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'search failure has a button Retry, not an empty-results message',
    (tester) async {
      final service = _TMDB();
      await _pump(tester, _search(service));
      await _query(tester, 'demo');
      service.searches.single.result.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('No results found'), findsNothing);
      final retry = find.widgetWithText(TextButton, 'Retry');
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(retry),
        matchesSemantics(
          label: 'Retry',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
      await tester.tap(retry);
      await tester.pump();
      expect(service.searches.last.query, 'demo');
      expect(service.searches.last.page, 1);
      service.searches.last.result.complete([]);
      await tester.pump();
      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'search pagination retains cards, deduplicates, and retries page two',
    (tester) async {
      final service = _TMDB();
      await _pump(tester, _search(service));
      await _query(tester, 'demo');
      service.searches.single.result.complete([_item(1)]);
      await tester.pump();
      await tester.tap(find.text('Load More'));
      await tester.pump();
      expect(service.searches.last.page, 2);
      expect(find.text('Demo title 1'), findsOneWidget);
      service.searches.last.result.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('Demo title 1'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(service.searches.last.page, 2);
      service.searches.last.result.complete([_item(1), _item(2), _item(2)]);
      await tester.pump();
      expect(find.text('Demo title 1'), findsOneWidget);
      expect(find.text('Demo title 2'), findsOneWidget);
    },
  );

  testWidgets('search filters apply year and type, and Clear restores titles', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(tester, _search(service), size: const Size(810, 1080));
    await _query(tester, 'demo');
    service.searches.single.result.complete([
      _item(1),
      _item(2, type: 'tv'),
      _item(3, year: '2000'),
    ]);
    await tester.pump();
    final year = find.widgetWithText(TextButton, '${DateTime.now().year}');
    await tester.tap(year);
    await tester.pump();
    expect(find.text('Demo title 3'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Movies only'));
    await tester.pump();
    expect(find.text('Demo title 2'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pump();
    expect(find.text('Demo title 2'), findsOneWidget);
    expect(find.text('Demo title 3'), findsOneWidget);
    expect(find.text('Search movie and TV titles'), findsOneWidget);
  });

  testWidgets('popular search cancels an earlier debounce', (tester) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await tester.enterText(find.byType(TextField), 'old');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Demo title 999'));
    await tester.pump(const Duration(seconds: 1));
    expect(service.searches.length, 1);
    expect(service.searches.single.query, 'Demo title 999');
    service.searches.single.result.complete([]);
    await tester.pump();
  });

  testWidgets('disposed search ignores completion and cancels debounce', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(tester, _search(service));
    await _query(tester, 'demo');
    await tester.enterText(find.byType(TextField), 'next');
    await tester.pumpWidget(const SizedBox());
    service.searches.single.result.completeError(StateError('offline'));
    await tester.pump(const Duration(seconds: 1));
    expect(service.searches.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browse rejects stale categories including an A-B-A switch', (
    tester,
  ) async {
    final service = _TMDB();
    await _pump(
      tester,
      CinemaBrowseTab(
        service: service,
        initialOptionId: 'collection-movies',
        onMediaTap: (_) {},
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, 'TV Shows'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Movies'));
    await tester.pump();
    service.discoveries.last.result.complete([_item(3)]);
    await tester.pump();
    service.discoveries.first.result.complete([_item(1)]);
    service.discoveries[1].result.completeError(StateError('offline'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Demo title 3'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Demo title 1'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('1 titles'), findsOneWidget);
  });

  testWidgets('browse first-page error retries page one', (tester) async {
    final service = _TMDB();
    await _pump(
      tester,
      CinemaBrowseTab(
        service: service,
        initialOptionId: 'collection-movies',
        onMediaTap: (_) {},
      ),
    );
    service.discoveries.single.result.completeError(StateError('offline'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Retry'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No titles found for this filter.'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    expect(service.discoveries.last.page, 1);
    service.discoveries.last.result.complete([]);
    await tester.pump();
    expect(find.text('No titles found for this filter.'), findsOneWidget);
  });

  for (final size in [const Size(360, 800), const Size(810, 1080)]) {
    testWidgets('real search and browse grids fit ${size.width}px', (
      tester,
    ) async {
      final service = _TMDB();
      await _pump(tester, _search(service), size: size);
      await _query(tester, 'demo');
      service.searches.single.result.complete(List.generate(20, _item));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final searchGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (searchGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        size.width < 600 ? 3 : 5,
      );
      for (final card in find.byType(NetflixPosterCard).evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
      final movies = find.widgetWithText(TextButton, 'Movies only');
      expect(tester.getSize(movies).height, greaterThanOrEqualTo(48));
      await _pump(
        tester,
        CinemaBrowseTab(
          service: service,
          initialOptionId: 'genre-movie-28',
          onMediaTap: (_) {},
        ),
        size: size,
      );
      service.discoveries.single.result.complete(List.generate(20, _item));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Demo title 0'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      final browseGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (browseGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        size.width < 600 ? 3 : 5,
      );
      for (final card in find.byType(NetflixPosterCard).evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
    });
  }
}
