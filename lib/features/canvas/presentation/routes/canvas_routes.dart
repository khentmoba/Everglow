import 'package:go_router/go_router.dart';

import '../screens/canvas_screen.dart';

/// Routes owned by the canvas feature.
final List<GoRoute> canvasRoutes = [
  GoRoute(path: '/canvas', builder: (_, _) => const CanvasScreen()),
];
