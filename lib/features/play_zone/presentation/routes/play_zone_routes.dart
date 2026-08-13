import 'package:go_router/go_router.dart';

import '../../table_tennis/presentation/screens/table_tennis_game_screen.dart';
import '../../table_tennis/presentation/screens/tt_multiplayer_lobby_screen.dart';
import '../screens/play_zone_hub_screen.dart';

/// Routes owned by the play zone feature.
final List<GoRoute> playZoneRoutes = [
  GoRoute(
    path: '/play-zone',
    builder: (_, _) => const PlayZoneHubScreen(),
    routes: [
      GoRoute(path: 'tt', builder: (_, _) => const TableTennisGameScreen()),
      GoRoute(
        path: 'tt/lobby',
        builder: (_, _) => const TTMultiplayerLobbyScreen(),
      ),
    ],
  ),
];
