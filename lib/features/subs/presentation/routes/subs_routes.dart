import 'package:go_router/go_router.dart';

import '../screens/subs_screen.dart';

/// Routes owned by the subs tracker feature.
final List<GoRoute> subsRoutes = [
  GoRoute(path: '/subs', builder: (_, _) => const SubsScreen()),
];
