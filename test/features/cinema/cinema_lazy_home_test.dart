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
  Future<List<MediaItem>> _feed() async {
    feeds++;
    return [];
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
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
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
      expect(service.feeds, 4);
      final home = tester.widget<CinemaHomeTab>(find.byType(CinemaHomeTab));
      home.onSwitchTab(3);
      await tester.pump();
      tester
          .widget<CinemaLibraryTab>(find.byType(CinemaLibraryTab))
          .onSwitchTab(0);
      await tester.pump();
      expect(service.feeds, 4);
      await tester
          .widget<CinemaHomeTab>(find.byType(CinemaHomeTab))
          .onRefresh();
      await tester.pump();
      expect(service.feeds, 8);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
