import 'package:go_router/go_router.dart';
import '../screens/travel_screen.dart';
import '../screens/trip_detail_screen.dart';

final List<GoRoute> travelRoutes = [
  GoRoute(path: '/travel', builder: (_, _) => const TravelScreen()),
  GoRoute(path: '/travel/:tripId', builder: (context, state) => TripDetailScreen(tripId: state.pathParameters['tripId']!)),
];
