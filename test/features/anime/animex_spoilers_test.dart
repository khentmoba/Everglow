import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/features/anime/data/models/anilist_detail.dart';
import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_watch_page.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';

const _poster = 'safe-series-poster.jpg';
const _episodes = [
  AniListEpisode(
    number: 1,
    title: 'First secret title',
    titleRomaji: 'First secret romaji',
    synopsis: 'First secret synopsis',
    thumbnail: 'secret-still-1.jpg',
    duration: 24,
  ),
  AniListEpisode(
    number: 2,
    title: 'Second secret title',
    synopsis: 'Second secret synopsis',
    thumbnail: 'secret-still-2.jpg',
  ),
  AniListEpisode(
    number: 3,
    title: 'Third secret title',
    synopsis: 'Third secret synopsis',
    thumbnail: 'secret-still-3.jpg',
  ),
];

Iterable<String> _imageUrls(WidgetTester tester) => tester
    .widgetList<AppNetworkImage>(find.byType(AppNetworkImage))
    .map((image) => image.imageUrl);

Future<void> _pumpSelector(
  WidgetTester tester, {
  required bool desktop,
  int selectedEpisode = 1,
  List<AniListEpisode> episodes = _episodes,
  ValueChanged<int>? onSelectEpisode,
}) async {
  tester.view.physicalSize = Size(desktop ? 1000 : 390, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final stores = AnimexStores.instance;
  await stores.load(username: 'clairjassen');
  await tester.pumpWidget(
    ChangeNotifierProvider<AnimexStores>.value(
      value: stores,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              void showInfo(AniListEpisode episode) {
                showEpisodeInfoSheetForTesting(
                  context,
                  episode: episode,
                  animeTitle: 'Demo anime',
                  fallbackPoster: _poster,
                  isPlaying: episode.number == selectedEpisode,
                  onPlay: () => onSelectEpisode?.call(episode.number),
                  hideSpoilers:
                      stores.hideSpoilers && episode.number >= selectedEpisode,
                );
              }

              return SizedBox(
                width: desktop ? 380 : 390,
                height: 650,
                child: desktop
                    ? buildDesktopEpisodesSidebarForTesting(
                        episodes: episodes,
                        selectedEpisode: selectedEpisode,
                        animeTitle: 'Demo anime',
                        fallbackPoster: _poster,
                        onSelectEpisode: onSelectEpisode ?? (_) {},
                        onShowInfo: showInfo,
                      )
                    : buildMobileEpisodesSectionForTesting(
                        episodes: episodes,
                        selectedEpisode: selectedEpisode,
                        animeTitle: 'Demo anime',
                        fallbackPoster: _poster,
                        onSelectEpisode: onSelectEpisode ?? (_) {},
                        onShowInfo: showInfo,
                      ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _sheet => find.byType(BottomSheet);
Finder get _sheetReveal =>
    find.descendant(of: _sheet, matching: find.text('Reveal details'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AnimexStores.instance.resetForTest();
  });

  test(
    'spoiler preference defaults on, including older saved preferences',
    () async {
      final stores = AnimexStores.instance;
      expect(stores.hideSpoilers, isTrue);
      SharedPreferences.setMockInitialValues({
        'animex_prefs_v1_clairjassen': json.encode({'titleJapanese': true}),
      });
      await stores.load(username: 'clairjassen');
      expect(stores.hideSpoilers, isTrue);
      expect(stores.titleJapanese, isTrue);
    },
  );

  test(
    'spoiler preference persists without replacing other preferences',
    () async {
      final stores = AnimexStores.instance;
      await stores.load(username: 'clairjassen');
      await stores.setTitleJapanese(true);
      await stores.toggleAlert('demo-alert');
      await stores.setHideSpoilers(false);

      final prefs = await SharedPreferences.getInstance();
      expect(
        json.decode(
          prefs.getString('animex_prefs_v1_clairjassen')!,
        )['hideSpoilers'],
        isFalse,
      );
      stores.resetForTest();
      await stores.load(username: 'clairjassen');
      expect(stores.hideSpoilers, isFalse);
      expect(stores.titleJapanese, isTrue);
      expect(stores.isAlertEnabled('demo-alert'), isTrue);

      await stores.setHideSpoilers(true);
      stores.resetForTest();
      await stores.load(username: 'clairjassen');
      expect(stores.hideSpoilers, isTrue);
    },
  );

  test(
    'switching profiles immediately restores safe defaults and isolates choice',
    () async {
      final stores = AnimexStores.instance;
      await stores.load(username: 'khentsgdz');
      await stores.setHideSpoilers(false);
      final switching = stores.switchUser('clairjassen');
      expect(stores.hideSpoilers, isTrue);
      await switching;
      await stores.setHideSpoilers(true);
      await stores.switchUser('octagram');
      expect(stores.hideSpoilers, isTrue);
      await stores.switchUser('khentsgdz');
      expect(stores.hideSpoilers, isFalse);
      await stores.switchUser('clairjassen');
      expect(stores.hideSpoilers, isTrue);
    },
  );

  test(
    'logout resets spoiler preference and never writes an unscoped key',
    () async {
      final stores = AnimexStores.instance;
      await stores.load(username: 'clairjassen');
      await stores.setHideSpoilers(false);
      await stores.switchUser(null);
      expect(stores.hideSpoilers, isTrue);
      await stores.setHideSpoilers(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('animex_prefs_v1'), isNull);
    },
  );

  for (final desktop in [false, true]) {
    final layout = desktop ? 'desktop' : 'mobile';
    testWidgets(
      '$layout hides current/upcoming metadata until explicit sheet reveal',
      (tester) async {
        await _pumpSelector(tester, desktop: desktop);
        for (final episode in _episodes) {
          expect(find.text(episode.title!), findsNothing);
          expect(find.text(episode.synopsis!), findsNothing);
          expect(_imageUrls(tester), isNot(contains(episode.thumbnail)));
        }
        expect(find.text('First secret romaji'), findsNothing);
        expect(find.text('Episode 1'), findsWidgets);
        expect(_imageUrls(tester), contains(_poster));
        if (desktop) {
          expect(find.text('Playing Episode 1'), findsOneWidget);
          expect(find.text('Up next: Episode 2'), findsOneWidget);
        }

        await tester.tap(find.text('Reveal details').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.text('Episode details hidden'), findsOneWidget);
        expect(find.text(_episodes.first.title!), findsNothing);
        expect(find.text(_episodes.first.synopsis!), findsNothing);
        expect(_imageUrls(tester), isNot(contains(_episodes.first.thumbnail)));

        await tester.tap(_sheetReveal);
        await tester.pumpAndSettle();
        expect(find.text(_episodes.first.title!), findsOneWidget);
        expect(find.text(_episodes.first.synopsis!), findsOneWidget);
        expect(_imageUrls(tester), contains(_episodes.first.thumbnail));
        expect(AnimexStores.instance.hideSpoilers, isTrue);
        expect(find.text(_episodes[1].title!), findsNothing);

        Navigator.of(tester.element(_sheet)).pop();
        await tester.pumpAndSettle();
        expect(find.text(_episodes.first.title!), findsNothing);
        expect(_imageUrls(tester), isNot(contains(_episodes.first.thumbnail)));
        await tester.tap(find.text('Reveal details').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.text('Episode details hidden'), findsOneWidget);
        expect(find.text(_episodes.first.title!), findsNothing);
      },
    );

    testWidgets(
      '$layout Hide spoilers switch is labelled and reveals/re-hides metadata',
      (tester) async {
        await _pumpSelector(tester, desktop: desktop);
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Hide spoilers'), findsOneWidget);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        await tester.tap(find.text('Hide spoilers'));
        await tester.pumpAndSettle();
        expect(AnimexStores.instance.hideSpoilers, isFalse);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
        expect(find.text(_episodes.first.title!), findsWidgets);
        expect(_imageUrls(tester), contains(_episodes.first.thumbnail));
        if (desktop) {
          expect(find.text('Up next: ${_episodes[1].title}'), findsOneWidget);
        } else {
          expect(find.text(_episodes.first.synopsis!), findsOneWidget);
        }
        await tester.tap(find.text('Hide spoilers'));
        await tester.pumpAndSettle();
        expect(AnimexStores.instance.hideSpoilers, isTrue);
        expect(find.text(_episodes.first.title!), findsNothing);
        expect(_imageUrls(tester), isNot(contains(_episodes.first.thumbnail)));
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$layout uses selected episode as boundary, not the history store',
      (tester) async {
        await _pumpSelector(tester, desktop: desktop, selectedEpisode: 2);
        expect(find.text(_episodes.first.title!), findsOneWidget);
        expect(_imageUrls(tester), contains(_episodes.first.thumbnail));
        for (final episode in _episodes.skip(1)) {
          expect(find.text(episode.title!), findsNothing);
          expect(find.text(episode.synopsis!), findsNothing);
          expect(_imageUrls(tester), isNot(contains(episode.thumbnail)));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$layout search ignores hidden titles/synopses but accepts episode number',
      (tester) async {
        await _pumpSelector(tester, desktop: desktop);
        if (!desktop) {
          await tester.tap(find.text('Search'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField), 'Second secret title');
        await tester.pumpAndSettle();
        expect(find.text('Episode 2'), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          'Second secret synopsis',
        );
        await tester.pumpAndSettle();
        expect(find.text('Episode 2'), findsNothing);
        await tester.enterText(find.byType(TextField), '2');
        await tester.pumpAndSettle();
        expect(find.text('Episode 2'), findsWidgets);
        expect(find.text(_episodes[1].title!), findsNothing);
        expect(_imageUrls(tester), isNot(contains(_episodes[1].thumbnail)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$layout hidden episode still plays without revealing metadata',
      (tester) async {
        int? selected;
        await _pumpSelector(
          tester,
          desktop: desktop,
          episodes: [_episodes[1]],
          onSelectEpisode: (episode) => selected = episode,
        );
        await tester.tap(find.text('Episode 2').hitTestable().first);
        await tester.pump();
        expect(selected, 2);
        expect(find.text(_episodes[1].title!), findsNothing);
        selected = null;
        await tester.tap(find.text('Reveal details').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.text('Play Episode 2'), findsOneWidget);
        await tester.tap(find.text('Play Episode 2'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(_sheet, findsNothing);
        expect(find.text(_episodes[1].synopsis!), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'direct episode sheet defaults to guarded, including an upcoming non-playing episode',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEpisodeInfoSheetForTesting(
                  context,
                  episode: _episodes[1],
                  animeTitle: 'Demo anime',
                  fallbackPoster: _poster,
                  isPlaying: false,
                  onPlay: () {},
                ),
                child: const Text('Open info'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open info'));
      await tester.pumpAndSettle();
      expect(find.text(_episodes[1].title!), findsNothing);
      expect(find.text(_episodes[1].synopsis!), findsNothing);
      expect(_imageUrls(tester), contains(_poster));
      expect(_imageUrls(tester), isNot(contains(_episodes[1].thumbnail)));
      await tester.tap(_sheetReveal);
      await tester.pumpAndSettle();
      expect(find.text(_episodes[1].title!), findsOneWidget);
      expect(find.text(_episodes[1].synopsis!), findsOneWidget);
      expect(_imageUrls(tester), contains(_episodes[1].thumbnail));
      expect(tester.takeException(), isNull);
    },
  );
}
