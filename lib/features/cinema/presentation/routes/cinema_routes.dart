import 'package:go_router/go_router.dart';

import '../../../../core/network/network_quality_service.dart';
import '../../../../core/router/deferred_route.dart';
import '../../../../core/utils/logger.dart';
import '../screens/cinema_screen.dart' deferred as cinema_lib;
import '../screens/video_player_screen.dart' deferred as player_lib;
import '../widgets/cinema_loading_shell.dart';

/// Starts downloading the Cinema screen's code chunk before the first tap, so
/// opening Cinema does not wait on a download.
///
/// Skipped on a slow or data-saving connection, where the download would
/// compete with the page Clair is actually looking at. Safe to call more than
/// once: a loaded library is reused, so later calls resolve immediately.
Future<void> warmCinemaLibrary() async {
  final network = NetworkQualityService.instance;
  if (network.isSlowConnection || network.isSaveData) return;
  try {
    await cinema_lib.loadLibrary();
  } catch (e, st) {
    Logger.w('Cinema: library warm-up failed', error: e, stackTrace: st);
  }
}

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
