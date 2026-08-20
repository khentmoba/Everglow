import 'package:go_router/go_router.dart';
import '../screens/budget_screen.dart';

final List<GoRoute> budgetRoutes = [
  GoRoute(path: '/budget', builder: (_, _) => const BudgetScreen()),
];
