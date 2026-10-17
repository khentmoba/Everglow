import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/screens/cinema_screen.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_home_tab.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_library_tab.dart';

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

class _Service implements TMDBService {
  int feeds = 0;
  final discoveries = <({String type, List<int>? genres, String? language})>[];
  List<MediaItem> items = [];
  Future<List<MediaItem>> _feed() async {
    feeds++;
    return items;
  }

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
  }) {
    discoveries.add((
      type: mediaType,
      genres: withGenres,
      language: withOriginalLanguage,
    ));
    return _feed();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MediaItem _item(int id, {bool anime = false, String type = 'movie'}) =>
    MediaItem(
      id: '$id',
      tmdbId: id,
      title: 'Demo $id',
      mediaType: type,
      posterPath: '',
      status: '',
      isAnime: anime,
      addedAt: DateTime(2026),
    );

void main() {
  testWidgets(
    'Home loads varied shelves and excludes anime movies and series',
    (tester) async {
      final service = _Service()
        ..items = [
          _item(1),
          _item(2, type: 'tv'),
          _item(3, anime: true),
          _item(4, anime: true, type: 'tv'),
        ];
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _Auth(),
          child: MaterialApp(home: CinemaScreen(service: service)),
        ),
      );
      await tester.pump();
      final home = tester.widget<CinemaHomeTab>(find.byType(CinemaHomeTab));
      expect(home.isLoadingHome, isFalse);
      expect(home.discoveryRows.length, 8);
      expect(service.discoveries.map((r) => r.genres?.single), [
        null,
        null,
        28,
        35,
        10749,
        53,
        878,
        18,
      ]);
      expect(service.discoveries.last.language, 'ko');
      expect(service.discoveries.last.type, 'tv');
      for (final row in [
        home.trendingCarousel,
        home.trendingGlobal,
        home.topTenToday,
        home.popularTVShows,
        home.newlyReleased,
        ...home.discoveryRows.values,
      ]) {
        expect(row.map((item) => item.tmdbId), [1, 2]);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Library entry skips Home feeds until first visit, refresh still works',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _Service();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: _Auth(),
          child: MaterialApp(
            home: CinemaScreen(initialTab: 3, service: service),
          ),
        ),
      );
      await tester.pump();
      expect(service.feeds, 0);
      tester
          .widget<CinemaLibraryTab>(find.byType(CinemaLibraryTab))
          .onSwitchTab(0);
      await tester.pump();
      await tester.pump();
      expect(service.feeds, 12);
      final home = tester.widget<CinemaHomeTab>(find.byType(CinemaHomeTab));
      home.onSwitchTab(3);
      await tester.pump();
      tester
          .widget<CinemaLibraryTab>(find.byType(CinemaLibraryTab))
          .onSwitchTab(0);
      await tester.pump();
      expect(service.feeds, 12);
      await tester
          .widget<CinemaHomeTab>(find.byType(CinemaHomeTab))
          .onRefresh();
      await tester.pump();
      expect(service.feeds, 24);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
