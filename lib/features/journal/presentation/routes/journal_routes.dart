import 'package:go_router/go_router.dart';
import '../screens/journal_screen.dart';

final List<GoRoute> journalRoutes = [
  GoRoute(path: '/journal', builder: (_, _) => const JournalScreen()),
];
