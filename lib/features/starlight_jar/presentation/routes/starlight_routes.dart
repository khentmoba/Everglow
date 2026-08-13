import 'package:go_router/go_router.dart';

import '../screens/starlight_page.dart';

/// Routes owned by the starlight jar feature.
final List<GoRoute> starlightRoutes = [
  GoRoute(path: '/starlight', builder: (_, _) => const StarlightPage()),
];
