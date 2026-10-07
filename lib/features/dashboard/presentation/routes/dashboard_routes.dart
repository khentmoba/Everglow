import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/dashboard_screen.dart' deferred as dashboard_lib;
import '../screens/letterbox_archive_screen.dart' deferred as letterbox_lib;

/// Routes owned by the dashboard feature.
final List<GoRoute> dashboardRoutes = [
  GoRoute(
    path: '/dashboard',
    builder: (_, state) => DeferredRouteLoader(
      label: 'Home',
      loadLibrary: dashboard_lib.loadLibrary,
      builder: () =>
          dashboard_lib.DashboardScreen(animate: state.extra == true),
    ),
  ),
  GoRoute(
    path: '/letterbox',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Letterbox',
      loadLibrary: letterbox_lib.loadLibrary,
      builder: () => letterbox_lib.LetterboxArchiveScreen(),
    ),
  ),
];
