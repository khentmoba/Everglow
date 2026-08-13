import 'package:go_router/go_router.dart';

import '../../features/academy/presentation/routes/academy_routes.dart';
import '../../features/ai/presentation/routes/ai_routes.dart';
import '../../features/books/presentation/routes/books_routes.dart';
import '../../features/bucket_list/presentation/routes/bucket_list_routes.dart';
import '../../features/calendar/presentation/routes/calendar_routes.dart';
import '../../features/canvas/presentation/routes/canvas_routes.dart';
import '../../features/chat/presentation/routes/chat_routes.dart';
import '../../features/cinema/presentation/routes/cinema_routes.dart';
import '../../features/daily_bloom/presentation/routes/garden_routes.dart';
import '../../features/dashboard/presentation/routes/dashboard_routes.dart';
import '../../features/entry/presentation/routes/entry_routes.dart';
import '../../features/gallery/presentation/routes/gallery_routes.dart';
import '../../features/jellyfin/presentation/routes/jellyfin_routes.dart';
import '../../features/manga/presentation/routes/manga_routes.dart';
import '../../features/play_zone/presentation/routes/play_zone_routes.dart';
import '../../features/starlight_jar/presentation/routes/starlight_routes.dart';
import '../../features/watch_party/presentation/routes/watch_party_routes.dart';
import 'app_error_page.dart';

/// App-wide router configuration.
///
/// Each feature owns its route modules under `presentation/routes/`; this
/// file only composes them. Simple routes use URL parameters. Complex object
/// routes use `extra`.
/// Navigation examples:
///   context.go('/dashboard')
///   context.push('/cinema/video/123?title=Foo&type=movie')
///   context.push('/books/reader', extra: bookItem)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    ...gatewayRoutes,
    ...dashboardRoutes,
    ...cinemaRoutes,
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
    ...jellyfinRoutes,
  ],
  errorBuilder: (context, state) => AppErrorPage(uri: state.uri),
);
