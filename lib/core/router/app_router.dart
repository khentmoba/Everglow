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
import '../../features/watch_party/presentation/routes/watch_party_routes.dart';
import '../../features/jukebox/presentation/routes/jukebox_routes.dart';
import '../../features/journal/presentation/routes/journal_routes.dart';
import 'app_error_page.dart';
import 'route_memory.dart';
import 'temp_preview_routes.dart'; // TEMP-PREVIEW-ONLY: revert before PR
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
  final router = GoRouter(
    refreshListenable: di.authService,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      const publicPaths = {
        '/',
        '/temp-persist-a', // TEMP-PREVIEW-ONLY: revert before PR
        '/temp-persist-b', // TEMP-PREVIEW-ONLY: revert before PR
      };
      final isPublic = publicPaths.contains(loc);

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
      final restore = RouteMemory.bootRestoreTarget(
        authed: authed,
        cinemaOnly: di.authService.isCinemaOnlyUser,
        uri: state.uri,
        remembered: RouteMemory.consumeBootLocation(),
      );
      if (restore != null) return restore;
      // Not authed -> bounce to gate, remembering where the link pointed
      // so the gateway can take the user straight there after login
      // (PR preview deep links like <preview>/cinema).
      if (!authed && !isPublic) {
        return Uri(
          path: '/',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      // Cinema-only users stay inside /cinema: couple pages would only
      // render empty for them (Firestore rules deny every read), so bounce
      // anything else — deep links and restored pages included — to /cinema.
      if (authed &&
          di.authService.isCinemaOnlyUser &&
          loc != '/' &&
          !loc.startsWith('/cinema')) {
        return '/cinema';
      }
      return null;
    },

    initialLocation: '/',
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
      ...tempPreviewRoutes, // TEMP-PREVIEW-ONLY: revert before PR
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
