import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/cinema/data/services/cinema_preferences.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/cinema_viewing_preferences.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer_sections/episode_list_section.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_navigator.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';

const _episodes = [
  {
    'season_number': 3,
    'episode_number': 7,
    'name': 'Secret ending',
    'overview': 'Secret plot',
    'still_path': '/secret.jpg',
  },
  {
    'season_number': 3,
    'episode_number': 8,
    'name': 'Other secret',
    'overview': 'Other plot',
  },
];

class _FakeTmdb implements TMDBService {
  final List<dynamic> episodes;
  _FakeTmdb({this.episodes = _episodes});
  @override
  Future<Map<String, dynamic>?> fetchTVShowDetails(int id) async => {
    'seasons': [
      {'season_number': 3, 'name': 'Season 3'},
      {'season_number': 4, 'name': 'Season 4'},
    ],
  };
  @override
  Future<List<dynamic>> fetchSeasonEpisodes(int id, int season) async =>
      episodes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _phone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    return tester.binding.setSurfaceSize(null);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cinema episodes hide plot metadata but keep episode stills', (
    tester,
  ) async {
    final played = <String>[];
    await tester.pumpWidget(
      _app(
        EpisodeListSection(
          hideSpoilers: true,
          episodes: _episodes,
          seasons: const [],
          isLoadingEpisodes: false,
          onPlayEpisode: (s, e, t) => played.add('$s/$e/$t'),
          onSeasonChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Secret ending'), findsNothing);
    expect(find.text('Secret plot'), findsNothing);
    expect(find.text('Episode 7'), findsOneWidget);
    // A frame gives no plot away, so the still is not a spoiler.
    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(
      tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).imageUrl,
      contains('/secret.jpg'),
    );
    await tester.tap(find.text('Episode 7'));
    await tester.pump();
    expect(played, ['3/7/Episode 7']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'anime defaults still show metadata and preserve real play title',
    (tester) async {
      final played = <String>[];
      await tester.pumpWidget(
        _app(
          EpisodeListSection(
            episodes: const [
              {
                'season_number': 5,
                'episode_number': 2,
                'name': 'Anime title',
                'overview': 'Anime overview',
              },
            ],
            seasons: const [],
            isLoadingEpisodes: false,
            onPlayEpisode: (s, e, t) => played.add('$s/$e/$t'),
            onSeasonChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Anime title'), findsOneWidget);
      expect(find.text('Anime overview'), findsOneWidget);
      await tester.tap(find.text('Anime title'));
      await tester.pump();
      expect(played, ['5/2/Anime title']);
    },
  );

  testWidgets(
    'revealing one episode expands that row inline, keeps Play neutral, and collapses again',
    (tester) async {
      await _phone(tester);
      var plays = 0;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              EpisodeTile(
                epNum: 7,
                epName: 'Secret ending',
                epOverview: 'Secret plot',
                stillUrl: 'fake-still',
                hideSpoilers: true,
                onTap: () => plays++,
              ),
              EpisodeTile(
                epNum: 8,
                epName: 'Other secret',
                epOverview: 'Other plot',
                hideSpoilers: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).imageUrl,
        'fake-still',
      );
      await tester.tap(find.text('Reveal details').first);
      await tester.pumpAndSettle();
      expect(plays, 0);
      // Revealed in place — no drawer over the list.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Secret ending'), findsOneWidget);
      expect(find.text('Secret plot'), findsOneWidget);
      expect(find.text('Other secret'), findsNothing);
      expect(find.text('Hide details'), findsOneWidget);
      // The row itself plays, so the drawer never held the only play.
      await tester.tap(find.text('Secret ending'));
      await tester.pump();
      expect(plays, 1);
      await tester.tap(find.text('Hide details'));
      await tester.pumpAndSettle();
      expect(find.text('Secret ending'), findsNothing);
      expect(plays, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navigator hides selected and upcoming episodes, uses unchanged season/episode callbacks',
    (tester) async {
      await _phone(tester);
      final prefs = CinemaPreferences();
      await prefs.setUser('demo');
      addTearDown(prefs.dispose);
      final seasons = <int>[];
      final episodes = <int>[];
      await tester.pumpWidget(
        _app(
          EpisodeNavigator(
            tmdbId: 123,
            initialSeason: 3,
            initialEpisode: 7,
            preferences: prefs,
            tmdbService: _FakeTmdb(),
            onSeasonChanged: seasons.add,
            onEpisodeChanged: episodes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      expect(find.text('Secret ending'), findsNothing);
      expect(find.text('Other secret'), findsNothing);
      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(
        tester
            .widgetList<EpisodeTile>(find.byType(EpisodeTile))
            .every((tile) => tile.hideSpoilers),
        isTrue,
      );
      await tester.tap(find.text('Episode 8'));
      await tester.pump();
      expect(episodes, [8]);
      await tester.tap(find.text('Season 4'));
      await tester.pump();
      expect(seasons, [4]);
      await tester.tap(find.text('Reveal details').last);
      await tester.pumpAndSettle();
      expect(find.text('Other secret'), findsOneWidget);
      expect(prefs.hideSpoilers, isTrue);
      await tester.tap(find.text('Hide details'));
      await tester.pumpAndSettle();
      expect(find.text('Other secret'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('navigator reacts when Hide spoilers changes', (tester) async {
    final prefs = CinemaPreferences();
    await prefs.setUser('demo');
    addTearDown(prefs.dispose);
    await tester.pumpWidget(
      _app(
        EpisodeNavigator(
          tmdbId: 123,
          initialSeason: 3,
          initialEpisode: 7,
          preferences: prefs,
          tmdbService: _FakeTmdb(
            episodes: const [
              {
                'episode_number': 7,
                'name': 'Secret title',
                'overview': 'Secret overview',
              },
            ],
          ),
          onSeasonChanged: (_) {},
          onEpisodeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Episodes'));
    await tester.pumpAndSettle();
    expect(find.text('Secret title'), findsNothing);
    await prefs.setHideSpoilers(false);
    await tester.pumpAndSettle();
    expect(find.text('Secret title'), findsOneWidget);
    expect(find.text('Secret overview'), findsOneWidget);
    await prefs.setHideSpoilers(true);
    await tester.pumpAndSettle();
    expect(find.text('Secret title'), findsNothing);
    expect(find.text('Secret overview'), findsNothing);
  });

  testWidgets(
    'long titles and stories never overflow the compact row, hidden or open',
    (tester) async {
      await _phone(tester);
      for (final hideSpoilers in [true, false]) {
        await tester.pumpWidget(
          _app(
            EpisodeListSection(
              hideSpoilers: hideSpoilers,
              episodes: const [
                {
                  'season_number': 1,
                  'episode_number': 12,
                  'name': 'A Very Long Episode Title That Cannot Fit One Line',
                  'overview':
                      'And a long story that runs well past two lines once the row is only eighty pixels tall, spilling into the next episode.',
                },
              ],
              seasons: const [],
              isLoadingEpisodes: false,
              onPlayEpisode: (_, _, _) {},
              onSeasonChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (hideSpoilers) {
          await tester.tap(find.text('Reveal details'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'preferences have accessible switches, update and react to profile changes without provider',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final prefs = CinemaPreferences();
      await prefs.setUser('demo-a');
      addTearDown(prefs.dispose);
      await tester.pumpWidget(
        _app(CinemaViewingPreferences(preferences: prefs)),
      );
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches.map((s) => s.value), [true, false]);
      expect(find.bySemanticsLabel(RegExp('Hide spoilers')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Autoplay next episode')),
        findsOneWidget,
      );
      await tester.tap(find.text('Hide spoilers'));
      await tester.pump();
      expect(prefs.hideSpoilers, isFalse);
      await tester.tap(find.text('Autoplay next episode'));
      await tester.pump();
      expect(prefs.autoplayNext, isTrue);
      await prefs.setUser('demo-b');
      await tester.pump();
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .map((s) => s.value),
        [true, false],
      );
      semantics.dispose();
    },
  );
}
