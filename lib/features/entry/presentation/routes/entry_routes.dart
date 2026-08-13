import 'package:go_router/go_router.dart';

import '../pages/gateway_page.dart';

/// Routes owned by the entry feature.
final List<GoRoute> gatewayRoutes = [
  GoRoute(path: '/', builder: (_, _) => const GatewayPage()),
];
