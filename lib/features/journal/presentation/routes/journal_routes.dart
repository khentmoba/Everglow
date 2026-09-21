import 'package:go_router/go_router.dart';

import '../../../../core/router/deferred_route.dart';
import '../screens/journal_screen.dart' deferred as journal_lib;

final List<GoRoute> journalRoutes = [
  GoRoute(
    path: '/journal',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Journal',
      loadLibrary: journal_lib.loadLibrary,
      builder: () => journal_lib.JournalScreen(),
    ),
  ),
];
