import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../widgets/shared_garden_view.dart' deferred as garden_lib;

/// Routes owned by the daily bloom / shared garden feature.
final List<GoRoute> gardenRoutes = [
  GoRoute(
    path: '/garden',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Our Garden',
      loadLibrary: garden_lib.loadLibrary,
      builder: () => garden_lib.SharedGardenView(),
    ),
  ),
];
