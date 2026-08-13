import 'package:go_router/go_router.dart';
import '../../../../core/router/route_helpers.dart';

import '../../data/models/watch_party_room.dart';
import '../screens/watch_party_screen.dart';

/// Routes owned by the watch party feature.
final List<GoRoute> watchPartyRoutes = [
  GoRoute(
    path: '/watch-party',
    builder: (_, state) {
      final args = extraOf<WatchPartyArgs>(state);
      if (args == null) return missingExtraPage(state);
      return WatchPartyScreen(initialRoom: args.room, isHost: args.isHost);
    },
  ),
];

/// Args for [WatchPartyScreen].
class WatchPartyArgs {
  final WatchPartyRoom room;
  final bool isHost;

  WatchPartyArgs({required this.room, required this.isHost});
}
