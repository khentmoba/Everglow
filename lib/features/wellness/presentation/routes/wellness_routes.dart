import 'package:go_router/go_router.dart';
import '../screens/wellness_screen.dart';

final List<GoRoute> wellnessRoutes = [
  GoRoute(path: '/wellness', builder: (_, _) => const WellnessScreen()),
];
