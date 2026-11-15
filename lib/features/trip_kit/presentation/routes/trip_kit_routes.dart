import 'package:go_router/go_router.dart';

import '../screens/trip_detail_screen.dart';
import '../screens/trip_list_screen.dart';

final List<GoRoute> tripKitRoutes = [
  GoRoute(path: '/trips', builder: (_, _) => const TripListScreen()),
  GoRoute(
    path: '/trips/:id',
    builder: (_, state) => TripDetailScreen(
      tripId: state.pathParameters['id'] ?? '',
    ),
  ),
];
