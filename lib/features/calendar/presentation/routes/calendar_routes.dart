import 'package:go_router/go_router.dart';

import '../screens/calendar_screen.dart';

/// Routes owned by the calendar feature.
final List<GoRoute> calendarRoutes = [
  GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
];
