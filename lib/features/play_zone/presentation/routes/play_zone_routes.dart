import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/play_zone_hub_screen.dart';
import '../screens/chess_game_screen.dart' deferred as chess_lib;
import '../screens/scribble_game_screen.dart' deferred as scribble_lib;
import '../../table_tennis/presentation/screens/table_tennis_game_screen.dart'
    deferred as tt_game_lib;
import '../../table_tennis/presentation/screens/tt_multiplayer_lobby_screen.dart'
    deferred as tt_lobby_lib;

final List<GoRoute> playZoneRoutes = [
  GoRoute(
    path: "/play-zone",
    builder: (_, _) => const PlayZoneHubScreen(),
    routes: [
      GoRoute(
        path: "tt",
        builder: (_, _) => DeferredRouteLoader(
          label: "Table Tennis",
          loadLibrary: tt_game_lib.loadLibrary,
          builder: () => tt_game_lib.TableTennisGameScreen(),
        ),
      ),
      GoRoute(
        path: "tt/lobby",
        builder: (_, _) => DeferredRouteLoader(
          label: "Table Tennis Lobby",
          loadLibrary: tt_lobby_lib.loadLibrary,
          builder: () => tt_lobby_lib.TTMultiplayerLobbyScreen(),
        ),
      ),
      GoRoute(
        path: "scribble",
        builder: (_, _) => DeferredRouteLoader(
          label: "Scribble",
          loadLibrary: scribble_lib.loadLibrary,
          builder: () => scribble_lib.ScribbleGameScreen(),
        ),
      ),
      GoRoute(
        path: "chess",
        builder: (_, _) => DeferredRouteLoader(
          label: "Chess",
          loadLibrary: chess_lib.loadLibrary,
          builder: () => chess_lib.ChessGameScreen(),
        ),
      ),
    ],
  ),
];