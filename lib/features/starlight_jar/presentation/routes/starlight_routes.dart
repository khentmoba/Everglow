import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/starlight_page.dart' deferred as starlight_lib;

/// Routes owned by the starlight jar feature.
final List<GoRoute> starlightRoutes = [
  GoRoute(
    path: '/starlight',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Starlight Jar',
      loadLibrary: starlight_lib.loadLibrary,
      builder: () => starlight_lib.StarlightPage(),
    ),
  ),
];
