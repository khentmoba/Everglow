import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/cinema_home_cache.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/screens/cinema_screen.dart';
import 'package:everglow/features/cinema/presentation/widgets/cinema_loading_shell.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_loading.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_nav_bar.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_home_tab.dart';

class _Auth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => null;
  @override
  bool get isCoupleUser => false;
  @override
  bool get isCinemaOnlyUser => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Answers every Home feed with [items], or waits on [gate] when one is set.
class _FeedService implements TMDBService {
  _FeedService({this.items = const [], this.gate});

  final List<MediaItem> items;
  final Completer<List<MediaItem>>? gate;

  Future<List<MediaItem>> _feed() => gate?.future ?? Future.value(items);

  @override
  Future<List<MediaItem>> fetchTrending({
    String region = 'all',
    String timeWindow = 'week',
  }) => _feed();
  @override
  Future<List<MediaItem>> fetchTrendingByCountry({
    required String countryCode,
  }) => _feed();
  @override
  Future<List<MediaItem>> fetchPopularTVShows() => _feed();
  @override
  Future<List<MediaItem>> fetchUpcoming({String region = 'PH'}) => _feed();
  @override
  Future<List<MediaItem>> discoverMedia({
    required String mediaType,
    String? sortBy,
    List<int>? withGenres,
    List<int>? withoutGenres,
    int? yearGte,
    int? yearLte,
    double? voteAverageGte,
    int? voteCountGte,
    String? withOriginalLanguage,
    int page = 1,
    bool failOnError = false,
  }) => _feed();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MediaItem _item(int id, {String type = 'movie'}) => MediaItem(
  id: '$id',
  tmdbId: id,
  title: 'Demo $id',
  mediaType: type,
  posterPath: '',
  status: '',
  isAnime: false,
  addedAt: DateTime(2026),
);

CinemaHomeTab _home(WidgetTester tester) =>
    tester.widget<CinemaHomeTab>(find.byType(CinemaHomeTab));

List<int> _ids(List<MediaItem> items) => items.map((m) => m.tmdbId).toList();

Future<void> _open(WidgetTester tester, TMDBService service) =>
    tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: _Auth(),
        child: MaterialApp(home: CinemaScreen(service: service)),
      ),
    );

Future<void> _close(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

/// Lets SharedPreferences (a platform channel) finish its pending work.
Future<void> _settleStorage(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CinemaHomeCache.resetForTests();
  });

  testWidgets(
    'CinemaLoadingShell renders themed skeleton immediately on frame 0',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CinemaLoadingShell()));
      expect(find.byType(CinemaLoadingShell), findsOneWidget);
      expect(find.byType(NetflixLoadingBillboard), findsOneWidget);
      expect(find.byType(NetflixLoadingRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CinemaScreen shell (nav bar, layout, billboard) renders on the first frame without waiting on network',
    (tester) async {
      final gate = Completer<List<MediaItem>>();
      await _open(tester, _FeedService(gate: gate));
      // First frame: nothing has resolved from the network.
      await tester.pump();
      expect(find.byType(CinemaScreen), findsOneWidget);
      expect(find.byType(CinemaHomeTab), findsOneWidget);
      expect(find.byType(NetflixNavBar), findsOneWidget);
      expect(find.byType(NetflixLoadingBillboard), findsOneWidget);
      expect(_home(tester).isLoadingHome, isTrue);
      expect(tester.takeException(), isNull);
      await _close(tester);
    },
  );

  testWidgets('cold open leaves Home empty until the network answers', (
    tester,
  ) async {
    final gate = Completer<List<MediaItem>>();
    await _open(tester, _FeedService(gate: gate));
    await tester.pump();
    expect(_home(tester).isLoadingHome, isTrue);
    expect(_home(tester).trendingGlobal, isEmpty);

    gate.complete([_item(1), _item(2, type: 'tv')]);
    await _settleStorage(tester);
    expect(_ids(_home(tester).trendingGlobal), [1, 2]);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets(
    'repeat open paints saved rows while the network is still pending',
    (tester) async {
      await _open(tester, _FeedService(items: [_item(1), _item(2, type: 'tv')]));
      await _settleStorage(tester);
      await _close(tester);

      await _open(tester, _FeedService(gate: Completer()));
      await tester.pump();
      expect(_home(tester).isLoadingHome, isTrue);
      expect(_ids(_home(tester).trendingGlobal), [1, 2]);
      expect(_ids(_home(tester).popularTVShows), [1, 2]);
      expect(tester.takeException(), isNull);
      await _close(tester);
    },
  );

  testWidgets('after an app restart the saved rows load from storage', (
    tester,
  ) async {
    await _open(tester, _FeedService(items: [_item(1)]));
    await _settleStorage(tester);
    await _close(tester);

    CinemaHomeCache.resetForTests();
    await _open(tester, _FeedService(gate: Completer()));
    await _settleStorage(tester);
    expect(_ids(_home(tester).trendingGlobal), [1]);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('warm() puts saved rows in memory before the first open', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await CinemaHomeCache.save({
        'trendingGlobal': [_item(7)],
      });
    });
    CinemaHomeCache.resetForTests();
    expect(CinemaHomeCache.session, isNull);

    await tester.runAsync(() => CinemaHomeCache.warm());

    expect(_ids(CinemaHomeCache.session!['trendingGlobal']!), [7]);
  });

  testWidgets('a failed or empty refresh keeps the saved rows', (tester) async {
    await _open(tester, _FeedService(items: [_item(1)]));
    await _settleStorage(tester);
    await _close(tester);

    await _open(tester, _FeedService());
    await _settleStorage(tester);
    expect(_ids(_home(tester).trendingGlobal), [1]);
    expect(
      _ids(CinemaHomeCache.session!['trendingGlobal']!),
      [1],
    );
    await _close(tester);
  });
}
