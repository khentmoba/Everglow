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
import 'app_error_page.dart';
import 'route_memory.dart';
import '../di/app_providers.dart' as di;

/// App-wide router configuration.
///
/// Each feature owns its route modules under `presentation/routes/`; this
/// file only composes them. Simple routes use URL parameters. Complex object
/// routes use `extra`.
/// Navigation examples:
///   context.go('/dashboard')
///   context.push('/cinema/video/123?title=Foo&type=movie')
///   context.push('/books/reader', extra: bookItem)
GoRouter createAppRouter() {
  final browserUri = Uri.base;
  // Keep root query jumps (for example `/?agent=cinema`) ahead of a saved page.
  final initialLocation = browserUri.path == '/' && browserUri.hasQuery
      ? '${browserUri.path}?${browserUri.query}'
      : RouteMemory.bootLocation ?? '/';
  final router = GoRouter(
    refreshListenable: di.authService,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final uri = state.uri;

      // Agent mode activation from query parameter (?agent=1, ?agent=khent, ?agent=cinema, ?agent=anime, ?agent=manga, etc.)
      final agentParam = uri.queryParameters['agent'] ?? uri.queryParameters['demo'];
      final jumpParam = uri.queryParameters['jump'] ?? uri.queryParameters['to'];
      String? targetRoute;

      if (agentParam != null) {
        final lower = agentParam.toLowerCase().trim();
        if (AgentMode.routeAliases.containsKey(lower)) {
          targetRoute = AgentMode.routeAliases[lower];
          final profile = lower == 'cinema' ? 'breyan' : 'khentsgdz';
          AgentMode.enable(profile: profile);
          di.authService.enableAgentSession(profile: profile);
        } else {
          final profile = AgentMode.parseProfile(agentParam);
          AgentMode.enable(profile: profile);
          di.authService.enableAgentSession(profile: profile);
        }
      } else if (AgentMode.isActive.value && di.authService.currentUser == null) {
        di.authService.enableAgentSession(profile: AgentMode.activeProfile.value);
      }

      if (jumpParam != null && jumpParam.isNotEmpty) {
        final lower = jumpParam.toLowerCase().trim();
        targetRoute = AgentMode.routeAliases[lower] ?? jumpParam;
        if (!targetRoute.startsWith('/')) targetRoute = '/$targetRoute';
      }

      // If opening doorway with an agent destination target, navigate directly
      if (loc == '/' && targetRoute != null && targetRoute != '/') {
        return targetRoute;
      }

      // The perf bench is reachable logged out (it carries its own fake data),
      // but only in builds made with --dart-define=EG_PERF_BENCH=true. Prefix
      // rather than exact-match so every bench scene stays reachable without
      // re-listing its path here; the guard is a compile-time constant, so none
      // of this exists in production builds.
      // In Agent Mode, all routes are accessible without bouncing to the gateway door.
      final isPublic = loc == '/' ||
          (kPerfBenchCompiledIn && loc.startsWith('/perf-bench')) ||
          AgentMode.isActive.value;

      // If the persisted session is still loading from disk, do NOT bounce
      // away from the requested location yet; wait for AuthService to notify.
      if (!di.authService.isSessionLoaded) return null;

      // Allow offline fallback (SharedPreferences currentUser) to reach dashboard
      // even when Firebase Auth is still pending; Firestore rules still enforce
      // server-side access, but the UI should not bounce.
      final authed =
          di.authService.isAuthenticated || di.authService.currentUser != null;
      // Boot restore (one-shot): a bare gateway reopens the remembered page
      // after a killed tab/PWA — directly when logged in, via the login's
      // `?from=` hop when logged out. Real links always win (any path or
      // any query skips this), so deep links and previews are untouched.
      // Not authed -> bounce to gate, remembering where the link pointed
      // so the gateway can take the user straight there after login
      // (PR preview deep links like <preview>/cinema).
      if (!authed && !isPublic) {
        return Uri(
          path: '/',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      // Cinema-only users stay inside /cinema and /anime (see
      // [AppErrorPage.cinemaOnlyRedirect]): couple pages would only
      // render empty for them (Firestore rules deny every read), so
      // anything else — deep links and restored pages included —
      // bounces to /cinema. (In Agent Mode, free navigation is allowed).
      if (authed && di.authService.isCinemaOnlyUser && !AgentMode.isActive.value) {
        final bounce = AppErrorPage.cinemaOnlyRedirect(loc);
        if (bounce != null) return bounce;
      }
      return null;
    },

    // Reopen where she left off after a killed tab/PWA: go_router uses
    // initialLocation only when the browser URL is exactly `/`, so real
    // links always win (any path or query skips the restore untouched).
    // Logged-out boots bounce through the usual `?from=` login hop below.
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
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
    errorBuilder: (context, state) => AppErrorPage(uri: state.uri),
  );
  // Remember every page so a killed tab/PWA reopens where Clair left off.
  // Unsafe pages (gateway, extra-only routes) are filtered inside.
  // The listener skips the boot route itself, so it is recorded too:
  // without this, opening a bookmarked page would never be remembered.
  void recordCurrentRoute() {
    RouteMemory.remember(
      router.routerDelegate.currentConfiguration.uri.toString(),
    );
  }

  router.routerDelegate.addListener(recordCurrentRoute);
  recordCurrentRoute();
  return router;
}
