import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/money_screen.dart' deferred as money_lib;

/// Routes owned by the money feature.
final List<GoRoute> moneyRoutes = [
  GoRoute(
    path: '/money',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Money',
      loadLibrary: money_lib.loadLibrary,
      builder: () => money_lib.MoneyScreen(),
    ),
  ),
];
