import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../../../../core/theme/section_fonts.dart';
import '../screens/memory_book_screen.dart' deferred as memory_book_lib;
import '../screens/memory_trivia_screen.dart' deferred as memory_trivia_lib;
import '../screens/motchi_minis_screen.dart' deferred as motchi_minis_lib;
import '../screens/motchi_today_screen.dart' deferred as motchi_today_lib;
import '../screens/motchi_preferences_screen.dart' deferred as motchi_prefs_lib;
import '../screens/study_screen.dart' deferred as study_lib;
import '../widgets/motchi_screen.dart' deferred as motchi_lib;

/// Routes owned by the AI / Motchi feature.
final List<GoRoute> aiRoutes = [
  GoRoute(
    path: '/motchi',
    builder: (_, state) => DeferredRouteLoader(
      label: 'Motchi',
      // This used to load only the section font and then build MotchiScreen
      // directly, so the ~35KB screen stayed in the initial bundle while the
      // loader made it look deferred. Load the screen's chunk too.
      loadLibrary: () async {
        await Future.wait([motchi_lib.loadLibrary(), SectionFonts.reading()]);
      },
      builder: () => motchi_lib.MotchiScreen(
        initialPrompt: state.extra is String ? state.extra as String : null,
      ),
    ),
  ),
  GoRoute(
    path: '/motchi-preferences',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Motchi settings',
      loadLibrary: motchi_prefs_lib.loadLibrary,
      builder: () => motchi_prefs_lib.MotchiPreferencesScreen(),
    ),
  ),
  GoRoute(
    path: '/motchi-memory',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Your memories',
      loadLibrary: memory_book_lib.loadLibrary,
      builder: () => memory_book_lib.MemoryBookScreen(),
    ),
  ),
  GoRoute(
    path: '/motchi-trivia',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Memory trivia',
      loadLibrary: memory_trivia_lib.loadLibrary,
      builder: () => memory_trivia_lib.MemoryTriviaScreen(),
    ),
  ),
  GoRoute(
    path: '/motchi-today',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Today',
      loadLibrary: motchi_today_lib.loadLibrary,
      builder: () => motchi_today_lib.MotchiTodayScreen(),
    ),
  ),
  GoRoute(
    path: '/motchi-minis',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Minis',
      loadLibrary: motchi_minis_lib.loadLibrary,
      builder: () => motchi_minis_lib.MotchiMinisScreen(),
    ),
  ),
  GoRoute(
    path: '/study',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Study',
      loadLibrary: study_lib.loadLibrary,
      builder: () => study_lib.StudyScreen(),
    ),
  ),
];
