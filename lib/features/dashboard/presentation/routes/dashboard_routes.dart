import 'package:go_router/go_router.dart';

import '../screens/dashboard_screen.dart';
import '../screens/letterbox_archive_screen.dart';

/// Routes owned by the dashboard feature.
final List<GoRoute> dashboardRoutes = [
  GoRoute(
    path: '/dashboard',
    builder: (_, state) => DashboardScreen(animate: state.extra == true),
  ),
  GoRoute(
    path: '/letterbox',
    builder: (_, _) => const LetterboxArchiveScreen(),
  ),
];
