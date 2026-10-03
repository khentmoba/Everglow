import 'package:go_router/go_router.dart';

import '../screens/tonight_screen.dart';

/// Routes owned by the Tonight decision feature.
final List<GoRoute> tonightRoutes = [
  GoRoute(path: '/tonight', builder: (_, _) => const TonightScreen()),
];
