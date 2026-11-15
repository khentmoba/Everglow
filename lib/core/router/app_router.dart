import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/academy/presentation/routes/academy_routes.dart';
import '../../features/ai/presentation/routes/ai_routes.dart';
import '../../features/books/presentation/routes/books_routes.dart';
import '../../features/bucket_list/presentation/routes/bucket_list_routes.dart';
import '../../features/calendar/presentation/routes/calendar_routes.dart';
import '../../features/canvas/presentation/routes/canvas_routes.dart';
import '../../features/chat/presentation/routes/chat_routes.dart';
import '../../features/cinema/presentation/routes/cinema_routes.dart';
import '../../features/anime/presentation/routes/anime_routes.dart';
import '../../features/daily_bloom/presentation/routes/garden_routes.dart';
import '../../features/dashboard/presentation/routes/dashboard_routes.dart';
import '../../features/entry/presentation/routes/entry_routes.dart';
import '../../features/gallery/presentation/routes/gallery_routes.dart';
import '../../features/manga/presentation/routes/manga_routes.dart';
import '../../features/play_zone/presentation/routes/play_zone_routes.dart';
import '../../features/starlight_jar/presentation/routes/starlight_routes.dart';
import '../../features/subs/presentation/routes/subs_routes.dart';
import '../../features/watch_party/presentation/routes/watch_party_routes.dart';
import '../../features/jukebox/presentation/routes/jukebox_routes.dart';
import '../../features/journal/presentation/routes/journal_routes.dart';
import '../../features/money/presentation/routes/money_routes.dart';
import '../../features/trip_kit/presentation/routes/trip_kit_routes.dart';
import '../../features/tonight/presentation/routes/tonight_routes.dart';
import '../agent/agent_mode.dart';
import '../perf/perf_bench_route.dart';
import '../system/tv_mode.dart';
import '../theme/app_breakpoints.dart';
import 'app_error_page.dart';
import 'route_memory.dart';
import 'route_helpers.dart';
import '../di/app_providers.dart' as di;

GoRouter createAppRouter() {
  final browserUri = Uri.base;
  final initialLocation = browserUri.path == '/' && browserUri.hasQuery
      ? '${browserUri.path}?${browserUri.query}'
      : RouteMemory.bootLocation ?? '/';
  final router = GoRouter(
    refreshListenable: di.authService,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final uri = state.uri;

      final agentParam =
          uri.queryParameters['agent'] ?? uri.queryParameters['demo'];
      final jumpParam =
          uri.queryParameters['jump'] ?? uri.queryParameters['to'];
      String? targetRoute;

      if (agentParam != null) {
        final lower = agentParam.toLowerCase().trim();
        if (AgentMode.routeAliases.containsKey(lower)) {
          targetRoute = AgentMode.routeAliases[lower];
          final profile = lower == 'cinema' ? 'breyan' : 'khentsgdz';
          if (AgentMode.enable(profile: profile)) {
            di.authService.enableAgentSession(profile: profile);
          } else {
            targetRoute = null;
          }
        } else {
          final profile = AgentMode.parseProfile(agentParam);
          if (AgentMode.enable(profile: profile)) {
            di.authService.enableAgentSession(profile: profile);
          }
        }
      } else if (AgentMode.isActive.value &&
          di.authService.currentUser == null) {
        di.authService.enableAgentSession(
          profile: AgentMode.activeProfile.value,
        );
      }

      if (jumpParam != null && jumpParam.isNotEmpty) {
        final lower = jumpParam.toLowerCase().trim();
        targetRoute = AgentMode.routeAliases[lower] ?? jumpParam;
        if (!targetRoute.startsWith('/')) targetRoute = '/$targetRoute';
      }

      if (loc == '/' && targetRoute != null && targetRoute != '/') {
        return agentJumpLocation(uri, targetRoute);
      }

      final isPublic =
          loc == '/' ||
          (kPerfBenchCompiledIn && loc.startsWith('/perf-bench')) ||
          AgentMode.isActive.value;

      if (!di.authService.isSessionLoaded) return null;

      final authed =
          di.authService.isAuthenticated || di.authService.currentUser != null;
      if (!authed && !isPublic) {
        return Uri(
          path: '/',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      if (authed &&
          di.authService.isCinemaOnlyUser &&
          !AgentMode.isActive.value) {
        final bounce = AppErrorPage.cinemaOnlyRedirect(loc);
        if (bounce != null) return bounce;
      }
      return null;
    },

    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ValueListenableBuilder<bool>(
          valueListenable: TvMode.isTvMode,
          builder: (context, isTv, _) =>
              (isTv || AppBreakpoint.isMobile(context))
                  ? child
                  : SelectionArea(child: child),
        ),
        routes: [
          ...gatewayRoutes,
          ...dashboardRoutes,
          ...cinemaRoutes,
          ...animeRoutes,
          ...booksRoutes,
          ...mangaRoutes,
          ...academyRoutes,
          ...playZoneRoutes,
          ...canvasRoutes,
          ...chatRoutes,
          ...aiRoutes,
          ...starlightRoutes,
          ...gardenRoutes,
          ...bucketListRoutes,
          ...galleryRoutes,
          ...calendarRoutes,
          ...watchPartyRoutes,
          ...jukeboxRoutes,
          ...journalRoutes,
          ...moneyRoutes,
          ...subsRoutes,
          ...tripKitRoutes,
          ...tonightRoutes,
          if (kPerfBenchCompiledIn) ...perfBenchRoutes,
        ],
      ),
    ],
    errorBuilder: (context, state) => AppErrorPage(uri: state.uri),
  );
  void recordCurrentRoute() {
    RouteMemory.remember(
      router.routerDelegate.currentConfiguration.uri.toString(),
    );
  }

  router.routerDelegate.addListener(recordCurrentRoute);
  recordCurrentRoute();
  return router;
}
