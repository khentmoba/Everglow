import 'package:go_router/go_router.dart';

import '../screens/anime_screen.dart';
import '../screens/cinema_screen.dart';
import '../screens/video_player_screen.dart';

/// Routes owned by the cinema feature.
final List<GoRoute> cinemaRoutes = [
  GoRoute(
    path: '/cinema',
    builder: (_, state) => CinemaScreen(
      initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
      initialBrowseOption: state.uri.queryParameters['browse'],
    ),
    routes: [
      GoRoute(
        path: 'video/:id',
        builder: (_, state) => VideoPlayerScreen(
          tmdbId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0,
          mediaType: state.uri.queryParameters['type'] ?? 'movie',
          title: state.uri.queryParameters['title'] ?? '',
          season: int.tryParse(state.uri.queryParameters['season'] ?? ''),
          episode: int.tryParse(state.uri.queryParameters['episode'] ?? ''),
          startSeconds: int.tryParse(state.uri.queryParameters['start'] ?? ''),
          isAnime: state.uri.queryParameters['anime'] == 'true',
          malId: int.tryParse(state.uri.queryParameters['malId'] ?? ''),
        ),
      ),
    ],
  ),
  GoRoute(path: '/anime', builder: (_, _) => const AnimeScreen()),
];
