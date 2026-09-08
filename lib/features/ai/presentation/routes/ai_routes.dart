import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/memory_book_screen.dart';
import '../screens/memory_trivia_screen.dart';
import '../screens/mochi_today_screen.dart';
import '../screens/study_screen.dart' deferred as study_lib;
import '../widgets/mochi_screen.dart';

/// Routes owned by the AI / Mochi feature.
final List<GoRoute> aiRoutes = [
  GoRoute(path: '/mochi', builder: (_, _) => const MochiScreen()),
  GoRoute(path: '/mochi-memory', builder: (_, _) => const MemoryBookScreen()),
  GoRoute(path: '/mochi-trivia', builder: (_, _) => const MemoryTriviaScreen()),
  GoRoute(path: '/mochi-today', builder: (_, _) => const MochiTodayScreen()),
  // Study screen pulls syncfusion PDF (~10MB) via StudyDocService — split
  // it out of the initial bundle with a deferred import.
  GoRoute(
    path: '/study',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Study',
      loadLibrary: study_lib.loadLibrary,
      builder: () => study_lib.StudyScreen(),
    ),
  ),
];
