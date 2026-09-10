import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/memory_book_screen.dart';
import '../screens/memory_trivia_screen.dart';
import '../screens/motchi_today_screen.dart';
import '../screens/study_screen.dart' deferred as study_lib;
import '../widgets/motchi_screen.dart';

/// Routes owned by the AI / Motchi feature.
final List<GoRoute> aiRoutes = [
  GoRoute(path: '/motchi', builder: (_, _) => const MotchiScreen()),
  GoRoute(path: '/motchi-memory', builder: (_, _) => const MemoryBookScreen()),
  GoRoute(path: '/motchi-trivia', builder: (_, _) => const MemoryTriviaScreen()),
  GoRoute(path: '/motchi-today', builder: (_, _) => const MotchiTodayScreen()),
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
