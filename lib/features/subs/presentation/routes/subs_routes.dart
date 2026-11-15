import 'package:go_router/go_router.dart';

import '../screens/subs_screen.dart';

final List<GoRoute> subsRoutes = [
  GoRoute(path: '/subs', builder: (_, _) => const SubsScreen()),
];
