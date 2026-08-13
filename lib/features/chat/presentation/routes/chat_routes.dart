import 'package:go_router/go_router.dart';

import '../screens/sanctuary_chat_screen.dart';

/// Routes owned by the chat feature.
final List<GoRoute> chatRoutes = [
  GoRoute(path: '/sanctuary', builder: (_, _) => const SanctuaryChatScreen()),
];
