import "package:go_router/go_router.dart";

import "../../../../core/router/deferred_route.dart";
// Cookbook splits out of the initial bundle (see docs/PERF_NOTES.md).
import "../screens/cookbook_screen.dart" deferred as cookbook_lib;

final List<GoRoute> cookbookRoutes = [
  GoRoute(
    path: "/cookbook",
    builder: (_, _) => DeferredRouteLoader(
      label: "Cookbook",
      loadLibrary: cookbook_lib.loadLibrary,
      builder: () => cookbook_lib.CookbookScreen(),
    ),
  ),
];