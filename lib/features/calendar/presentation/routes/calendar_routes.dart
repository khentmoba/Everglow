import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/calendar_screen.dart' deferred as calendar_lib;

/// Routes owned by the calendar feature.
final List<GoRoute> calendarRoutes = [
  GoRoute(
    path: '/calendar',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Calendar',
      loadLibrary: calendar_lib.loadLibrary,
      builder: () => calendar_lib.CalendarScreen(),
    ),
  ),
];
