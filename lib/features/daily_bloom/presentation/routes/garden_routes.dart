import 'package:go_router/go_router.dart';

import '../widgets/shared_garden_view.dart';

/// Routes owned by the daily bloom / shared garden feature.
final List<GoRoute> gardenRoutes = [
  GoRoute(path: '/garden', builder: (_, _) => const SharedGardenView()),
];
