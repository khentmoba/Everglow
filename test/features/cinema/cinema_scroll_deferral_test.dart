import 'dart:async';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/cinema_home_cache.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/screens/cinema_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  String? get currentUser => null;

  @override
  bool get isCoupleUser => false;

  @override
  bool get isCinemaOnlyUser => false;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedDiscoveryService implements TMDBService {
  final Completer<List<MediaItem>> discoveryCompleter =
      Completer<List<MediaItem>>();

  List<MediaItem> _sample(int id) => [
    MediaItem(
      id: '$id',
      tmdbId: id,
      title: 'Sample $id',
      mediaType: 'movie',
      posterPath: '',
      status: 'watchlist',
      addedAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<MediaItem>> fetchTrending({
    String region = 'all',
    String timeWindow = 'week',
  }) async => _sample(1);

  @override
  Future<List<MediaItem>> fetchTrendingByCountry({
    String countryCode = 'PH',
  }) async => _sample(2);

  @override
  Future<List<MediaItem>> fetchPopularTVShows() async => _sample(3);

  @override
  Future<List<MediaItem>> fetchUpcoming({String region = 'PH'}) async =>
      _sample(4);

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
  }) => discoveryCompleter.future;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'CinemaScreen defers CinemaHomeCache persistence while vertically scrolling and flushes on scroll end',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      CinemaHomeCache.resetForTests();
      addTearDown(CinemaHomeCache.resetForTests);

      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = _DelayedDiscoveryService();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _FakeAuth(),
          child: MaterialApp(home: CinemaScreen(service: service)),
        ),
      );
      await tester.pump();
      await tester.pump();

      final scrollCenter = tester.getCenter(find.byType(CustomScrollView).first);
      final gesture = await tester.startGesture(scrollCenter);
      await gesture.moveBy(const Offset(0, -140));
      await tester.pump();

      service.discoveryCompleter.complete([
        MediaItem(
          id: '99',
          tmdbId: 99,
          title: 'Deferred Discovery Film',
          mediaType: 'movie',
          posterPath: '',
          status: 'watchlist',
          addedAt: DateTime(2026),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cinema_home_rows_v1'), isNull);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(prefs.getString('cinema_home_rows_v1'), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
