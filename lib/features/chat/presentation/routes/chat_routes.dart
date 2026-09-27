import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/sanctuary_chat_screen.dart' deferred as chat_lib;

/// Routes owned by the chat feature.
final List<GoRoute> chatRoutes = [
  GoRoute(
    path: '/sanctuary',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Sanctuary',
      loadLibrary: chat_lib.loadLibrary,
      builder: () => chat_lib.SanctuaryChatScreen(),
    ),
  ),
];
