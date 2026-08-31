import 'package:go_router/go_router.dart';

import '../screens/anime_screen.dart';

/// Routes owned by the anime feature.
final List<GoRoute> animeRoutes = [
  GoRoute(path: '/anime', builder: (_, _) => const AnimeScreen()),
];
