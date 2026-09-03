import "package:go_router/go_router.dart";
import "../../../../core/router/deferred_route.dart";
import "../../../../core/router/route_helpers.dart";

import "../../data/models/watch_party_room.dart";
// The player (WebRTC voice + synced playback + chat) splits out of the
// initial bundle via a deferred import (see docs/PERF_NOTES.md). Direct
// pushes from the watch-together widgets use the same chunk via their own
// deferred imports.
import "../screens/watch_party_screen.dart" deferred as party_lib;

/// Routes owned by the watch party feature.
final List<GoRoute> watchPartyRoutes = [
  GoRoute(
    path: "/watch-party",
    builder: (_, state) {
      final args = extraOf<WatchPartyArgs>(state);
      if (args == null) return missingExtraPage(state);
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

/// Args for [WatchPartyScreen].
class WatchPartyArgs {
  final WatchPartyRoom room;
  final bool isHost;

  WatchPartyArgs({required this.room, required this.isHost});
}