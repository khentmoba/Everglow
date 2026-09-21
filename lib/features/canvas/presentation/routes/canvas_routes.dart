import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/canvas_screen.dart' deferred as canvas_lib;

/// Routes owned by the canvas feature.
final List<GoRoute> canvasRoutes = [
  GoRoute(
    path: '/canvas',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Canvas',
      loadLibrary: canvas_lib.loadLibrary,
      builder: () => canvas_lib.CanvasScreen(),
    ),
  ),
];
