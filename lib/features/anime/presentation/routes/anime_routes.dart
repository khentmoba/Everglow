import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/anime_screen.dart' deferred as anime_lib;

/// Routes owned by the anime feature.
final List<GoRoute> animeRoutes = [
  GoRoute(
    path: '/anime',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Anime',
      loadLibrary: anime_lib.loadLibrary,
      builder: () => anime_lib.AnimeScreen(),
    ),
  ),
];
