import 'package:go_router/go_router.dart';
import '../screens/cookbook_screen.dart';

final List<GoRoute> cookbookRoutes = [
  GoRoute(path: '/cookbook', builder: (_, _) => const CookbookScreen()),
];
