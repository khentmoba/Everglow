import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart' as custom_theme;
import 'core/router/app_router.dart';
import 'services/auth_service.dart';
import 'services/presence_service.dart';
import 'services/storage_service.dart';
import 'features/books/data/services/our_books_service.dart';
import 'features/date_randomizer/data/services/date_idea_service.dart';
import 'features/guardian/data/services/guardian_service.dart';
import 'features/chat/data/services/chat_service.dart';
import 'features/daily_bloom/presentation/providers/garden_provider.dart';
import 'features/heartbeat/data/services/mood_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/jukebox/presentation/providers/jukebox_provider.dart';
import 'features/heartbeat/presentation/controllers/mood_controller.dart';
import 'features/guardian/presentation/controllers/guardian_controller.dart';
import 'features/watch_party/data/services/voice_chat_service.dart';
import 'features/watch_party/presentation/widgets/incoming_watch_party_banner.dart';
import 'features/ai/data/services/ai_service.dart';
import 'core/services/notification_service.dart';

/// Global key for SnackBar notifications.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  
  try {
    await dotenv.load(fileName: "assets/env.txt");
    print("Environment variables loaded successfully");
  } catch (e) {
    print("Warning: Could not load env.txt file: $e. Using fallbacks.");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore persistence for all platforms (including Web)
  // This fixes the "always buffering" issue and makes data "always there"
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  print("Firestore persistence enabled for robust real-time experience");

  // Self-hosted Google Fonts only — never fetch from the network at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Wire global keys into NotificationService so it can show
  // foreground SnackBars and navigate on notification tap.
  NotificationService.setScaffoldMessengerKey(_scaffoldMessengerKey);

  // Initialize push notifications (FCM) — non-critical, never block runApp
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    print("Warning: Push notification init failed: $e. Continuing without notifications.");
  }

  runZonedGuarded(
    () => runApp(const EverglowApp()),
    (error, stack) {
      final msg = error.toString();
      if (msg.contains('onSnapshotUnsubscribe') || msg.contains('FIRESTORE INTERNAL ASSERTION')) {
        if (kDebugMode) debugPrint('[Firestore] Known race condition (suppressed): $error');
      } else {
        if (kDebugMode) debugPrint('[Unhandled] $error\n$stack');
      }
    },
  );
}

class EverglowApp extends StatelessWidget {
  const EverglowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => StorageService()),
        Provider(create: (_) => PresenceService()),
        Provider(create: (_) => DateIdeaService()),
        Provider(create: (_) => OurBooksService()),
        Provider(create: (_) => GuardianService()),
        Provider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => GardenProvider()),
        Provider(create: (_) => MoodService()),
        ChangeNotifierProvider(
          create: (context) => MoodController(context.read<MoodService>()),
        ),
        ChangeNotifierProvider(create: (_) => AIService()),
        ChangeNotifierProvider(
          create: (context) => GuardianController(
            context.read<GuardianService>(),
            moodService: context.read<MoodService>(),
            authService: context.read<AuthService>(),
          )..setAIService(context.read<AIService>()),
        ),
        ChangeNotifierProvider(create: (_) => JukeboxProvider()),
      ],
      child: MaterialApp.router(
        title: 'Everglow v6.0.0',
        debugShowCheckedModeBanner: false,
        theme: custom_theme.AppTheme.gamifiedTheme,
        routerConfig: appRouter,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        builder: (context, child) => _AppRoot(child: child!),
      ),
    );
  }
}

/// Wraps every route (gateway, dashboard, chat, cinema, etc.)
/// so the silent incoming-call banner appears regardless of
/// which screen the user is on. Also keeps the global
/// `VoiceChatService.watchIncoming()` listener in sync with
/// the auth state.
class _AppRoot extends StatefulWidget {
  final Widget child;
  const _AppRoot({required this.child});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  AuthService? _authService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    if (_authService != auth) {
      _authService?.removeListener(_syncListener);
      _authService = auth;
      auth.addListener(_syncListener);
      _syncListener();
    }
  }

  @override
  void dispose() {
    _authService?.removeListener(_syncListener);
    super.dispose();
  }

  void _syncListener() {
    final auth = _authService;
    if (auth == null || !mounted) return;
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (auth.isCoupleUser && myUid != null && myUid.isNotEmpty) {
      VoiceChatService.watchIncoming(
        myUid: myUid,
        partnerUid: partnerUid,
      );
      // Expose context to NotificationService for push → navigation
      NotificationService.setNavContext(context);
    } else {
      VoiceChatService.clearIncomingWatcher();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AuthService, bool>(
      selector: (_, auth) => auth.isCoupleUser,
      builder: (context, isCoupleUser, child) {
        if (!isCoupleUser) return widget.child;
        return Stack(
          children: [
            widget.child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: false,
                child: IncomingWatchPartyBanner(),
              ),
            ),
          ],
        );
      },
    );
  }
}
