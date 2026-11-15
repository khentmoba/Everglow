import 'package:go_router/go_router.dart';
import '../../../../core/router/deferred_route.dart';
import '../../../../core/router/route_helpers.dart';

import '../../data/models/watch_party_room.dart';
import '../screens/watch_party_lobby_screen.dart';
import '../screens/watch_party_screen.dart' deferred as party_lib;

final List<GoRoute> watchPartyRoutes = [
  GoRoute(
    path: "/watch-party",
    builder: (_, state) {
      final args = extraOf<WatchPartyArgs>(state);
      if (args == null) return const WatchPartyLobbyScreen();
      return DeferredRouteLoader(
        label: "Watch Party",
        loadLibrary: party_lib.loadLibrary,
        builder: () => party_lib.WatchPartyScreen(
          initialRoom: args.room,
          isHost: args.isHost,
        ),
      );
    },
  ),
];

class WatchPartyArgs {
  final WatchPartyRoom room;
  final bool isHost;

  WatchPartyArgs({required this.room, required this.isHost});
}