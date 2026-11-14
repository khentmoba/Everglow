import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../../../../core/theme/section_fonts.dart';
import '../screens/anime_screen.dart' deferred as anime_lib;

Future<void> _loadAnime() async {
  await Future.wait([anime_lib.loadLibrary(), SectionFonts.anime()]);
}

/// Fetches Anime's code chunk and fonts before the first tap.
Future<void> warmAnimeLibrary() =>
    DeferredRouteLoader.warm('Anime', _loadAnime);

/// Routes owned by the anime feature.
final List<GoRoute> animeRoutes = [
  GoRoute(
    path: '/anime',
    builder: (_, state) => DeferredRouteLoader(
      label: 'Anime',
      loadLibrary: _loadAnime,
      builder: () => anime_lib.AnimeScreen(
        initialAnilistId: int.tryParse(
          state.uri.queryParameters['id'] ??
              state.uri.queryParameters['anilistId'] ??
              '',
        ),
        initialMalId: int.tryParse(state.uri.queryParameters['malId'] ?? ''),
        initialTmdbId: int.tryParse(state.uri.queryParameters['tmdbId'] ?? ''),
        initialSource: state.uri.queryParameters['source'],
        initialType: state.uri.queryParameters['type'],
        initialFormat: state.uri.queryParameters['format'],
        initialTitle: state.uri.queryParameters['title'],
        initialPoster: state.uri.queryParameters['poster'],
        initialEpisode: int.tryParse(state.uri.queryParameters['ep'] ?? ''),
      ),
    ),
  ),
];
