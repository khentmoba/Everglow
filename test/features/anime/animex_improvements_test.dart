import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/data/services/anilist_service.dart';
import 'package:everglow/features/anime/presentation/screens/anime_screen.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_browse_page.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_navigation.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_poster_card.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

MediaItem _testAnime({
  int anilistId = 1500,
  int malId = 500,
  String title = 'Slime Reincarnation Chronicle',
  String source = 'jikan',
}) =>
    MediaItem(
      id: 'test-anime',
      tmdbId: malId,
      anilistId: anilistId,
      title: title,
      mediaType: 'tv',
      posterPath: '/slime.jpg',
      year: '2026',
      status: 'airing',
      isAnime: true,
      addedAt: DateTime(2026),
      source: source,
      score: 8.5,
      episodeCount: 24,
      currentEpisode: 3,
      airingStatus: 'RELEASING',
      format: 'TV',
      genres: const ['Action', 'Fantasy', 'Isekai', 'Reincarnation'],
      synopsis: 'A corporate worker wakes up in an enchanted fantasy realm.',
    );

class _MockAniListService implements AniListService {
  @override
  Future<AnimexMediaPage> fetchAnimexPage({
    String? search,
    String? sort,
    String? status,
    String? season,
    int? seasonYear,
    String? format,
    String? genre,
    List<String>? genres,
    int page = 1,
    int perPage = 24,
  }) async {
    return const AnimexMediaPage(
      items: [],
      scores: [],
      currentPage: 1,
      hasNextPage: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AnimeXNavigation', () {
    test('buildAnimeUri builds URL with query parameters', () {
      final item = _testAnime();
      final uri = AnimeXNavigation.buildAnimeUri(item);

      expect(uri.path, '/anime');
      expect(uri.queryParameters['id'], '1500');
      expect(uri.queryParameters['malId'], '500');
      expect(uri.queryParameters['title'], 'Slime Reincarnation Chronicle');
      expect(uri.queryParameters['poster'], '/slime.jpg');
      expect(uri.queryParameters['ep'], '3');
      expect(uri.queryParameters['type'], 'tv');
      expect(uri.queryParameters['format'], 'TV');
    });

    test('buildAnimeUri preserves movie format and TMDB source correctly', () {
      final movie = MediaItem(
        id: 'movie-1',
        tmdbId: 888,
        title: 'Your Name.',
        mediaType: 'movie',
        posterPath: '/movie.jpg',
        year: '2016',
        status: '',
        isAnime: true,
        addedAt: DateTime(2026),
        source: 'tmdb',
        format: 'MOVIE',
      );
      final uri = AnimeXNavigation.buildAnimeUri(movie);

      expect(uri.path, '/anime');
      expect(uri.queryParameters['tmdbId'], '888');
      expect(uri.queryParameters['source'], 'tmdb');
      expect(uri.queryParameters['type'], 'movie');
      expect(uri.queryParameters['format'], 'MOVIE');
    });

    test('openInNewTab triggers configured launcher', () async {
      final item = _testAnime();
      Uri? launchedUri;
      AnimeXNavigation.urlLauncherForTesting = (uri) async {
        launchedUri = uri;
        return true;
      };
      addTearDown(() => AnimeXNavigation.urlLauncherForTesting = null);

      final result = await AnimeXNavigation.openInNewTab(item, episode: 5);
      expect(result, isTrue);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters['ep'], '5');
      expect(launchedUri!.queryParameters['id'], '1500');
    });

    test('isMiddleClick identifies mouse tertiary button', () {
      const middleDown = PointerDownEvent(
        buttons: kTertiaryButton,
      );
      const leftDown = PointerDownEvent(
        buttons: kPrimaryButton,
      );
      const rightDown = PointerDownEvent(
        buttons: kSecondaryButton,
      );

      expect(AnimeXNavigation.isMiddleClick(middleDown), isTrue);
      expect(AnimeXNavigation.isMiddleClick(leftDown), isFalse);
      expect(AnimeXNavigation.isMiddleClick(rightDown), isFalse);
    });
  });

  group('AnimeXPosterCard middle click & open in new tab', () {
    testWidgets('middle click on poster opens anime in new tab', (
      tester,
    ) async {
      final item = _testAnime();
      Uri? launchedUri;
      AnimeXNavigation.urlLauncherForTesting = (uri) async {
        launchedUri = uri;
        return true;
      };
      addTearDown(() => AnimeXNavigation.urlLauncherForTesting = null);

      bool tappedNormal = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeXPosterCard(
              item: item,
              onTap: () => tappedNormal = true,
            ),
          ),
        ),
      );

      final cardFinder = find.byType(AnimeXPosterCard);
      expect(cardFinder, findsOneWidget);

      // Perform middle-click (buttons: kTertiaryButton)
      final center = tester.getCenter(cardFinder);
      final testPointer = TestPointer(1, PointerDeviceKind.mouse, 0, kTertiaryButton);
      await tester.sendEventToBinding(testPointer.down(center));
      await tester.pump();
      await tester.sendEventToBinding(testPointer.up());
      await tester.pump();

      expect(tappedNormal, isFalse);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters['id'], '1500');
      expect(launchedUri!.queryParameters['title'], 'Slime Reincarnation Chronicle');
    });

    testWidgets('normal left click triggers onTap', (tester) async {
      final item = _testAnime();
      bool tappedNormal = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeXPosterCard(
              item: item,
              onTap: () => tappedNormal = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AnimeXPosterCard));
      await tester.pump();

      expect(tappedNormal, isTrue);
    });
  });

  group('AnimeXController Multi-genre', () {
    test('presetBrowse sets multiple genres and backward-compatible getter', () {
      final controller = AnimeXController();
      addTearDown(controller.dispose);

      controller.presetBrowse(genres: ['Fantasy', 'Reincarnation']);
      expect(controller.browseGenres, ['Fantasy', 'Reincarnation']);
      expect(controller.browseGenre, 'Fantasy');

      controller.browseGenre = 'Action';
      expect(controller.browseGenres, ['Action']);
      expect(controller.browseGenre, 'Action');

      controller.browseGenre = null;
      expect(controller.browseGenres, isEmpty);
      expect(controller.browseGenre, isNull);
    });
  });

  group('AnimeXBrowsePage Multi-genre UI', () {
    testWidgets('multi-genre picker sheet toggles genres and applies filter', (
      tester,
    ) async {
      final controller = AnimeXController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimeXBrowsePage(
              controller: controller,
              service: _MockAniListService(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Look for the initial "All Genres" button
      expect(find.text('All Genres'), findsOneWidget);

      // Tap on "All Genres" to open the picker sheet
      await tester.tap(find.text('All Genres'));
      await tester.pumpAndSettle();

      expect(find.text('Select Genres & Themes'), findsOneWidget);
      expect(find.text('Fantasy'), findsOneWidget);
      expect(find.text('Reincarnation'), findsOneWidget);

      // Select 'Fantasy' and 'Reincarnation'
      await tester.tap(find.text('Fantasy'));
      await tester.pump();
      await tester.tap(find.text('Reincarnation'));
      await tester.pump();

      // Button in sheet shows 'Apply (2)'
      expect(find.text('Apply (2)'), findsOneWidget);
      await tester.tap(find.text('Apply (2)'));
      await tester.pumpAndSettle();

      // Browse page now shows Genres (2)
      expect(find.text('Genres (2)'), findsOneWidget);
      expect(controller.browseGenres, containsAll(['Fantasy', 'Reincarnation']));

      // Active genre chips are visible
      expect(find.text('Clear all'), findsOneWidget);

      // Tap 'Clear all' to reset
      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(find.text('All Genres'), findsOneWidget);
      expect(controller.browseGenres, isEmpty);
    });
  });

  group('AnimeScreen & AnimeXController deep linking', () {
    test('AnimeScreen passes initial parameters and AnimeXController opens watch item', () {
      const screen = AnimeScreen(
        initialAnilistId: 9999,
        initialMalId: 8888,
        initialTmdbId: 7777,
        initialSource: 'tmdb',
        initialType: 'movie',
        initialFormat: 'MOVIE',
        initialTitle: 'Direct Loaded Movie',
        initialEpisode: 1,
      );

      expect(screen.initialAnilistId, 9999);
      expect(screen.initialMalId, 8888);
      expect(screen.initialTmdbId, 7777);
      expect(screen.initialSource, 'tmdb');
      expect(screen.initialType, 'movie');
      expect(screen.initialFormat, 'MOVIE');
      expect(screen.initialTitle, 'Direct Loaded Movie');
      expect(screen.initialEpisode, 1);

      final controller = AnimeXController();
      addTearDown(controller.dispose);

      final item = _testAnime(anilistId: 9999, malId: 8888, title: 'Direct Loaded Movie').copyWith(
        mediaType: 'movie',
        format: 'MOVIE',
        source: 'tmdb',
        tmdbId: 7777,
      );
      controller.openWatch(item, episode: 1);

      expect(controller.watchItem, isNotNull);
      expect(controller.watchItem!.anilistId, 9999);
      expect(controller.watchItem!.tmdbId, 7777);
      expect(controller.watchItem!.mediaType, 'movie');
      expect(controller.watchItem!.format, 'MOVIE');
      expect(controller.watchItem!.source, 'tmdb');
      expect(controller.watchItem!.title, 'Direct Loaded Movie');
      expect(controller.watchEpisode, 1);

      controller.closeDetail();
      expect(controller.watchItem, isNull);
      expect(controller.watchEpisode, isNull);
    });
  });

  group('SelectionArea', () {
    testWidgets('wrapped text in SelectionArea is selectable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: Text('Copyable Anime Synopsis and Title'),
            ),
          ),
        ),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.text('Copyable Anime Synopsis and Title'), findsOneWidget);
    });
  });
}
