import 'package:go_router/go_router.dart';

import '../screens/party_downloads_screen.dart';

/// Routes owned by the jellyfin library feature.
final List<GoRoute> jellyfinRoutes = [
  GoRoute(
    path: '/party-downloads',
    builder: (_, _) => const PartyDownloadsScreen(),
  ),
];
