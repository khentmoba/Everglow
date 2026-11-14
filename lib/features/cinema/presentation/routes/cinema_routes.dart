import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/cinema_screen.dart' deferred as cinema_lib;
import '../screens/video_player_screen.dart' deferred as player_lib;
import '../widgets/cinema_loading_shell.dart';

/// Starts downloading the Cinema screen's code chunk before the first tap, so
/// opening Cinema does not wait on a download. See [DeferredRouteLoader.warm].
Future<void> warmCinemaLibrary() =>
    DeferredRouteLoader.warm('Cinema', cinema_lib.loadLibrary);

/// Routes owned by the cinema feature.
final List<GoRoute> cinemaRoutes = [
  GoRoute(
    path: '/cinema',
    builder: (_, state) => DeferredRouteLoader(
      label: 'Cinema',
      loadingBuilder: (_) => const CinemaLoadingShell(),
      loadLibrary: cinema_lib.loadLibrary,
      builder: () => cinema_lib.CinemaScreen(
        initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        initialBrowseOption: state.uri.queryParameters['browse'],
      ),
    ),
    routes: [
      GoRoute(
        path: 'video/:id',
        builder: (_, state) => DeferredRouteLoader(
          label: 'Cinema player',
          loadLibrary: player_lib.loadLibrary,
          builder: () => player_lib.VideoPlayerScreen(
            tmdbId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0,
            mediaType: state.uri.queryParameters['type'] ?? 'movie',
            title: state.uri.queryParameters['title'] ?? '',
            season: int.tryParse(state.uri.queryParameters['season'] ?? ''),
            episode: int.tryParse(state.uri.queryParameters['episode'] ?? ''),
            startSeconds: int.tryParse(
              state.uri.queryParameters['start'] ?? '',
            ),
            isAnime: state.uri.queryParameters['anime'] == 'true',
            malId: int.tryParse(state.uri.queryParameters['malId'] ?? ''),
            posterPath: state.uri.queryParameters['poster'] ?? '',
            allEpisodesWatched: state.uri.queryParameters['watched'] == 'true',
            currentEpisodeCompleted:
                state.uri.queryParameters['completed'] == 'true',
          ),
        ),
      ),
    ],
  ),
];
