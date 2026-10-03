import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/cinema_preferences.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_library_tab.dart';

MediaItem _item(
  String title,
  int added, {
  int? watched,
  String status = 'to-watch',
  bool anime = false,
  String type = 'movie',
  bool reminder = false,
}) => MediaItem(
  id: title,
  tmdbId: added,
  title: title,
  mediaType: type,
  posterPath: '',
  status: status,
  isAnime: anime,
  addedAt: DateTime(2026, 1, added),
  progressUpdatedAt: watched == null ? null : DateTime(2026, 2, watched),
  remindMe: reminder,
);

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  String? currentUser = 'demo-a';
  void change(String? name) {
    currentUser = name;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<String> _titles(WidgetTester tester) => tester
    .widgetList<NetflixPosterCard>(find.byType(NetflixPosterCard))
    .map((c) => c.item.title)
    .toList();

Future<void> _pump(
  WidgetTester tester,
  List<MediaItem> items, {
  Size size = const Size(360, 1000),
  CinemaPreferences? preferences,
  AuthService? auth,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    return tester.binding.setSurfaceSize(null);
  });
  Widget tab = CinemaLibraryTab(
    watchlist: items,
    onMediaTap: (_) {},
    onSwitchTab: (_) {},
    preferences: preferences,
  );
  if (auth != null) {
    tab = ChangeNotifierProvider<AuthService>.value(value: auth, child: tab);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: tab),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _sort(WidgetTester tester, String label) async {
  await tester.tap(
    find.byWidgetPredicate((widget) => widget is DropdownButtonFormField).first,
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (size, columns) in [
    (const Size(360, 1000), 3),
    (const Size(810, 1080), 5),
  ]) {
    testWidgets(
      'real My List has $columns columns at ${size.width}px and accessible 48px filters',
      (tester) async {
        final semantics = tester.ensureSemantics();

        await _pump(
          tester,
          List.generate(6, (i) => _item('Movie $i', i + 1)),
          size: size,
        );
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          columns,
        );
        for (final label in [
          'All',
          'Watching',
          'To Watch',
          'Watched',
          'Reminders',
        ]) {
          final button = find.ancestor(
            of: find.text(label),
            matching: find.byType(TextButton),
          );
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(
            tester
                .getSemantics(button)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
          );
        }
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'search, all three sorts and status filters compose without mutating source list',
    (tester) async {
      final items = [
        _item('Zulu', 1, watched: 5, status: 'watching'),
        _item('Alpha', 3, watched: 2, status: 'watched'),
        _item('Beta', 2),
        _item('Anime series', 6, anime: true, type: 'tv'),
        _item('Anime film', 4, anime: true),
      ];
      await _pump(tester, items);
      expect(_titles(tester), ['Anime film', 'Alpha', 'Beta', 'Zulu']);
      await _sort(tester, 'Last watched');
      expect(_titles(tester), ['Zulu', 'Alpha', 'Anime film', 'Beta']);
      await _sort(tester, 'Title');
      expect(_titles(tester), ['Alpha', 'Anime film', 'Beta', 'Zulu']);
      await tester.enterText(find.byType(TextField), '  ALP  ');
      await tester.pump();
      expect(_titles(tester), ['Alpha']);
      await tester.tap(find.text('Watching'));
      await tester.pump();
      expect(_titles(tester), isEmpty);
      expect(
        find.text('No titles match your search or filter.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(_titles(tester), ['Zulu']);
      await tester.tap(find.text('All'));
      await tester.pump();
      await _sort(tester, 'Recently saved');
      expect(_titles(tester), ['Anime film', 'Alpha', 'Beta', 'Zulu']);
      expect(items.map((i) => i.title), [
        'Zulu',
        'Alpha',
        'Beta',
        'Anime series',
        'Anime film',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reminder-only library stays browsable and genuinely empty list keeps settings',
    (tester) async {
      await _pump(tester, [
        _item('Coming soon', 1, status: '', reminder: true),
      ]);
      await tester.tap(find.text('Reminders'));
      await tester.pump();
      expect(_titles(tester), ['Coming soon']);
      expect(find.text('Your list is empty'), findsNothing);
      await _pump(tester, []);
      expect(find.text('Your list is empty'), findsOneWidget);
      expect(find.text('Viewing preferences'), findsOneWidget);
    },
  );

  testWidgets(
    'library initializes profile from available AuthService and supports injection',
    (tester) async {
      final auth = _FakeAuth();
      final prefs = CinemaPreferences();
      addTearDown(auth.dispose);
      addTearDown(prefs.dispose);
      await _pump(tester, [_item('Demo', 1)], preferences: prefs, auth: auth);
      expect(prefs.currentUser, 'demo-a');
      await prefs.setHideSpoilers(false);
      auth.change('demo-b');
      await tester.pump();
      expect(prefs.currentUser, 'demo-b');
      expect(prefs.hideSpoilers, isTrue);
      await tester.tap(find.text('Viewing preferences'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Hide spoilers'), findsOneWidget);
      expect(find.text('Autoplay next episode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
