import 'package:go_router/go_router.dart';

import '../screens/memory_book_screen.dart';
import '../screens/memory_trivia_screen.dart';
import '../screens/mochi_today_screen.dart';
import '../screens/study_screen.dart';
import '../widgets/mochi_screen.dart';

/// Routes owned by the AI / Mochi feature.
final List<GoRoute> aiRoutes = [
  GoRoute(path: '/mochi', builder: (_, _) => const MochiScreen()),
  GoRoute(path: '/mochi-memory', builder: (_, _) => const MemoryBookScreen()),
  GoRoute(path: '/mochi-trivia', builder: (_, _) => const MemoryTriviaScreen()),
  GoRoute(path: '/mochi-today', builder: (_, _) => const MochiTodayScreen()),
  GoRoute(path: '/study', builder: (_, _) => const StudyScreen()),
];
