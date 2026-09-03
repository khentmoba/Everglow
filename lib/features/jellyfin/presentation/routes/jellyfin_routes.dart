import "package:go_router/go_router.dart";

import "../../../../../core/router/deferred_route.dart";
// Archive search + download UI splits out of the initial bundle (see
// docs/PERF_NOTES.md); loaded on first visit to /party-downloads.
import "../screens/party_downloads_screen.dart" deferred as downloads_lib;

/// Routes owned by the jellyfin library feature.
final List<GoRoute> jellyfinRoutes = [
  GoRoute(
    path: "/party-downloads",
    builder: (_, _) => DeferredRouteLoader(
      label: "Party Downloads",
      loadLibrary: downloads_lib.loadLibrary,
      builder: () => downloads_lib.PartyDownloadsScreen(),
    ),
  ),
];