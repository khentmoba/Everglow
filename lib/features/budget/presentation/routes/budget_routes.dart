import "package:go_router/go_router.dart";

import "../../../../core/router/deferred_route.dart";
// Budget tracker splits out of the initial bundle (see docs/PERF_NOTES.md).
import "../screens/budget_screen.dart" deferred as budget_lib;

final List<GoRoute> budgetRoutes = [
  GoRoute(
    path: "/budget",
    builder: (_, _) => DeferredRouteLoader(
      label: "Budget",
      loadLibrary: budget_lib.loadLibrary,
      builder: () => budget_lib.BudgetScreen(),
    ),
  ),
];