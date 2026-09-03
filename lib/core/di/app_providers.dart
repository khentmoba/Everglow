import "package:provider/provider.dart";
import "package:provider/single_child_widget.dart";

import "../../features/ai/data/services/ai_service.dart";
import "../../features/books/data/services/our_books_service.dart";
import "../../features/chat/data/services/chat_service.dart";
import "../../features/daily_bloom/presentation/providers/garden_provider.dart";
import "../../features/date_randomizer/data/services/date_idea_service.dart";
import "../../features/guardian/data/services/guardian_service.dart";
import "../../features/guardian/presentation/controllers/guardian_controller.dart";
import "../../features/heartbeat/data/services/mood_service.dart";
import "../../features/heartbeat/presentation/controllers/mood_controller.dart";
import "../../features/jukebox/data/services/spotify_auth_service.dart";
import "../../features/jukebox/data/services/spotify_player_service.dart";
import "../../features/jukebox/presentation/providers/jukebox_provider.dart";
import "../../features/jukebox/presentation/providers/music_stats_provider.dart";
import "../services/auth_service.dart";
import "../services/presence_service.dart";
import "../services/storage_service.dart";

/// Eager: the router (`app_router.dart`) uses this synchronously as its
/// `refreshListenable` at import time, so it must exist before `runApp`.
/// Everything else below is lazy (`create` defaults to `lazy: true`).
final AuthService authService = AuthService();

/// Startup-performance notes (why everything else is `create`, not `value`):
/// - The old file constructed Presence/Mood/AI/Guardian/Spotify/Chat singletons
///   as globals at import time — i.e. BEFORE `Firebase.initializeApp()` in
///   `main.dart` finished. Several of those constructors touch
///   `FirebaseFirestore.instance` / `FirebaseAuth` in field initializers, so
///   import-time construction both slowed first paint (synchronous work before
///   `runApp`) and raced Firebase init. Lazy `create` runs each constructor on
///   first `read`/`watch` instead — after bootstrap — so unused features
///   (Spotify, Guardian AI, Jukebox stats) cost zero until visited.
/// - `Provider`/`ChangeNotifierProvider(create:)` default to lazy already; the
///   explicit `lazy: true` below is documentation, not behavior change.
/// - Order matters: controllers read sibling services via `ctx.read` inside
///   their own `create`, so each service is listed BEFORE its controller.
final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider.value(value: authService),
  Provider(
    create: (_) => StorageService(),
    lazy: true,
  ), // plain service, no notify
  Provider(create: (_) => PresenceService(), lazy: true),
  Provider(create: (_) => DateIdeaService(), lazy: true),
  Provider(create: (_) => OurBooksService(), lazy: true),
  Provider(create: (_) => GuardianService(), lazy: true),
  Provider(create: (_) => ChatService(), lazy: true),
  ChangeNotifierProvider(create: (_) => GardenProvider()),
  Provider(create: (_) => MoodService(), lazy: true),
  ChangeNotifierProvider(create: (ctx) => MoodController(ctx.read<MoodService>())),
  ChangeNotifierProvider(create: (_) => AIService()),
  ChangeNotifierProvider(
    create: (ctx) => GuardianController(
      ctx.read<GuardianService>(),
      moodService: ctx.read<MoodService>(),
      authService: ctx.read<AuthService>(),
      aiService: ctx.read<AIService>(),
    ),
  ),
  ChangeNotifierProvider(create: (_) => SpotifyAuthService()),
  ChangeNotifierProvider(
    create: (ctx) {
      final spotifyAuth = ctx.read<SpotifyAuthService>();
      final player = SpotifyPlayerService(spotifyAuth);
      // Start listening to link status once auth is ready; actual init is lazy (needs user gesture).
      // Runs on first read of the player (jukebox route), NOT at app start.
      spotifyAuth.start();
      return player;
    },
  ),
  ChangeNotifierProvider(create: (_) => JukeboxProvider()),
  ChangeNotifierProvider(create: (_) => MusicStatsProvider()),
];