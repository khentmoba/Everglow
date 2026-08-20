import 'package:go_router/go_router.dart';
import '../screens/rag_screen.dart';

final List<GoRoute> ragRoutes = [
  GoRoute(path: '/rag', builder: (_, _) => const RagScreen()),
];
